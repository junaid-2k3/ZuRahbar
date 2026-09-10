"""Journey planning and fare rules.

These run against the built dataset in data/curated/, so they double as a check
that the build still produces a network a rider can be routed across.
"""

from __future__ import annotations

import pytest

from zurehbar.graph.network import build_network
from zurehbar.graph.plan import calculate_fare, plan_journey
from zurehbar.paths import CURATED_DIR

pytestmark = pytest.mark.skipif(
    not (CURATED_DIR / "routes.json").exists(),
    reason="run `python -m zurehbar.model.build` first",
)


@pytest.fixture(scope="module")
def network():
    return build_network()


def test_one_seat_ride_along_the_corridor(network):
    plan = plan_journey("Chamkani", "Karkhano Market", network=network)
    assert plan.found
    assert len(plan.legs) == 1
    assert plan.legs[0].route_id in {"ER-01", "SR-02", "XER-15"}
    assert plan.legs[0].platform


def test_trip_requiring_a_transfer_names_the_transfer_station(network):
    plan = plan_journey("Chamkani", "Kohat Adda", network=network)
    assert plan.found
    assert len(plan.legs) >= 2
    assert plan.transfers
    assert plan.legs[0].alight_station == plan.legs[1].board_station


def test_rider_spellings_and_urdu_reach_the_same_plan(network):
    english = plan_journey("Saddar Bazar", "Karkhano Market", network=network)
    roman = plan_journey("sadar bazaar", "Kharkhano", network=network)
    urdu = plan_journey("صدر", "کارخانو مارکیٹ", network=network)
    assert english.found and roman.found and urdu.found
    assert english.origin_id == roman.origin_id == urdu.origin_id
    assert english.destination_id == roman.destination_id == urdu.destination_id


def test_unknown_station_suggests_alternatives(network):
    plan = plan_journey("Hogwarts", "Saddar Bazar", network=network)
    assert not plan.found
    assert "No Zu station matches" in plan.message


def test_late_night_trip_is_flagged_as_outside_service_hours(network):
    plan = plan_journey("Chamkani", "Kohat Adda", time_of_day="11:00pm", network=network)
    assert plan.service_available is False
    assert any("service hours" in warning for warning in plan.warnings)


def test_morning_trip_is_within_service_hours(network):
    plan = plan_journey("Chamkani", "Saddar Bazar", time_of_day="9:00am", network=network)
    assert plan.service_available is True


def test_missing_stop_data_is_reported_as_our_gap_not_a_missing_bus(network):
    """DR-14 starts at Board Bazar, but the map only yields stops from PTCL Office on."""
    plan = plan_journey("Board Bazar", "Regi Model Town", network=network)
    assert not plan.found
    assert any("DR-14" in warning for warning in plan.warnings)
    assert any("not published" in warning for warning in plan.warnings)


def test_fare_bands_match_the_published_table(network):
    from zurehbar.graph.plan import Leg

    def fare_for(km: float) -> int:
        leg = Leg(
            route_id="SR-02", route_label=None, service_type="standard", direction_label=None,
            board_station_id="a", board_station="A", alight_station_id="b", alight_station="B",
            platform=None, stop_count=1, ride_time_min=1, wait_time_min=1, distance_km=km,
        )
        return calculate_fare([leg], network).total_pkr

    assert fare_for(3) == 30
    assert fare_for(5) == 30
    assert fare_for(7) == 35
    assert fare_for(12) == 45
    assert fare_for(27) == 60
    assert fare_for(38) == 70
    assert fare_for(95) == 70  # capped at the single journey ticket price


def test_fare_is_reported_as_an_estimate_with_its_reason(network):
    plan = plan_journey("Chamkani", "Karkhano Market", network=network)
    assert plan.fare.is_estimate
    assert plan.fare.basis == "distance_band"
    assert "interpolated" in plan.fare.note


def test_express_legs_surface_the_flat_fare_exception_without_asserting_it(network):
    plan = plan_journey("Chamkani", "Karkhano Market", network=network)
    if any(leg.service_type in {"express", "super_express"} for leg in plan.legs):
        assert "flat Rs. 55" in plan.fare.note
        assert plan.fare.basis == "distance_band"
