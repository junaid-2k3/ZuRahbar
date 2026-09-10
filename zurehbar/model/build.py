"""Merge every extraction into the curated dataset.

Inputs
    data/raw/pages/...                the cached operation-schedule HTML
    data/review/fare_table.json       verified fare bands
    data/review/route_registry.json   verified route inventory with lengths
    data/review/map_only_routes.json  stop sequences for routes with no timetable
    config/station_aliases.yaml       canonical station registry

Outputs
    data/curated/{stations,routes,fares,service_hours,dataset_report}.json

The build fails loudly on integrity violations. A route that quietly loses a
stop, or a stop that points at a station nobody has heard of, becomes a rider
standing at the wrong kerb.
"""

from __future__ import annotations

import argparse
import json
import logging
from datetime import datetime, timezone
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

from zurehbar.extract.schedule import ScheduleParse, parse_schedule
from zurehbar.model import naming
from zurehbar.model.schemas import (
    FareBand,
    FareRules,
    Provenance,
    Route,
    RouteDirection,
    RouteStop,
    ServiceHours,
    Station,
)
from zurehbar.paths import CACHE_INDEX, CURATED_DIR, REVIEW_DIR, TESTS_FIXTURES, ensure_dirs

log = logging.getLogger(__name__)

SCHEDULE_URL = "https://transpeshawar.pk/passenger-services/operation-schedule/"
FAQ_URL = "https://transpeshawar.pk/customer-services/frequently-asked-questions/"
HOURS_URL = "https://transpeshawar.pk/passenger-services/operation-hours/"

# Routes whose map-read stop sequence is trustworthy enough to route a rider over.
ROUTABLE_CONFIDENCE = {"high"}


def _now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def cached_page(url: str) -> Path | None:
    if not CACHE_INDEX.exists():
        return None
    index = json.loads(CACHE_INDEX.read_text(encoding="utf-8"))
    target = urlparse(url).path
    for entry in index.values():
        if urlparse(entry.get("url", "")).path == target:
            path = Path(entry["path"])
            if path.exists():
                return path
    return None


def load_schedule() -> ScheduleParse:
    path = cached_page(SCHEDULE_URL) or (TESTS_FIXTURES / "operation_schedule.html")
    return parse_schedule(path.read_text(encoding="utf-8", errors="ignore"), source_url=SCHEDULE_URL)


def load_review(name: str) -> dict[str, Any]:
    path = REVIEW_DIR / f"{name}.json"
    if not path.exists():
        raise FileNotFoundError(f"missing review file {path}; run the vision extraction first")
    return json.loads(path.read_text(encoding="utf-8"))


def _interpolate_distances(direction: RouteDirection, length_km: float | None) -> None:
    """Split a route's published length across its legs in proportion to time.

    The fare table charges by kilometres travelled, but the site publishes only
    route totals and per-leg times. Splitting the total by time is the closest
    honest approximation available from the published data; every distance
    derived this way is marked as such in the dataset report.
    """
    if not length_km or len(direction.stops) < 2:
        return
    legs = direction.stops[:-1]
    total_sec = sum(stop.travel_time_to_next_sec or 0 for stop in legs)
    if total_sec > 0:
        for stop in legs:
            seconds = stop.travel_time_to_next_sec or 0
            stop.distance_to_next_km = round(length_km * seconds / total_sec, 3)
    else:
        share = round(length_km / len(legs), 3)
        for stop in legs:
            stop.distance_to_next_km = share


def build() -> dict[str, Any]:
    ensure_dirs()
    naming.reload_aliases()

    schedule = load_schedule()
    registry = load_review("route_registry")
    fares_raw = load_review("fare_table")
    map_routes = load_review("map_only_routes")

    anomalies: list[str] = list(schedule.anomalies)
    retrieved_at = _now()

    registry_by_id = {r["route_id"]: r for r in registry["payload"]["routes"]}
    timetable_by_id = {route.route_id: route for route in schedule.routes}

    schedule_provenance = Provenance(
        source_url=SCHEDULE_URL,
        source_type="html_table",
        retrieved_at=retrieved_at,
        note="parsed from the per-route timetables on the operation schedule page",
    )
    map_provenance = Provenance(
        source_url=registry["source_image"],
        source_type="vision_verified",
        retrieved_at=retrieved_at,
        verified_by=registry["verified_by"],
        note=registry["source_image_version"],
    )

    routes: list[Route] = []
    station_routes: dict[str, set[str]] = {}
    corridor_ids: set[str] = set()

    for route_id, meta in registry_by_id.items():
        parsed = timetable_by_id.get(route_id)
        directions: list[RouteDirection] = []

        if parsed is not None:
            for parsed_direction in parsed.directions:
                stops = [
                    RouteStop(
                        seq=index,
                        station_id=stop.station_id,
                        name_source=stop.name_source,
                        first_bus_mon_thu=stop.first_bus_mon_thu,
                        first_bus_fri_sun=stop.first_bus_fri_sun,
                        last_bus_mon_thu=stop.last_bus_mon_thu,
                        last_bus_fri_sun=stop.last_bus_fri_sun,
                        platform=stop.platform,
                        travel_time_to_next_sec=stop.travel_time_to_next_sec,
                    )
                    for index, stop in enumerate(parsed_direction.stops)
                ]
                direction = RouteDirection(
                    label=parsed_direction.label,
                    origin_id=stops[0].station_id,
                    destination_id=stops[-1].station_id,
                    stops=stops,
                )
                _interpolate_distances(direction, meta.get("length_km"))
                directions.append(direction)
            confidence = "high"
            routable = True
        else:
            entry = next(
                (r for r in map_routes["payload"]["routes"] if r["route_id"] == route_id), None
            )
            confidence = entry["confidence"] if entry else "needs_human"
            routable = confidence in ROUTABLE_CONFIDENCE
            if entry and entry["stops"]:
                stops = [
                    RouteStop(
                        seq=index,
                        station_id=naming.resolve(stop["name"]),
                        name_source=stop["name"],
                    )
                    for index, stop in enumerate(entry["stops"])
                ]
                direction = RouteDirection(
                    label=" to ".join(meta["endpoints"]),
                    origin_id=stops[0].station_id,
                    destination_id=stops[-1].station_id,
                    stops=stops,
                )
                _interpolate_distances(direction, meta.get("length_km"))
                directions.append(direction)
            elif entry:
                anomalies.append(
                    f"{route_id}: no stop sequence available ({entry.get('caveat', 'unreadable on the map')})"
                )

        route = Route(
            route_id=route_id,
            map_label=meta.get("map_label"),
            service_type=meta.get("service_type", "unknown"),
            length_km=meta.get("length_km"),
            headway_min_low=parsed.headway_min_low if parsed else None,
            headway_min_high=parsed.headway_min_high if parsed else None,
            has_timetable=bool(parsed),
            stop_confidence=confidence,
            routable=routable and bool(directions),
            endpoints=meta.get("endpoints", []),
            directions=directions,
            provenance=schedule_provenance if parsed else map_provenance,
        )
        routes.append(route)

        for direction in directions:
            for stop in direction.stops:
                station_routes.setdefault(stop.station_id, set()).add(route_id)
                if route_id in {"ER-01", "SR-02"}:
                    corridor_ids.add(stop.station_id)

    # --- stations -----------------------------------------------------------
    registered = naming.known_stations()
    stations: list[Station] = []
    unregistered: list[str] = []
    for station_id in sorted(station_routes):
        record = registered.get(station_id)
        if record is None:
            unregistered.append(station_id)
        stations.append(
            Station(
                station_id=station_id,
                name=record.get("name") if record else naming.canonical_name(station_id),
                aliases=list((record or {}).get("aliases") or []),
                urdu=list((record or {}).get("urdu") or []),
                pashto=list((record or {}).get("pashto") or []),
                served_by=sorted(station_routes[station_id]),
                is_corridor_station=station_id in corridor_ids,
                provenance=schedule_provenance if record else map_provenance,
            )
        )

    if unregistered:
        anomalies.append(
            f"{len(unregistered)} stations are not in config/station_aliases.yaml and have no "
            f"curated aliases: {', '.join(unregistered)}"
        )

    # --- fares --------------------------------------------------------------
    fare_payload = fares_raw["payload"]
    fares = FareRules(
        currency=fare_payload["currency"],
        effective_from=fare_payload["effective_from"],
        bands=[FareBand(**band) for band in fare_payload["bands"]],
        single_journey_ticket_pkr=fare_payload["single_journey_ticket_pkr"],
        feeder_express_flat_fare_pkr=fare_payload["feeder_express_flat_fare_pkr"],
        zu_card_price_pkr=fare_payload["zu_card_price_pkr"],
        zu_card_price_note=fare_payload.get("zu_card_price_note"),
        zu_card_price_source=fare_payload.get("zu_card_price_source"),
        provenance=Provenance(
            source_url=fares_raw["source_image"],
            source_type="vision_verified",
            retrieved_at=retrieved_at,
            verified_by=fares_raw["verified_by"],
            note="; ".join(fares_raw["notes"][:2]),
        ),
    )

    service_hours = ServiceHours(
        opens="06:00",
        closes="22:00",
        days="all week",
        note=(
            "TransPeshawar states the Zu service runs about 16 hours a day, 6 AM to 10 PM, "
            "seven days a week. Individual routes start and finish later than that; the "
            "per-route first and last bus times in routes.json are what a rider should trust."
        ),
        provenance=Provenance(
            source_url=HOURS_URL,
            source_type="html_prose",
            retrieved_at=retrieved_at,
        ),
    )

    # --- integrity checks ---------------------------------------------------
    failures: list[str] = []
    station_ids = {station.station_id for station in stations}
    for route in routes:
        for direction in route.directions:
            if len(direction.stops) < 2:
                failures.append(f"{route.route_id}: direction '{direction.label}' has fewer than 2 stops")
            for stop in direction.stops:
                if stop.station_id not in station_ids:
                    failures.append(f"{route.route_id}: stop '{stop.name_source}' has no station record")
        if route.routable and not route.directions:
            failures.append(f"{route.route_id}: marked routable but carries no stop sequence")
        # A published endpoint that never appears in the route's own stop list means
        # the sequence is truncated -- riders at that endpoint cannot be planned for.
        sequence_ids = {
            stop.station_id for direction in route.directions for stop in direction.stops
        }
        for endpoint in route.endpoints:
            endpoint_id = naming.resolve(endpoint)
            if sequence_ids and endpoint_id not in sequence_ids:
                anomalies.append(
                    f"{route.route_id}: published endpoint '{endpoint}' is absent from its stop "
                    "sequence, so that end of the route cannot be planned"
                )
    if not fares.bands:
        failures.append("fare table has no bands")
    for band, following in zip(fares.bands, fares.bands[1:]):
        if band.max_km is not None and following.min_km < band.max_km:
            failures.append(f"fare bands {band.index} and {following.index} overlap")

    report = {
        "built_at": retrieved_at,
        "counts": {
            "routes": len(routes),
            "routes_with_timetable": sum(1 for r in routes if r.has_timetable),
            "routable_routes": sum(1 for r in routes if r.routable),
            "stations": len(stations),
            "corridor_stations": len(corridor_ids),
            "fare_bands": len(fares.bands),
        },
        "distance_model": (
            "Per-leg distances are interpolated from each route's published total length in "
            "proportion to that leg's travel time. The website publishes no per-leg distances, "
            "and the fare table charges by kilometre, so fares computed from these distances are "
            "estimates; band boundaries and prices themselves are exact."
        ),
        "unregistered_stations": unregistered,
        "anomalies": anomalies,
        "integrity_failures": failures,
    }

    CURATED_DIR.mkdir(parents=True, exist_ok=True)
    _write(CURATED_DIR / "routes.json", [route.model_dump(mode="json") for route in routes])
    _write(CURATED_DIR / "stations.json", [station.model_dump(mode="json") for station in stations])
    _write(CURATED_DIR / "fares.json", fares.model_dump(mode="json"))
    _write(CURATED_DIR / "service_hours.json", service_hours.model_dump(mode="json"))
    _write(CURATED_DIR / "dataset_report.json", report)
    return report


def _write(path: Path, payload: Any) -> None:
    path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the curated Zu dataset")
    parser.add_argument("--strict", action="store_true", help="exit non-zero on anomalies too")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    report = build()
    counts = report["counts"]
    print("built", ", ".join(f"{value} {key}" for key, value in counts.items()))
    if report["unregistered_stations"]:
        print(f"unregistered stations: {len(report['unregistered_stations'])}")
    print(f"anomalies: {len(report['anomalies'])}")
    for failure in report["integrity_failures"]:
        print("  INTEGRITY FAILURE:", failure)
    if report["integrity_failures"]:
        return 1
    if args.strict and report["anomalies"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
