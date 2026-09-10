"""Station name normalisation.

The site spells the same station several ways -- "Kharkhano" in a direction
label but "Karkhano Market" in the table below it, "University Of Peshawar" and
"University of Peshawar" in adjacent routes, "Shah Alam Pul" and "Shah Alam
Pull". Riders add more: "Sadar", "Saddar Bazaar", "صدر".

Every station reference in the pipeline is resolved to a canonical `station_id`
slug through this module, so that graph joins, fare lookups and rider queries
all land on the same node. Aliases live in config/station_aliases.yaml.
"""

from __future__ import annotations

import re
import unicodedata
from functools import lru_cache
from typing import Any

import yaml

from zurehbar.paths import STATION_ALIASES

_PUNCT = re.compile(r"[^\w\s-]", re.UNICODE)
_SPACES = re.compile(r"[\s_]+")
_DASHES = re.compile(r"-{2,}")


def slugify(name: str) -> str:
    """Lowercase ASCII slug: 'Bab-e-Peshawar' -> 'bab-e-peshawar'."""
    text = unicodedata.normalize("NFKD", name.strip())
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    text = _PUNCT.sub("", text.lower())
    text = _SPACES.sub("-", text).strip("-")
    return _DASHES.sub("-", text)


# Arabic/Urdu diacritics and the zero-width joiners that show up in copied text.
_URDU_MARKS = re.compile(r"[ً-ْٰ​-‏ـ]")


def _fold(name: str) -> str:
    """Aggressive key for alias matching: drops case, punctuation and spacing.

    Non-Latin scripts must survive folding -- an ASCII-only fold collapses every
    Urdu alias to the empty string, which silently maps all of them to whichever
    station was registered last.
    """
    text = unicodedata.normalize("NFKC", (name or "").strip().lower())
    text = _URDU_MARKS.sub("", text)
    text = "".join(
        ch for ch in unicodedata.normalize("NFKD", text) if not unicodedata.combining(ch)
    )
    return re.sub(r"[^\w]", "", text, flags=re.UNICODE).replace("_", "")


@lru_cache(maxsize=1)
def _alias_table() -> tuple[dict[str, str], dict[str, dict[str, Any]]]:
    """Return (folded alias -> station_id, station_id -> record)."""
    if not STATION_ALIASES.exists():
        return {}, {}
    raw = yaml.safe_load(STATION_ALIASES.read_text(encoding="utf-8")) or {}
    stations: dict[str, dict[str, Any]] = raw.get("stations", {})
    lookup: dict[str, str] = {}
    for station_id, record in stations.items():
        names = [record.get("name", station_id), station_id]
        names += record.get("aliases", []) or []
        names += record.get("urdu", []) or []
        names += record.get("pashto", []) or []
        for name in names:
            lookup[_fold(str(name))] = station_id
    return lookup, stations


def resolve(name: str) -> str:
    """Map any spelling of a station to its canonical station_id.

    Unknown names fall back to their slug so that parsing never loses a stop;
    `is_known` tells callers whether the result is a registered station.
    """
    lookup, _ = _alias_table()
    folded = _fold(name)
    if folded in lookup:
        return lookup[folded]
    return slugify(name) or folded


def is_known(station_id: str) -> bool:
    _, stations = _alias_table()
    return station_id in stations


def canonical_name(station_id: str) -> str:
    _, stations = _alias_table()
    record = stations.get(station_id)
    if record and record.get("name"):
        return str(record["name"])
    return station_id.replace("-", " ").title()


def known_stations() -> dict[str, dict[str, Any]]:
    _, stations = _alias_table()
    return stations


def reload_aliases() -> None:
    _alias_table.cache_clear()
