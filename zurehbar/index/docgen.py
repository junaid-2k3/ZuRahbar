"""Turn the curated dataset and the scraped pages into retrieval documents.

Two families share one collection, separated by a `doc_type` payload field:

* **Structured-to-text.** Deterministic sentences generated from
  data/curated/: one document per route direction, per station, per fare band,
  plus service hours. Semantic search cannot traverse a graph, but it can find
  "which bus goes to Board Bazar" if that sentence exists, and the numbers in it
  come straight from the dataset rather than from a model.
* **Prose.** The FAQ, how-to-use, code of conduct, card registration, bicycle
  programme and news pages, chunked by `zurehbar.extract.prose`.

Every document carries `route_ids` and `station_ids` in its payload, which is
what makes "only ER-01" style filtering possible at query time.
"""

from __future__ import annotations

import hashlib
import json
import logging
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import urlparse

from zurehbar.config import load_config
from zurehbar.extract.prose import extract_page
from zurehbar.model import naming
from zurehbar.paths import CACHE_INDEX, CURATED_DIR

log = logging.getLogger(__name__)

SCHEDULE_URL = "https://transpeshawar.pk/passenger-services/operation-schedule/"
FARES_URL = "https://transpeshawar.pk/passenger-services/fares-recharge/"


@dataclass
class Document:
    doc_id: str
    doc_type: str
    title: str
    text: str
    source_url: str
    route_ids: list[str] = field(default_factory=list)
    station_ids: list[str] = field(default_factory=list)
    lang: str = "en"
    verified: bool = True
    section: str | None = None

    def payload(self) -> dict[str, Any]:
        return {
            "doc_id": self.doc_id,
            "doc_type": self.doc_type,
            "title": self.title,
            "text": self.text,
            "source_url": self.source_url,
            "route_ids": self.route_ids,
            "station_ids": self.station_ids,
            "lang": self.lang,
            "verified": self.verified,
            "section": self.section,
        }


def _load(name: str) -> Any:
    return json.loads((CURATED_DIR / f"{name}.json").read_text(encoding="utf-8"))


def _minutes(seconds: int | None) -> str:
    if not seconds:
        return "a few minutes"
    return f"{round(seconds / 60)} minutes"


def _time_12h(value: str | None) -> str | None:
    if not value:
        return None
    hour, _, minute = value.partition(":")
    hour_i = int(hour)
    suffix = "am" if hour_i < 12 else "pm"
    display = hour_i % 12 or 12
    return f"{display}:{minute} {suffix}"


def route_documents(routes: list[dict[str, Any]]) -> list[Document]:
    documents: list[Document] = []
    for route in routes:
        route_id = route["route_id"]
        label = route.get("map_label") or route_id
        service = route.get("service_type", "unknown").replace("_", " ")
        article = "an" if service[0] in "aeiou" else "a"
        length = route.get("length_km")
        headway_low, headway_high = route.get("headway_min_low"), route.get("headway_min_high")

        for direction in route.get("directions", []):
            names = [
                naming.canonical_name(stop["station_id"]) for stop in direction.get("stops", [])
            ]
            if len(names) < 2:
                continue
            stops = direction["stops"]
            first = _time_12h(stops[0].get("first_bus_mon_thu"))
            last = _time_12h(stops[0].get("last_bus_mon_thu"))
            platform = stops[0].get("platform")

            sentences = [
                f"Zu route {route_id} ({label}) is {article} {service} service running "
                f"{names[0]} to {names[-1]}.",
                f"It calls at {len(names)} stops in this direction: {', '.join(names)}.",
            ]
            if length:
                sentences.append(f"The route is {length} km long end to end.")
            if headway_low:
                span = (
                    f"{headway_low} to {headway_high}"
                    if headway_high and headway_high != headway_low
                    else f"{headway_low}"
                )
                sentences.append(f"Buses run every {span} minutes.")
            if first and last:
                sentences.append(
                    f"From {names[0]} the first bus leaves at {first} and the last bus at {last}."
                )
            if platform:
                sentences.append(f"Board at platform {platform} at {names[0]}.")
            total = sum(stop.get("travel_time_to_next_sec") or 0 for stop in stops)
            if total:
                sentences.append(f"End to end the ride takes about {_minutes(total)}.")
            if not route.get("has_timetable"):
                sentences.append(
                    "This route has no published timetable on the TransPeshawar website; its stops "
                    "are read from the network map."
                )

            documents.append(
                Document(
                    doc_id=f"route:{route_id}:{direction['origin_id']}:{direction['destination_id']}",
                    doc_type="route",
                    title=f"{route_id}: {names[0]} to {names[-1]}",
                    text=" ".join(sentences),
                    source_url=(
                        SCHEDULE_URL if route.get("has_timetable") else route["provenance"]["source_url"]
                    ),
                    route_ids=[route_id],
                    station_ids=[stop["station_id"] for stop in stops],
                    verified=route.get("stop_confidence") == "high",
                )
            )

        if not route.get("directions"):
            endpoints = " and ".join(route.get("endpoints", []))
            documents.append(
                Document(
                    doc_id=f"route:{route_id}",
                    doc_type="route",
                    title=f"{route_id}: {endpoints}",
                    text=(
                        f"Zu route {route_id} ({label}) is {article} {service} service between "
                        f"{endpoints}, {length} km long. TransPeshawar publishes no timetable or "
                        "stop list for this route, so its intermediate stops are not known here."
                    ),
                    source_url=route["provenance"]["source_url"],
                    route_ids=[route_id],
                    verified=False,
                )
            )
    return documents


def station_documents(stations: list[dict[str, Any]], routes: list[dict[str, Any]]) -> list[Document]:
    platforms: dict[tuple[str, str], str] = {}
    for route in routes:
        for direction in route.get("directions", []):
            for stop in direction.get("stops", []):
                if stop.get("platform"):
                    platforms[(stop["station_id"], route["route_id"])] = stop["platform"]

    documents: list[Document] = []
    for station in stations:
        station_id = station["station_id"]
        name = station["name"]
        served = station.get("served_by", [])
        sentences = [
            f"{name} is a Zu Peshawar stop served by "
            f"{', '.join(served) if served else 'no route in this dataset'}."
        ]
        if station.get("is_corridor_station"):
            sentences.append("It is a station on the main BRT corridor.")
        else:
            sentences.append("It is an off-corridor bus stop rather than a corridor station.")

        boarding = {
            route_id: platforms[(station_id, route_id)]
            for route_id in served
            if (station_id, route_id) in platforms
        }
        if boarding:
            sentences.append(
                "Boarding platforms: "
                + ", ".join(f"{route_id} at platform {value}" for route_id, value in boarding.items())
                + "."
            )
        other_names = list(station.get("aliases") or []) + list(station.get("urdu") or [])
        if other_names:
            sentences.append("Also written as " + ", ".join(other_names) + ".")

        documents.append(
            Document(
                doc_id=f"station:{station_id}",
                doc_type="station",
                title=name,
                text=" ".join(sentences),
                source_url=SCHEDULE_URL,
                route_ids=served,
                station_ids=[station_id],
            )
        )
    return documents


def fare_documents(fares: dict[str, Any]) -> list[Document]:
    bands = fares["bands"]
    table = "; ".join(
        (
            f"up to {band['max_km']} km costs Rs. {band['fare_pkr']}"
            if band["min_km"] == 0
            else (
                f"{band['min_km']} to {band['max_km']} km costs Rs. {band['fare_pkr']}"
                if band["max_km"]
                else f"over {band['min_km']} km costs Rs. {band['fare_pkr']}"
            )
        )
        for band in bands
    )
    documents = [
        Document(
            doc_id="fare:bands",
            doc_type="fare",
            title="Zu Peshawar bus fares",
            text=(
                f"Zu Peshawar bus fares are charged by the distance travelled, not by the number "
                f"of stops. Effective {fares['effective_from']}, the fares are: {table}. "
                f"A single journey ticket costs Rs. {fares['single_journey_ticket_pkr']}. "
                f"Express buses on feeder routes charge a flat fare of Rs. "
                f"{fares['feeder_express_flat_fare_pkr']}. "
                f"A Zu Card costs Rs. {fares['zu_card_price_pkr']}."
            ),
            source_url=FARES_URL,
        ),
        Document(
            doc_id="fare:zu-card",
            doc_type="fare",
            title="Zu Card price",
            text=(
                f"A Zu Card costs Rs. {fares['zu_card_price_pkr']}, bought from the ticket office "
                "at any Zu station. Buying one needs a valid National ID card and biometric "
                "verification. The card has no expiry and works on both Zu buses and Zu bicycles. "
                + (fares.get("zu_card_price_note") or "")
            ).strip(),
            source_url=fares.get("zu_card_price_source") or FARES_URL,
        ),
        Document(
            doc_id="fare:minimum",
            doc_type="fare",
            title="Minimum and maximum Zu fare",
            text=(
                f"The cheapest Zu bus fare is Rs. {bands[0]['fare_pkr']} for a trip under "
                f"{bands[0]['max_km']} km. The most anyone pays for one journey is Rs. "
                f"{fares['single_journey_ticket_pkr']}. Fares rose on 1 July 2025, when the "
                f"minimum went from Rs. {bands[0].get('previous_fare_pkr')} to Rs. "
                f"{bands[0]['fare_pkr']}; express routes on a flat fare were not increased."
            ),
            source_url=FARES_URL,
        ),
    ]
    return documents


def service_hours_document(hours: dict[str, Any]) -> Document:
    return Document(
        doc_id="service:hours",
        doc_type="service",
        title="Zu operating hours",
        text=(
            f"Zu Peshawar runs from {_time_12h(hours['opens'])} to {_time_12h(hours['closes'])}, "
            f"{hours['days']}, about 16 hours a day. {hours.get('note') or ''}"
        ).strip(),
        source_url=hours["provenance"]["source_url"],
    )


def _cached_pages() -> Iterable[tuple[str, Path]]:
    if not CACHE_INDEX.exists():
        return []
    config = load_config()
    index = json.loads(CACHE_INDEX.read_text(encoding="utf-8"))
    for entry in index.values():
        url = entry.get("url", "")
        if not entry.get("content_type", "").startswith("text/html"):
            continue
        if "/wp-json/" in url or not config.wants(url):
            continue
        path = Path(entry["path"])
        if path.exists():
            yield url, path


def prose_documents() -> list[Document]:
    documents: list[Document] = []
    known_stations = set(naming.known_stations())
    for url, path in _cached_pages():
        html = path.read_text(encoding="utf-8", errors="ignore")
        for chunk in extract_page(html, url):
            mentioned = sorted(
                station_id
                for station_id in known_stations
                if naming.canonical_name(station_id).lower() in chunk.text.lower()
            )
            documents.append(
                Document(
                    doc_id=f"prose:{chunk.doc_id}",
                    doc_type=chunk.doc_type,
                    title=chunk.title,
                    text=chunk.text,
                    source_url=url,
                    station_ids=mentioned[:20],
                    section=chunk.section,
                )
            )
    return documents


def build_documents() -> list[Document]:
    routes = _load("routes")
    stations = _load("stations")
    fares = _load("fares")
    hours = _load("service_hours")

    documents = (
        route_documents(routes)
        + station_documents(stations, routes)
        + fare_documents(fares)
        + [service_hours_document(hours)]
        + prose_documents()
    )

    by_id: dict[str, Document] = {document.doc_id: document for document in documents}
    return _dedupe_by_text(list(by_id.values()))


def _dedupe_by_text(documents: list[Document]) -> list[Document]:
    """The site serves identical content at two URLs.

    The FAQ, for instance, answers at both /frequently-asked-questions/ and
    /customer-services/frequently-asked-questions/. Indexing both halves the
    value of every retrieved slot and makes the assistant repeat itself, so the
    deeper, section-scoped URL wins and the shallow duplicate is dropped.
    """
    best: dict[str, Document] = {}
    for document in documents:
        key = hashlib.sha1(" ".join(document.text.split()).lower().encode("utf-8")).hexdigest()
        incumbent = best.get(key)
        if incumbent is None:
            best[key] = document
            continue
        depth = urlparse(document.source_url).path.count("/")
        incumbent_depth = urlparse(incumbent.source_url).path.count("/")
        if depth > incumbent_depth:
            best[key] = document
    return list(best.values())


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    documents = build_documents()
    output = CURATED_DIR / "documents.json"
    output.write_text(
        json.dumps([document.payload() for document in documents], indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    counts: dict[str, int] = {}
    for document in documents:
        counts[document.doc_type] = counts.get(document.doc_type, 0) + 1
    print(f"{len(documents)} documents ->", ", ".join(f"{v} {k}" for k, v in sorted(counts.items())))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
