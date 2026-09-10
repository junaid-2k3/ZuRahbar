"""Embeddings for the Zu corpus.

Dense vectors come from Qwen3-Embedding-0.6B, chosen so the retrieval side
speaks the same family as the Qwen model generating Rehbar's replies, and
because riders will ask in English, Urdu, Pashto and Roman Urdu.

Two details about this model are easy to get wrong and expensive to find later:

* it is **instruction-aware** -- queries are prefixed with a task instruction,
  documents are not. Embedding both the same way costs real retrieval accuracy;
* it pools the **last token** with left padding, not the mean.

`sentence-transformers` handles the pooling when the model is loaded through it,
so the code below only has to get the instruction asymmetry right.

Qwen3-Embedding is dense-only, so lexical matching comes from a separate BM25
sparse vector. That pairing matters here specifically: station names are rare
proper nouns that dense retrieval blurs together, and BM25 anchors "Hashtnagri"
exactly.
"""

from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from typing import Iterable, Sequence

log = logging.getLogger(__name__)

DEFAULT_MODEL = os.environ.get("EMBED_MODEL", "Qwen/Qwen3-Embedding-0.6B")
QUERY_INSTRUCTION = (
    "Given a question from a Zu Peshawar bus rider, retrieve the route, fare, station or "
    "service information that answers it"
)


@dataclass
class SparseVector:
    indices: list[int]
    values: list[float]


class DenseEmbedder:
    """Lazily loaded so that importing the pipeline does not pull in torch."""

    def __init__(
        self,
        model_name: str = DEFAULT_MODEL,
        device: str | None = None,
        max_seq_length: int = 512,
    ):
        self.model_name = model_name
        self.device = device
        self.max_seq_length = max_seq_length
        self._model = None

    @property
    def model(self):
        if self._model is None:
            from sentence_transformers import SentenceTransformer

            log.info("loading %s (first run downloads the weights)", self.model_name)
            self._model = SentenceTransformer(self.model_name, device=self.device)
            # Qwen3-Embedding advertises a 32k context. Left unchanged, every batch
            # is padded far beyond the length of any document in this corpus (the
            # median is ~210 characters) and CPU encoding crawls. Capping the
            # sequence length costs nothing here and is the difference between
            # minutes and hours for a full reindex.
            if self._model.max_seq_length > self.max_seq_length:
                self._model.max_seq_length = self.max_seq_length
        return self._model

    @property
    def dimension(self) -> int:
        getter = getattr(self.model, "get_embedding_dimension", None) or (
            self.model.get_sentence_embedding_dimension
        )
        return int(getter())

    def embed_documents(self, texts: Sequence[str], batch_size: int = 4) -> list[list[float]]:
        vectors = self.model.encode(
            list(texts),
            batch_size=batch_size,
            normalize_embeddings=True,
            show_progress_bar=False,
        )
        return [vector.tolist() for vector in vectors]

    def embed_query(self, text: str) -> list[float]:
        vector = self.model.encode(
            [text],
            prompt=f"Instruct: {QUERY_INSTRUCTION}\nQuery: ",
            normalize_embeddings=True,
            show_progress_bar=False,
        )[0]
        return vector.tolist()


class SparseEncoder:
    """BM25 sparse vectors via fastembed -- no model download, pure lexical."""

    def __init__(self, model_name: str = "Qdrant/bm25"):
        self.model_name = model_name
        self._model = None

    @property
    def model(self):
        if self._model is None:
            from fastembed import SparseTextEmbedding

            self._model = SparseTextEmbedding(model_name=self.model_name)
        return self._model

    def encode_documents(self, texts: Iterable[str]) -> list[SparseVector]:
        return [
            SparseVector(indices=vector.indices.tolist(), values=vector.values.tolist())
            for vector in self.model.embed(list(texts))
        ]

    def encode_query(self, text: str) -> SparseVector:
        vector = next(iter(self.model.query_embed(text)))
        return SparseVector(indices=vector.indices.tolist(), values=vector.values.tolist())
