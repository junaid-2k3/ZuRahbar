# Software Requirements Specification
## ZuRehbar — AI Voice & Text Assistant for Zu Transport Riders

**Version:** 1.0
**Date:** September 11, 2026
**Prepared by:** Sajid Islam and team (2–3 member team)
**Scope note:** This document covers **functional and system behavior requirements only**. User interface and interaction design (screens, layouts, voice UX flows, visual design) are deliberately out of scope here and will be covered in a separate UI/UX SRS.

---

## 1. Introduction

### 1.1 Purpose
This document specifies the functional requirements for ZuRehbar, an AI-powered assistant that helps Zu Transport riders in Peshawar determine which bus(es) to take between two locations, where to transfer, and what the fare will be. It is intended to guide development for an initial build, and — pending validation — a future pitch to Zu Transport as an integrated or companion product.

### 1.2 Background
Zu Transport (Peshawar's bus service, transpeshawar.pk) operates a multi-route network including main routes and feeder ("F") routes, with direction-dependent branch codes (e.g., "-12", "-09", "-10", "-16") observed on its published stop lists. Riders — particularly newcomers — often don't know which bus to take, and many trips require 2–3 transfers. Zu Transport's existing app/website shows timing and route info but does not do route-finding or trip planning.

### 1.3 Scope
ZuRehbar will:
- Accept natural-language text and voice queries about how to travel between two points on the Zu Transport network.
- Resolve the query to specific stops, compute a route (direct or via transfers), and return route, transfer, fare, and travel-time information.
- Operate as a mobile app for the initial build, targeting the entire Zu Transport network (including feeder routes).
- Be developed with the intent of eventually pitching to Zu Transport as a real product, not solely as a one-off hackathon demo.

Out of scope for v1 is detailed in Section 7.

### 1.4 Definitions & Abbreviations
| Term | Meaning |
|---|---|
| Stop | An official, named Zu Transport stop/station |
| Leg | One continuous ride on a single bus/route between two stops |
| Transfer | A change from one bus/route to another mid-journey |
| Feeder route ("F") | A branch route feeding into the main network (per site's stop naming) |
| ASR | Automatic Speech Recognition (speech-to-text) |
| TTS | Text-to-Speech |
| Qwen | The LLM powering query understanding and response generation |

### 1.5 References
- Zu Transport website: https://transpeshawar.pk/

---

## 2. Overall Description

### 2.1 Product Perspective
ZuRehbar is a new, standalone mobile application. It is not (in v1) embedded into Zu Transport's existing app/site, and does not depend on any real-time data feed from Zu Transport — it operates on a static, structured dataset of stops, routes, and fares.

### 2.2 Product Functions (Summary)
- Understand rider queries in text or voice, in English or Urdu.
- Resolve named locations to official stops, including fuzzy-matched and off-network locations.
- Plan an optimal route (direct or multi-transfer) between origin and destination.
- Calculate fare per leg and total trip fare.
- Return a complete answer: route(s), transfer point(s), fare, estimated travel time, frequency, and walking guidance to/from stops.
- Maintain conversational context within a session (follow-up queries).
- Persist frequently used routes across sessions without requiring account creation.
- Allow users to flag incorrect/outdated answers.

### 2.3 User Characteristics
Primary users are Zu Transport riders in Peshawar, including newcomers unfamiliar with the network, who may query in English or Urdu, by text or voice, and may be on unreliable mobile data connections while commuting.

### 2.4 Operating Environment
- **Platform:** Mobile app (initial build target).
- **Connectivity:** Must remain usable under poor/patchy connectivity — this is a hard requirement given the target usage context (commuters, mobile data).
- **Data source:** A static, structured stops/routes/fares dataset (already exists in some form and will be extended/cleaned for this project) — no live/real-time Zu Transport data feed exists or is assumed.

### 2.5 Design & Implementation Constraints
- Voice is implemented as separate ASR → Qwen (text reasoning) → TTS stages, not an end-to-end speech-to-speech model.
- No formal user accounts/login in v1 — cross-session personalization must work without signup (see FR-11).
- Team of 2–3 building this; timeline is flexible (more than a month / not yet fixed).

### 2.6 Assumptions & Dependencies
See Section 6 — several data/policy questions (route code meanings, multi-leg fare policy) remain open and are documented there rather than assumed silently.

---

## 3. Functional Requirements

### 3.1 Query Input & Understanding (FR-1)
- **FR-1.1** The system shall accept rider queries via both text and voice input.
- **FR-1.2** The system shall understand queries in English and Urdu.
- **FR-1.3** The system shall fuzzy-match loosely typed or spoken stop names to canonical stop names in the dataset (e.g., "uni town" → "University Town").

### 3.2 Location Resolution (FR-2)
- **FR-2.1** If a named location is not a recognized Zu Transport stop, the system shall resolve it to the nearest official stop rather than rejecting the query.
- **FR-2.2** If a query is ambiguous (e.g., matches multiple stops with similar confidence), the system shall ask a clarifying question rather than silently guessing.
- **FR-2.3** *(Dependent on Open Issue #3)* "Nearest stop" resolution must be defined using a method compatible with the dataset's structure, since the dataset stores stop **sequence/order only, not GPS coordinates** (per FR-3.3).

### 3.3 Route & Fare Dataset (FR-3)
- **FR-3.1** The system shall use an existing structured dataset of stops, routes, and fares (already available; to be extended/validated for this project rather than built from scratch).
- **FR-3.2** Dataset coverage shall include the entire Zu Transport network, including feeder ("F") routes.
- **FR-3.3** The dataset shall record stop ordering/sequence per route. GPS coordinates are not required for v1.
- **FR-3.4** The dataset shall capture directionality: a route's stop sequence may differ between outbound and return direction (see Open Issue #1 regarding decoding branch codes like "-12", "-09", "F", "B").

### 3.4 Trip Planning / Routing Engine (FR-4)
- **FR-4.1** The routing engine shall select the overall best route based on efficiency (time/convenience), not automatically prefer a direct route over one with transfers.
- **FR-4.2** There shall be no fixed cap on the number of transfers considered; the engine shall return the best route it finds regardless of transfer count.
- **FR-4.3** By default, the system shall return a single best route. The user shall be able to request multiple route options (e.g., fastest vs. cheapest vs. fewest transfers) on demand.
- **FR-4.4** Routing logic shall account for direction of travel, since outbound and return paths may differ (per FR-3.4).

### 3.5 Fare Calculation (FR-5)
- **FR-5.1** Standard routes: fare shall be calculated using Zu Transport's distance/stage-based model (fare determined by stage/distance traveled, consistent with its tap-in/tap-out fare structure).
- **FR-5.2** Express routes: fare shall be calculated as a flat fare, per Zu Transport's express fare policy.
- **FR-5.3** For multi-leg trips, total fare shall default to the sum of each leg's individual fare. *(Whether Zu Transport offers a combined/discounted multi-leg fare is unconfirmed — see Open Issue #2; this default should be revisited if confirmed otherwise.)*

### 3.6 Response Generation (FR-6)
- **FR-6.1** Each response shall include: bus/route number(s) to take, transfer point(s) if any, total fare, and estimated travel time.
- **FR-6.2** Where frequency data is available in the dataset, responses shall include bus frequency (e.g., "every ~15 minutes").
- **FR-6.3** Responses shall include walking guidance to the first stop and from the last stop to the destination — the system is not strictly stop-to-stop only.

### 3.7 Conversation & Session Management (FR-7)
- **FR-7.1** The system shall support contextual follow-up queries within a session (e.g., "what about from there to Hayatabad instead?").
- **FR-7.2** If a follow-up query omits the origin, the system shall reuse the origin from earlier in the same session.

### 3.8 Voice Pipeline (FR-8)
- **FR-8.1** Voice input shall be converted to text via a dedicated ASR stage.
- **FR-8.2** Query understanding and response generation shall be handled by Qwen operating on text.
- **FR-8.3** Text responses shall be converted to speech via a dedicated TTS stage.

### 3.9 Error Handling & Edge Cases (FR-9)
- **FR-9.1** If the dataset does not directly cover a query (unrecognized location or unserved trip), the system shall attempt to provide the closest reasonable answer rather than a flat failure message.
- **FR-9.2** The system shall explicitly detect and handle: (a) identical origin and destination, and (b) destinations outside Zu Transport's coverage area — in both cases returning a clear, specific message rather than a nonsensical or silent failure.
- **FR-9.3** The system shall be aware of Zu Transport's service hours. Queries made outside operating hours shall be answered with a message noting this and, where possible, the next available service time.

### 3.10 Feedback Mechanism (FR-10)
- **FR-10.1** The system shall provide a lightweight way for a user to flag a response as wrong or outdated. *(How flagged feedback is reviewed/actioned is not yet defined — see Open Issue #4.)*

### 3.11 Personalization & Data Persistence (FR-11)
- **FR-11.1** The system shall not require account creation or login.
- **FR-11.2** The system shall persist a user's frequently used routes (including implied home/work locations) across sessions using device-local storage or implicit channel identity (e.g., a phone number on a messaging channel, or a device identifier), without requiring explicit signup.

### 3.12 Service Hours & Availability (FR-12)
- **FR-12.1** The system shall maintain and reference Zu Transport's operating hours to support FR-9.3.

---

## 4. Non-Functional Requirements (Functional-Adjacent Only)

- **NFR-1 (Connectivity resilience):** The app shall remain usable on poor/patchy mobile connectivity — e.g., through lightweight requests, local caching of the route/fare dataset on-device, and graceful degradation when connectivity drops mid-session.
- **NFR-2 (Data currency):** All routing/fare data is static (no real-time bus tracking or live delay data exists or is assumed for v1). The system's accuracy is bounded by how current the underlying static dataset is.
- **NFR-3 (Language coverage):** Query understanding must reliably handle both English and Urdu inputs, including stop-name variants.
- **NFR-4 (Extensibility):** The routing/fare logic should be structured so that a future combined multi-leg fare rule (if confirmed) or GPS-based nearest-stop matching can be added without a full redesign.

---

## 5. External Interfaces (Non-UI)

- **5.1 Route/Fare Dataset:** Primary data source for all routing and fare logic (existing structured dataset, to be validated/extended).
- **5.2 Qwen (LLM):** Handles natural-language understanding of queries and generation of responses.
- **5.3 ASR/TTS Services:** Separate speech-to-text and text-to-speech components supporting the voice channel (FR-8).

---

## 6. Assumptions, Dependencies & Open Issues

These are explicitly unresolved and should be tracked, not silently assumed away:

1. **Route/branch code meanings unknown.** Suffixes seen on Zu Transport's site (e.g., "-12", "-09", "-10", "-16", "F", "B") have not yet been decoded. This must be investigated before directional and feeder-route logic (FR-3.4, FR-4.4) can be implemented reliably.
2. **Multi-leg fare policy unconfirmed.** It's unknown whether Zu Transport offers any combined/discounted fare for transfer trips, or whether each leg is charged independently. Default assumption (FR-5.3) is sum-of-legs until confirmed.
3. **"Nearest stop" resolution method undefined.** Since the dataset stores stop sequence but not GPS coordinates (FR-3.3), the method for resolving an off-network location to its "nearest" stop (FR-2.1) needs to be defined — e.g., via text/fuzzy proximity on the network graph, or by adding GPS data later.
4. **Feedback handling loop undefined.** FR-10.1 covers letting a user flag a bad answer, but where that feedback goes and how/whether it corrects the dataset is not yet designed.
5. **Full out-of-scope boundary not finalized.** Beyond the exclusions in Section 7, the team has not yet finalized every boundary (e.g., specific edge cases around express vs. stage-fare routes).
6. **Timeline is flexible.** No fixed hackathon deadline was set at time of writing; requirement scope may need revisiting as a deadline firms up.

---

## 7. Out of Scope (v1)

- Formal user accounts, login, or signup flows.
- Ticket payment, booking, or fare payment integration.
- Real-time bus location tracking or live delay information (data is static only).
- Multi-city support (Peshawar / Zu Transport only).
- UI/UX and interaction design — covered in a separate SRS.

---

## 8. Future Enhancements (Candidate, Not Committed)

- Confirming and implementing a combined multi-leg fare model, if one exists.
- Adding GPS coordinates to the dataset to improve nearest-stop resolution.
- Formal accounts, if cross-device (not just cross-session/device) personalization becomes a requirement.
- Real-time data integration, if/when Zu Transport exposes live bus data.
- Expanding language support beyond English/Urdu (e.g., Pashto, Roman Urdu) if user testing shows demand.
