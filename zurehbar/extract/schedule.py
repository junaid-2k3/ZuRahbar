"""Parser for /passenger-services/operation-schedule/.

This page is the routing backbone of the whole dataset. Avada renders one tab
pane per route, and each pane holds:

* two `timeline-wrapper` blocks (`farward` / `backward`) listing the stations in
  order with the running time to the next station, e.g. "1:25 mins";
* two `<table>` elements, one per direction, giving per-station first bus and
  last bus times (split Monday~Thursday / Friday~Sunday), the headway in the
  column header, and the boarding platform.

The tables are treated as authoritative: they carry the times and platforms, and
on at least one route (ER-10) the timeline block disagrees with the table about
which stations are served. Travel times are computed from the difference between
consecutive first-bus timestamps, which are given to the second, and the
timeline figures are used as a cross-check. Every disagreement is recorded in
`ScheduleParse.anomalies` rather than smoothed over -- a route that quietly
loses a stop is a rider sent to a bus that never comes.
"""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass, field
from typing import Iterable

from selectolax.parser import HTMLParser

from zurehbar.model.naming import resolve

log = logging.getLogger(__name__)

SERVICE_TYPES = {"ER": "express", "SR": "standard", "DR": "direct"}
ROUTE_ID = re.compile(r"^[EDS]R-\d+[AB]?$", re.IGNORECASE)
HEADWAY = re.compile(r"every\s*(\d+)\s*(?:~|-|to)?\s*(\d+)?\s*minute", re.IGNORECASE)
# "6:30:00am", "8:14;30am" (a typo on the live page), "7:00pm", "8:02.30 am"
CLOCK = re.compile(r"(\d{1,2})\s*[:;.\s]\s*(\d{2})(?:\s*[:;.\s]\s*(\d{2}))?\s*([ap])\.?m", re.IGNORECASE)
# "1:25 mins", "1:55mins", "2 mins"
DURATION = re.compile(r"(?:(\d{1,2})\s*:\s*)?(\d{1,2})(?:\s*mins?)", re.IGNORECASE)
# The live page contains broken markup such as "Bakhshu Pul/td>" where a closing
# tag was typed without its opening angle bracket; the parser sees it as text.
BROKEN_TAG = re.compile(r"\s*/?\s*(?:td|tr|th|p|div|strong|span)\s*>\s*$", re.IGNORECASE)

# Cross-check tolerance between the table-derived travel time and the timeline
# figure printed on the page.
TRAVEL_TIME_TOLERANCE_SEC = 60


@dataclass
class ParsedStop:
    seq: int
    station_id: str
    name_source: str
    first_bus_mon_thu: str | None = None
    first_bus_fri_sun: str | None = None
    last_bus_mon_thu: str | None = None
    last_bus_fri_sun: str | None = None
    platform: str | None = None
    travel_time_to_next_sec: int | None = None
    _first_bus_sec: int | None = None


@dataclass
class ParsedDirection:
    label: str
    stops: list[ParsedStop]

    @property
    def origin_id(self) -> str:
        return self.stops[0].station_id if self.stops else ""

    @property
    def destination_id(self) -> str:
        return self.stops[-1].station_id if self.stops else ""


@dataclass
class ParsedRoute:
    route_id: str
    service_type: str
    headway_min_low: int | None
    headway_min_high: int | None
    directions: list[ParsedDirection]

    @property
    def mean_headway_min(self) -> float | None:
        if self.headway_min_low is None:
            return None
        high = self.headway_min_high or self.headway_min_low
        return (self.headway_min_low + high) / 2


@dataclass
class ScheduleParse:
    source_url: str
    routes: list[ParsedRoute]
    anomalies: list[str] = field(default_factory=list)

    def by_id(self, route_id: str) -> ParsedRoute:
        for route in self.routes:
            if route.route_id.upper() == route_id.upper():
                return route
        raise KeyError(route_id)

    def station_ids(self) -> set[str]:
        return {
            stop.station_id
            for route in self.routes
            for direction in route.directions
            for stop in direction.stops
        }


def _text(node) -> str:
    return " ".join(node.text().split())


def clean_station_name(name: str) -> str:
    """Strip the stray closing tags the site leaves inside table cells."""
    cleaned = " ".join((name or "").split())
    previous = None
    while cleaned != previous:
        previous = cleaned
        cleaned = BROKEN_TAG.sub("", cleaned).strip()
    return cleaned


def parse_clock(value: str) -> tuple[str, int] | None:
    """'6:31:25am' -> ('06:31', 23485). Returns None when unparseable."""
    match = CLOCK.search(value or "")
    if not match:
        return None
    hour, minute, second, meridiem = match.groups()
    hour_i, minute_i, second_i = int(hour), int(minute), int(second or 0)
    if hour_i == 12:
        hour_i = 0
    if meridiem.lower() == "p":
        hour_i += 12
    if not (0 <= hour_i <= 23 and 0 <= minute_i <= 59):
        return None
    return f"{hour_i:02d}:{minute_i:02d}", hour_i * 3600 + minute_i * 60 + second_i


def parse_duration(value: str) -> int | None:
    """'1:25 mins' -> 85 seconds; '2 mins' -> 120; blank -> None."""
    text = " ".join((value or "").split())
    match = DURATION.search(text)
    if not match:
        return None
    minutes, tail = match.group(1), match.group(2)
    if minutes is None:
        return int(tail) * 60
    return int(minutes) * 60 + int(tail)


def _parse_headway(table_html: str) -> tuple[int | None, int | None]:
    match = HEADWAY.search(table_html)
    if not match:
        return None, None
    low = int(match.group(1))
    high = int(match.group(2)) if match.group(2) else low
    return low, high


def _timeline(pane, direction: str) -> list[tuple[str, int | None]]:
    """Station label plus running time to the next station, in travel order."""
    items = []
    for node in pane.css(f"div.timeline-wrapper.{direction} div.timeline-item"):
        label_node = node.css_first("div.station-label")
        time_node = node.css_first("div.time")
        if not label_node:
            continue
        items.append((_text(label_node), parse_duration(_text(time_node) if time_node else "")))
    if direction == "backward":
        # The backward block is printed in forward order; each node still carries
        # the time to the next station in the backward direction.
        items.reverse()
    return items


def _parse_table(table) -> tuple[str, list[ParsedStop]]:
    rows = table.css("tr")
    if len(rows) < 3:
        return "", []
    header_cells = [_text(c) for c in rows[0].css("td,th")]
    label = header_cells[0] if header_cells else ""

    stops: list[ParsedStop] = []
    for row in rows[2:]:
        cells = [_text(c) for c in row.css("td,th")]
        if not cells or not cells[0]:
            continue
        name = clean_station_name(cells[0])
        if not name:
            continue
        values = cells[1:]
        times = [parse_clock(v) for v in values[:4]]
        platform = values[4] if len(values) > 4 and values[4] else None
        stop = ParsedStop(
            seq=len(stops),
            station_id=resolve(name),
            name_source=name,
            first_bus_mon_thu=times[0][0] if len(times) > 0 and times[0] else None,
            first_bus_fri_sun=times[1][0] if len(times) > 1 and times[1] else None,
            last_bus_mon_thu=times[2][0] if len(times) > 2 and times[2] else None,
            last_bus_fri_sun=times[3][0] if len(times) > 3 and times[3] else None,
            platform=platform,
            _first_bus_sec=times[0][1] if len(times) > 0 and times[0] else None,
        )
        stops.append(stop)
    return label, stops


def _apply_travel_times(
    route_id: str,
    direction_label: str,
    stops: list[ParsedStop],
    timeline: list[tuple[str, int | None]],
    anomalies: list[str],
) -> None:
    """Travel time from consecutive first-bus timestamps, cross-checked."""
    for current, following in zip(stops, stops[1:]):
        if current._first_bus_sec is not None and following._first_bus_sec is not None:
            delta = following._first_bus_sec - current._first_bus_sec
            if 0 < delta <= 3600:
                current.travel_time_to_next_sec = delta

    timeline_by_station: dict[str, int | None] = {}
    for label, seconds in timeline:
        timeline_by_station.setdefault(resolve(label), seconds)

    for stop in stops[:-1]:
        printed = timeline_by_station.get(stop.station_id)
        if stop.travel_time_to_next_sec is None:
            stop.travel_time_to_next_sec = printed
            continue
        if printed is not None and abs(printed - stop.travel_time_to_next_sec) > TRAVEL_TIME_TOLERANCE_SEC:
            anomalies.append(
                f"{route_id} [{direction_label}] {stop.name_source}: timetable implies "
                f"{stop.travel_time_to_next_sec}s to next stop, page timeline prints {printed}s"
            )

    timeline_ids = [resolve(label) for label, _ in timeline]
    table_ids = [stop.station_id for stop in stops]
    if timeline_ids and timeline_ids != table_ids:
        missing = set(timeline_ids) - set(table_ids)
        extra = set(table_ids) - set(timeline_ids)
        anomalies.append(
            f"{route_id} [{direction_label}] timeline and timetable disagree; "
            f"only in timeline: {sorted(missing) or 'none'}; only in timetable: {sorted(extra) or 'none'}"
        )


def parse_schedule(html: str, source_url: str = "") -> ScheduleParse:
    tree = HTMLParser(html)
    tab_labels = [_text(a) for a in tree.css("ul.nav-tabs li a")]
    route_ids = [label for label in tab_labels if ROUTE_ID.match(label)]
    panes = tree.css("div.tab-pane")

    anomalies: list[str] = []
    if len(route_ids) < len(panes):
        anomalies.append(f"{len(panes)} tab panes but only {len(route_ids)} route ids in the tab strip")

    routes: list[ParsedRoute] = []
    for index, pane in enumerate(panes):
        route_id = route_ids[index] if index < len(route_ids) else f"UNKNOWN-{index}"
        tables = pane.css("table")
        if len(tables) != 2:
            anomalies.append(f"{route_id}: expected 2 direction tables, found {len(tables)}")

        headway_low, headway_high = _parse_headway(pane.html or "")
        timelines = [_timeline(pane, "farward"), _timeline(pane, "backward")]

        directions: list[ParsedDirection] = []
        for table_index, table in enumerate(tables):
            label, stops = _parse_table(table)
            if not stops:
                anomalies.append(f"{route_id}: direction table {table_index} produced no stops")
                continue
            timeline = timelines[table_index] if table_index < len(timelines) else []
            _apply_travel_times(route_id, label, stops, timeline, anomalies)
            directions.append(ParsedDirection(label=label, stops=stops))

        if len(directions) == 2:
            forward_ids = [s.station_id for s in directions[0].stops]
            backward_ids = [s.station_id for s in directions[1].stops]
            if sorted(forward_ids) != sorted(backward_ids):
                only_forward = sorted(set(forward_ids) - set(backward_ids))
                only_backward = sorted(set(backward_ids) - set(forward_ids))
                anomalies.append(
                    f"{route_id}: direction station sets differ; only outbound: "
                    f"{only_forward or 'none'}; only inbound: {only_backward or 'none'}"
                )

        routes.append(
            ParsedRoute(
                route_id=route_id,
                service_type=SERVICE_TYPES.get(route_id[:2].upper(), "unknown"),
                headway_min_low=headway_low,
                headway_min_high=headway_high,
                directions=directions,
            )
        )

    return ScheduleParse(source_url=source_url, routes=routes, anomalies=anomalies)


def parse_schedule_file(path, source_url: str = "") -> ScheduleParse:
    from pathlib import Path

    return parse_schedule(Path(path).read_text(encoding="utf-8", errors="ignore"), source_url)
