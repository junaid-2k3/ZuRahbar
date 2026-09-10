"""Generated documents must carry the dataset's numbers, not paraphrases of them."""

from __future__ import annotations

import json

import pytest

from zurehbar.index.docgen import build_documents
from zurehbar.paths import CURATED_DIR

pytestmark = pytest.mark.skipif(
    not (CURATED_DIR / "routes.json").exists(),
    reason="run `python -m zurehbar.model.build` first",
)


@pytest.fixture(scope="module")
def documents():
    return build_documents()


def test_every_document_type_is_present(documents):
    types = {document.doc_type for document in documents}
    assert {"route", "station", "fare", "faq", "service"} <= types


def test_doc_ids_are_unique(documents):
    ids = [document.doc_id for document in documents]
    assert len(ids) == len(set(ids))


def test_the_same_page_served_at_two_urls_is_indexed_once(documents):
    """The FAQ answers at both /frequently-asked-questions/ and the section URL."""
    normalised = [" ".join(document.text.split()).lower() for document in documents]
    assert len(normalised) == len(set(normalised))


def test_route_documents_name_their_stops_and_platform(documents):
    er01 = next(d for d in documents if d.doc_id.startswith("route:ER-01:chamkani"))
    assert "Chamkani" in er01.text and "Karkhano Market" in er01.text
    assert "platform 3" in er01.text
    assert "ER-01" in er01.route_ids


def test_fare_document_states_the_exact_published_prices(documents):
    fares = json.loads((CURATED_DIR / "fares.json").read_text(encoding="utf-8"))
    document = next(d for d in documents if d.doc_id == "fare:bands")
    for band in fares["bands"]:
        assert f"Rs. {band['fare_pkr']}" in document.text
    assert "distance travelled, not by the number of stops" in document.text


def test_unverified_routes_say_so_in_their_text(documents):
    unverified = [d for d in documents if d.doc_type == "route" and not d.verified]
    assert unverified
    assert all(
        "no published timetable" in d.text or "publishes no timetable" in d.text
        for d in unverified
    )


def test_every_document_has_a_source_url(documents):
    assert all(document.source_url.startswith("https://") for document in documents)


def test_zu_card_price_conflict_is_resolved_to_the_newer_page(documents):
    """The FAQ (2023) says Rs. 300; the card page (2025) says PKR 400."""
    card = next(d for d in documents if d.doc_id == "fare:zu-card")
    assert "Rs. 400" in card.text
    assert "zu-card-registration" in card.source_url
    # The disagreement is stated, not hidden -- a rider quoted the wrong price at
    # the ticket office is the failure this guards against.
    assert "300" in card.text and "disagree" in card.text
