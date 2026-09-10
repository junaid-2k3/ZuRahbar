"""Shared fetch layer for transpeshawar.pk.

Every network call in the pipeline goes through `Fetcher` so that the site's
quirks are handled in exactly one place:

* TLS -- the origin serves its leaf certificate without the intermediate, so a
  normal client fails with "unable to verify the first certificate". We disable
  verification for this one host only (driven by `tls_verify` in
  config/scrape_targets.yaml), never globally.
* Politeness -- one request per second, single threaded, with a User-Agent that
  names the project and a contact address. The site publishes no robots.txt.
* Caching -- every response is written to data/raw/ and re-requested
  conditionally via ETag / Last-Modified. Parsers are expected to be rewritten
  many times; re-parsing must never re-hit the network.
"""

from __future__ import annotations

import hashlib
import json
import logging
import time
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import Any
from urllib.parse import urljoin, urlparse

import httpx

from zurehbar.config import ScrapeConfig, load_config
from zurehbar.paths import CACHE_INDEX, RAW_DIR, ensure_dirs

log = logging.getLogger(__name__)

USER_AGENT = (
    "ZuRehbar-Scraper/0.1 (Zu Peshawar rider assistant dataset; "
    "contact: junaid.fastt@gmail.com)"
)

TEXT_MIME_PREFIXES = ("text/", "application/json", "application/xml")


@dataclass
class Response:
    url: str
    status: int
    path: Path
    from_cache: bool
    content_type: str

    @property
    def is_text(self) -> bool:
        return self.content_type.startswith(TEXT_MIME_PREFIXES)

    def text(self) -> str:
        return self.path.read_text(encoding="utf-8", errors="ignore")

    def bytes(self) -> bytes:
        return self.path.read_bytes()

    def json(self) -> Any:
        return json.loads(self.text())


def cache_key(url: str) -> str:
    return hashlib.sha256(url.encode("utf-8")).hexdigest()[:20]


def _suffix_for(url: str, content_type: str) -> str:
    ext = Path(urlparse(url).path).suffix.lower()
    if ext in {".pdf", ".jpg", ".jpeg", ".png", ".webp", ".docx", ".xlsx", ".csv"}:
        return ext
    if "json" in content_type:
        return ".json"
    if "pdf" in content_type:
        return ".pdf"
    if "png" in content_type:
        return ".png"
    if "jpeg" in content_type:
        return ".jpg"
    return ".html"


class Fetcher:
    """Rate limited, disk cached HTTP client scoped to one site."""

    def __init__(self, config: ScrapeConfig | None = None, subdir: str = "pages"):
        ensure_dirs()
        self.config = config or load_config()
        self.subdir = RAW_DIR / subdir
        self.subdir.mkdir(parents=True, exist_ok=True)
        self._last_request_at = 0.0
        self._index: dict[str, dict[str, Any]] = self._load_index()

        verify = self.config.tls_verify
        if not verify:
            # Scoped to this client only. The reason is the missing intermediate
            # certificate described in the module docstring, not a shortcut.
            warnings.filterwarnings("ignore", message="Unverified HTTPS request")

        self.client = httpx.Client(
            verify=verify,
            follow_redirects=True,
            timeout=httpx.Timeout(45.0, connect=20.0),
            headers={"User-Agent": USER_AGENT, "Accept-Language": "en,ur;q=0.8"},
        )

    # -- cache index ---------------------------------------------------------

    def _load_index(self) -> dict[str, dict[str, Any]]:
        if CACHE_INDEX.exists():
            return json.loads(CACHE_INDEX.read_text(encoding="utf-8"))
        return {}

    def _save_index(self) -> None:
        CACHE_INDEX.write_text(
            json.dumps(self._index, indent=2, sort_keys=True), encoding="utf-8"
        )

    # -- fetching ------------------------------------------------------------

    def _throttle(self) -> None:
        elapsed = time.monotonic() - self._last_request_at
        wait = self.config.request_delay_seconds - elapsed
        if wait > 0:
            time.sleep(wait)
        self._last_request_at = time.monotonic()

    def get(self, url: str, *, refresh: bool = False) -> Response:
        """Fetch a URL, returning a cached copy when the origin says it is fresh."""
        url = urljoin(self.config.base_url + "/", url)
        key = cache_key(url)
        entry = self._index.get(key)

        if entry and not refresh:
            cached = Path(entry["path"])
            if cached.exists() and entry.get("complete"):
                return Response(
                    url=url,
                    status=entry.get("status", 200),
                    path=cached,
                    from_cache=True,
                    content_type=entry.get("content_type", ""),
                )

        headers: dict[str, str] = {}
        if entry and entry.get("path") and Path(entry["path"]).exists():
            if entry.get("etag"):
                headers["If-None-Match"] = entry["etag"]
            if entry.get("last_modified"):
                headers["If-Modified-Since"] = entry["last_modified"]

        response = self._request_with_retry(url, headers)

        if response.status_code == 304 and entry:
            log.debug("304 not modified: %s", url)
            return Response(
                url=url,
                status=304,
                path=Path(entry["path"]),
                from_cache=True,
                content_type=entry.get("content_type", ""),
            )

        response.raise_for_status()
        content_type = response.headers.get("content-type", "").split(";")[0].strip()
        path = self.subdir / f"{key}{_suffix_for(url, content_type)}"
        path.write_bytes(response.content)

        self._index[key] = {
            "url": url,
            "path": str(path),
            "status": response.status_code,
            "content_type": content_type,
            "etag": response.headers.get("etag"),
            "last_modified": response.headers.get("last-modified"),
            "bytes": len(response.content),
            "fetched_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
            "complete": True,
        }
        self._save_index()

        return Response(
            url=url,
            status=response.status_code,
            path=path,
            from_cache=False,
            content_type=content_type,
        )

    def _request_with_retry(
        self, url: str, headers: dict[str, str], attempts: int = 4
    ) -> httpx.Response:
        delay = 2.0
        last_error: Exception | None = None
        for attempt in range(1, attempts + 1):
            self._throttle()
            try:
                response = self.client.get(url, headers=headers)
            except (httpx.TimeoutException, httpx.TransportError) as exc:
                last_error = exc
                log.warning("transport error (%s/%s) on %s: %s", attempt, attempts, url, exc)
            else:
                if response.status_code < 500 or response.status_code == 304:
                    return response
                last_error = httpx.HTTPStatusError(
                    f"server error {response.status_code}",
                    request=response.request,
                    response=response,
                )
                log.warning("HTTP %s (%s/%s) on %s", response.status_code, attempt, attempts, url)
            if attempt < attempts:
                time.sleep(delay)
                delay *= 2
        raise RuntimeError(f"giving up on {url}") from last_error

    def get_json(self, url: str, *, refresh: bool = False) -> Any:
        return self.get(url, refresh=refresh).json()

    def get_with_headers(self, url: str) -> tuple[httpx.Response, str]:
        """Uncached fetch used where response headers matter (REST pagination)."""
        url = urljoin(self.config.base_url + "/", url)
        response = self._request_with_retry(url, {})
        response.raise_for_status()
        return response, url

    def close(self) -> None:
        self.client.close()

    def __enter__(self) -> "Fetcher":
        return self

    def __exit__(self, *exc: object) -> None:
        self.close()
