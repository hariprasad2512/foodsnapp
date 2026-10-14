# FoodSnap — Agent Instructions

FoodSnap is a Snapchat-style, camera-first app for sending meal photos to a dietician (one dietician, many clients). Flutter (Android APK + Web PWA) + Firebase.

## Read first
- `docs/UI_UX_SPEC.md` — screens S01–S14, tokens, copy. Source of truth for UI.
- `docs/TECH_SPEC.md` — data model, security rules, functions, milestones. Source of truth for behavior.

If something is not in these docs, do not invent it. Ask, or leave a `TODO(spec)` comment.

## How to work
- Work **one milestone at a time** (TECH_SPEC §14). Finish it, make sure `flutter analyze` is clean and the app runs, then stop and report.
- Before each milestone, restate in 3–5 lines what you are about to build and which screens/files it touches.
- Prefer small, reviewable changes. Do not refactor unrelated code.
- Never commit secrets. `firebase_options.dart` and the VAPID key come from the developer's setup.

## Conventions
- State: Riverpod. Routing: go_router. No code generation (no freezed, no build_runner).
- Widgets never call Firebase directly: widget → provider → repository → Firebase.
- Models are plain Dart classes with `fromMap` / `toMap`.
- Every async screen handles loading, error, and empty states exactly as in the UI spec.
- Use the design tokens from UI spec §5 via the theme. No hard-coded colors or sizes in widgets.
- Use the exact microcopy strings from UI spec §11.
- Platform code (web install detection, notifications) lives in `lib/core/platform/` behind conditional imports so both Android and web builds compile.
- Security-sensitive logic (invite redemption, streaks, unread counters, push) belongs in Cloud Functions, never in the client.

## Commands
```
flutter pub get
flutter analyze
flutter test
flutter run -d chrome          # web
flutter run                    # Android device/emulator
flutter build apk --release
flutter build web --release
firebase emulators:start       # Auth, Firestore, Storage, Functions
cd rules_test && npm test      # security rules tests
cd functions && npm run build
firebase deploy --only hosting,functions,firestore:rules,storage
```

## Definition of done (per milestone)
1. Acceptance criteria in TECH_SPEC §14 are met.
2. `flutter analyze` has no warnings; tests for the touched logic pass.
3. Rules tests still pass if rules or data shape changed.
4. A short note on what changed, what was tested manually, and anything left as `TODO(spec)`.
