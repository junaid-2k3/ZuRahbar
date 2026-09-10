"""Inventory the site through the WordPress REST API.

transpeshawar.pk exposes an unauthenticated /wp-json/wp/v2/ API. It gives us a
complete page/post/media list with `modified` timestamps for free, which is far
more reliable than crawling links, and lets later runs detect changed pages
without diffing HTML.
"""

from __future__ import annotations

import json
import logging
from typing import Any, Iterator

from zurehbar.config import load_config
from zurehbar.http import Fetcher
from zurehbar.paths import RAW_API, ensure_dirs

log = logging.getLogger(__name__)

PAGE_FIELDS = "id,slug,link,title,modified,date,content,excerpt,parent,type"
MEDIA_FIELDS = "id,slug,link,title,modified,source_url,mime_type,media_type,post,alt_text,caption"


def _paginate(fetcher: Fetcher, endpoint: str, fields: str, per_page: int = 100) -> Iterator[dict[str, Any]]:
    page = 1
    while True:
        url = f"/wp-json/wp/v2/{endpoint}?per_page={per_page}&page={page}&_fields={fields}"
        response, _ = fetcher.get_with_headers(url)
        batch = response.json()
        if not batch:
            return
        yield from batch
        total_pages = int(response.headers.get("X-WP-TotalPages", "1") or 1)
        log.info("%s page %s/%s (%s items)", endpoint, page, total_pages, len(batch))
        if page >= total_pages:
            return
        page += 1


def inventory(fetcher: Fetcher | None = None, refresh: bool = False) -> dict[str, list[dict[str, Any]]]:
    """Pull pages, posts and media listings, cached as JSON in data/raw/api/."""
    ensure_dirs()
    owns_fetcher = fetcher is None
    fetcher = fetcher or Fetcher(subdir="pages")
    result: dict[str, list[dict[str, Any]]] = {}
    try:
        for endpoint, fields in (
            ("pages", PAGE_FIELDS),
            ("posts", PAGE_FIELDS),
            ("media", MEDIA_FIELDS),
        ):
            cache_file = RAW_API / f"{endpoint}.json"
            if cache_file.exists() and not refresh:
                result[endpoint] = json.loads(cache_file.read_text(encoding="utf-8"))
                log.info("%s: %s items (cached)", endpoint, len(result[endpoint]))
                continue
            items = list(_paginate(fetcher, endpoint, fields))
            cache_file.write_text(json.dumps(items, indent=1, ensure_ascii=False), encoding="utf-8")
            result[endpoint] = items
            log.info("%s: %s items (fetched)", endpoint, len(items))
    finally:
        if owns_fetcher:
            fetcher.close()
    return result


def rider_relevant_pages(items: list[dict[str, Any]]) -> list[dict[str, Any]]:
    config = load_config()
    return [item for item in items if config.wants(item.get("link", ""))]


def media_for_pages(media: list[dict[str, Any]], page_ids: set[int]) -> list[dict[str, Any]]:
    """Media attached to an in-scope page, restricted to useful MIME types."""
    config = load_config()
    allow = set(config.asset_mime_allowlist)
    return [
        item
        for item in media
        if item.get("mime_type") in allow and item.get("post") in page_ids
    ]
