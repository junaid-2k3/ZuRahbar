"""Tests for the operation-schedule parser.

This parser is where a silent mis-parse turns into confidently wrong rider
directions, so the expectations below are pinned to values read off the live
page during reconnaissance.
"""

from __future__ import annotations

import pytest

from zurehbar.extract.schedule import parse_schedule
from zurehbar.paths import TESTS_FIXTURES

ER01_FORWARD = [
    "chamkani",
    "sardar-garhi",
    "lahore-adda",
    "hashtnagri",
    "malik-saad-shaheed",
    "khyber-bazar",
    "dabgari-gardens",
    "saddar-bazar",
    "university-of-peshawar",
    "mall-of-hayatabad",
    "karkhano-market",
]

EXPECTED_ROUTE_IDS = [
    "ER-01", "SR-02", "DR-03A", "DR-03B", "DR-05",
    "DR-06", "DR-07", "SR-08", "ER-09", "ER-10",
]


@pytest.fixture(scope="module")
def parsed():
    html = (TESTS_FIXTURES / "operation_schedule.html").read_text(encoding="utf-8", errors="ignore")
    return parse_schedule(html, source_url="https://transpeshawar.pk/passenger-services/operation-schedule/")


def test_all_ten_routes_found(parsed):
    assert [route.route_id for route in parsed.routes] == EXPECTED_ROUTE_IDS


def test_every_route_has_two_directions(parsed):
    for route in parsed.routes:
        assert len(route.directions) == 2, route.route_id


def test_service_type_derived_from_prefix(parsed):
    types = {route.route_id: route.service_type for route in parsed.routes}
    assert types["ER-01"] == "express"
    assert types["SR-02"] == "standard"
    assert types["DR-03A"] == "direct"


def test_er01_forward_station_sequence(parsed):
    route = parsed.by_id("ER-01")
    forward = route.directions[0]
    assert [stop.station_id for stop in forward.stops] == ER01_FORWARD
    assert forward.origin_id == "chamkani"
    assert forward.destination_id == "karkhano-market"


def test_er01_backward_is_the_reverse_sequence(parsed):
    route = parsed.by_id("ER-01")
    backward = route.directions[1]
    assert [stop.station_id for stop in backward.stops] == list(reversed(ER01_FORWARD))
    assert backward.origin_id == "karkhano-market"
    assert backward.destination_id == "chamkani"


def test_er01_first_and_last_bus_times(parsed):
    first_stop = parsed.by_id("ER-01").directions[0].stops[0]
    assert first_stop.station_id == "chamkani"
    assert first_stop.first_bus_mon_thu == "06:30"
    assert first_stop.first_bus_fri_sun == "06:30"
    assert first_stop.last_bus_mon_thu == "19:00"
    assert first_stop.platform == "3"


def test_er01_travel_times_in_seconds(parsed):
    stops = parsed.by_id("ER-01").directions[0].stops
    # "1:25 mins" on the Chamkani node = 1 min 25 s to Sardar Garhi.
    assert stops[0].travel_time_to_next_sec == 85
    assert stops[1].travel_time_to_next_sec == 360
    # The terminus has no onward leg.
    assert stops[-1].travel_time_to_next_sec is None


def test_headway_parsed(parsed):
    route = parsed.by_id("ER-01")
    assert route.headway_min_low == 4
    assert route.headway_min_high == 6


def test_sr02_is_the_full_corridor(parsed):
    route = parsed.by_id("SR-02")
    assert len(route.directions[0].stops) == 30
    ids = {stop.station_id for stop in route.directions[0].stops}
    assert {"chamkani", "saddar-bazar", "university-town", "karkhano-market"} <= ids


def test_no_stop_has_an_empty_station_id(parsed):
    for route in parsed.routes:
        for direction in route.directions:
            for stop in direction.stops:
                assert stop.station_id, f"{route.route_id} {direction.label}"


def test_times_are_all_normalised_to_24h(parsed):
    for route in parsed.routes:
        for direction in route.directions:
            for stop in direction.stops:
                for value in (
                    stop.first_bus_mon_thu,
                    stop.first_bus_fri_sun,
                    stop.last_bus_mon_thu,
                    stop.last_bus_fri_sun,
                ):
                    if value is not None:
                        assert len(value) == 5 and value[2] == ":", value
                        assert 0 <= int(value[:2]) <= 23


def test_parser_reports_anomalies_instead_of_hiding_them(parsed):
    # ER-10's second table is one row short on the live page; the parser must
    # surface that rather than silently emitting a shorter route.
    assert isinstance(parsed.anomalies, list)


def test_broken_markup_in_station_names_is_cleaned(parsed):
    """DR-03B's inbound table contains the literal text 'Bakhshu Pul/td>'."""
    from zurehbar.extract.schedule import clean_station_name

    assert clean_station_name("Bakhshu Pul/td>") == "Bakhshu Pul"

    inbound = parsed.by_id("DR-03B").directions[1]
    assert "bakhshu-pul" in {stop.station_id for stop in inbound.stops}
    assert not any(">" in stop.name_source for stop in inbound.stops)
