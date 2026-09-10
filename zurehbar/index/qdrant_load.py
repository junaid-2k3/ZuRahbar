"""Create the Qdrant collection and load the Zu corpus into it.

The collection carries two named vectors per point -- a dense Qwen3 embedding
and a BM25 sparse vector -- and is queried with reciprocal rank fusion over
both. Payload indexes on `doc_type`, `route_ids` and `station_ids` let a caller
narrow to one route or one station before ranking, which is what turns "when is
the last ER-01 bus" from a similarity guess into a lookup.

Point IDs are UUID5 of the document id, so re-running the loader updates each
point in place instead of growing a second copy of the corpus.
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import uuid
from typing import Any, Sequence

from qdrant_client import QdrantClient, models

from zurehbar.index.docgen import Document, build_documents
from zurehbar.index.embed import DenseEmbedder, SparseEncoder
from zurehbar.paths import CURATED_DIR

log = logging.getLogger(__name__)

QDRANT_URL = os.environ.get("QDRANT_URL", "http://localhost:6333")
COLLECTION = os.environ.get("QDRANT_COLLECTION", "zu_rider")
NAMESPACE = uuid.UUID("6f1a5f6e-0d2f-5a3b-9c4d-1e2f3a4b5c6d")

DENSE_VECTOR = "dense"
SPARSE_VECTOR = "bm25"


def point_id(doc_id: str) -> str:
    return str(uuid.uuid5(NAMESPACE, doc_id))


def ensure_collection(client: QdrantClient, dimension: int, recreate: bool = False) -> None:
    exists = client.collection_exists(COLLECTION)
    if exists and recreate:
        client.delete_collection(COLLECTION)
        exists = False
    if not exists:
        client.create_collection(
            collection_name=COLLECTION,
            vectors_config={
                DENSE_VECTOR: models.VectorParams(
                    size=dimension, distance=models.Distance.COSINE
                )
            },
            sparse_vectors_config={
                SPARSE_VECTOR: models.SparseVectorParams(
                    modifier=models.Modifier.IDF,
                )
            },
        )
        log.info("created collection %s (dense dim %s)", COLLECTION, dimension)

    for field, schema in (
        ("doc_type", models.PayloadSchemaType.KEYWORD),
        ("route_ids", models.PayloadSchemaType.KEYWORD),
        ("station_ids", models.PayloadSchemaType.KEYWORD),
        ("lang", models.PayloadSchemaType.KEYWORD),
        ("verified", models.PayloadSchemaType.BOOL),
    ):
        try:
            client.create_payload_index(COLLECTION, field_name=field, field_schema=schema)
        except Exception:  # noqa: BLE001 - index already exists
            pass


def load(
    documents: Sequence[Document] | None = None,
    recreate: bool = False,
    batch_size: int = 8,
) -> int:
    documents = list(documents or build_documents())
    dense = DenseEmbedder()
    sparse = SparseEncoder()

    client = QdrantClient(url=QDRANT_URL, timeout=120)
    ensure_collection(client, dense.dimension, recreate=recreate)

    total = 0
    for start in range(0, len(documents), batch_size):
        batch = documents[start : start + batch_size]
        texts = [_embedding_text(document) for document in batch]
        dense_vectors = dense.embed_documents(texts, batch_size=batch_size)
        sparse_vectors = sparse.encode_documents(texts)

        client.upsert(
            collection_name=COLLECTION,
            points=[
                models.PointStruct(
                    id=point_id(document.doc_id),
                    vector={
                        DENSE_VECTOR: dense_vector,
                        SPARSE_VECTOR: models.SparseVector(
                            indices=sparse_vector.indices, values=sparse_vector.values
                        ),
                    },
                    payload=document.payload(),
                )
                for document, dense_vector, sparse_vector in zip(batch, dense_vectors, sparse_vectors)
            ],
        )
        total += len(batch)
        log.info("upserted %s/%s", total, len(documents))
    return total


def _embedding_text(document: Document) -> str:
    """Give the encoder the title too -- a bare stop list retrieves poorly."""
    parts = [document.title]
    if document.section and document.section not in document.text:
        parts.append(document.section)
    parts.append(document.text)
    return "\n".join(parts)


def search(
    query: str,
    limit: int = 5,
    doc_type: str | None = None,
    route_id: str | None = None,
    station_id: str | None = None,
) -> list[dict[str, Any]]:
    """Hybrid search: dense and BM25 candidates fused with reciprocal rank fusion."""
    dense = DenseEmbedder()
    sparse = SparseEncoder()
    client = QdrantClient(url=QDRANT_URL, timeout=120)

    conditions = []
    if doc_type:
        conditions.append(models.FieldCondition(key="doc_type", match=models.MatchValue(value=doc_type)))
    if route_id:
        conditions.append(models.FieldCondition(key="route_ids", match=models.MatchValue(value=route_id)))
    if station_id:
        conditions.append(
            models.FieldCondition(key="station_ids", match=models.MatchValue(value=station_id))
        )
    query_filter = models.Filter(must=conditions) if conditions else None

    sparse_query = sparse.encode_query(query)
    response = client.query_points(
        collection_name=COLLECTION,
        prefetch=[
            models.Prefetch(
                query=dense.embed_query(query), using=DENSE_VECTOR, limit=limit * 4, filter=query_filter
            ),
            models.Prefetch(
                query=models.SparseVector(
                    indices=sparse_query.indices, values=sparse_query.values
                ),
                using=SPARSE_VECTOR,
                limit=limit * 4,
                filter=query_filter,
            ),
        ],
        query=models.FusionQuery(fusion=models.Fusion.RRF),
        limit=limit,
        with_payload=True,
    )
    return [
        {
            "score": point.score,
            "doc_type": point.payload.get("doc_type"),
            "title": point.payload.get("title"),
            "text": point.payload.get("text"),
            "source_url": point.payload.get("source_url"),
        }
        for point in response.points
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description="Load the Zu corpus into Qdrant")
    parser.add_argument("--recreate", action="store_true", help="drop and rebuild the collection")
    parser.add_argument("--query", help="run a search instead of loading")
    parser.add_argument("--doc-type")
    parser.add_argument("--route-id")
    parser.add_argument("--limit", type=int, default=5)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")

    if args.query:
        for hit in search(args.query, limit=args.limit, doc_type=args.doc_type, route_id=args.route_id):
            print(f"[{hit['score']:.4f}] ({hit['doc_type']}) {hit['title']}")
            print(f"    {hit['text'][:200]}")
        return 0

    documents_file = CURATED_DIR / "documents.json"
    if documents_file.exists():
        payloads = json.loads(documents_file.read_text(encoding="utf-8"))
        documents = [
            Document(
                doc_id=item["doc_id"],
                doc_type=item["doc_type"],
                title=item["title"],
                text=item["text"],
                source_url=item["source_url"],
                route_ids=item.get("route_ids", []),
                station_ids=item.get("station_ids", []),
                lang=item.get("lang", "en"),
                verified=item.get("verified", True),
                section=item.get("section"),
            )
            for item in payloads
        ]
    else:
        documents = build_documents()

    total = load(documents, recreate=args.recreate)
    print(f"loaded {total} documents into {COLLECTION} at {QDRANT_URL}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
