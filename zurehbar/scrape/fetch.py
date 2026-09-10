"""Download in-scope page HTML and assets into data/raw/."""

from __future__ import annotations

import logging
import re
from dataclasses import dataclass
from typing import Iterable

from zurehbar.config import load_config
from zurehbar.http import Fetcher, Response

log = logging.getLogger(__name__)

# Avada emits sized image variants alongside the original: foo-1024x595.png.
SIZED_VARIANT = re.compile(r"-\d{2,4}x\d{2,4}(?=\.[a-z]{3,4}$)")


def original_asset_url(url: str) -> str:
    """Strip Avada's size suffix so we download the full-resolution original."""
    return SIZED_VARIANT.sub("", url)


@dataclass
class FetchReport:
    pages: list[Response]
    assets: list[Response]
    failures: list[tuple[str, str]]

    def summary(self) -> str:
        cached = sum(1 for r in self.pages + self.assets if r.from_cache)
        return (
            f"{len(self.pages)} pages, {len(self.assets)} assets "
            f"({cached} from cache), {len(self.failures)} failures"
        )


def fetch_pages(urls: Iterable[str], refresh: bool = False) -> FetchReport:
    config = load_config()
    pages: list[Response] = []
    failures: list[tuple[str, str]] = []
    with Fetcher(config, subdir="pages") as fetcher:
        for url in dict.fromkeys(urls):
            try:
                pages.append(fetcher.get(url, refresh=refresh))
            except Exception as exc:  # noqa: BLE001 - one bad page must not stop the run
                log.warning("page failed %s: %s", url, exc)
                failures.append((url, str(exc)))
    return FetchReport(pages=pages, assets=[], failures=failures)


def fetch_assets(urls: Iterable[str], refresh: bool = False) -> FetchReport:
    config = load_config()
    assets: list[Response] = []
    failures: list[tuple[str, str]] = []
    with Fetcher(config, subdir="assets") as fetcher:
        for url in dict.fromkeys(original_asset_url(u) for u in urls):
            try:
                assets.append(fetcher.get(url, refresh=refresh))
            except Exception as exc:  # noqa: BLE001
                log.warning("asset failed %s: %s", url, exc)
                failures.append((url, str(exc)))
    return FetchReport(pages=[], assets=assets, failures=failures)
