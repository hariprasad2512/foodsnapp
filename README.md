# FoodSnapp

**FoodSnapp is a camera-first app for sending meal photos to a dietician — one dietician, many clients.**

It borrows Snapchat's interaction model — the camera *is* the home screen, swipe between camera / chat / history, big shutter, one-tap send — but there are **no filters, no stories, and nothing disappears. Photos are kept forever, because the history is the point.**

## How it works

- **Client:** takes a photo before each meal, tags it (the tag is auto-selected by time of day), and sends it in two taps: shutter → send. Each client has exactly one dietician.
- **Dietician:** has many clients. A glanceable clients list shows unread counts, the last meal, and who hasn't logged today — without opening anything. She reacts, comments, and chats with each client.
- **Calm, not gamified:** the only game mechanic is the logging streak. Success feedback is a checkmark, never green.
- **Privacy:** these are health-adjacent photos. Storage is private by security rule (relationship members only). Keep this app to people you know.

## Platforms

One Flutter codebase ships two targets:

| Target | Notes |
|---|---|
| Android (APK) | Primary client experience, `camera` plugin viewfinder |
| Web PWA | Dietician installs on iPhone via Safari → Add to Home Screen; uses the browser camera via `image_picker` |

## Status

Built milestone-by-milestone per `docs/TECH_SPEC.md` §14:

- [x] **M0** — Project setup (Flutter boots on Android + Chrome, Firebase connected, theme tokens, router skeleton)
- [x] **M1** — Firestore + Storage rules with emulator tests (`rules_test/`)
- [x] **M2** — Email auth + role gating (sign-in, role screen)
- [x] **M3** — Invite pairing via client transaction (dietician creates code → client redeems → both see the relationship)
- [ ] M4+ — Capture → send, timeline, history, feedback, streaks (see `docs/TECH_SPEC.md` §14)

> **Spark-only (decided in M3, see `TECH_SPEC.md` §17):** no Blaze plan, so there are no Cloud Functions in v1. `functions/` is kept dormant (typed, never deployed). Pairing runs as a client-side Firestore transaction guarded by security rules, and push is descoped to in-app realtime until/unless Blaze lands.

## Technical

### Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (stable), Dart null-safe |
| State | `flutter_riverpod` (`AsyncNotifier` / `StreamProvider`) |
| Routing | `go_router` with auth/role redirects |
| Backend | Firebase: Auth, Firestore, Storage, Hosting (`asia-south1`) |
| Image pipeline | 1280px q80 + 360px thumb q75 in an isolate, EXIF stripped — never upload raw |
| Lints | `flutter_lints`; no codegen (no freezed/build_runner) |

### Architecture

```
widgets → Riverpod providers → repositories → Firebase SDKs
```

Widgets never call Firebase directly. Models are plain Dart classes with `fromMap`/`toMap`. Trusted logic (invite redeem validation, streaks, unread counters, push) belongs in Cloud Functions — or, while Spark-only, in security rules.

### Design

Indigo palette, Inter font, theme tokens in `lib/core/theme/` (from `docs/UI_UX_SPEC.md` §5 — no hard-coded colors/sizes in widgets). Meal docs always write `calories: null` in v1 (reserved for v2 calorie estimation). Specs are the source of truth: `docs/UI_UX_SPEC.md` (screens S01–S14) and `docs/TECH_SPEC.md`.

## Getting started

```sh
flutter pub get
flutterfire configure   # REQUIRED: generates gitignored firebase_options.dart + google-services.json
flutter run             # Android device/emulator (primary)
flutter run -d chrome   # web PWA variant
```

| Command | Purpose |
|---|---|
| `flutter analyze` | Must be clean per milestone |
| `flutter test` | Dart unit tests (`test/`) |
| `cd rules_test && npm test` | Security-rules tests via Firestore emulator |
| `cd functions && npm run build` | Dormant-functions typecheck |
| `flutter build apk --release` | Release APK (register release/Play SHA-1 in Firebase console first — only debug SHA-1 is registered) |
| `flutter build web --release` | Release PWA |

Firebase config files (`lib/firebase_options.dart`, `android/app/google-services.json`) are **never committed** — each developer runs `flutterfire configure` locally.
