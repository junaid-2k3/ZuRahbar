"""Vision-assisted extraction for the assets that hold no machine-readable text.

Two rider-critical facts live only inside images on transpeshawar.pk:

* the fare table (`TP-New-Fares.jpeg`) -- distance bands and prices in Urdu;
* the network map (`MAP_001.jpg`, `English-Map-JGP.png`) -- the full route
  inventory with route lengths in km, and the stop sequences for the routes that
  the operation-schedule page does not cover.

The network map is far too dense to read in one pass, so this module slices it
into overlapping tiles that a vision model can read one at a time. Output is
written to data/review/ with a `confidence` marker and a pointer back to the
source image; nothing reaches data/curated/ until a human (or Claude reading the
same image) has confirmed it. A hallucinated fare or a missing transfer point
strands a rider, so the review gate is not optional.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image

from zurehbar.paths import REVIEW_DIR, ensure_dirs

Image.MAX_IMAGE_PIXELS = None

FARE_PROMPT = """Read this Urdu fare table image. Return JSON:
{"effective_from": "YYYY-MM-DD or null",
 "bands": [{"index": 1, "min_km": 0, "max_km": 5, "fare_pkr": 30}],
 "notes": ["verbatim translation of each note line"]}
Report only what is printed. If a cell is unreadable, use null and say so in notes."""

MAP_PROMPT = """This is one tile of the Zu Peshawar network map. Return JSON:
{"routes": [{"route_id": "...", "label": "...", "endpoints": ["...", "..."], "length_km": 0}],
 "stops": [{"route_id": "...", "code": "I25", "name": "...", "order_hint": 1}],
 "unreadable": ["describe anything you could not read"]}
Transcribe station names exactly as printed, including spelling mistakes."""


@dataclass
class Tile:
    path: Path
    row: int
    col: int
    box: tuple[int, int, int, int]


@dataclass
class VisionDraft:
    """A vision transcription awaiting verification."""

    kind: str
    source_image: str
    payload: dict[str, Any]
    confidence: str = "unverified"
    verified_by: str | None = None
    verified_at: str | None = None
    notes: list[str] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        return {
            "kind": self.kind,
            "source_image": self.source_image,
            "confidence": self.confidence,
            "verified_by": self.verified_by,
            "verified_at": self.verified_at,
            "drafted_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
            "notes": self.notes,
            "payload": self.payload,
        }

    def write(self, name: str) -> Path:
        ensure_dirs()
        path = REVIEW_DIR / f"{name}.json"
        path.write_text(json.dumps(self.to_dict(), indent=2, ensure_ascii=False), encoding="utf-8")
        return path


def tile_image(
    image_path: str | Path,
    out_dir: str | Path,
    rows: int = 3,
    cols: int = 3,
    overlap: float = 0.12,
    scale: float = 1.0,
) -> list[Tile]:
    """Slice a large map into overlapping tiles a vision model can actually read.

    Overlap matters: route labels and stop codes sit near tile seams, and a stop
    cut in half is a stop silently dropped from the network.
    """
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    image = Image.open(image_path).convert("RGB")
    if scale != 1.0:
        image = image.resize((int(image.width * scale), int(image.height * scale)), Image.LANCZOS)

    width, height = image.size
    tile_w, tile_h = width / cols, height / rows
    pad_w, pad_h = tile_w * overlap, tile_h * overlap

    tiles: list[Tile] = []
    for row in range(rows):
        for col in range(cols):
            left = max(0, int(col * tile_w - pad_w))
            upper = max(0, int(row * tile_h - pad_h))
            right = min(width, int((col + 1) * tile_w + pad_w))
            lower = min(height, int((row + 1) * tile_h + pad_h))
            box = (left, upper, right, lower)
            path = out_dir / f"tile_r{row}c{col}.png"
            image.crop(box).save(path)
            tiles.append(Tile(path=path, row=row, col=col, box=box))
    return tiles


def crop_region(
    image_path: str | Path,
    out_path: str | Path,
    box: tuple[float, float, float, float],
    scale: float = 2.0,
) -> Path:
    """Crop a fractional region (0-1 coordinates) and upscale it for legibility."""
    image = Image.open(image_path).convert("RGB")
    width, height = image.size
    left, upper, right, lower = box
    crop = image.crop((int(left * width), int(upper * height), int(right * width), int(lower * height)))
    if scale != 1.0:
        crop = crop.resize((int(crop.width * scale), int(crop.height * scale)), Image.LANCZOS)
    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    crop.save(out_path)
    return out_path


def asset_path(url_fragment: str) -> Path:
    """Find a downloaded asset in the raw cache by a fragment of its URL."""
    import json as _json

    from zurehbar.paths import CACHE_INDEX

    index = _json.loads(CACHE_INDEX.read_text(encoding="utf-8"))
    for entry in index.values():
        if url_fragment in entry.get("url", ""):
            return Path(entry["path"])
    raise FileNotFoundError(url_fragment)


def prepare_map_tiles(url_fragment: str = "MAP_001.jpg", rows: int = 3, cols: int = 3) -> list[Tile]:
    from zurehbar.paths import RAW_DIR

    source = asset_path(url_fragment)
    return tile_image(source, RAW_DIR / "map_tiles", rows=rows, cols=cols, scale=1.6)
