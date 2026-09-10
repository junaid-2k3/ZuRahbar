"""Station name resolution must survive the site's spellings and the rider's."""

from __future__ import annotations

import pytest

from zurehbar.model import naming


@pytest.fixture(autouse=True)
def _fresh_aliases():
    naming.reload_aliases()


@pytest.mark.parametrize(
    ("spoken", "station_id"),
    [
        ("Kharkhano", "karkhano-market"),          # direction label on the site
        ("Karkhano Market", "karkhano-market"),
        ("Sadar Bazaar", "saddar-bazar"),          # Roman-Urdu rider spelling
        ("saddar bazar", "saddar-bazar"),
        ("UoP", "university-of-peshawar"),
        ("University Of Peshawar", "university-of-peshawar"),
        ("Shah Alam Pull", "shah-alam-pul"),
        ("Dabgari Garden", "dabgari-gardens"),
        ("Hayatabad", "mall-of-hayatabad"),
    ],
)
def test_variants_resolve_to_one_station(spoken, station_id):
    assert naming.resolve(spoken) == station_id


@pytest.mark.parametrize(
    ("urdu", "station_id"),
    [
        ("صدر", "saddar-bazar"),
        ("صدر بازار", "saddar-bazar"),
        ("چمکنی", "chamkani"),
        ("یونیورسٹی ٹاؤن", "university-town"),
    ],
)
def test_urdu_script_resolves(urdu, station_id):
    """An ASCII-only fold collapses every Urdu alias onto one station."""
    assert naming.resolve(urdu) == station_id


def test_unknown_names_do_not_collide():
    assert naming.resolve("Some Place") == "some-place"
    assert not naming.is_known("some-place")
    assert naming.is_known("chamkani")


def test_canonical_name_is_the_spoken_form():
    assert naming.canonical_name("saddar-bazar") == "Saddar Bazar"
    assert naming.canonical_name("university-of-peshawar") == "University of Peshawar"
