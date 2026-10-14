# FoodSnap — Technical Specification (v1)

Companion doc: `UI_UX_SPEC.md` (screens S01–S14 are referenced by ID).
Rule for the agent: build milestone by milestone (§14), keep every milestone runnable, do not add features that are not in these docs.

---

## 1. Goals and non-goals

**Goals (v1)**
- Client sends meal photos (tag + optional note) to one dietician; dietician has many clients.
- Realtime timeline (meal cards + text messages), day-grouped history, streaks, reactions and comments.
- Push notifications on Android and on iPhone (via installed PWA).
- One Flutter codebase → Android APK + Web PWA.

**Non-goals (v1)**: calorie ML, video, voice, payments, multi-dietician per client, public sign-up flow polish, native iOS build.

## 2. Stack

| Concern | Choice |
|---|---|
| Framework | Flutter (latest stable), Dart null-safe |
| State | `flutter_riverpod` (AsyncNotifier/StreamProvider) |
| Routing | `go_router` with auth/role redirects |
| Backend | Firebase: Auth, Firestore, Storage, Cloud Messaging, Cloud Functions (v2, Node 20, TypeScript), Hosting |
| Functions region | `asia-south1` (Mumbai) |
| Camera | `camera` on Android; `image_picker` (camera source) on web |
| Image processing | `image` package, run in `compute()`/isolate |
| Config | `flutterfire configure` → `firebase_options.dart` |
| Lints | `flutter_lints`; no code generation (no freezed/build_runner) to keep things simple |

Use `flutter pub add <package>` so versions resolve to the latest compatible. Do not hand-pin versions.

## 3. Architecture

```
Flutter app (Android APK / Web PWA)
  UI (widgets)  →  Riverpod providers  →  Repositories  →  Firebase SDKs
                                                         │
                  Firebase: Auth · Firestore · Storage ◄─┘
                                   │ triggers
                              Cloud Functions ──► FCM push
```

Rules:
- Widgets never call Firebase directly; they use providers that wrap repositories.
- Repositories are plain Dart classes with `fromMap`/`toMap` models (no codegen).
- Anything that must be trusted (redeeming invites, streaks, unread counts, push) runs in Cloud Functions.

## 4. Project structure

```
foodsnap/
├─ AGENTS.md
├─ docs/ (UI_UX_SPEC.md, TECH_SPEC.md)
├─ lib/
│  ├─ main.dart
│  ├─ app.dart                    # MaterialApp.router, themes
│  ├─ router.dart                 # go_router + redirect logic
│  ├─ core/
│  │   ├─ theme/                  # tokens from UI spec §5
│  │   ├─ platform/               # install_prompt (web), notifications, capture service
│  │   └─ utils/                  # time, tag-by-time, date formatting
│  ├─ data/
│  │   ├─ models/                 # app_user, relationship, meal, message, invite
│  │   └─ repositories/           # auth, user, relationship, meal, message, invite, storage
│  └─ features/
│      ├─ auth/                   # S01, S02
│      ├─ pairing/                # S03, S11
│      ├─ camera/                 # S05, S06
│      ├─ timeline/               # S07, S12 (timeline tab)
│      ├─ history/                # S08, S12 (history tab)
│      ├─ meal_detail/            # S09
│      ├─ clients/                # S10
│      └─ settings/               # S13, S14 banners
├─ functions/                     # Cloud Functions (TypeScript)
├─ firestore.rules
├─ storage.rules
├─ firebase.json
└─ test/ , rules_test/
```

## 5. Data model

All timestamps are Firestore `Timestamp`. `createdAt` uses `FieldValue.serverTimestamp()`.

### `users/{uid}`
| Field | Type | Notes |
|---|---|---|
| `role` | `"client"` \| `"dietician"` | Immutable after creation |
| `displayName` | string | 2–40 chars |
| `email` | string | |
| `timezone` | string | IANA name, e.g. `Asia/Kolkata`, saved at creation |
| `createdAt` | timestamp | |

Subcollection `users/{uid}/tokens/{token}`: `{ platform: "android"|"web", updatedAt }` (FCM tokens).

### `invites/{code}`  (doc id = 6-char code)
Alphabet: `ABCDEFGHJKLMNPQRSTUVWXYZ23456789` (no I, O, 0, 1).
| Field | Type |
|---|---|
| `dieticianId` | string |
| `dieticianName` | string |
| `createdAt`, `expiresAt` | timestamp (expires 48 h after creation) |
| `usedBy` | string \| null |
| `usedAt` | timestamp \| null |
| `revoked` | bool |

### `relationships/{relId}`
| Field | Type | Notes |
|---|---|---|
| `dieticianId`, `clientId` | string | |
| `dieticianName`, `clientName` | string | Denormalized at redeem time so neither side needs to read the other's user doc |
| `status` | `"active"` | Only value in v1 |
| `createdAt` | timestamp | |
| `lastMealAt` | timestamp \| null | Set by function |
| `lastMealTag` | string \| null | Set by function |
| `lastMealLocalDate` | string \| null | `yyyy-MM-dd` from the client device |
| `streakCount` | int | Set by function, default 0 |
| `unreadForDietician`, `unreadForClient` | int | Incremented by functions; each side may reset only its own to 0 |
| `lastActivityAt` | timestamp | For sorting |

Constraint: a client can be in **at most one** active relationship in v1 (enforced in `redeemInvite`).

### `relationships/{relId}/meals/{mealId}`
| Field | Type | Notes |
|---|---|---|
| `clientId` | string | = auth uid at creation |
| `mealTag` | `"breakfast"`\|`"lunch"`\|`"snack"`\|`"dinner"` | |
| `note` | string \| null | ≤ 200 chars |
| `photoUrl`, `thumbUrl` | string | Download URLs |
| `photoPath`, `thumbPath` | string | Storage paths (for deletion) |
| `createdAt` | timestamp | server time |
| `localDate` | string | `yyyy-MM-dd` in the **client's** local time; used for grouping and streaks |
| `localTime` | string | `HH:mm` |
| `reaction` | string \| null | One emoji from the allowed set, written by dietician |
| `dieticianComment` | string \| null | ≤ 300 chars |
| `calories` | int \| null | **Reserved for v2**, always null in v1 |
| `caloriesSource` | `"dietician"`\|`"ai"`\|`"user"` \| null | **Reserved for v2** |

### `relationships/{relId}/messages/{msgId}`
`{ senderId, text (1–1000 chars), createdAt }`

## 6. Security rules

Write these **before** any UI (Milestone M1) and test them with the emulator.

### Firestore (`firestore.rules`) — behavior to implement
```
helper isSignedIn()
helper rel(relId)        = get(/relationships/relId).data
helper isMember(relId)   = uid == rel.clientId || uid == rel.dieticianId
helper isClientOf(relId) = uid == rel.clientId
helper isDieticianOf(relId) = uid == rel.dieticianId

users/{uid}
  read:   uid == auth.uid
  create: uid == auth.uid, role in [client, dietician], keys limited to the allowed fields
  update: uid == auth.uid and role unchanged

users/{uid}/tokens/{t}
  read, write: uid == auth.uid

invites/{code}
  create: signed in, user's role == "dietician", data.dieticianId == auth.uid,
          expiresAt <= request.time + 48h, usedBy == null
  read (get/list): resource.data.dieticianId == auth.uid      (dietician lists own invites)
  update: only the owner, only to set revoked = true
  delete: false
  (Redeeming goes through a Cloud Function, never a direct client write.)

relationships/{relId}
  read:   isMember(relId)
  list:   resource.data.clientId == uid || resource.data.dieticianId == uid
  create/delete: false   (only functions)
  update: member may change only their own unread counter, and only to 0:
          - client:    affectedKeys == ['unreadForClient'],    new value == 0
          - dietician: affectedKeys == ['unreadForDietician'], new value == 0

relationships/{relId}/meals/{mealId}
  read:   isMember(relId)
  create: isClientOf(relId), clientId == auth.uid, mealTag in allowed set,
          createdAt == request.time, note/comment length limits,
          calories == null, keys limited to the schema
  update: isDieticianOf(relId), affectedKeys hasOnly ['reaction','dieticianComment'],
          reaction in ['👍','❤️','👏','😬', null], comment length ≤ 300
  delete: isClientOf(relId)

relationships/{relId}/messages/{msgId}
  read:   isMember(relId)
  create: isMember(relId), senderId == auth.uid, text length 1–1000, createdAt == request.time
  update, delete: false
```

### Storage (`storage.rules`) — path `meals/{relId}/{fileName}`
- `read`: signed in and member of `relId` (use `firestore.get(...)` to check the relationship).
- `write`: signed in and **client** of `relId`, `request.resource.size < 3 * 1024 * 1024`, `request.resource.contentType.matches('image/jpeg')`.
- `delete`: client of `relId`.

## 7. Cloud Functions (TypeScript, v2, region `asia-south1`)

| Function | Trigger | Does |
|---|---|---|
| `redeemInvite` | Callable `{code}` | Validates auth + role == client; invite exists, not used, not revoked, not expired; client has no active relationship. In one transaction: marks invite used, creates `relationships/{relId}` with denormalized names and counters at 0. Returns `{relId}`. Errors map to the S03 messages: `not-found`, `expired`, `already-used`, `already-connected`. |
| `onMealCreated` | `relationships/{relId}/meals/{mealId}` create | Updates `lastMealAt`, `lastMealTag`, `lastActivityAt`; updates streak (see below); `unreadForDietician += 1`; sends push to the dietician: title = client name, body = `"{Tag} 🍽️"` (+ note if any). |
| `onMealUpdated` | meal update | If `reaction` or `dieticianComment` changed → `unreadForClient += 1`, push to the client: title = dietician name, body = reaction + comment. |
| `onMessageCreated` | message create | Increments the other side's unread counter, updates `lastActivityAt`, pushes the text (truncated to 100 chars). |
| `onMealDeleted` | meal delete | Deletes `photoPath` and `thumbPath` from Storage. |

**Streak logic (in `onMealCreated`)**: let `d = meal.localDate`, `last = relationship.lastMealLocalDate`.
- `last == null` → streak = 1
- `d == last` → unchanged
- `d == last + 1 day` → streak += 1
- `d > last + 1 day` → streak = 1
- `d < last` (late or offline upload) → unchanged
Then set `lastMealLocalDate = max(d, last)`. Use pure date-string math (no timezone conversion on the server).

**Push payload:** FCM `notification` (title/body) plus `data: { relId, type: "meal"|"message"|"feedback" }`. Send to all tokens under the recipient's `users/{uid}/tokens`; delete tokens that return `registration-token-not-registered`. A notification tap routes to the relevant timeline (client: S07; dietician: S12 for `relId`).

## 8. Auth and routing

- Providers: Email/Password and Google. (On iOS PWA, Google popup/redirect flows can be unreliable; the dietician can use email/password. Do not block on this.)
- `go_router` redirect order:
  1. no user → `/signin`
  2. user without a profile doc → `/role`
  3. client without an active relationship → `/join`
  4. client → `/home`
  5. dietician → `/clients`
- Routes: `/signin`, `/role`, `/join`, `/home`, `/meal/:relId/:mealId`, `/clients`, `/clients/:relId`, `/clients/:relId/meal/:mealId`, `/settings`.
- Active relationship for a client: query `relationships` where `clientId == uid` (limit 1), exposed via a provider.

## 9. Core flows

### 9.1 Capture → send
1. `CaptureService` returns an image (`camera` plugin on Android; `image_picker` on web).
2. S06: tag preselected via `tagForTime(DateTime.now())`; note optional.
3. On Send: generate `mealId` locally (`doc().id`), build `localDate`/`localTime` from the device clock.
4. In an isolate: decode, fix orientation, resize to **1280 px long edge** JPEG q80 (`photo`) and **360 px** JPEG q75 (`thumb`).
5. Upload both to `meals/{relId}/{mealId}.jpg` and `meals/{relId}/{mealId}_thumb.jpg`; fetch download URLs.
6. Create the meal doc (rules require `createdAt == request.time`, so use `serverTimestamp()`).
7. UI state machine for the chip: `sending → sent | failed(retry)`. The processed bytes are kept in memory for retry. (No persistent offline queue in v1.)

### 9.2 Pairing
1. Dietician opens S11 → client generates a random code from the allowed alphabet, writes `invites/{code}` (retry on collision).
2. Client enters the code on S03 → callable `redeemInvite` → router sends them to `/home`.

### 9.3 Timeline merge
Two live queries per relationship, each ordered by `createdAt` descending, limit 50: `meals` and `messages`. A provider merges them into one list sorted ascending by `createdAt`. Items with `hasPendingWrites` and a null server time use the local time. "Load earlier" extends both queries by 50.

### 9.4 Unread reset
- Client opening page 0 sets `unreadForClient = 0`. Dietician opening S12 sets `unreadForDietician = 0`.

### 9.5 "No log today" flag (dietician, S10)
Compute in the app: `now.hour >= 14` and `lastMealLocalDate != todayLocalDate` (dietician's local date).

### 9.6 Streak display
Read `streakCount` and `lastMealLocalDate` from the relationship. If `lastMealLocalDate` is older than yesterday (local), display 0 on the client.

## 10. Platform configuration

### Android
- `minSdkVersion` 24. Permissions: `CAMERA`, `POST_NOTIFICATIONS` (Android 13+), `INTERNET`.
- Notification channel `meals` (default importance).
- Release: build an APK for yourself and use Play Console **internal testing** for installs. App signing via the Play-managed key.

### Web PWA (Firebase Hosting)
- `web/manifest.json`: `name: "FoodSnap"`, `short_name: "FoodSnap"`, `display: "standalone"`, `start_url: "/"`, `theme_color` = primary, `background_color` = `#0C0C14`, icons 192/512 plus a **maskable** 512.
- `web/index.html`: `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`, `apple-mobile-web-app-capable`, `apple-touch-icon` (180×180).
- `web/firebase-messaging-sw.js`: standard FCM service worker, handles background messages and `notificationclick` → opens `/clients/{relId}` or `/home` based on `data`.
- Web push needs the **VAPID key** from the Firebase console (put it in a Dart constant or `--dart-define`).
- Hosting: `firebase.json` rewrites everything to `/index.html`. Serve over HTTPS only.
- **iOS specifics:** web push works only on iOS 16.4+ and only when the PWA is installed to the Home Screen; the permission request must come from a user tap (S14 banner). Detect "installed" via `display-mode: standalone` media query or `navigator.standalone`, behind a conditional import so the Android build still compiles.
- Test on a real iPhone early (M5).

## 11. Offline and errors

- Enable Firestore offline persistence (default on mobile; enable explicitly on web).
- Text messages written offline queue automatically through Firestore.
- Photo upload failure → `failed` chip with Retry (see §9.1). Never silently drop a photo.
- Global error handling: show a snackbar for unexpected errors; log to console (no crash-reporting SDK in v1).
- Use `AsyncValue` everywhere: every screen has loading, error, and empty states as defined in the UI spec.

## 12. Image handling rules

- Never upload the raw camera image. Always resize/compress (§9.1).
- Strip EXIF GPS (re-encoding through `image` does this).
- Use `cached_network_image` (or equivalent) for thumbnails; the History and Clients screens use `thumbUrl` only; the Meal Detail screen loads `photoUrl`.

## 13. Testing

- **Rules tests (required):** `@firebase/rules-unit-testing` against the emulator. Must prove: a client cannot read another relationship; a client cannot write a dietician-only field; a dietician cannot create meals; no one can create relationships or redeem invites directly; role cannot change; storage read/write is limited to members/the client.
- **Unit tests:** `tagForTime`, streak function, invite code generator, timeline merge.
- **Widget tests:** MealTagChip selection, S06 default tag.
- **Manual QA checklist (end of v1):** sign up both roles, pair, send 3 meals offline→online, reaction/comment round trip, push on Android, push on installed iPhone PWA, two clients isolated from each other, streak increments across two days.

## 14. Milestones (build in this order)

Each milestone ends with something runnable and a short manual check.

| # | Milestone | Done when |
|---|---|---|
| M0 | Project setup | Flutter app boots on Android and Chrome; Firebase connected; theme tokens, router skeleton, `AGENTS.md` committed |
| M1 | Rules + emulator tests | `firestore.rules`, `storage.rules` written; all §13 rules tests pass |
| M2 | Auth + role (S01, S02) | Email sign-up works; profile doc created; redirects land correctly per §8 |
| M3 | Pairing (S03, S10 empty, S11, `redeemInvite`) | Dietician creates a code; a second account redeems it; both see the relationship; second redeem fails |
| M4 | Capture → send (S05, S06, upload pipeline) | Meal appears in Firestore + Storage with thumbnail; chip shows sent/failed; web variant works |
| M5 | Notifications + PWA | FCM tokens saved; dietician gets a push on Android and on an installed iPhone PWA; S14 banners |
| M6 | Timeline (S07, S12 timeline) | Merged meals + messages, realtime, unread counters, text chat both ways |
| M7 | History + Meal detail (S08, S09) | Day grouping, week dots, pagination, swipe between meals, delete |
| M8 | Dietician feedback | Reactions, comments, quick-reply chips, push to client |
| M9 | Clients list polish (S10 full) | Unread badge, sort order, "No log today", streak, multi-client isolation verified |
| M10 | Streaks + final QA | Streak logic + tests; manual QA checklist passes; release APK + Hosting deploy |

## 15. v2 hooks: calorie estimation (do not build now)

- Meal docs already include nullable `calories` and `caloriesSource`.
- Planned flow: a new function `estimateCalories(relId, mealId)` sends the photo to a vision-capable model with a prompt asking for dish names, assumed portion, and a calorie **range**; the user/dietician confirms or edits; `caloriesSource` records who set it.
- Daily totals and the calorie ring (UI spec §9) read from `calories` aggregated by `localDate`.
- Treat all estimates as approximate and keep the dietician in the loop.

## 16. Risks and open decisions

1. **Firebase plan:** Cloud Functions need the **Blaze (pay-as-you-go)** plan, and new Cloud Storage buckets may also require it. Check the console before M0. For two-digit user counts the usage stays inside the free quotas, but set a **budget alert**. If Blaze is not acceptable, the fallback is Supabase (Auth, Postgres, Storage, Edge Functions) with the same data model.
2. **iOS PWA quirks:** push and install behavior differs from Android. Validate on a real iPhone at M5, not at the end.
3. **Flutter web camera:** the live viewfinder is not used on web by design (uses the browser's native camera via `image_picker`).
4. **No persistent upload queue:** if the app is killed mid-upload the photo is lost. Acceptable for v1; revisit if it happens in practice.
5. **Dietician sign-up is open:** anyone can pick the dietician role. Fine for a private trial; add verification before any public release.
6. **Privacy:** these are health-adjacent photos. Storage is private by rule (members only). Add a short privacy note in the app before sharing it beyond people you know.

## 17. Spark-only operation (decided in M3 — no Blaze)

Blaze was rejected to stay in the free tier, so there are **no Cloud Functions** in v1. `functions/` is kept dormant (tested, never deployed) in case Blaze ever lands.

- **Pairing (§9.2 changed):** the client claims the invite and creates its relationship in one Firestore transaction, at the deterministic id `relationships/rel_{clientUid}`. Rules (§6) validate the invite (exists, unrevoked, unexpired, unused), the relationship shape (counters 0, names truthful, timestamps), and the deterministic id — a second relationship is structurally impossible. Residual risk vs functions: two clients redeeming the same code in the same instant could both pass validation (last writer wins `usedBy`). Acceptable for a private trial.
- **Push notifications descoped:** no server means no FCM push. M5 becomes in-app realtime only (listeners already update live); S14 banners stay hidden until/unless Blaze lands.
- **Unread counters / streaks:** start at 0 via pairing. Increments need a Spark-compatible redesign at M6/M9/M10 (client-side computation or dropped) — do not assume function increments.
- **Invite reads:** any signed-in user may GET a single invite (codes are unguessable); LIST stays owner-only.
