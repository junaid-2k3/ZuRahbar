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
