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
