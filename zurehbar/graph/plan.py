"""Journey planning and fare calculation -- the tools Rehbar calls.

Retrieval alone cannot answer "how do I get from University Town to Saddar
Bazaar". These two functions compute the answer deterministically from the
curated dataset; Qwen's job is to phrase the result and to ask for whatever the
rider left out, never to invent a route or a price.
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field
from datetime import time as clock_time
from typing import Any

import networkx as nx

from zurehbar.graph.network import NetworkData, build_network
from zurehbar.model import naming

WEEKEND = {"friday", "saturday", "sunday"}


@dataclass
class Leg:
    route_id: str
    route_label: str | None
    service_type: str
    direction_label: str | None
    board_station_id: str
    board_station: str
    alight_station_id: str
    alight_station: str
    platform: str | None
    stop_count: int
    ride_time_min: float
    wait_time_min: float
    distance_km: float
    intermediate_stations: list[str] = field(default_factory=list)
    first_bus: str | None = None
    last_bus: str | None = None


@dataclass
class FareBreakdown:
    total_pkr: int
    basis: str
    distance_km: float
    band_index: int | None
    is_estimate: bool
    note: str


@dataclass
class JourneyPlan:
    found: bool
    origin_id: str
    destination_id: str
    origin: str
    destination: str
    legs: list[Leg] = field(default_factory=list)
    transfers: list[str] = field(default_factory=list)
    total_time_min: float = 0.0
    fare: FareBreakdown | None = None
    service_available: bool | None = None
    warnings: list[str] = field(default_factory=list)
    message: str = ""

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _resolve_station(name: str, network: NetworkData) -> tuple[str | None, list[str]]:
    station_id = naming.resolve(name)
    if network.has_station(station_id):
        return station_id, []
    needle = naming.slugify(name)
    suggestions = [
        sid for sid in network.stations if needle and (needle in sid or sid in needle)
    ]
    if not suggestions:
        tokens = {token for token in needle.split("-") if len(token) > 3}
        suggestions = [
            sid for sid in network.stations if tokens & set(sid.split("-"))
        ]
    return None, sorted(suggestions)[:5]


def _parse_time(value: str | None) -> clock_time | None:
    if not value:
        return None
    text = value.strip().lower().replace(".", ":")
    meridiem = None
    for suffix in ("am", "pm"):
        if text.endswith(suffix):
            meridiem = suffix
            text = text[: -len(suffix)].strip()
    parts = text.split(":")
    try:
        hour = int(parts[0])
        minute = int(parts[1]) if len(parts) > 1 else 0
    except (ValueError, IndexError):
        return None
    if meridiem == "pm" and hour < 12:
        hour += 12
    if meridiem == "am" and hour == 12:
        hour = 0
    if not (0 <= hour <= 23 and 0 <= minute <= 59):
        return None
    return clock_time(hour, minute)


def calculate_fare(legs: list[Leg], network: NetworkData) -> FareBreakdown:
    """Fare for a whole journey.

    Zu charges by distance travelled, in nine bands, capped at the price of a
    single-journey ticket. The fare image adds one exception: express buses
    *running on feeder routes* charge a flat Rs. 55 instead.

    That exception is deliberately not applied automatically. The site never
    states which express routes count as feeder services -- ER-01 is the main
    corridor express, while ER-09, ER-12 and ER-16 run well off-corridor -- and
    charging a rider the flat fare on a corridor express would be wrong in the
    direction that costs them money. So the distance band is returned as the
    answer and the flat-fare exception is surfaced as a note whenever an express
    leg is involved, for Rehbar to mention rather than assert.

    The distances themselves are the interpolated per-leg figures from the build
    step: the site publishes each route's total length and each leg's running
    time, never per-leg distances. Band boundaries and prices are exact; the
    kilometres a given trip is credited with are an estimate.
    """
    fares = network.fares
    distance = round(sum(leg.distance_km for leg in legs), 2)
    single_ticket = fares["single_journey_ticket_pkr"]
    flat = fares["feeder_express_flat_fare_pkr"]

    band_index = None
    fare = fares["bands"][-1]["fare_pkr"]
    for band in fares["bands"]:
        upper = band["max_km"]
        if distance >= band["min_km"] - 1e-9 and (upper is None or distance <= upper + 1e-9):
            fare, band_index = band["fare_pkr"], band["index"]
            break

    fare = min(fare, single_ticket)
    note = (
        f"About {distance} km of travel falls in fare band {band_index}, Rs. {fare}. "
        "Distances are interpolated from published route lengths, so treat the band as "
        "approximate when a trip sits near a boundary."
    )
    if any(leg.service_type in {"express", "super_express"} for leg in legs):
        note += (
            f" This trip uses an express service; express buses on feeder routes are charged a "
            f"flat Rs. {flat}, so the fare may be that instead. The website does not say which "
            "express routes count as feeder services."
        )

    return FareBreakdown(
        total_pkr=fare,
        basis="distance_band",
        distance_km=distance,
        band_index=band_index,
        is_estimate=True,
        note=note,
    )


def _service_window(leg: Leg, at: clock_time, weekend: bool) -> bool | None:
    first, last = leg.first_bus, leg.last_bus
    if not first or not last:
        return None
    first_t, last_t = _parse_time(first), _parse_time(last)
    if not first_t or not last_t:
        return None
    return first_t <= at <= last_t


def plan_journey(
    origin: str,
    destination: str,
    time_of_day: str | None = None,
    day_of_week: str | None = None,
    network: NetworkData | None = None,
) -> JourneyPlan:
    network = network or build_network()

    origin_id, origin_hints = _resolve_station(origin, network)
    destination_id, destination_hints = _resolve_station(destination, network)

    if origin_id is None or destination_id is None:
        unknown = origin if origin_id is None else destination
        hints = origin_hints if origin_id is None else destination_hints
        return JourneyPlan(
            found=False,
            origin_id=origin_id or "",
            destination_id=destination_id or "",
            origin=origin,
            destination=destination,
            message=f"No Zu station matches {unknown!r}.",
            warnings=[f"Did you mean: {', '.join(hints)}?"] if hints else [],
        )

    if origin_id == destination_id:
        return JourneyPlan(
            found=False,
            origin_id=origin_id,
            destination_id=destination_id,
            origin=naming.canonical_name(origin_id),
            destination=naming.canonical_name(destination_id),
            message="Origin and destination are the same station.",
        )

    source, target = network.station_node(origin_id), network.station_node(destination_id)
    try:
        path = nx.shortest_path(network.graph, source, target, weight="weight")
    except nx.NetworkXNoPath:
        return JourneyPlan(
            found=False,
            origin_id=origin_id,
            destination_id=destination_id,
            origin=naming.canonical_name(origin_id),
            destination=naming.canonical_name(destination_id),
            message="No Zu route connects these two stations in the current dataset.",
            warnings=_coverage_warnings(network, origin_id, destination_id),
        )

    legs = _legs_from_path(network, path)
    plan = JourneyPlan(
        found=bool(legs),
        origin_id=origin_id,
        destination_id=destination_id,
        origin=naming.canonical_name(origin_id),
        destination=naming.canonical_name(destination_id),
        legs=legs,
        transfers=[leg.board_station for leg in legs[1:]],
        total_time_min=round(sum(leg.ride_time_min + leg.wait_time_min for leg in legs), 1),
    )
    plan.fare = calculate_fare(legs, network)

    at = _parse_time(time_of_day)
    if at is not None:
        weekend = (day_of_week or "").strip().lower() in WEEKEND
        windows = [_service_window(leg, at, weekend) for leg in legs]
        if any(window is False for window in windows):
            plan.service_available = False
            closed = [leg.route_id for leg, window in zip(legs, windows) if window is False]
            plan.warnings.append(
                f"At {time_of_day} these routes are outside their published service hours: "
                f"{', '.join(closed)}. Zu runs roughly 06:00 to 22:00, and individual routes "
                "stop earlier."
            )
        elif all(window is True for window in windows):
            plan.service_available = True

    if not legs:
        plan.message = "The two stations resolve to the same point on the network."
    return plan


def _coverage_warnings(network: NetworkData, origin_id: str, destination_id: str) -> list[str]:
    """Explain a missing path when the cause is missing data, not a missing bus.

    Nine routes have no timetable on the website, and for three of them the
    network map is too dense to read a stop sequence off. Those routes are in the
    dataset but excluded from planning, so a rider whose trip depends on one gets
    told the gap is ours, not the network's.
    """
    warnings: list[str] = []
    for station_id in (origin_id, destination_id):
        station = network.stations.get(station_id, {})
        unroutable = [
            route_id
            for route_id in station.get("served_by", [])
            if not network.routes.get(route_id, {}).get("routable")
        ]
        for route_id, route in network.routes.items():
            endpoints = {naming.resolve(name) for name in route.get("endpoints", [])}
            if station_id not in endpoints or route_id in unroutable:
                continue
            # A route can be routable overall yet still be missing this station:
            # DR-14 is listed as starting at Board Bazar, but the map only yields
            # its stop sequence from PTCL Office onwards.
            in_sequence = any(
                stop["station_id"] == station_id
                for direction in route.get("directions", [])
                for stop in direction.get("stops", [])
            )
            if not in_sequence:
                unroutable.append(route_id)
        if unroutable:
            name = naming.canonical_name(station_id)
            warnings.append(
                f"{name} is served by {', '.join(sorted(unroutable))}, whose stop sequence is not "
                "published on the website, so those routes are excluded from planning. The trip "
                "may well be possible on one of them."
            )
    if not warnings:
        warnings.append(
            "Some routes have no published stop list and are excluded from planning; "
            "the trip may still be possible in practice."
        )
    return warnings


def _legs_from_path(network: NetworkData, path: list[str]) -> list[Leg]:
    graph = network.graph
    legs: list[Leg] = []
    current: dict[str, Any] | None = None

    for previous, node in zip(path, path[1:]):
        edge = graph.edges[previous, node]
        kind = edge.get("kind")

        if kind == "board":
            data = graph.nodes[node]
            route = network.routes.get(data["route_id"], {})
            weekday_first = data.get("first_bus_mon_thu")
            weekday_last = data.get("last_bus_mon_thu")
            current = {
                "route_id": data["route_id"],
                "route_label": route.get("map_label"),
                "service_type": route.get("service_type", "unknown"),
                "direction_label": data.get("direction_label"),
                "board_station_id": data["station_id"],
                "platform": data.get("platform"),
                "wait_sec": edge.get("weight", 0),
                "ride_sec": 0,
                "distance_km": 0.0,
                "stations": [data["station_id"]],
                "first_bus": weekday_first,
                "last_bus": weekday_last,
            }
        elif kind == "ride" and current is not None:
            current["ride_sec"] += edge.get("weight", 0)
            current["distance_km"] += edge.get("distance_km", 0.0) or 0.0
            current["stations"].append(graph.nodes[node]["station_id"])
        elif kind == "alight" and current is not None:
            stations = current["stations"]
            legs.append(
                Leg(
                    route_id=current["route_id"],
                    route_label=current["route_label"],
                    service_type=current["service_type"],
                    direction_label=current["direction_label"],
                    board_station_id=stations[0],
                    board_station=naming.canonical_name(stations[0]),
                    alight_station_id=stations[-1],
                    alight_station=naming.canonical_name(stations[-1]),
                    platform=current["platform"],
                    stop_count=len(stations) - 1,
                    ride_time_min=round(current["ride_sec"] / 60, 1),
                    wait_time_min=round(current["wait_sec"] / 60, 1),
                    distance_km=round(current["distance_km"], 2),
                    intermediate_stations=[
                        naming.canonical_name(station) for station in stations[1:-1]
                    ],
                    first_bus=current["first_bus"],
                    last_bus=current["last_bus"],
                )
            )
            current = None

    return [leg for leg in legs if leg.stop_count > 0]
