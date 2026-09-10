#!/usr/bin/env python
"""Retrieval smoke test across the languages riders actually use.

Confirms the live Qdrant collection answers in English, Urdu and Roman Urdu, and
that payload filtering narrows to a single route.
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from zurehbar.index.qdrant_load import search  # noqa: E402

CASES = [
    ("how much does a Zu card cost", None, None),
    ("کیا زو کارڈ سائیکل پر چلتا ہے", None, None),
    ("chamkani se karkhano tak kitna kiraya hai", None, None),
    ("what time is the last bus", None, "ER-01"),
    ("which buses stop at Board Bazar", "station", None),
]


def main() -> int:
    for query, doc_type, route_id in CASES:
        filters = []
        if doc_type:
            filters.append(f"doc_type={doc_type}")
        if route_id:
            filters.append(f"route_id={route_id}")
        suffix = f"  [{', '.join(filters)}]" if filters else ""
        print(f"\nQ: {query}{suffix}")
        for hit in search(query, limit=3, doc_type=doc_type, route_id=route_id):
            print(f"  [{hit['score']:.3f}] ({hit['doc_type']}) {hit['title']}")
            print(f"      {hit['text'][:170]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
