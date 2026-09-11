# ZuRehbar Phase 1 (MVP) — Design Spec

**Date:** 2026-09-11
**Status:** Approved for planning
**Scope:** Phase 1 only (text Q&A, on-device routing, fare calc) per the Project Plan's phased order. Voice (Phase 2), interactive map (Phase 3), and polish/supporting features (Phase 4) are explicitly out of scope here.

## Source documents

- `build_documents/ZuRehbar_SRS_Functional_v1.md` (FR-1–FR-12)
- `build_documents/ZuRehbar_SRS_UI_v1.md` (UI-2–UI-13)
- `build_documents/ZuRehbar_Project_Plan_v1.md` (tech stack, phases, MAP spec)

This spec does not restate those requirements in full — it records the decisions needed to start building Phase 1 and the architecture that implements them.

## Decisions made (this session)

| # | Question | Decision |
|---|---|---|
| 1 | Repo layout | **Monorepo.** `app/` (Flutter) and `backend/` (Firebase Functions) added to this repo, alongside the existing data pipeline (`zurehbar/`, `scripts/`, `data/`). This repo's `CLAUDE.md` scope statement ("this repo is its data source... rider app is a separate Flutter build") is now stale and must be updated as part of Phase 1 work. |
| 2 | Routing split | **On-device**, confirmed. Backend only proxies Qwen calls. Matches NFR-1 (connectivity resilience). |
| 3 | Multi-leg fare policy | **Keep whole-trip distance fare** (this repo's existing `calculate_fare`: single tap-in/tap-out priced on total trip distance), overriding SRS FR-5.3's stated sum-of-legs default. This is a deliberate deviation from the SRS, kept because it matches how the real fare system works and is already built/tested. Functional SRS Open Issue #2 is resolved this way for Phase 1. |
| 4 | "Andrej Karpathy skill" | Not a real installed skill — means a coding-style preference: minimal, readable, no premature abstraction, build only what the current phase needs, explicit over clever. Applied as a style constraint on all Phase 1 code, not a tool. |
| 5 | Primary answer format (UI SRS Open Issue #1) | **Structured card**: route badges, fare, time, transfer points as a scannable card. Chosen over a plain chat bubble because it makes stops/routes tappable (UI-5.5.1) and embeds the Phase 3 schematic map (MAP-2) without a redesign. |
| 6 | Express flat fare (FR-5.2) | **Still open** — see "Open items" below. Phase 1 default: never auto-apply the flat Rs. 55 fare; always return the distance-band fare plus a note that an express flat fare may apply. This is the existing, already-built behavior. |

## Newly discovered context (not in the SRS/Plan docs)

- This repo's data pipeline (`zurehbar/scrape` → `extract` → `model` → `graph` → `index`) already produces the "existing structured dataset" both SRS docs assume exists (`data/curated/{routes,stations,fares,service_hours}.json`, plus `dataset_report.json` for anomalies). Phase 1 does not need to build this dataset — it needs to **bridge** it into the app.
- Functional SRS Open Issue #1 (route/branch code meanings) is already resolved for every code except bare `F`/`B` (not present on the current network map): `ER` = Express, `SR` = BRT Stopping, `DR` = Direct, `XER` = Super Express; trailing letters (`DR-03A`/`DR-03B`) are branch variants, not direction.
- The source site's own text is self-contradictory on express fares: one notice says "Express Routes... are operating on a flat fare basis" (implying *all* express routes are flat-fare), while the network summary calls `DR-*` routes "Direct / Feeder Routes" — meaning "feeder" maps to the `direct` service type, not `express`. Under the current route classification (`express`, `direct`, `standard`, `super_express` are mutually exclusive), there may be no route that is both "express" and "feeder" as FR-5.2's flat-fare condition requires. This is a genuine source contradiction, not something to resolve by guessing.
- Known dataset gaps that Phase 1 inherits as-is (per `CLAUDE.md`): 3 routes (`DR-11`, `ER-16`, `XER-15`) are excluded from routing (unreadable stop sequences) but stay searchable; no GPS coordinates (only needed starting Phase 3); station name folding must preserve non-Latin script for Urdu/Pashto aliases.

## Architecture

```
[Flutter App — app/]
   │ 1. User types query (text only in Phase 1)
   ▼
[Backend: Firebase Function — backend/] ──▶ [Qwen DashScope API]
   │ 2. Extract intent/entities (origin, destination) from query text
   ▼
[Flutter App — on-device]
   │ 3. Dart routing engine runs against local Drift DB
   │    (ported from zurehbar/graph/{network,plan}.py)
   │    → best route(s), fare, transfers, time
   ▼
[Backend: Firebase Function] ──▶ [Qwen DashScope API]
   │ 4. Phrase the computed route data as a natural-language reply
   ▼
[Flutter App]
   5. Renders structured-card answer; text stays in scrollable
      chat history (UI-5.6.1)
```

Dataset flow (build-time / sync, separate from the query flow above):

```
data/curated/*.json (this repo's existing pipeline output)
   │  new: scripts/export_app_dataset.py
   ▼
Firestore (canonical, seeded once) ──sync──▶ Drift (bundled + refreshed on-device)
```

## Components

### 1. Dataset bridge (`scripts/export_app_dataset.py`, new)
- Reads `data/curated/routes.json`, `stations.json`, `fares.json`, `service_hours.json`.
- Excludes the 3 non-routable routes from the routing graph feed but keeps them in the searchable stop/route lookup, matching the existing `_coverage_warnings` behavior.
- Writes: (a) a Firestore-seed JSON (one doc per route/station/fare-band, matching the curated shape — no new intermediate format), (b) the same data as a Flutter asset bundled at build time so the app has a working copy with zero network calls on first launch.
- No schema invention: Drift tables mirror the curated JSON fields directly.

### 2. Backend (`backend/`, new — Firebase Functions, Node.js/TypeScript)
- `extractQuery`: takes raw query text, calls Qwen (DashScope) to extract `{origin, destination, intent}`. Stateless proxy; DashScope API key stored in Firebase Functions config/secrets, never shipped in the app.
- `phraseAnswer`: takes the app's computed route/fare/time JSON, calls Qwen to produce the rider-facing reply text.
- No dataset-sync or feedback endpoints in Phase 1 (Phase 4).

### 3. Flutter app (`app/`, new)
- Drift DB seeded from the bundled dataset asset (component 1).
- Dart routing engine: direct port of `graph/network.py`'s route-stop graph (`(route, direction, station)` nodes, boarding cost = half headway + transfer penalty) and `graph/plan.py`'s planner/fare calculator. Same algorithm, same fare policy (decision #3).
- Fuzzy stop-name matching (FR-1.3): plain string/fuzzy matching in Dart (e.g. edit-distance or token-based), no vector search — per the SRS's own note that vector search is undecided and out of scope here.
- Home screen only: single search box + From/To toggle (UI-4.2.1/4.2.2), autocomplete (UI-4.2.3), scrollable chat history (UI-5.6.1), structured-card answers with color-coded route badges (UI-5.4.1, decision #5). Saved Routes and Settings tabs exist as navigation stubs (empty screens), full functionality is Phase 4.
- No voice, no map rendering, no offline-banner/settings/feedback UI in Phase 1.

## Error handling (Phase 1 slice of FR-9)

- Same origin/destination, off-network destination, off-hours queries: handled by the ported Dart routing engine using the same logic as the existing Python `graph/plan.py` (per FR-9.2/9.3), phrased by Qwen.
- Unrecognized/off-network origin: nearest-stop fallback is deferred — Functional SRS Open Issue #3 (no GPS, only stop sequence) is unresolved; Phase 1 returns a clarifying question (FR-2.2) instead of guessing a "nearest" stop.

## Testing

Manual testing only (per the Project Plan, team's explicit choice — no automated suite). Recommended (not required): a checklist of known real trips including same-origin/destination, off-network locations, and off-hours queries, run before Phase 1 is considered done — mirrors the Project Plan's own recommendation in §6.

## Manual setup required (user must do before/alongside implementation)

- Provide the Qwen/DashScope API key (user has said they will).
- Create a Firebase project; enable Firestore and Cloud Functions.
- Provide `google-services.json` (Android) for the Flutter app to link to the Firebase project.
- Local toolchain: Flutter SDK + Android SDK installed on the dev machine building `app/`.
- Firebase CLI login (`firebase login`) on whichever machine deploys `backend/`.

## Open items carried forward (not resolved here)

1. **Express flat-fare route classification (FR-5.2).** Source data is self-contradictory (see "Newly discovered context"). Phase 1 ships with the safe default (distance-band fare + note); revisit if/when an authoritative feeder/express route list is provided.
2. **Nearest-stop resolution (Functional SRS Open Issue #3).** No GPS in the dataset yet (MAP-3 adds this in Phase 3). Phase 1 asks a clarifying question instead of resolving to "nearest" stop.
3. **Feedback loop design (Open Issue #4).** Deferred to Phase 4 — no "Report issue" backend/UI in Phase 1.
4. **`CLAUDE.md` update.** The repo's scope statement needs rewriting once `app/`/`backend/` land, to stop describing this as a data-pipeline-only repo.

## Out of scope (Phase 1, restated)

Voice (ASR/TTS), interactive schematic map, saved-routes full functionality, settings functionality, onboarding flow, accessibility pass, feedback mechanism, offline-mode banner/hardening, "Powered by AI" branding element, GPS data collection, user accounts, payments, real-time tracking, Play Store distribution, CI/CD, automated tests.
