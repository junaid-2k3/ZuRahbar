"""The FAQ page is the densest rider-facing prose on the site."""

from __future__ import annotations

import pytest

from zurehbar.extract.prose import extract_faq, extract_page
from zurehbar.paths import TESTS_FIXTURES

FAQ_URL = "https://transpeshawar.pk/customer-services/frequently-asked-questions/"


@pytest.fixture(scope="module")
def faq_html():
    return (TESTS_FIXTURES / "faq.html").read_text(encoding="utf-8", errors="ignore")


def test_every_accordion_entry_becomes_one_document(faq_html):
    chunks = extract_faq(faq_html, FAQ_URL)
    assert len(chunks) == 26


def test_question_and_answer_stay_together(faq_html):
    chunks = {chunk.section: chunk.text for chunk in extract_faq(faq_html, FAQ_URL)}
    card = next(text for section, text in chunks.items() if "Zu Card cost" in section)
    assert "Rs. 300" in card
    assert card.startswith("Question:")
    assert "Answer:" in card


def test_doc_ids_are_stable_and_unique(faq_html):
    first = extract_faq(faq_html, FAQ_URL)
    second = extract_faq(faq_html, FAQ_URL)
    assert [c.doc_id for c in first] == [c.doc_id for c in second]
    assert len({c.doc_id for c in first}) == len(first)


def test_page_extraction_routes_faq_pages_to_the_faq_path(faq_html):
    chunks = extract_page(faq_html, FAQ_URL)
    assert all(chunk.doc_type == "faq" for chunk in chunks)
    assert len(chunks) == 26


def test_navigation_boilerplate_is_not_indexed(faq_html):
    texts = " ".join(chunk.text for chunk in extract_page(faq_html, FAQ_URL))
    assert "Leave this field empty if you're human" not in texts
