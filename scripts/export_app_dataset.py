"""Bridges data/curated/*.json into the app/backend artifacts ZuRehbar needs.

Run from the repo root: .venv/bin/python scripts/export_app_dataset.py
"""

from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

# scripts/*.py insert the project root on sys.path themselves, matching this
# repo's existing convention (see CLAUDE.md) so this file also runs standalone.
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from zurehbar.paths import CURATED_DIR  # noqa: E402

CURATED_FILENAMES = ["routes.json", "stations.json", "fares.json", "service_hours.json"]


def export_to_flutter_assets(curated_dir: Path, assets_dir: Path) -> list[Path]:
    assets_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for name in CURATED_FILENAMES:
        destination = assets_dir / name
        shutil.copyfile(curated_dir / name, destination)
        written.append(destination)
    return written


def build_firestore_seed(curated_dir: Path) -> dict:
    routes = json.loads((curated_dir / "routes.json").read_text(encoding="utf-8"))
    stations = json.loads((curated_dir / "stations.json").read_text(encoding="utf-8"))
    fares = json.loads((curated_dir / "fares.json").read_text(encoding="utf-8"))
    service_hours = json.loads((curated_dir / "service_hours.json").read_text(encoding="utf-8"))

    return {
        "routes": {route["route_id"]: route for route in routes},
        "stations": {station["station_id"]: station for station in stations},
        "fares": {"current": fares},
        "service_hours": {"current": service_hours},
    }


def export_to_firestore_seed(curated_dir: Path, output_path: Path) -> Path:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    seed = build_firestore_seed(curated_dir)
    output_path.write_text(json.dumps(seed, ensure_ascii=False, indent=2), encoding="utf-8")
    return output_path


if __name__ == "__main__":
    project_root = Path(__file__).resolve().parent.parent
    export_to_flutter_assets(CURATED_DIR, project_root / "app" / "assets" / "data")
    export_to_firestore_seed(CURATED_DIR, project_root / "data" / "export" / "firestore_seed.json")
