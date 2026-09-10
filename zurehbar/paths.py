"""Canonical filesystem locations for the pipeline.

Everything downstream resolves paths through here so that the project can be
run from any working directory.
"""

from __future__ import annotations

from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent

CONFIG_DIR = PROJECT_ROOT / "config"
SCRAPE_TARGETS = CONFIG_DIR / "scrape_targets.yaml"
STATION_ALIASES = CONFIG_DIR / "station_aliases.yaml"

DATA_DIR = PROJECT_ROOT / "data"
RAW_DIR = DATA_DIR / "raw"
RAW_PAGES = RAW_DIR / "pages"
RAW_ASSETS = RAW_DIR / "assets"
RAW_API = RAW_DIR / "api"
CACHE_INDEX = RAW_DIR / "cache_index.json"

REVIEW_DIR = DATA_DIR / "review"
CURATED_DIR = DATA_DIR / "curated"

TESTS_FIXTURES = PROJECT_ROOT / "tests" / "fixtures"


def ensure_dirs() -> None:
    for path in (RAW_PAGES, RAW_ASSETS, RAW_API, REVIEW_DIR, CURATED_DIR):
        path.mkdir(parents=True, exist_ok=True)
