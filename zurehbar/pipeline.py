"""Run the whole pipeline: scrape, build, generate documents, index.

    python -m zurehbar.pipeline              # everything, using the cache
    python -m zurehbar.pipeline --skip index # stop before Qdrant
    python -m zurehbar.pipeline --refresh    # ignore the HTTP cache

Vision extraction is deliberately not a stage. The fare table and the network
map are transcribed by a person or by Claude reading the image, and the result
is committed to data/review/ with a `verified_by` stamp. Wiring that into an
unattended run would put unverified fares in front of riders.
"""

from __future__ import annotations

import argparse
import logging
import sys

STAGES = ("scrape", "build", "docgen", "index")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the ZuRehbar dataset pipeline")
    parser.add_argument("--skip", nargs="*", default=[], choices=STAGES, help="stages to skip")
    parser.add_argument("--only", nargs="*", default=[], choices=STAGES, help="stages to run")
    parser.add_argument("--refresh", action="store_true", help="ignore the HTTP cache")
    parser.add_argument("--recreate", action="store_true", help="drop and rebuild the collection")
    args = parser.parse_args()

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
    wanted = [stage for stage in STAGES if stage not in args.skip and (not args.only or stage in args.only)]

    for stage in wanted:
        print(f"\n=== {stage} ===")
        if stage == "scrape":
            from zurehbar.scrape import run as scrape_run

            sys.argv = ["scrape", *(["--refresh"] if args.refresh else [])]
            if scrape_run.main() != 0:
                return 1
        elif stage == "build":
            from zurehbar.model import build as build_module

            report = build_module.build()
            counts = report["counts"]
            print("built", ", ".join(f"{v} {k}" for k, v in counts.items()))
            for failure in report["integrity_failures"]:
                print("  INTEGRITY FAILURE:", failure)
            if report["integrity_failures"]:
                return 1
            print(f"anomalies recorded: {len(report['anomalies'])} (see data/curated/dataset_report.json)")
        elif stage == "docgen":
            from zurehbar.index import docgen

            sys.argv = ["docgen"]
            if docgen.main() != 0:
                return 1
        elif stage == "index":
            from zurehbar.index import qdrant_load

            sys.argv = ["qdrant_load", *(["--recreate"] if args.recreate else [])]
            if qdrant_load.main() != 0:
                return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
