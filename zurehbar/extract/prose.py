"""Turn rider-facing pages into retrieval documents.

Two shapes of content matter:

* Accordion FAQs (`/customer-services/frequently-asked-questions/`). Avada wraps
  each entry in `div.fusion-panel` with the question in
  `span.fusion-toggle-heading` and the answer in `div.panel-body`. One Q&A pair
  is one document -- splitting a question from its answer, or gluing two
  unrelated answers together, is what makes a RAG assistant confidently wrong.
* Ordinary prose pages (how to use the service, code of conduct, card
  registration, bicycles). These are split at heading boundaries and then packed
  to a target size, never mid-sentence.

Avada also stamps every page with chrome -- the sidebar menu, the newsletter
form, the footer. That boilerplate repeats on all 41 pages, so it is stripped
before chunking; left in, it dominates similarity search.
"""

from __future__ import annotations

import hashlib
import re
from dataclasses import dataclass
from typing import Iterable

from selectolax.parser import HTMLParser

BOILERPLATE_SELECTORS = (
    "script", "style", "noscript", "form", "footer", "nav",
    "div.fusion-widget-area", "aside", "div.fusion-footer",
    "div.fusion-sliding-bar-wrapper", "div.avada-footer-scripts",
)

BOILERPLATE_PHRASES = (
    "Leave this field empty if you're human",
    "Newsletter",
    "Latest Posts",
)

# Roughly four characters per token; the index targets ~400-token chunks.
TARGET_CHARS = 1600
OVERLAP_CHARS = 200
MIN_CHARS = 80

ZERO_WIDTH = re.compile(r"[​-‏﻿]")


@dataclass
class ProseChunk:
    doc_id: str
    title: str
    section: str | None
    text: str
    source_url: str
    doc_type: str = "prose"
    lang: str = "en"


def _clean(text: str) -> str:
    text = ZERO_WIDTH.sub("", text or "")
    text = re.sub(r"\s+", " ", text)
    return text.strip()


def _strip_chrome(tree: HTMLParser) -> None:
    for selector in BOILERPLATE_SELECTORS:
        for node in tree.css(selector):
            node.decompose()


def page_title(tree: HTMLParser) -> str:
    for selector in ("h1.entry-title", "h1", "title"):
        node = tree.css_first(selector)
        if node:
            title = _clean(node.text())
            if title:
                return title.split("|")[0].strip()
    return "Untitled"


def _doc_id(source_url: str, key: str) -> str:
    digest = hashlib.sha1(f"{source_url}#{key}".encode("utf-8")).hexdigest()[:16]
    return digest


def extract_faq(html: str, source_url: str) -> list[ProseChunk]:
    """One document per question-and-answer pair."""
    tree = HTMLParser(html)
    title = page_title(tree)
    chunks: list[ProseChunk] = []
    for index, panel in enumerate(tree.css("div.fusion-panel")):
        heading = panel.css_first("span.fusion-toggle-heading") or panel.css_first("h4.panel-title")
        body = panel.css_first("div.panel-body")
        if not heading or not body:
            continue
        question = _clean(heading.text())
        answer = _clean(body.text())
        if not question or len(answer) < 5:
            continue
        chunks.append(
            ProseChunk(
                doc_id=_doc_id(source_url, f"faq-{index}"),
                title=title,
                section=question,
                text=f"Question: {question}\nAnswer: {answer}",
                source_url=source_url,
                doc_type="faq",
            )
        )
    return chunks


def _sections(tree: HTMLParser) -> list[tuple[str | None, str]]:
    """Walk the main content, breaking a new section at every heading."""
    root = (
        tree.css_first("div.post-content")
        or tree.css_first("main")
        or tree.css_first("body")
    )
    if root is None:
        return []

    sections: list[tuple[str | None, list[str]]] = [(None, [])]
    for node in root.css("h1, h2, h3, h4, h5, p, li, td, blockquote"):
        text = _clean(node.text())
        if not text or any(phrase in text for phrase in BOILERPLATE_PHRASES):
            continue
        if node.tag in {"h1", "h2", "h3", "h4", "h5"}:
            sections.append((text, []))
        else:
            sections[-1][1].append(text)

    merged: list[tuple[str | None, str]] = []
    for heading, lines in sections:
        # Avada repeats sidebar links as list items; drop runs of very short lines.
        body = " ".join(line for line in lines if len(line) > 25)
        if body:
            merged.append((heading, body))
    return merged


def _pack(text: str) -> Iterable[str]:
    """Split long text at sentence boundaries into overlapping windows."""
    if len(text) <= TARGET_CHARS:
        yield text
        return
    sentences = re.split(r"(?<=[.!?])\s+", text)
    buffer = ""
    for sentence in sentences:
        if buffer and len(buffer) + len(sentence) + 1 > TARGET_CHARS:
            yield buffer.strip()
            buffer = buffer[-OVERLAP_CHARS:] + " " + sentence
        else:
            buffer = f"{buffer} {sentence}".strip()
    if buffer.strip():
        yield buffer.strip()


def extract_page(html: str, source_url: str) -> list[ProseChunk]:
    tree = HTMLParser(html)
    _strip_chrome(tree)
    title = page_title(tree)

    if tree.css_first("div.fusion-panel"):
        faq = extract_faq(html, source_url)
        if faq:
            return faq

    chunks: list[ProseChunk] = []
    for section_index, (heading, body) in enumerate(_sections(tree)):
        for part_index, part in enumerate(_pack(body)):
            if len(part) < MIN_CHARS:
                continue
            chunks.append(
                ProseChunk(
                    doc_id=_doc_id(source_url, f"s{section_index}-p{part_index}"),
                    title=title,
                    section=heading,
                    text=part,
                    source_url=source_url,
                )
            )
    return chunks
