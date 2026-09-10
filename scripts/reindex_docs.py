#!/usr/bin/env python
"""Re-embed and upsert only the documents whose text has changed.

    python scripts/reindex_docs.py fare:bands fare:zu-card
    python scripts/reindex_docs.py --changed

Point IDs are UUID5 of the document id, so an upsert replaces the stored point
in place. Full reindexing costs about an hour on CPU; a corrected fare should not.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from qdrant_client import QdrantClient  # noqa: E402

from zurehbar.index.docgen import build_documents  # noqa: E402
from zurehbar.index.qdrant_load import COLLECTION, QDRANT_URL, load, point_id  # noqa: E402


def changed_doc_ids(documents) -> list[str]:
    """Compare stored payload text against freshly generated text."""
    client = QdrantClient(url=QDRANT_URL, timeout=120)
    stale: list[str] = []
    for start in range(0, len(documents), 100):
        batch = documents[start : start + 100]
        stored = client.retrieve(
            collection_name=COLLECTION,
            ids=[point_id(document.doc_id) for document in batch],
            with_payload=True,
        )
        by_id = {point.id: (point.payload or {}).get("text") for point in stored}
        for document in batch:
            if by_id.get(point_id(document.doc_id)) != document.text:
                stale.append(document.doc_id)
    return stale


def main() -> int:
    parser = argparse.ArgumentParser(description="Re-index selected documents")
    parser.add_argument("doc_ids", nargs="*", help="document ids to re-embed")
    parser.add_argument("--changed", action="store_true", help="re-embed everything that differs")
    args = parser.parse_args()

    documents = build_documents()
    if args.changed:
        wanted = set(changed_doc_ids(documents))
    else:
        wanted = set(args.doc_ids)
    if not wanted:
        print("nothing to re-index")
        return 0

    selected = [document for document in documents if document.doc_id in wanted]
    missing = wanted - {document.doc_id for document in selected}
    for doc_id in sorted(missing):
        print(f"  no such document: {doc_id}")

    print(f"re-embedding {len(selected)} documents: {', '.join(d.doc_id for d in selected)}")
    load(selected, recreate=False, batch_size=4)
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
