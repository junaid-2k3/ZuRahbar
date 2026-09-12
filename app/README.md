# ZuRehbar app (Phase 1)

The rider-facing Flutter app: ask a question in plain English, Roman Urdu or Urdu,
get the buses to take, where to change, the fare and the travel time.

Routing and fares are computed **on-device**, from the dataset bundled at
`assets/data/`. Qwen only reads the question and words the answer — it never
computes a route or a price.

## Run it

```bash
flutter pub get

# 1. Make sure the bundled dataset exists (regenerate after any pipeline change):
(cd .. && .venv/bin/python -m zurehbar.pipeline --only export-app)

# 2. Run. The API key is passed in at build time, never committed. The repo
#    keeps one in build_documents/qwen_api.txt, which is gitignored:
flutter run --dart-define=QWEN_API_KEY="$(cat ../build_documents/qwen_api.txt)"

# Optional overrides (defaults are ModelScope + Qwen2.5-72B-Instruct):
#   --dart-define=QWEN_API_BASE_URL=https://dashscope.aliyuncs.com/compatible-mode/v1
#   --dart-define=QWEN_MODEL=qwen-plus
```

**With no key the app still runs.** It answers entirely on-device: the same
routes, the same fares, worded by `lib/api/local_assistant.dart` instead of by
Qwen, and each answer says so. The same fallback catches a dead network
mid-session (NFR-1), so a demo never dies on connectivity.

Check the key, endpoint and model actually answer before you rely on them:

```bash
../scripts/check_qwen.sh
```

The bundled key is a ModelScope one (`ms-…`), so it goes with the default
`https://api-inference.modelscope.cn/v1`. A DashScope key (`sk-…`) needs
`--dart-define=QWEN_API_BASE_URL=https://dashscope-intl.aliyuncs.com/compatible-mode/v1`
and a DashScope model name.

## Build an APK

```bash
flutter build apk --release --dart-define=QWEN_API_KEY="$(cat ../build_documents/qwen_api.txt)"
```

> The key ends up inside the APK and is extractable from it. That is acceptable
> only for a private demo build — see the deviation note in
> `docs/superpowers/specs/2026-09-11-zurehbar-phase1-design.md`.

### If a cold Android build fails on a Kotlin session file

```
Execution failed for task ':gradle:compileKotlin'.
> java.nio.file.NoSuchFileException: /usr/lib/flutter/.../gradle/.kotlin/sessions/....salive
```

The Kotlin Gradle plugin writes scratch files under each project's `.kotlin`
directory, and one of the projects in a Flutter Android build is Flutter's own
Gradle plugin inside the SDK install — read-only when Flutter came from a system
package manager. Point that directory somewhere writable **in
`~/.gradle/gradle.properties`**:

```properties
kotlin.project.persistent.dir=/tmp/zurehbar-kotlin
```

It has to live there: a project's own `gradle.properties` is not visible to
included builds, so `android/gradle.properties` has no effect. The equivalent
one-off is `flutter build apk -Pkotlin.project.persistent.dir=<writable dir>`.

## Tests

```bash
flutter test
```

`test/integration/` is the part worth knowing about: `real_dataset_test.dart`
plans real trips against the actual bundled dataset (the unit tests use inline
fixtures), and `app_smoke_test.dart` drives the real widget tree end to end with
no backend.

## Layout

```
lib/
  api/          backend_client.dart   the two calls, as an interface
                qwen_direct_client.dart  Qwen, called straight from the app
                local_assistant.dart  on-device extraction + phrasing fallback
  data/         drift schema + seeding the bundled dataset
  models/       the curated JSON shapes
  routing/      network_graph.dart    route-stop graph + Dijkstra
                journey_planner.dart  planner + fare calculator
                station_resolver.dart fuzzy stop-name matching (FR-1.3)
  ui/           home_screen.dart, answer_card.dart, chat_controller.dart
```

`routing/` is a direct port of `zurehbar/graph/{network,plan}.py` — same graph,
same fare policy. Keep the two in step.
