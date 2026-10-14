# FoodSnap — Agent Instructions

Camera-first meal-photo app (1 dietician ↔ many clients). One Flutter codebase → Android APK + Web PWA. Flutter + Riverpod + go_router + Firebase (Auth, Firestore, Storage, FCM, Functions v2 Node 20 `asia-south1`, Hosting).

## Read first

- `docs/UI_UX_SPEC.md` — screens S01–S14, tokens §5, microcopy §11. Source of truth for UI.
- `docs/TECH_SPEC.md` — data model §5, rules §6, functions §7, milestones §14 (M0–M10). Source of truth for behavior.
- If it's not in these docs, do not invent it. Ask, or leave a `TODO(spec)` comment.

## How to work

- Work **one milestone at a time** (TECH_SPEC §14). Finish it, `flutter analyze` clean + app runs, then stop and report.
- Before each milestone, restate in 3–5 lines what you will build and which screens/files it touches.
- Small, reviewable diffs. Do not refactor unrelated code.
- Never commit secrets. `lib/firebase_options.dart` and the web VAPID key come from the developer's `flutterfire configure` — never hardcode them.
- Android app id is `com.hpsdstudio.foodsnapp` (display name FoodSnapp). Debug SHA-1 is registered in console (Google sign-in works on debug); release/Play-signing SHA-1 must be registered before any release build.

## Conventions

- State: Riverpod (`AsyncNotifier`/`StreamProvider`). Routing: `go_router` with redirect order in TECH_SPEC §8. No codegen (no freezed/build_runner).
- Layering: widget → provider → repository → Firebase. Widgets never call Firebase directly.
- Models are plain Dart classes with `fromMap`/`toMap`. Trusted logic (invite redeem, streaks, unread counters, push) lives in Cloud Functions, never the client.
- Theme tokens from UI spec §5 via `lib/core/theme/` — no hard-coded colors/sizes in widgets. Exact microcopy strings from UI spec §11. No green anywhere; success = `textPrimary`/white + check icon.
- Every async screen handles loading/error/empty states per UI spec. Use `AsyncValue` everywhere.
- Platform code (install detection, notifications, capture) in `lib/core/platform/` behind conditional imports so Android + web both compile.
- Meal docs always write `calories: null` in v1 (reserved for v2). Image pipeline: never upload raw — 1280px q80 + 360px thumb q75 in isolate, strips EXIF.
- Spark-only (no Blaze, decided M3): no Cloud Functions — pairing is a client transaction + rules (TECH_SPEC §17), push descoped. `functions/` is dormant: keep it building/passing, never deploy.

## Commands

```sh
flutter pub get
flutter analyze                                   # must be clean per milestone
flutter test                                      # focused: flutter test test/<file>.dart
flutter run                                       # Android device/emulator (primary)
flutter run -d chrome                             # web PWA variant
flutter build apk --release
flutter build web --release
firebase emulators:start                          # Auth, Firestore, Storage, Functions (needs JDK 21+; Android builds use 17 — if emulators refuse to start, prefix commands with JAVA_HOME=<jdk21+> PATH=<jdk21+>/bin:$PATH)
cd rules_test && npm test                         # security rules tests (M1+; runs emulators:exec --project demo-foodsnap from repo root)
cd functions && npm run build                     # functions typecheck
firebase deploy --only hosting,functions,firestore:rules,storage
```
Add deps with `flutter pub add <package>` (let versions resolve, don't hand-pin).

## Definition of done (per milestone)

1. Acceptance criteria in TECH_SPEC §14 met.
2. `flutter analyze` clean; tests for touched logic pass; rules tests still pass if rules/data shape changed.
3. Short report: what changed, manual test (Android emulator first), anything left as `TODO(spec)`.
