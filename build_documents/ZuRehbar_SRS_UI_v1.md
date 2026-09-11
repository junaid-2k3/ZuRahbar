# Software Requirements Specification
## ZuRehbar — UI/UX & Interaction Requirements (Part 2)

**Version:** 1.0
**Date:** September 11, 2026
**Prepared by:** Sajid Islam and team (2–3 member team)
**Companion document:** ZuRehbar_SRS_Functional_v1.md (Part 1 — functional & system requirements)

**Scope note:** This document specifies **structural and interaction requirements** — screens, navigation, input/output behavior, and information architecture. It deliberately does **not** specify pixel-level visual design (exact colors, typography, spacing, iconography) — that belongs to a later visual design phase, once these requirements are validated.

---

## 1. Introduction

### 1.1 Purpose
This document defines how a rider interacts with ZuRehbar: what screens exist, how text and voice input work, how answers are presented, and how saved routes, feedback, and settings are surfaced. It complements the Functional SRS (Part 1), which defines what the system computes and returns; this document defines how that is presented and interacted with.

### 1.2 Scope
Covers the mobile app's screen structure, input modes, response presentation, and interaction patterns for v1. Does not cover: exact visual styling (colors/fonts beyond brand alignment), high-fidelity mockups, or backend/routing logic (see Part 1).

### 1.3 Definitions
Same as Part 1 (Stop, Leg, Transfer, ASR, TTS, Qwen), plus:
- **Barge-in:** The ability for a user to interrupt the assistant while it is speaking.
- **Empty state:** A screen/message state shown when there's no answer to display (e.g., no route found).

---

## 2. Overall UI/UX Approach

- **UI-2.1** The app shall use a minimal, clean visual style.
- **UI-2.2** The app shall align its branding (colors/logo) with Zu Transport's existing brand identity, for consistency and trust.
- **UI-2.3** The app shall support both light and dark themes, with a user-facing toggle (see Section 13, Settings).
- **UI-2.4** The app shall follow platform-native design conventions (Material Design on Android, Human Interface Guidelines on iOS) rather than a fully custom cross-platform look.

---

## 3. Information Architecture & Navigation

- **UI-3.1** The app shall be organized into a small set of tabs: **Home**, **Saved Routes**, and **Settings**.
- **UI-3.2** The **Home** screen is the primary interaction surface (query input + answers).
- **UI-3.3** The **Saved Routes** screen lists the user's saved/frequent routes (see Section 6).
- **UI-3.4** The **Settings** screen exposes user-configurable options (see Section 13).

---

## 4. Query Input UI

### 4.1 Input Modes
- **UI-4.1.1** The Home screen shall support both text entry and voice entry as first-class, equally accessible input modes.

### 4.2 Text Input Behavior
- **UI-4.2.1** The primary input shall be a single free-text/voice box (consistent with a Google Maps–style "where to?" search pattern), where a user can type or say both origin and destination in one query.
- **UI-4.2.2** An alternative structured entry mode with separate "From" and "To" fields shall also be available for users who prefer explicit entry.
- **UI-4.2.3** As the user types a stop name, the system shall show quick-tap autocomplete suggestions matching the dataset's stop names.

### 4.3 Voice Input Behavior
- **UI-4.3.1** Voice input shall be activated by tapping a mic button (tap to start, tap to stop) — not press-and-hold.
- **UI-4.3.2** While listening, the app shall show an animated waveform visual as feedback that audio is being captured.
- **UI-4.3.3** After a voice query, the app shall display the transcribed text of what the user said (not just the spoken answer), so the user can visually confirm what was understood.
- **UI-4.3.4** Users shall be able to interrupt (barge-in) Rehbar while it is speaking a voice answer, rather than being forced to let it finish.

---

## 5. Response & Answer Display UI

### 5.1 Answer Format
- **UI-5.1.1** *(Open — see Section 14)* The primary visual format for a route answer (plain chat bubble vs. structured card vs. route diagram) is not yet finalized and needs a follow-up decision before screen design begins.

### 5.2 Map View
- **UI-5.2.1** Each answer shall include a map view showing the relevant route(s), stops, and transfer point(s) visually, alongside the text/structured answer.

### 5.3 Multiple Route Options Display
- **UI-5.3.1** When the user requests multiple route options (per Functional SRS FR-4.3), the app shall present them as swipeable cards (one option per card, swipe to compare).

### 5.4 Route/Bus Number Visual Treatment
- **UI-5.4.1** Bus/route numbers shall be shown as color-coded badges to make them quick to spot and distinguish at a glance.

### 5.5 Tappable Actions on Answer Elements
- **UI-5.5.1** Stops and routes referenced within an answer shall be tappable, exposing actions such as "save as favorite" and "view this stop on the map."

### 5.6 Conversation History Display
- **UI-5.6.1** Past queries and answers within a session shall remain visible as a scrollable chat history, rather than being replaced by each new query.

---

## 6. Saved & Frequent Routes UI

- **UI-6.1** Users shall be able to manually save/pin a route (via the tappable actions in UI-5.5.1).
- **UI-6.2** The Home screen shall surface saved and/or frequently used routes by default, before the user types or speaks anything (per UI-3.2).
- **UI-6.3** The **Saved Routes** tab (UI-3.3) shall list these routes in a dedicated screen, distinct from the Home screen's quick-access surfacing. *(This reconciles an earlier lighter answer of "no dedicated section, just automatic suggestions" — the later navigation-structure decision explicitly established a dedicated Saved Routes tab; both automatic surfacing on Home and a full dedicated list under Saved Routes are included.)*

---

## 7. Feedback UI

- **UI-7.1** Each answer shall include a "Report issue" button/link (not simple thumbs up/down) for flagging a wrong or outdated answer.
- **UI-7.2** After tapping "Report issue," the user shall be able to add details/comments about what was wrong, rather than submitting a bare flag with no context.

---

## 8. Language UI

- **UI-8.1** The app shall auto-detect whether a query is in English or Urdu; there shall be no explicit manual language toggle in v1.

---

## 9. System State & Edge Case UI

- **UI-9.1** "No route found" and off-hours messages (per Functional SRS FR-9.2, FR-9.3) shall be shown as plain text answers within the normal chat/answer flow, not as a distinct illustrated empty-state screen.
- **UI-9.2** The app shall show an explicit indicator (e.g., a banner) when the device is offline or on poor connectivity, rather than failing silently.

---

## 10. Onboarding

- **UI-10.1** First-time users shall see an onboarding/intro flow explaining what ZuRehbar does and how to use text and voice input, before reaching the main Home screen.

---

## 11. Accessibility Requirements

- **UI-11.1** Accessibility is a priority for v1, including at minimum: adjustable text size and screen-reader compatibility (see also Settings, UI-13.1).

---

## 12. AI Transparency / Branding

- **UI-12.1** The app shall visibly communicate that it is powered by AI/Qwen (e.g., a "Powered by AI" badge or similar), rather than keeping this invisible to the user.

---

## 13. Settings Configurability

- **UI-13.1** The Settings tab shall allow the user to configure at minimum:
  - Language (overriding auto-detection if needed)
  - Voice on/off
  - Text size
  - Clearing saved data (saved/frequent routes, local history)
  - Theme (light/dark), per UI-2.3

---

## 14. Assumptions, Dependencies & Open Issues

1. **Primary answer format undecided.** Whether the main route answer renders as a plain chat bubble, a structured info card, or a route-diagram-first layout (UI-5.1.1) needs to be decided before detailed screen design/wireframing starts.
2. **Saved Routes reconciliation.** An earlier answer suggested no dedicated saved-routes screen (automatic suggestions only); a later answer established a dedicated "Saved Routes" tab. This document treats the tab as authoritative (Section 6) — flagged here for visibility in case that wasn't intentional.
3. **From/To vs. single-box default behavior.** Both a single free-text/voice box and a structured From/To mode are in scope (UI-4.2.1–4.2.2), but which is the default view, and how a user switches between them, needs interaction-design detailing.
4. **Exact visual design deferred.** Specific colors (beyond "match Zu Transport branding"), typography, iconography, and spacing are intentionally not specified here and should be defined in a subsequent visual design pass.

---

## 15. Out of Scope (This Document)

- Pixel-level visual design (exact colors, fonts, spacing, iconography).
- High-fidelity mockups/wireframes.
- Backend, routing, and fare-calculation logic (see Functional SRS, Part 1).
- Any functionality not already defined in Part 1 (this document only covers how existing functional requirements are presented and interacted with).
