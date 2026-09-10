# ZuRehbar dataset pipeline

Scrapes [transpeshawar.pk](https://transpeshawar.pk/), extracts the Zu Peshawar
(Peshawar BRT) route, fare and service data, and produces two things ZuRehbar
needs to answer a rider's question:

1. **A structured dataset** in `data/curated/` — stations, routes, ordered stops,
   travel times, fare bands — driving a deterministic journey planner and fare
   calculator.
2. **A Qdrant collection** (`zu_rider`) of hybrid dense + BM25 vectors over both
   that structured data and the site's prose, for everything that is not a
   point-to-point trip.

Qwen phrases the answer. It does not compute the route or the price.

## Why both

Vector search alone cannot answer "how do I get from University Town to Saddar
Bazaar". Retrieval finds text that *mentions* stations; it cannot compute a
transfer or price a trip. So the graph tools do the reasoning and the index
handles fares, cards, rules, hours and station facts.

## Quick start

```bash
python -m venv .venv && .venv/bin/pip install -e ".[dev]"
docker compose up -d                        # Qdrant on :6333

.venv/bin/python -m zurehbar.scrape.run     # fetch pages + assets (cached)
.venv/bin/python -m zurehbar.model.build    # -> data/curated/*.json
.venv/bin/python -m zurehbar.index.docgen   # -> data/curated/documents.json
.venv/bin/python -m zurehbar.index.qdrant_load --recreate

.venv/bin/python -m zurehbar.index.qdrant_load --query "how much does a Zu card cost"
.venv/bin/python scripts/smoke_retrieval.py   # English, Urdu, Roman Urdu, filters
.venv/bin/python scripts/ask.py --demo        # rider question -> tools -> grounded context
.venv/bin/python scripts/reindex_docs.py --changed   # re-embed only what changed
.venv/bin/pytest
```

## What the source actually publishes

Reconnaissance findings that shape every design decision here:

| Fact | Consequence |
|---|---|
| WordPress with an open `/wp-json` REST API | Page inventory and `modified` timestamps come free; no blind crawling |
| The TLS chain is broken — no intermediate certificate is served | Every client must skip verification **for this host only** (`zurehbar/http.py`) |
| No `robots.txt`, no sitemap | Scope is an explicit allowlist in `config/scrape_targets.yaml`; 1 req/s |
| `/passenger-services/operation-schedule/` holds 20 timetable tables | 10 routes × 2 directions with stops, first/last bus, platform, headway |
| The site claims 13 routes; the network map lists **19** | The route inventory comes from the map, not the prose |
| Fares exist **only inside an Urdu JPEG** | Vision transcription, verified against a second fare image |
| Fares are charged by **distance**, not by stage count | Per-leg distances are needed, and the site publishes none |
| Route maps are images; 9 routes have no timetable | 6 recovered from the map, 3 left explicitly unresolved |

## Known limits

* **Fares are estimates.** The fare bands and prices are exact. The kilometres a
  trip is credited with are not: the site publishes route totals and per-leg
  *times*, never per-leg distances, so each leg's distance is interpolated from
  its route's published length in proportion to its running time. Trips near a
  band boundary can land in the wrong band. `FareBreakdown.is_estimate` says so
  on every result.
* **The flat express fare is not applied automatically.** The fare image says
  express buses *on feeder routes* charge a flat Rs. 55, but the site never says
  which express routes count as feeder services. Charging that on a corridor
  express would overcharge a rider, so the distance band is returned and the
  exception is surfaced as a note.
* **Three routes cannot be planned.** DR-11, ER-16 and XER-15 have no timetable
  and their stop sequences are unreadable on the network map. They are in the
  dataset and searchable as text, but excluded from routing, and the planner says
  so when a rider's trip depends on one.
* **Two routes are truncated.** DR-14 and DR-14A are published as starting at
  Board Bazar, but the map only yields stops from PTCL Office onward.
* **The site publishes two different Zu Card prices.** The card purchase page
  (last modified 2025-02-11) says PKR 400; the FAQ (last modified 2023-07-19)
  still says Rs. 300. The dataset uses 400 and states the disagreement, so a
  rider is not sent to the ticket office with the wrong money.
* **The source contradicts itself in places.** ER-10's timeline and timetable
  disagree about which stations it serves, and its inbound table is one stop
  short. Every such case is recorded in `data/curated/dataset_report.json`
  rather than smoothed over.

## Embedding throughput

Measured on this machine (12 cores, 7.6 GB RAM, no GPU, and swapping):
**~13 s per document**, whether the model runs in float32 or bfloat16 — CPU
bfloat16 is emulated, so it buys memory, not speed. A full 247-document reindex
therefore takes roughly an hour, and a single query embedding costs a second or
two.

That is fine for a one-off build and too slow for a voice assistant's tail
latency. Three ways out, in order of preference:

1. **Run the embedder on a GPU.** Same model, same vectors, two orders of
   magnitude faster. Nothing in the pipeline changes.
2. **Cache query embeddings.** Riders ask the same few hundred questions.
3. **Swap the model.** `EMBED_MODEL` is read from the environment, so
   `EMBED_MODEL=intfloat/multilingual-e5-small` (118M parameters, 384-dim, solid
   Urdu) indexes in minutes on CPU. Vector size is read from the model, so the
   collection adapts — but the collection must be recreated, not updated, since
   the dense dimension changes.

## Known warnings

`qdrant-client` 1.19 talks to the pinned server image 1.12.4 and prints a version
mismatch warning. Loading and hybrid search both work, but align the two before
relying on newer query features: either bump the image in `docker-compose.yml`
or pin the client to the server's minor version.

## Layout

```
config/scrape_targets.yaml   rider-relevant allowlist
config/station_aliases.yaml  147 stations: site spellings, Roman Urdu, Urdu script
zurehbar/http.py             rate-limited, disk-cached fetcher
zurehbar/scrape/             REST inventory, downloader, link crawl
zurehbar/extract/            schedule tables, prose chunking, vision tiling
zurehbar/model/              schemas, name resolution, dataset build
zurehbar/graph/              network graph, journey planner, fare calculator
zurehbar/index/              document generation, embeddings, Qdrant loader
zurehbar/agent/tools.py      the three tools Qwen calls
data/raw/                    verbatim HTML, images, PDFs (git-ignored)
data/review/                 vision transcriptions with provenance
data/curated/                the verified dataset
```

## Re-running

The fetcher caches every response and revalidates with `ETag`/`If-Modified-Since`,
so re-runs are cheap and parser work never re-hits the network. Point IDs in
Qdrant are UUID5 of the document id, so reloading updates in place.

When TransPeshawar publishes a new fare image or map version, re-run the scrape,
re-read the changed image, update the file in `data/review/`, and rebuild. The
`verified_by` and `verified_at` fields on those files record who last checked.
