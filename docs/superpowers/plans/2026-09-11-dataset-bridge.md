# Dataset Bridge Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn this repo's existing `data/curated/*.json` pipeline output into the two artifacts the ZuRehbar app/backend need: a bundled asset copy for the Flutter app, and a Firestore-seed file for the backend.

**Architecture:** A single Python script, run manually (like the rest of this repo's pipeline stages), reads the four curated JSON files and writes two outputs: a byte-for-byte copy into `app/assets/data/` (no new schema — the Flutter app parses the same shape this repo already validates), and a Firestore-seed JSON keyed by collection and document id for the backend's seed script (Backend plan, Task 3) to consume.

**Tech Stack:** Python 3.11, stdlib `json`/`pathlib` only (no new dependency — this repo's existing `zurehbar.paths.CURATED_DIR` constant is reused).

**Spec:** `docs/superpowers/specs/2026-09-11-zurehbar-phase1-design.md`

## Global Constraints

- Reuse the curated JSON shape as-is for the Flutter asset bundle — no new intermediate format (per spec's "Dataset bridge" section).
- Do not filter out non-routable routes (`DR-11`, `ER-16`, `XER-15`) from either output — they must stay searchable even though the Dart routing graph (Flutter plan) skips them for pathfinding, matching this repo's existing `_coverage_warnings` behavior.
- Run everything from the repo root (`/home/junaid/zu Rahbar`) — this package is not pip-installed (see `CLAUDE.md`).

---

### Task 1: Copy curated dataset into the Flutter asset bundle

**Files:**
- Create: `scripts/export_app_dataset.py`
- Test: `tests/test_export_app_dataset.py`

**Interfaces:**
- Consumes: `zurehbar.paths.CURATED_DIR` (existing constant, already used by `zurehbar/graph/network.py:26`).
- Produces: `export_to_flutter_assets(curated_dir: Path, assets_dir: Path) -> list[Path]` — returns the list of files it wrote. The Flutter plan's dataset loader task reads exactly these four filenames from `app/assets/data/`.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_export_app_dataset.py
import json
from pathlib import Path

from scripts.export_app_dataset import export_to_flutter_assets

CURATED_FILES = ["routes.json", "stations.json", "fares.json", "service_hours.json"]


def test_export_to_flutter_assets_copies_all_curated_files(tmp_path):
    curated_dir = tmp_path / "curated"
    curated_dir.mkdir()
    for name in CURATED_FILES:
        (curated_dir / name).write_text(json.dumps({"marker": name}), encoding="utf-8")

    assets_dir = tmp_path / "assets" / "data"
    written = export_to_flutter_assets(curated_dir, assets_dir)

    assert {path.name for path in written} == set(CURATED_FILES)
    for name in CURATED_FILES:
        content = json.loads((assets_dir / name).read_text(encoding="utf-8"))
        assert content == {"marker": name}


def test_export_to_flutter_assets_creates_assets_dir(tmp_path):
    curated_dir = tmp_path / "curated"
    curated_dir.mkdir()
    for name in CURATED_FILES:
        (curated_dir / name).write_text("{}", encoding="utf-8")

    assets_dir = tmp_path / "does" / "not" / "exist" / "yet"
    export_to_flutter_assets(curated_dir, assets_dir)

    assert assets_dir.is_dir()
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `.venv/bin/pytest tests/test_export_app_dataset.py -v`
Expected: FAIL with `ModuleNotFoundError: No module named 'scripts.export_app_dataset'`

- [ ] **Step 3: Write the minimal implementation**

```python
# scripts/export_app_dataset.py
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
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `.venv/bin/pytest tests/test_export_app_dataset.py -v`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add scripts/export_app_dataset.py tests/test_export_app_dataset.py
git commit -m "feat: export curated dataset to Flutter asset bundle"
```

---

### Task 2: Build the Firestore-seed file

**Files:**
- Modify: `scripts/export_app_dataset.py`
- Test: `tests/test_export_app_dataset.py`

**Interfaces:**
- Consumes: same curated JSON shape as Task 1.
- Produces: `build_firestore_seed(curated_dir: Path) -> dict` and `export_to_firestore_seed(curated_dir: Path, output_path: Path) -> Path`. The seed dict shape — `{"routes": {route_id: {...}}, "stations": {station_id: {...}}, "fares": {"current": {...}}, "service_hours": {"current": {...}}}` — is exactly what the Backend plan's Task 3 (`seedFirestore.ts`) reads.

- [ ] **Step 1: Write the failing test**

```python
# tests/test_export_app_dataset.py — append

def test_build_firestore_seed_keys_routes_and_stations_by_id(tmp_path):
    curated_dir = tmp_path / "curated"
    curated_dir.mkdir()
    (curated_dir / "routes.json").write_text(
        json.dumps([{"route_id": "ER-01", "service_type": "express"}]), encoding="utf-8"
    )
    (curated_dir / "stations.json").write_text(
        json.dumps([{"station_id": "chamkani", "name": "Chamkani"}]), encoding="utf-8"
    )
    (curated_dir / "fares.json").write_text(json.dumps({"currency": "PKR"}), encoding="utf-8")
    (curated_dir / "service_hours.json").write_text(
        json.dumps({"opens": "06:00"}), encoding="utf-8"
    )

    from scripts.export_app_dataset import build_firestore_seed

    seed = build_firestore_seed(curated_dir)

    assert seed["routes"] == {"ER-01": {"route_id": "ER-01", "service_type": "express"}}
    assert seed["stations"] == {"chamkani": {"station_id": "chamkani", "name": "Chamkani"}}
    assert seed["fares"] == {"current": {"currency": "PKR"}}
    assert seed["service_hours"] == {"current": {"opens": "06:00"}}


def test_export_to_firestore_seed_writes_json_file(tmp_path):
    curated_dir = tmp_path / "curated"
    curated_dir.mkdir()
    (curated_dir / "routes.json").write_text(json.dumps([]), encoding="utf-8")
    (curated_dir / "stations.json").write_text(json.dumps([]), encoding="utf-8")
    (curated_dir / "fares.json").write_text(json.dumps({}), encoding="utf-8")
    (curated_dir / "service_hours.json").write_text(json.dumps({}), encoding="utf-8")

    from scripts.export_app_dataset import export_to_firestore_seed

    output_path = tmp_path / "export" / "firestore_seed.json"
    result = export_to_firestore_seed(curated_dir, output_path)

    assert result == output_path
    assert json.loads(output_path.read_text(encoding="utf-8")) == {
        "routes": {},
        "stations": {},
        "fares": {"current": {}},
        "service_hours": {"current": {}},
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `.venv/bin/pytest tests/test_export_app_dataset.py -v`
Expected: FAIL with `ImportError: cannot import name 'build_firestore_seed'`

- [ ] **Step 3: Write the minimal implementation**

```python
# scripts/export_app_dataset.py — add below export_to_flutter_assets

import json


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
```

Also update the `if __name__ == "__main__":` block:

```python
if __name__ == "__main__":
    project_root = Path(__file__).resolve().parent.parent
    export_to_flutter_assets(CURATED_DIR, project_root / "app" / "assets" / "data")
    export_to_firestore_seed(CURATED_DIR, project_root / "data" / "export" / "firestore_seed.json")
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `.venv/bin/pytest tests/test_export_app_dataset.py -v`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add scripts/export_app_dataset.py tests/test_export_app_dataset.py
git commit -m "feat: export curated dataset to a Firestore-seed file"
```

---

### Task 3: Wire into the pipeline and gitignore the generated output

**Files:**
- Modify: `zurehbar/pipeline.py` (add an `export-app` stage after `docgen`, following the same `--only` stage pattern already used for `scrape`/`build`/`docgen`/`index`)
- Modify: `.gitignore` (generated app assets and Firestore seed should not be committed — they're regenerated from `data/curated/`, same policy as `data/raw/`)

**Interfaces:**
- Consumes: `export_to_flutter_assets` and `export_to_firestore_seed` from Task 1/2.
- Produces: running `.venv/bin/python -m zurehbar.pipeline --only export-app` (or the full pipeline) leaves `app/assets/data/*.json` and `data/export/firestore_seed.json` up to date.

- [ ] **Step 1: Read the existing pipeline stage pattern**

Read `zurehbar/pipeline.py` in full before editing — this task must match its existing `--only` stage dispatch exactly, not invent a new convention. There is no test to write first here: this task wires two already-tested functions into an existing dispatcher, so the check is the manual run in Step 3.

- [ ] **Step 2: Add the `export-app` stage**

Add a stage function calling both Task 1/2 functions with `CURATED_DIR` and the project-root-relative output paths, and register it in whatever stage list/dict `pipeline.py` already uses, in a position after `docgen` (dataset must be curated before it's exported).

- [ ] **Step 3: Run it and verify the outputs**

Run: `.venv/bin/python -m zurehbar.pipeline --only export-app`
Expected: `app/assets/data/routes.json`, `stations.json`, `fares.json`, `service_hours.json` and `data/export/firestore_seed.json` all exist and are non-empty (`ls -la app/assets/data/ data/export/`).

- [ ] **Step 4: Gitignore the generated files**

Add to `.gitignore`:
```
app/assets/data/
data/export/
```

- [ ] **Step 5: Commit**

```bash
git add zurehbar/pipeline.py .gitignore
git commit -m "feat: add export-app pipeline stage for the dataset bridge"
```
