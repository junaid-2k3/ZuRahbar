"""Scrape scope is a policy decision, so it gets a test.

The rider tier must not pull in the 598 tender and financial PDFs: they answer
no rider's question and they dilute retrieval.
"""

from __future__ import annotations

import pytest

from zurehbar.config import load_config


@pytest.fixture(scope="module")
def config():
    return load_config()


@pytest.mark.parametrize(
    "url",
    [
        "https://transpeshawar.pk/passenger-services/operation-schedule/",
        "https://transpeshawar.pk/passenger-services/fares-recharge/",
        "https://transpeshawar.pk/customer-services/frequently-asked-questions/",
        "https://transpeshawar.pk/services/peshawar-zu-system/",
        "https://transpeshawar.pk/how-to-use-our-services/",
        "https://transpeshawar.pk/chamkani-center/",
    ],
)
def test_rider_pages_are_in_scope(config, url):
    assert config.wants(url)


@pytest.mark.parametrize(
    "url",
    [
        "https://transpeshawar.pk/tender/",
        "https://transpeshawar.pk/audited-statements/",
        "https://transpeshawar.pk/annual-general-meeting-agm/",
        "https://transpeshawar.pk/job-openings/",
        "https://transpeshawar.pk/about-transpeshawar/our-board/",
        "https://transpeshawar.pk/media-room/press-briefs/",
        "https://transpeshawar.pk/feed/",
        "https://transpeshawar.pk/wp-json/wp/v2/pages",
    ],
)
def test_corporate_and_machine_paths_are_out_of_scope(config, url):
    assert not config.wants(url)


def test_other_hosts_are_never_in_scope(config):
    assert not config.wants("https://facebook.com/TransPeshawar/")
    assert not config.wants("https://fonts.googleapis.com/css")


def test_tls_verification_is_off_only_because_the_chain_is_broken(config):
    """The origin omits its intermediate certificate; this is scoped to one host."""
    assert config.tls_verify is False
    assert config.host == "transpeshawar.pk"


def test_the_crawl_is_polite(config):
    assert config.request_delay_seconds >= 1.0


def test_the_fare_and_map_images_are_pinned_as_priority_assets(config):
    assets = " ".join(config.all_priority_assets())
    assert "TP-New-Fares.jpeg" in assets
    assert "MAP_001.jpg" in assets
