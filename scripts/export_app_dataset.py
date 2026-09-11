"""Bridges data/curated/*.json into the app/backend artifacts ZuRehbar needs.

Run from the repo root: .venv/bin/python scripts/export_app_dataset.py
"""

from __future__ import annotations

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


if __name__ == "__main__":
    project_root = Path(__file__).resolve().parent.parent
    export_to_flutter_assets(CURATED_DIR, project_root / "app" / "assets" / "data")
