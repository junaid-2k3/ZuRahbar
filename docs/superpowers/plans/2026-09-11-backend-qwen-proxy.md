# Backend Qwen Proxy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Two Firebase Cloud Functions that proxy Qwen calls for the app — `extractQuery` (text → origin/destination/intent) and `phraseAnswer` (computed route JSON → rider-facing reply text) — plus a one-off script to seed Firestore from the dataset bridge's output.

**Architecture:** Firebase Functions (Node.js/TypeScript), both functions are `onRequest` plain HTTPS endpoints (POST, JSON body/response) so the Flutter app calls them with Dio per the project's chosen networking stack, rather than pulling in the separate `cloud_functions` callable SDK. Both share one Qwen HTTP client module. The Qwen API key never reaches the app — it lives only in Firebase Functions secrets.

**Tech Stack:** Node.js 20, TypeScript, `firebase-functions` v2, `firebase-admin` (for the seed script only), Jest for tests, native `fetch` for the Qwen HTTP call (no SDK dependency needed for a single chat-completions endpoint).

**Spec:** `docs/superpowers/specs/2026-09-11-zurehbar-phase1-design.md`

## Global Constraints

- Qwen API key is never committed and never shipped in the app — it is read from a Firebase Functions secret (`DASHSCOPE_API_KEY`) at runtime, per the spec's "Manual setup required" section.
- The exact Qwen endpoint URL and model name are read from Functions config (`QWEN_API_BASE_URL`, `QWEN_MODEL`), not hardcoded — the key found in this repo (`build_documents/qwen_api.txt`, gitignored) is a ModelScope-style key (`ms-...` prefix); confirm the base URL/model against whatever provider docs came with the hackathon's Qwen access before first deploy (see Task 1, Step 6).
- `phraseAnswer`'s input shape mirrors this repo's existing Python `JourneyPlan`/`Leg`/`FareBreakdown` dataclasses (`zurehbar/graph/plan.py:23-66`) field-for-field in snake_case — the Flutter app's Dart port (Flutter plan) must produce exactly this JSON shape.

---

### Task 1: Scaffold the Functions project and build `extractQuery`

**Files:**
- Create: `backend/firebase.json`
- Create: `backend/.firebaserc` (placeholder — user fills in their project id, see Step 6)
- Create: `backend/functions/package.json`
- Create: `backend/functions/tsconfig.json`
- Create: `backend/functions/jest.config.js`
- Create: `backend/functions/src/qwen.ts`
- Create: `backend/functions/src/extractQuery.ts`
- Create: `backend/functions/src/index.ts`
- Test: `backend/functions/src/__tests__/extractQuery.test.ts`

**Interfaces:**
- Produces: `callQwen(systemPrompt: string, userMessage: string): Promise<string>` in `qwen.ts` — used by both this task and Task 2.
- Produces: the `extractQuery` callable, request `{ text: string }`, response `{ origin: string | null, destination: string | null, intent: string }`.

- [ ] **Step 1: Scaffold the Functions project**

```bash
mkdir -p backend/functions/src/__tests__
```

`backend/firebase.json`:
```json
{
  "functions": [
    {
      "source": "functions",
      "codebase": "default",
      "runtime": "nodejs20"
    }
  ]
}
```

`backend/.firebaserc`:
```json
{
  "projects": {
    "default": "REPLACE_WITH_YOUR_FIREBASE_PROJECT_ID"
  }
}
```

`backend/functions/package.json`:
```json
{
  "name": "zurehbar-functions",
  "version": "1.0.0",
  "engines": { "node": "20" },
  "main": "lib/index.js",
  "scripts": {
    "build": "tsc",
    "test": "jest",
    "serve": "npm run build && firebase emulators:start --only functions"
  },
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  },
  "devDependencies": {
    "@types/jest": "^29.5.0",
    "@types/node": "^20.0.0",
    "jest": "^29.7.0",
    "ts-jest": "^29.1.0",
    "typescript": "^5.4.0"
  }
}
```

`backend/functions/tsconfig.json`:
```json
{
  "compilerOptions": {
    "module": "commonjs",
    "target": "es2020",
    "lib": ["es2020"],
    "outDir": "lib",
    "rootDir": "src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true
  },
  "include": ["src"]
}
```

`backend/functions/jest.config.js`:
```js
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
};
```

- [ ] **Step 2: Install dependencies**

Run: `cd backend/functions && npm install`
Expected: `node_modules/` created, no errors.

- [ ] **Step 3: Write the failing test**

```typescript
// backend/functions/src/__tests__/extractQuery.test.ts
import { extractQueryHandler } from "../extractQuery";
import * as qwen from "../qwen";

jest.mock("../qwen");

describe("extractQueryHandler", () => {
  it("parses Qwen's JSON reply into origin/destination/intent", async () => {
    (qwen.callQwen as jest.Mock).mockResolvedValue(
      JSON.stringify({ origin: "University Town", destination: "Saddar", intent: "route" })
    );

    const result = await extractQueryHandler({ text: "how do I get from uni town to saddar" });

    expect(result).toEqual({
      origin: "University Town",
      destination: "Saddar",
      intent: "route",
    });
  });

  it("returns nulls when Qwen can't find one side of the trip", async () => {
    (qwen.callQwen as jest.Mock).mockResolvedValue(
      JSON.stringify({ origin: null, destination: "Hayatabad", intent: "route" })
    );

    const result = await extractQueryHandler({ text: "how do I get to hayatabad" });

    expect(result.origin).toBeNull();
    expect(result.destination).toBe("Hayatabad");
  });

  it("throws if Qwen's reply is not valid JSON", async () => {
    (qwen.callQwen as jest.Mock).mockResolvedValue("not json");

    await expect(extractQueryHandler({ text: "anything" })).rejects.toThrow(
      "Qwen returned an unparseable extraction response"
    );
  });
});
```

- [ ] **Step 4: Run the test to verify it fails**

Run: `cd backend/functions && npm test`
Expected: FAIL with `Cannot find module '../extractQuery'`

- [ ] **Step 5: Write the minimal implementation**

```typescript
// backend/functions/src/qwen.ts
export async function callQwen(systemPrompt: string, userMessage: string): Promise<string> {
  const apiKey = process.env.DASHSCOPE_API_KEY;
  const baseUrl = process.env.QWEN_API_BASE_URL ?? "https://api-inference.modelscope.cn/v1";
  const model = process.env.QWEN_MODEL ?? "Qwen/Qwen2.5-72B-Instruct";

  if (!apiKey) {
    throw new Error("DASHSCOPE_API_KEY is not set");
  }

  const response = await fetch(`${baseUrl}/chat/completions`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content: userMessage },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error(`Qwen request failed: ${response.status} ${await response.text()}`);
  }

  const data = (await response.json()) as {
    choices: { message: { content: string } }[];
  };
  return data.choices[0].message.content;
}
```

```typescript
// backend/functions/src/extractQuery.ts
import { callQwen } from "./qwen";

const SYSTEM_PROMPT = `You extract trip intent from a Zu Transport (Peshawar BRT) rider's
message. Reply with ONLY a JSON object: {"origin": string|null, "destination": string|null,
"intent": "route"|"fare"|"other"}. Use null for a side of the trip the rider didn't mention.
Do not invent a location the rider didn't say.`;

export interface ExtractQueryRequest {
  text: string;
}

export interface ExtractQueryResult {
  origin: string | null;
  destination: string | null;
  intent: string;
}

export async function extractQueryHandler(
  request: ExtractQueryRequest
): Promise<ExtractQueryResult> {
  const reply = await callQwen(SYSTEM_PROMPT, request.text);
  try {
    return JSON.parse(reply) as ExtractQueryResult;
  } catch {
    throw new Error("Qwen returned an unparseable extraction response");
  }
}
```

```typescript
// backend/functions/src/index.ts
import { onRequest } from "firebase-functions/v2/https";
import { extractQueryHandler, ExtractQueryRequest } from "./extractQuery";

export const extractQuery = onRequest(
  { secrets: ["DASHSCOPE_API_KEY"] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "POST only" });
      return;
    }
    try {
      const result = await extractQueryHandler(req.body as ExtractQueryRequest);
      res.status(200).json(result);
    } catch (error) {
      res.status(502).json({ error: (error as Error).message });
    }
  }
);
```

Note: `req.body` on `onRequest` is already-parsed JSON when the client sends `Content-Type: application/json` — Firebase Functions parses this for you, no `body-parser` needed.

- [ ] **Step 6: Run the test to verify it passes**

Run: `cd backend/functions && npm test`
Expected: PASS (3 tests)

- [ ] **Step 7: Confirm the Qwen endpoint before first real deploy**

This step has no automated check — it needs you to confirm the base URL/model against whatever docs the hackathon organizers gave for Qwen access, then set:
```bash
firebase functions:secrets:set DASHSCOPE_API_KEY --project <your-project-id>
# paste the key from build_documents/qwen_api.txt when prompted — do not commit that file
firebase functions:config:set qwen.base_url="<confirmed base url>" qwen.model="<confirmed model name>" --project <your-project-id>
```

- [ ] **Step 8: Commit**

```bash
git add backend/firebase.json backend/.firebaserc backend/functions/package.json \
  backend/functions/tsconfig.json backend/functions/jest.config.js \
  backend/functions/src/qwen.ts backend/functions/src/extractQuery.ts \
  backend/functions/src/index.ts backend/functions/src/__tests__/extractQuery.test.ts
git commit -m "feat: add extractQuery Qwen proxy function"
```

---

### Task 2: Build `phraseAnswer`

**Files:**
- Create: `backend/functions/src/phraseAnswer.ts`
- Modify: `backend/functions/src/index.ts`
- Test: `backend/functions/src/__tests__/phraseAnswer.test.ts`

**Interfaces:**
- Consumes: `callQwen` from `qwen.ts` (Task 1).
- Produces: the `phraseAnswer` callable, request shape `JourneyPlanPayload` (defined below, mirrors `zurehbar/graph/plan.py`'s `JourneyPlan.to_dict()`), response `{ reply: string }`. The Flutter app's journey planner (Flutter plan) must serialize to this exact shape.

- [ ] **Step 1: Write the failing test**

```typescript
// backend/functions/src/__tests__/phraseAnswer.test.ts
import { phraseAnswerHandler } from "../phraseAnswer";
import * as qwen from "../qwen";

jest.mock("../qwen");

const SAMPLE_PLAN = {
  found: true,
  origin: "University Town",
  destination: "Saddar",
  legs: [
    {
      route_id: "ER-01",
      route_label: "BRT Xpress Route 01",
      service_type: "express",
      board_station: "University Town",
      alight_station: "Saddar",
      ride_time_min: 22.5,
      wait_time_min: 3.0,
    },
  ],
  transfers: [],
  total_time_min: 25.5,
  fare: {
    total_pkr: 45,
    basis: "distance_band",
    is_estimate: true,
    note: "About 12.4 km of travel falls in fare band 3, Rs. 45.",
  },
  warnings: [],
};

describe("phraseAnswerHandler", () => {
  it("passes the plan to Qwen and returns its reply text", async () => {
    (qwen.callQwen as jest.Mock).mockResolvedValue(
      "Take the ER-01 from University Town to Saddar, about 26 minutes, Rs. 45."
    );

    const result = await phraseAnswerHandler({ plan: SAMPLE_PLAN });

    expect(result).toEqual({
      reply: "Take the ER-01 from University Town to Saddar, about 26 minutes, Rs. 45.",
    });
    expect(qwen.callQwen).toHaveBeenCalledWith(
      expect.any(String),
      JSON.stringify(SAMPLE_PLAN)
    );
  });

  it("passes through a not-found plan's message without inventing a route", async () => {
    const notFound = { found: false, message: "Origin and destination are the same station." };
    (qwen.callQwen as jest.Mock).mockResolvedValue(
      "Looks like your origin and destination are the same stop."
    );

    const result = await phraseAnswerHandler({ plan: notFound });

    expect(result.reply).toContain("same stop");
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend/functions && npm test`
Expected: FAIL with `Cannot find module '../phraseAnswer'`

- [ ] **Step 3: Write the minimal implementation**

```typescript
// backend/functions/src/phraseAnswer.ts
import { callQwen } from "./qwen";

const SYSTEM_PROMPT = `You are Rehbar, a friendly assistant for Zu Transport (Peshawar BRT)
riders. You are given a JSON journey plan already computed by deterministic code — never
recompute or contradict its route, fare, or timing numbers. If "found" is false, explain
the "message" field plainly. Keep the reply short and conversational. If "fare".note
mentions a caveat (e.g. an express flat-fare exception), mention it briefly rather than
asserting a fare with false certainty.`;

export interface JourneyPlanPayload {
  found: boolean;
  message?: string;
  [key: string]: unknown;
}

export interface PhraseAnswerRequest {
  plan: JourneyPlanPayload;
}

export interface PhraseAnswerResult {
  reply: string;
}

export async function phraseAnswerHandler(
  request: PhraseAnswerRequest
): Promise<PhraseAnswerResult> {
  const reply = await callQwen(SYSTEM_PROMPT, JSON.stringify(request.plan));
  return { reply };
}
```

```typescript
// backend/functions/src/index.ts — add
import { phraseAnswerHandler, PhraseAnswerRequest } from "./phraseAnswer";

export const phraseAnswer = onRequest(
  { secrets: ["DASHSCOPE_API_KEY"] },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "POST only" });
      return;
    }
    try {
      const result = await phraseAnswerHandler(req.body as PhraseAnswerRequest);
      res.status(200).json(result);
    } catch (error) {
      res.status(502).json({ error: (error as Error).message });
    }
  }
);
```

After deploy, these are reachable at `https://<region>-<project-id>.cloudfunctions.net/extractQuery` and `.../phraseAnswer` — the Flutter app's backend client (Flutter plan, Task 5) posts JSON to these URLs with Dio.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd backend/functions && npm test`
Expected: PASS (5 tests total)

- [ ] **Step 5: Commit**

```bash
git add backend/functions/src/phraseAnswer.ts backend/functions/src/index.ts \
  backend/functions/src/__tests__/phraseAnswer.test.ts
git commit -m "feat: add phraseAnswer Qwen proxy function"
```

---

### Task 3: Firestore seed script

**Files:**
- Create: `backend/functions/scripts/seedFirestore.ts`
- Test: `backend/functions/src/__tests__/seedFirestore.test.ts`

**Interfaces:**
- Consumes: `data/export/firestore_seed.json`, produced by the Dataset Bridge plan's Task 2 (`export_to_firestore_seed`). Shape: `{ routes: Record<string, object>, stations: Record<string, object>, fares: { current: object }, service_hours: { current: object } }`.
- Produces: `buildBatches(seed: FirestoreSeed): { collection: string; docId: string; data: object }[]` — a pure function the test verifies without touching a real database; the script's `main()` feeds this list into `firebase-admin`'s batched writes.

- [ ] **Step 1: Write the failing test**

```typescript
// backend/functions/src/__tests__/seedFirestore.test.ts
import { buildBatches } from "../../scripts/seedFirestore";

describe("buildBatches", () => {
  it("flattens every collection into (collection, docId, data) triples", () => {
    const seed = {
      routes: { "ER-01": { route_id: "ER-01" } },
      stations: { chamkani: { station_id: "chamkani" } },
      fares: { current: { currency: "PKR" } },
      service_hours: { current: { opens: "06:00" } },
    };

    const batches = buildBatches(seed);

    expect(batches).toEqual(
      expect.arrayContaining([
        { collection: "routes", docId: "ER-01", data: { route_id: "ER-01" } },
        { collection: "stations", docId: "chamkani", data: { station_id: "chamkani" } },
        { collection: "fares", docId: "current", data: { currency: "PKR" } },
        { collection: "service_hours", docId: "current", data: { opens: "06:00" } },
      ])
    );
    expect(batches).toHaveLength(4);
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd backend/functions && npm test`
Expected: FAIL with `Cannot find module '../../scripts/seedFirestore'`

- [ ] **Step 3: Write the minimal implementation**

```typescript
// backend/functions/scripts/seedFirestore.ts
//
// Manual run, once per dataset refresh: node lib-scripts/seedFirestore.js
// Requires GOOGLE_APPLICATION_CREDENTIALS pointed at a service account key
// for your Firebase project (see plan Step 5 for setup).
import * as fs from "fs";
import * as path from "path";
import * as admin from "firebase-admin";

export interface FirestoreSeed {
  routes: Record<string, object>;
  stations: Record<string, object>;
  fares: Record<string, object>;
  service_hours: Record<string, object>;
}

export interface SeedBatch {
  collection: string;
  docId: string;
  data: object;
}

export function buildBatches(seed: FirestoreSeed): SeedBatch[] {
  const batches: SeedBatch[] = [];
  for (const [collection, docs] of Object.entries(seed)) {
    for (const [docId, data] of Object.entries(docs)) {
      batches.push({ collection, docId, data });
    }
  }
  return batches;
}

async function main() {
  const seedPath = path.resolve(__dirname, "../../../data/export/firestore_seed.json");
  const seed = JSON.parse(fs.readFileSync(seedPath, "utf-8")) as FirestoreSeed;
  const batches = buildBatches(seed);

  admin.initializeApp();
  const db = admin.firestore();
  const writer = db.bulkWriter();
  for (const { collection, docId, data } of batches) {
    writer.set(db.collection(collection).doc(docId), data);
  }
  await writer.close();
  console.log(`Seeded ${batches.length} documents across ${Object.keys(seed).length} collections.`);
}

if (require.main === module) {
  main().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd backend/functions && npm test`
Expected: PASS (6 tests total)

- [ ] **Step 5: Run the seed script against your real Firebase project**

This step needs your live project and is not automated:
```bash
# from the Firebase console: Project Settings → Service Accounts → Generate new private key
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account-key.json
cd backend/functions && npx tsc && node lib/../scripts-lib/seedFirestore.js
```
(Add `"scripts": ["scripts"]` to `tsconfig.json`'s `include` array first, or compile the script with a separate `tsc` invocation, so it lands somewhere Node can run it directly — either works, pick whichever keeps `functions/lib/` limited to deployable function code.)

- [ ] **Step 6: Commit**

```bash
git add backend/functions/scripts/seedFirestore.ts backend/functions/src/__tests__/seedFirestore.test.ts
git commit -m "feat: add Firestore seed script for the curated dataset"
```
