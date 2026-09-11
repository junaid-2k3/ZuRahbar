# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

The **data pipeline** for ZuRehbar, an AI assistant for Zu Peshawar (Peshawar BRT) riders. It scrapes
`transpeshawar.pk` and produces two artefacts:

1. `data/curated/*.json` — the structured route/fare/station dataset, driving a deterministic journey
   planner and fare calculator.
2. A Qdrant collection (`zu_rider`) of hybrid dense + BM25 vectors over that dataset plus the site's prose.

The rider-facing app is a separate Flutter build (see `build_documents/`); this repo is its data source.
Qwen phrases answers — it never computes a route or a price. That split is the core design rule here.

## Commands

The package is **not** pip-installed, so `python -m zurehbar.*` resolves only from the repo root — run
everything from `/home/junaid/zu Rahbar`. A bare `cd /tmp && python -m zurehbar.model.build` fails with
`ModuleNotFoundError`, and a heredoc piped to `python -` inherits that too. The `scripts/*.py` files work
from anywhere because each inserts the project root on `sys.path` itself.

```bash
docker compose up -d                                  # Qdrant on :6333 (required for index/search)

.venv/bin/python -m zurehbar.pipeline                 # scrape -> build -> docgen -> index
.venv/bin/python -m zurehbar.pipeline --only build docgen
.venv/bin/python -m zurehbar.scrape.run [--refresh]   # --refresh ignores the HTTP cache
.venv/bin/python -m zurehbar.model.build [--strict]   # --strict also fails on anomalies
.venv/bin/python -m zurehbar.index.docgen
.venv/bin/python -m zurehbar.index.qdrant_load --recreate
.venv/bin/python -m zurehbar.index.qdrant_load --query "how much does a Zu card cost" [--route-id ER-01]

.venv/bin/python scripts/smoke_retrieval.py           # retrieval across English/Urdu/Roman Urdu + filters
.venv/bin/python scripts/ask.py --demo                # rider question -> tools -> grounded context
.venv/bin/python scripts/reindex_docs.py --changed    # re-embed only documents whose text changed

.venv/bin/pytest                                      # 69 tests, no network or Qdrant needed
.venv/bin/pytest tests/test_plan.py -k transfer       # single test
```

**Never run a full `--recreate` reindex to fix a few documents.** Embedding costs ~13 s/document on CPU
here (~1 hour for the corpus). `scripts/reindex_docs.py --changed` diffs generated text against stored
payloads and re-embeds only what moved. Point IDs are UUID5 of the document id, so upserts replace in place.

## Architecture

Stage boundaries matter more than file layout:

```
scrape/      WP REST API inventory + allowlist filter -> data/raw/ (verbatim, cached)
extract/     schedule.py: the 20 timetable tables      prose.py: FAQ + page chunking
             vision.py: tiles the network map for a vision model to read
model/       naming.py: every station name -> one station_id      build.py: -> data/curated/
graph/       network.py: route-stop graph              plan.py: planner + fare calculator
index/       docgen.py -> documents.json               embed.py + qdrant_load.py -> Qdrant
agent/       tools.py: the three tools Qwen calls, with their JSON schemas
```

**Why the graph is built over route-stop nodes, not stations** (`graph/network.py`): a station-to-station
graph cannot express waiting for a bus. Nodes are `(route, direction, station)`; boarding costs half the
route's headway plus a transfer penalty, riding costs only travel time. A shortest path therefore prefers a
one-seat ride unless a transfer genuinely saves time.

**Why vision extraction is not a pipeline stage:** the fare table and route inventory exist only inside
images. Transcriptions land in `data/review/*.json` with a `verified_by` stamp and a per-record
`confidence`, and only `confidence: high` records become routable. Automating this would put unverified
fares in front of riders. When re-reading an image, update the review file and rebuild — never edit
`data/curated/` by hand.

## What the source actually publishes

Reconnaissance findings that explain otherwise-puzzling code:

- **The TLS chain is broken** — no intermediate certificate. Verification is disabled for this one host,
  in `http.py` only, driven by `tls_verify` in `config/scrape_targets.yaml`.
- **No robots.txt, no sitemap.** Scope is an explicit allowlist; the crawler runs at 1 req/s.
- **Fares are charged by distance, not by stage count** — nine bands, Rs. 30 to Rs. 70, effective
  2025-07-01. This contradicts FR-5.1 in the functional SRS, which assumes a stage model.
- **The prose claims 13 routes; the network map lists 19.** The map legend is the only place giving each
  route's length in km, which is what the distance-based fare needs.
- **Route code prefixes decode as** ER = Express Route, SR = BRT Stopping Route, DR = Direct Route,
  XER = Super Express. The trailing letter in `DR-03A`/`DR-03B` and `DR-14`/`DR-14A` is a *branch variant*,
  not a direction — direction is a separate axis held in each route's `directions[]`. This answers
  Functional SRS Open Issue #1 for every code except "F"/"B", which do not appear on the current map.
- **The site contradicts itself.** Two Zu Card prices (card page 2025-02-11 says Rs. 400; FAQ 2023-07-19
  says Rs. 300 — the newer wins, and the conflict is stated in the document text). ER-10's timeline
  disagrees with its own timetable. Broken markup leaves literal `Bakhshu Pul/td>` in a table cell.

## Invariants worth preserving

- **`data/curated/dataset_report.json` records anomalies rather than hiding them.** `build.py` fails hard
  on integrity violations (dangling station reference, overlapping fare bands) and records everything else.
  A route that quietly loses a stop is a rider sent to a bus that never comes.
- **Fares are estimates and must say so.** The site publishes route totals and per-leg *times*, never
  per-leg distances, so leg distances are interpolated by time share. Band boundaries and prices are exact;
  the kilometres credited to a trip are not. `FareBreakdown.is_estimate` carries this.
- **The flat express fare is never applied automatically.** The fare image says express buses *on feeder
  routes* pay a flat Rs. 55, but the site never says which express routes are feeder services. Applying it
  to a corridor express such as ER-01 would undercharge. The distance band is returned; the exception is a
  note for Qwen to mention.
- **Missing data is reported as our gap, not a missing bus.** Three routes (DR-11, ER-16, XER-15) have
  unreadable stop sequences and are excluded from planning but stay searchable; `_coverage_warnings` says so
  when a rider's trip depends on one.
- **Station names go through `naming.resolve` before any lookup.** Folding must preserve non-Latin script —
  an ASCII-only fold silently maps every Urdu alias onto one station.
- **`config/station_aliases.yaml` is hand-maintained.** New stations from a rebuild show up in the report's
  `unregistered_stations`; add Roman-Urdu and Urdu forms there, since riders speak Urdu and Pashto.

## Open gaps against the product plan

- **No GPS coordinates.** `build_documents/ZuRehbar_Project_Plan_v1.md` MAP-3 requires per-stop coordinates
  for the schematic map, superseding FR-3.3. The site publishes none; they need an external source.
- **No exporter to Firestore or Drift.** The app bundles a local SQLite (Drift) copy synced from Firestore;
  nothing here writes either format yet.
- **Multi-leg fare policy differs from the SRS.** FR-5.3 defaults to sum-of-legs; `calculate_fare` prices
  the whole journey once on total distance, which matches a tap-in/tap-out distance fare. Unresolved
  (Functional SRS Open Issue #2).

## Embedding model

`EMBED_MODEL` (default `Qwen/Qwen3-Embedding-0.6B`, 1024-dim) is read from the environment. Two details are
easy to get wrong: queries take an instruction prefix and documents do not, and `max_seq_length` is capped
at 512 because the model advertises 32k and pads every batch far past any document here. Dense-only, so
lexical matching comes from a BM25 sparse vector fused server-side with RRF — station names are rare proper
nouns that dense retrieval blurs, and BM25 anchors "Hashtnagri" exactly. Changing the model changes the
vector size, which requires `--recreate`, not an update.

`qdrant-client` 1.19 warns on every connection that it is talking to the 1.12.4 server pinned in
`docker-compose.yml`. Loading and hybrid search both work; align the two before relying on newer query
features.
