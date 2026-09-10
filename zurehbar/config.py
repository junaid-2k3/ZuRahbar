"""Loader for config/scrape_targets.yaml."""

from __future__ import annotations

import fnmatch
from dataclasses import dataclass, field
from functools import lru_cache
from typing import Any
from urllib.parse import urlparse

import yaml

from zurehbar.paths import SCRAPE_TARGETS


@dataclass(frozen=True)
class ScrapeConfig:
    base_url: str
    tls_verify: bool
    request_delay_seconds: float
    include_paths: tuple[str, ...] = field(default_factory=tuple)
    exclude_paths: tuple[str, ...] = field(default_factory=tuple)
    force_live_html: tuple[str, ...] = field(default_factory=tuple)
    priority_assets: dict[str, list[str]] = field(default_factory=dict)
    asset_mime_allowlist: tuple[str, ...] = field(default_factory=tuple)

    @property
    def host(self) -> str:
        return urlparse(self.base_url).netloc

    def path_of(self, url: str) -> str:
        path = urlparse(url).path or "/"
        if not path.endswith("/") and "." not in path.rsplit("/", 1)[-1]:
            path += "/"
        return path

    def wants(self, url: str) -> bool:
        """True when a URL is in the rider-relevant scope."""
        if urlparse(url).netloc not in ("", self.host):
            return False
        path = self.path_of(url)
        if any(fnmatch.fnmatch(path, pattern) for pattern in self.exclude_paths):
            return False
        return any(fnmatch.fnmatch(path, pattern) for pattern in self.include_paths)

    def needs_live_html(self, url: str) -> bool:
        return self.path_of(url) in self.force_live_html

    def all_priority_assets(self) -> list[str]:
        return [url for group in self.priority_assets.values() for url in group]


@lru_cache(maxsize=1)
def load_config() -> ScrapeConfig:
    raw: dict[str, Any] = yaml.safe_load(SCRAPE_TARGETS.read_text(encoding="utf-8"))
    site = raw["site"]
    return ScrapeConfig(
        base_url=site["base_url"].rstrip("/"),
        tls_verify=bool(site.get("tls_verify", True)),
        request_delay_seconds=float(site.get("request_delay_seconds", 1.0)),
        include_paths=tuple(raw.get("include_paths", [])),
        exclude_paths=tuple(raw.get("exclude_paths", [])),
        force_live_html=tuple(raw.get("force_live_html", [])),
        priority_assets=raw.get("priority_assets", {}),
        asset_mime_allowlist=tuple(raw.get("asset_mime_allowlist", [])),
    )
