"""Bounded link crawl to catch in-scope pages the REST API misses.

The API lists published pages, but the site also links to content that is not a
`page` object (station micro-sites, redirected slugs). This crawler starts from
the homepage, follows same-host links two levels deep, and keeps whatever the
scrape_targets allowlist accepts.
"""

from __future__ import annotations

import logging
from urllib.parse import urldefrag, urljoin

from selectolax.parser import HTMLParser

from zurehbar.config import load_config
from zurehbar.http import Fetcher

log = logging.getLogger(__name__)


def crawl(start: str = "/", max_depth: int = 2, max_pages: int = 120) -> list[str]:
    config = load_config()
    seen: set[str] = set()
    found: list[str] = []
    frontier = [(urljoin(config.base_url + "/", start), 0)]

    with Fetcher(config, subdir="pages") as fetcher:
        while frontier and len(seen) < max_pages:
            url, depth = frontier.pop(0)
            url = urldefrag(url).url
            if url in seen:
                continue
            seen.add(url)
            try:
                response = fetcher.get(url)
            except Exception as exc:  # noqa: BLE001
                log.warning("crawl failed %s: %s", url, exc)
                continue
            if not response.is_text:
                continue
            if config.wants(url):
                found.append(url)
            if depth >= max_depth:
                continue
            tree = HTMLParser(response.text())
            for node in tree.css("a[href]"):
                href = node.attributes.get("href") or ""
                if href.startswith(("#", "mailto:", "tel:", "javascript:")):
                    continue
                absolute = urldefrag(urljoin(url, href)).url
                if config.wants(absolute) and absolute not in seen:
                    frontier.append((absolute, depth + 1))

    log.info("crawl visited %s urls, %s in scope", len(seen), len(found))
    return found
