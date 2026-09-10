"""Entry point for the scrape stage: `python -m zurehbar.scrape.run`."""

from __future__ import annotations

import argparse
import json
import logging

from zurehbar.config import load_config
from zurehbar.paths import RAW_API, ensure_dirs
from zurehbar.scrape import discover, fetch, wp_api


def main() -> int:
    parser = argparse.ArgumentParser(description="Scrape rider-relevant transpeshawar.pk content")
    parser.add_argument("--refresh", action="store_true", help="ignore the disk cache")
    parser.add_argument("--no-crawl", action="store_true", help="skip the supplementary link crawl")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
    ensure_dirs()
    config = load_config()

    catalog = wp_api.inventory(refresh=args.refresh)
    pages = wp_api.rider_relevant_pages(catalog["pages"] + catalog["posts"])
    page_urls = [item["link"] for item in pages]
    page_ids = {item["id"] for item in pages}

    if not args.no_crawl:
        page_urls += discover.crawl()

    page_report = fetch.fetch_pages(page_urls, refresh=args.refresh)

    asset_urls = list(config.all_priority_assets())
    asset_urls += [item["source_url"] for item in wp_api.media_for_pages(catalog["media"], page_ids)]
    asset_report = fetch.fetch_assets(asset_urls, refresh=args.refresh)

    manifest = {
        "in_scope_pages": sorted(dict.fromkeys(page_urls)),
        "assets": sorted(dict.fromkeys(asset_urls)),
        "page_records": [
            {"id": p["id"], "slug": p["slug"], "link": p["link"], "modified": p["modified"]}
            for p in pages
        ],
        "failures": page_report.failures + asset_report.failures,
    }
    (RAW_API / "scrape_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )

    print("pages:", page_report.summary())
    print("assets:", asset_report.summary())
    for url, error in manifest["failures"]:
        print("  FAILED", url, "-", error)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
