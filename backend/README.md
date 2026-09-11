# backend

Firebase Cloud Functions (v2, `onRequest`) that proxy Qwen for the ZuRehbar app.

## Functions

- **`extractQuery`** — takes a rider's free-text message and asks Qwen to pull out
  `{ origin, destination, intent }` so the deterministic planner can route it.
- **`phraseAnswer`** — takes an already-computed journey plan (route, fare, timing) and
  asks Qwen to phrase it as a short conversational reply. Qwen never computes numbers,
  only wording.

## Configuration

Copy `functions/.env.example` to `functions/.env` (already gitignored) for local
emulation, or set the same three variables as Cloud Functions v2 environment variables /
a `.env.<project-id>` file per Firebase's docs.

**The plan document's `firebase functions:config:set qwen.base_url=... qwen.model=...`
instruction does not work here.** That's the v1 runtime-config API, and it does not
populate `process.env` for a v2 `onRequest` function — `qwen.ts` reads
`process.env.QWEN_API_BASE_URL` / `process.env.QWEN_MODEL` directly, so a deployer who
follows that instruction literally will silently keep the hardcoded fallback model
forever. Use a `.env`/`.env.<project-id>` file or `defineString` params instead.

## Known gap

Neither endpoint currently has request authentication or rate limiting — anyone with the
URL can invoke it and consume Qwen/DashScope quota. Add Firebase App Check or another
gate before a public launch.
