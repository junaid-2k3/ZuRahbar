# ZuRehbar — Project Plan

**Version:** 1.0
**Date:** September 11, 2026
**Team:** muhammad hamza + junaid ahmad 
**Reference documents (required reading, not repeated here):**
- `ZuRehbar_SRS_Functional_v1.md` — Part 1: all functional/system requirements (FR-1 through FR-12)
- `ZuRehbar_SRS_UI_v1.md` — Part 2: all screen/interaction requirements (UI-2 through UI-13)

This plan does not restate those requirements — it defines **how the team builds them**: tech stack, architecture, phasing, and one new feature not yet covered in either SRS.

---

## 1. Core Functionality — At a Glance

For full detail, see the referenced sections in each SRS. Summary only:

| Area | Source |
|---|---|
| Text + voice query understanding, English/Urdu, fuzzy stop matching | Functional SRS §3.1–3.2 |
| Existing structured stops/routes/fares dataset, full network incl. feeder routes | Functional SRS §3.3 |
| Route planning engine (best-route, no transfer cap, multi-option on request) | Functional SRS §3.4 |
| Fare calculation (distance/stage + express flat fare) | Functional SRS §3.5 |
| Response generation (route, fare, time, frequency, walking guidance) | Functional SRS §3.6 |
| Session context / follow-ups | Functional SRS §3.7 |
| Voice pipeline (ASR → Qwen → TTS) | Functional SRS §3.8 |
| Error handling & edge cases | Functional SRS §3.9 |
| Feedback mechanism | Functional SRS §3.10 |
| No-login persistence of frequent/home/work routes | Functional SRS §3.11 |
| Service hours awareness | Functional SRS §3.12 |
| Screens (Home / Saved Routes / Settings), input UI, answer display, onboarding, accessibility | UI SRS §3–13 |
| **Interactive route map (NEW)** | Specified below, §2 of this plan |

---

## 2. New Feature Specification: Interactive Route Map

Not covered in either SRS — specified here since it affects both dataset design and architecture.

- **MAP-1:** For any computed route answer, the app shall render a schematic (metro-map-style) diagram of the network, with the specific path and stations for that answer highlighted.
- **MAP-2:** The map shall be embedded inline within the answer card (per the UI SRS's answer-display flow), not a separate full-screen view.
- **MAP-3:** The underlying dataset must carry GPS coordinates per stop (superseding Functional SRS §3.3, which had marked this out of scope) — needed to lay out stops consistently on the schematic diagram, even though the rendered map itself is stylized rather than a literal geographic map.
- **MAP-4:** The diagram style is custom/schematic (not an embedded Google Maps/OSM view) — stops and connecting lines drawn and styled by the app, in the spirit of a transit map rather than a street map.

This supersedes the earlier "no GPS coordinates needed" decision — flagged here explicitly since it changes both the dataset schema and the data-collection task.

---

## 3. Tech Stack

### 3.1 Mobile App
| Component | Choice | Notes |
|---|---|---|
| Framework | **Flutter (Dart)** | Cross-platform; Android is the primary/only target for this build |
| State management | Riverpod (suggested default) | Not specified by team; swap freely — implementation detail |
| Local database | **Drift** (SQLite-based, Flutter-native ORM) | Bundled dataset (stops/routes/fares/GPS), saved routes, offline feedback queue. Chosen as the Flutter-appropriate equivalent of Room/SQLite |
| Networking | Dio | REST calls to backend |
| Voice | `speech_to_text` (ASR) + `flutter_tts` (TTS) | Wraps Android's built-in speech APIs, per team's choice |
| Map rendering | Flutter `CustomPainter` / canvas drawing | Schematic diagram, not a maps SDK — no Google Maps/OSM dependency needed |
| Local prefs | `shared_preferences` | Settings: language override, voice on/off, text size, theme |

### 3.2 Backend
| Component | Choice | Notes |
|---|---|---|
| Platform | **Firebase Cloud Functions** (Google Cloud) | Lightweight, fits the team's Firebase/Google Cloud choice; Cloud Run is the fallback if functions outgrow their limits |
| Language | Node.js / TypeScript (suggested default) | Tight Firebase integration; swappable |
| Source-of-truth database | Firestore | Canonical stops/routes/fares/GPS dataset; app syncs a local copy into Drift |
| Responsibilities | (1) Proxy all Qwen DashScope calls (keeps API key server-side), (2) serve dataset sync/update endpoint, (3) receive feedback ("Report issue") submissions | Routing/fare computation itself runs **on-device** (see §4), not on the backend — this keeps the app usable on patchy connectivity per the Functional SRS's connectivity requirement |

### 3.3 AI/ML
| Component | Choice | Notes |
|---|---|---|
| Model access | modelscope (Qwen API)** | Called only from the backend, never directly from the app |
| Role | Query understanding (extract origin/destination/intent from text or transcribed voice) + natural-language response generation (turn computed route/fare/time data into a rider-friendly reply) | Qwen does **not** compute the route or fare itself — that's deterministic graph/logic code, see §4 |

### 3.4 Distribution & Tooling
| Component | Choice |
|---|---|
| Version control | GitHub (private repo) |
| Distribution | Debug/release **APK for hackathon demo & judging only** — no Play Store listing, so no signing/publishing pipeline needed |
| Testing | Manual testing only — no automated suite planned |
| Budget | Available — not constrained to free tiers for Firebase/DashScope usage |

---

## 4. System Architecture

```
[Flutter App]
   │  1. User query (text or voice)
   │     — voice: speech_to_text → transcript shown to user
   ▼
[Backend: Firebase Function] ──▶ [Qwen DashScope API]
   │  2. Backend sends transcript to Qwen for
   │     intent/entity extraction (origin, destination)
   ▼
[Flutter App — on-device]
   │  3. Local routing engine runs against the bundled
   │     Drift database (stops/routes/fares/GPS)
   │     → computes best route(s), fare, transfers, time
   ▼
[Backend: Firebase Function] ──▶ [Qwen DashScope API]
   │  4. Backend sends computed route data to Qwen to
   │     generate the natural-language response text
   ▼
[Flutter App]
   5. Displays answer (text/voice via flutter_tts) +
      schematic map with path/stations highlighted (MAP-1–4)
```

**Why routing runs on-device rather than on the backend:** the team's choice of a bundled local database plus the connectivity-resilience requirement in the Functional SRS both point the same direction — the app needs to produce answers even with a weak connection. Only the Qwen calls (which inherently require network access) go through the backend. If this split doesn't match the team's intent, it's worth confirming before Phase 1 starts.

**Dataset sync:** the backend/Firestore holds the canonical dataset; the app periodically syncs it into its local Drift database, so day-to-day querying and routing work fully offline between syncs.

---

## 5. Development Phases

No fixed dates (per team's choice to keep this open-ended) — phases are ordered, not scheduled.

**Phase 1 — MVP Core (text-based Q&A, routing, fare)**
- Bundle existing dataset into Drift; decode route/branch codes (-12, -09, F, B — Functional SRS Open Issue #1) as a prerequisite
- Backend: Qwen proxy for query understanding + response generation
- On-device routing engine: direct + multi-transfer, no cap, overall-best-route default with multi-option on request
- Fare calculation: stage/distance + express flat fare, sum-of-legs default (Open Issue #2 — revisit if a combined fare is confirmed)
- Location resolution: fuzzy matching, nearest-stop fallback, clarification on ambiguity
- Core UI: single search box + From/To mode, scrollable chat history, autocomplete
- **Prerequisite before UI build starts:** resolve the still-open "primary answer format" decision from the UI SRS (§14, Open Issue #1)

**Phase 2 — Voice**
- ASR integration: tap-to-activate mic, waveform feedback, transcript display
- TTS integration: spoken answers with barge-in support
- Voice and text share the same backend understanding/response pipeline

**Phase 3 — Interactive Map**
- Add GPS coordinates to the dataset schema (MAP-3) — data collection/verification task
- Build the custom schematic map renderer (MAP-4) and embed it inline in the answer card (MAP-2)
- Highlight the computed path and stations for each answer (MAP-1)

**Phase 4 — Polish & Supporting Features**
- Saved/frequent routes: manual pin, automatic Home-screen surfacing, dedicated Saved Routes tab
- Feedback: "Report issue" button + comment capture
- Settings: language override, voice toggle, text size, clear data, theme
- Onboarding flow for first-time users
- Accessibility pass (text scaling, screen-reader labels)
- Offline-mode hardening: offline/poor-connectivity banner, graceful degradation
- "Powered by AI/Qwen" branding element

---

## 6. Testing & Quality Approach

Manual testing only, per the team's choice. Given routing and fare logic are the highest-risk components to get subtly wrong (multi-transfer graph search, stage-fare calculation, direction-aware routing), it's worth manually testing these against a checklist of known real trips (including edge cases: same origin/destination, off-network locations, off-hours queries) before each phase is considered done — flagged here as a recommendation, not a requirement, since automated testing was explicitly declined.

---

## 7. Open Items Carried Forward

These remain unresolved and should be closed out before or during the relevant phase:

1. **Route/branch code meanings** (-12, -09, F, B, etc.) — needed for Phase 1 routing and Phase 3 map accuracy. (Functional SRS Open Issue #1)
2. **Multi-leg combined fare policy** — unconfirmed; defaulting to sum-of-legs. (Functional SRS Open Issue #2)
3. **Primary answer display format** (chat bubble vs. card vs. diagram-first) — unresolved in the UI SRS; blocks detailed Phase 1 screen design. (UI SRS Open Issue #1)
4. **On-device vs. backend routing split** — this plan assumes on-device (§4); confirm this matches team intent before Phase 1 architecture is locked in.
5. **"Andrej Karpathy skills"** — mentioned as something you have installed for use during execution, but nothing matching that name turned up in a catalog search. If you can point to what this refers to (a specific skill name, or where it's installed), it can be factored into how the team works.
6. since this is for a qwen hackathon and they will provided api for all of their models, if this project can use qwen models for its functionality use them and inform me about that.
---

## 8. Out of Scope / Non-Goals

Carried forward from both SRS documents, plus this plan's own additions:
- User accounts, ticket payment/booking, real-time bus tracking, multi-city support (Functional SRS §7)
- Google Play Store distribution — demo APK only for this build
- Automated test suite
- CI/CD pipeline
