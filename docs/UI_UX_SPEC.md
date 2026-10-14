# FoodSnap — UI/UX Specification (v1)

Audience: the developer and the AI coding agent (OpenCode). Companion doc: `TECH_SPEC.md`.
Rule for the agent: if this document does not say it, do not build it. If something is ambiguous, ask before inventing.

---

## 1. Product summary

FoodSnap is a camera-first app for sending meal photos to a dietician. It borrows Snapchat's interaction model (camera is the home screen, swipe between camera / chat / history, big shutter, one-tap send) but **has no filters, no stories, no disappearing photos**. Photos are kept forever because the history is the point.

- **Client**: takes a photo before each meal, tags it, sends it. Has exactly one dietician in v1.
- **Dietician**: has many clients. Sees each client's meals, reacts, comments, and chats.

Platforms: **Android (APK)** and **Web PWA** (the dietician installs it on iPhone via Safari → Add to Home Screen). One Flutter codebase.

## 2. Design principles

1. **Camera first.** A signed-in, paired client lands on the live camera. No feed, no menu.
2. **Two taps to send.** Shutter → Send. The meal tag is auto-selected by time of day.
3. **Keep everything.** Nothing disappears. History and streaks depend on it.
4. **Glanceable for the dietician.** She may have 20+ clients. Unread counts, last meal, and "not logged today" must be visible without opening anything.
5. **Calm, not gamified.** The only game mechanic is the logging streak.
6. **Reserve space for calories.** v2 adds calorie data. v1 must not need a redesign to add it (see §9).

## 3. Roles and screen access

| Role | Lands on | Can do |
|---|---|---|
| Client | S05 Camera (center page of S04 Home) | Capture, send, chat, view own history, delete own meal |
| Dietician | S10 Clients list | Create invites, view clients' timelines/history, react, comment, chat |

Role is chosen once at first sign-in and cannot be changed afterwards.

## 4. Navigation map

```
Launch
 ├─ not signed in ───────────────► S01 Sign in
 ├─ signed in, no role ──────────► S02 Role & name
 ├─ client, not paired ──────────► S03 Enter invite code
 ├─ client, paired ──────────────► S04 Client Home (PageView, starts on Camera)
 │      ◄ page 0: S07 Timeline/Chat   ●page 1: S05 Camera   page 2: S08 History ►
 │      S05 ──shutter──► S06 Preview & Send ──send──► back to S05
 │      S07/S08 ──tap meal──► S09 Meal Detail
 └─ dietician ───────────────────► S10 Clients List
        ├─ "+ Add client" ───────► S11 Invite sheet
        └─ tap client ───────────► S12 Client Detail (tabs: Timeline | History)
                                      └─ tap meal ─► S09 Meal Detail (dietician mode)
Any signed-in user: S13 Settings (from avatar/menu), S14 Install/Notifications banners
```

## 5. Design tokens

### Color
| Token | Light | Dark |
|---|---|---|
Palette: **Indigo**. Cool, calm UI chrome so that warm food photos stand out. Do not use green anywhere in the UI.

| Token | Light | Dark |
|---|---|---|
| `primary` | `#5B5BD6` | `#8E8EF5` |
| `onPrimary` | `#FFFFFF` | `#14143A` |
| `background` | `#F6F6FB` | `#0C0C14` |
| `surface` | `#FFFFFF` | `#16161F` |
| `textPrimary` | `#14141F` | `#F2F2F8` |
| `textSecondary` | `#6B6B80` | `#A0A0B8` |
| `divider` | `#E6E6F0` | `#262633` |
| `danger` | `#E5484D` | `#FF6B70` |
| `warning` | `#F59E0B` | `#FBBF24` |

The **camera screens (S05, S06) are always dark** regardless of system theme (pure black background, white icons). The palette only shows up in buttons, chips, chat bubbles, badges, and the dietician's screens.

Success feedback (e.g. "Sent ✓") uses `textPrimary`/white with a check icon, not a green color.

Meal tag colors (same in light and dark): Breakfast `#F59E0B` (amber), Lunch `#EF6C4D` (coral), Snack `#EC4899` (pink), Dinner `#0EA5E9` (sky blue).

### Type (bundle the Inter font; do not fetch fonts over the network)
| Style | Size/Line | Weight |
|---|---|---|
| title | 22/28 | 700 |
| heading | 18/24 | 600 |
| body | 16/24 | 400 |
| label | 14/20 | 500 |
| caption | 12/16 | 400 |

### Shape and spacing
- Spacing scale: 4, 8, 12, 16, 24, 32.
- Radius: cards/images 16, bottom sheets 24 (top corners), chips and buttons 999 (pill).
- Minimum tap target: 48×48 dp.
- Elevation: avoid shadows; use surface contrast and dividers.

### Wide screens
On web with width > 480 px, center the app in a 480 px column over `background`. Do not build a separate desktop layout.

## 6. Screens

### S01 — Sign in
- **Layout:** App logo + name "FoodSnap" centered, tagline "Snap your meal. Send it. Done.", buttons: **Continue with Google** (Android and web), **Email** (email + password fields, "Sign in" / "Create account" toggle).
- **Behavior:** On success, router decides the next screen (see §4).
- **States:** loading (button spinner, fields disabled), error text under the form ("Wrong email or password", "No internet connection").
- **Done when:** a new user can create an account with email, and Google works on Android.

### S02 — Role & name
- **Layout:** Title "Who are you?", name text field (prefilled from Google if available, required, 2–40 chars), two large selectable cards: **"I'm logging my meals"** (Client) and **"I'm a dietician"** (Dietician), button **Continue** (disabled until both chosen).
- **Behavior:** writes the user profile; shows a one-line note "You can't change this later."

### S03 — Enter invite code (client only)
- **Layout:** Title "Connect with your dietician", subtitle "Enter the 6-character code she shared", a 6-box code input (auto-uppercase, no ambiguous characters), button **Connect**.
- **Behavior:** calls the redeem function. On success → S04. 
- **Errors:** "Code not found", "Code expired — ask your dietician for a new one", "Code already used", "You're already connected".
- **Also:** a link-style button "Sign out" at the bottom.

### S04 — Client Home (container)
- A horizontal `PageView` with three pages, **initial page = 1 (Camera)**. No visible app bar, no bottom nav.
- Edge hints on S05 show the other pages (see S05).
- Android back from page 0 or 2 returns to page 1; back from page 1 exits the app.

### S05 — Camera (client, center page)
- **Layout (full-bleed live preview, dark UI):**
  - Top-left: flash toggle (off / auto / on). Top-center: streak badge `🔥 12` (hidden if streak is 0). Top-right: flip camera and a small avatar button that opens S13 Settings.
  - **Reserved slot (v1 hidden):** a thin area below the status bar for the future daily calorie ring. Keep the layout slot, render nothing.
  - Bottom center: **shutter button**, 76 dp circle, 4 dp white ring, 8 dp gap, white fill. Bottom-left: gallery button (last photo thumbnail, 44 dp). Bottom-right: empty.
  - Left edge: chat icon with unread dot. Right edge: history icon. Both are subtle and double as swipe hints.
- **Behavior:**
  - Tap shutter → light haptic, 120 ms white flash, go to S06 with the captured image.
  - Tap on preview → focus point indicator. Pinch → zoom (nice to have, not blocking).
  - Gallery button → pick an image from the device → S06.
  - Swipe right → page 0 (Timeline). Swipe left → page 2 (History).
- **Web client variant:** no live viewfinder. Show the same layout with a large **Take photo** button that opens the device camera via the browser. Everything after that is identical.
- **States:**
  - Permission not granted: dark screen, camera icon, "FoodSnap needs your camera to snap your meals", button **Allow camera**. If permanently denied: **Open settings**.
  - Camera initializing: black with a small spinner.
  - Camera error: "Couldn't start the camera" + **Retry**; gallery button still works.
- **Done when:** app opens to a live camera within ~1.5 s of launch on a mid-range Android phone (after the first run).

### S06 — Preview & Send (client)
- **Layout (dark):** the photo fills the screen (contain, black bars allowed).
  - Top-left: **✕** (discard → back to S05, no confirmation).
  - Bottom area (a translucent panel): row of four **meal tag chips** (Breakfast, Lunch, Snack, Dinner), single-select, **one preselected by time of day** (table below). Under it, a one-line text field "Add a note (optional)" with a 200-char limit. Bottom-right: round **Send** button in `primary` (arrow icon in `onPrimary`, 56 dp).
- **Auto meal tag by local time:**

| Local time | Tag |
|---|---|
| 05:00–10:59 | Breakfast |
| 11:00–14:59 | Lunch |
| 15:00–18:59 | Snack |
| 19:00–22:59 | Dinner |
| 23:00–04:59 | Snack |

- **Behavior:** Send → immediately return to S05 and show an upload progress chip at the top ("Sending…" with a small spinner). On success: chip turns to "Sent ✓" for 1.5 s, then disappears. The streak badge updates.
- **Failure:** chip turns red: "Couldn't send · Retry". Tapping it retries. The photo stays in memory until sent or discarded.
- **Optional polish (not blocking):** on Send, the photo shrinks toward the left edge chat icon.

### S07 — Timeline / Chat (client, page 0)
One chronological conversation with the dietician that mixes **meal cards** and **text messages**.
- **Header:** dietician's name and avatar (initials), back chevron (returns to the camera page).
- **Body:** newest at the bottom, auto-scroll to the bottom on open and on new items. Date separators ("Today", "Yesterday", "Mon 13 Oct").
  - **Text bubble:** mine right (primary color), hers left (surface). Time in caption under the bubble group.
  - **Meal card (always right-aligned, since the client sent it):** square image (max 280 dp wide, radius 16), tag chip + time overlay at the bottom-left of the image, note below the image if present. Below that, if the dietician reacted or commented: a small row with her **reaction emoji** and her **comment text**.
  - Tap meal card → S09.
- **Composer (bottom):** text field "Message", send icon. A camera icon on the left jumps to S05 (page 1).
- **Empty state:** illustration-free, text only: "Your meals and messages will show up here. Swipe right to snap your first meal." with a **Go to camera** button.
- **Loading:** skeleton cards. **Offline:** banner "You're offline. Messages will send when you're back."

### S08 — History (client, page 2)
- **Top summary:** current streak (`🔥 12 days`), and a **7-dot week row** (last 7 days, filled dot = at least one meal logged that day, today's dot outlined).
- **Body:** meals grouped by day, newest first. Each day has a sticky header: "Today · 3 meals", "Tue, 13 Oct · 4 meals". Under each header, a **3-column grid** of square thumbnails with a small colored dot for the tag. A small emoji badge in the corner if the dietician reacted.
- **Tap thumbnail →** S09.
- **Pagination:** load the latest 60 meals, then "Load more" at the bottom.
- **Empty state:** "No meals yet. Your history starts with your first snap."

### S09 — Meal Detail (both roles)
- **Layout:** full-screen image on black with pinch-to-zoom, ✕ at the top-left (back), a **delete** icon at the top-right for the client's own meals (confirm dialog: "Delete this meal? This can't be undone.").
- **Bottom sheet (peek height, draggable):** tag chip, date/time, note, then dietician feedback:
  - **Client mode:** shows her reaction and comment (read-only), or "No feedback yet."
  - **Dietician mode:** a **reaction bar** (👍 ❤️ 👏 😬), a **comment field**, and **quick-reply chips** ("Looks good 👍", "Reduce oil", "Add protein", "Smaller portion"). Tapping a chip fills the comment field; pressing **Save** writes it.
  - **Reserved row (v1 hidden):** "Calories" with an estimate and a source label. Keep the slot, render nothing in v1.
- **Navigation:** swipe left/right pages through the other meals of the same day.

### S10 — Clients list (dietician home)
- **Header:** "Clients" title, avatar button (S13), **+ Add client** button.
- **Banner area:** notification/install banners (S14) when applicable.
- **List rows (72 dp):** initials avatar, client name, subtitle `Lunch · 12:40` (last meal tag and time, or "No meals yet"), trailing: unread **badge** (number), streak `🔥 12`, and an orange **"No log today"** chip when the client has no meal for today's date and it's after 14:00 local.
- **Sorting:** unread count (descending), then last meal time (descending).
- **Empty state:** "No clients yet. Tap **Add client** to invite your first one."
- **Realtime:** the list updates live. No pull-to-refresh.

### S11 — Invite sheet (dietician)
- **Bottom sheet:** title "Invite a client", a large 6-character code (tap to copy), expiry text "Valid for 48 hours · one use", buttons **Copy code** and **Share** (system share sheet with the message: "Join me on FoodSnap. Install the app and use code ABC123.").
- Opening the sheet creates a fresh invite. Below, a list of **active invites** (code, expires in…) with a **Revoke** action.

### S12 — Client Detail (dietician)
- **Header:** client name, streak, back chevron.
- **Two tabs:** **Timeline** and **History**.
  - **Timeline:** identical to S07 but mirrored: the client's meal cards on the **left**, the dietician's text bubbles on the **right**, with a composer. Meal cards show her reaction/comment inline and a **React / Comment** action row beneath each card that opens S09 in dietician mode.
  - **History:** identical to S08 (summary, week dots, day-grouped grid).
- Opening the screen clears the unread count for her.

### S13 — Settings (minimal)
- Display name (read-only), email (read-only), role (read-only), notification toggle row (shows permission status, button to enable), **Sign out**, app version.
- No account deletion UI in v1.

### S14 — Banners (shown on S07 and S10, dismissible per session)
1. **Enable notifications:** "Get notified when {a client sends a meal | your dietician replies}." Button **Turn on**. Must be triggered by a tap (required by iOS).
2. **Install on iPhone (iOS Safari, not installed as a PWA):** replaces the banner above. Content: "To get notifications, add FoodSnap to your Home Screen." with three numbered steps and small icons: ① Tap **Share** ② Tap **Add to Home Screen** ③ Open **FoodSnap** from your Home Screen. It reappears every launch until the app runs standalone.

## 7. Components

| Component | Notes |
|---|---|
| `MealTagChip` | Pill, tag color dot + label. Selected state = filled with tag color at 15% opacity and a 1.5 dp outline. |
| `MealCard` | Image + overlays + feedback row (see S07). One widget, two alignments (client/dietician view). |
| `MessageBubble` | Radius 16, tail-less, max width 78% of screen. |
| `StreakBadge` | `🔥 N`, pill on translucent dark background. |
| `WeekDots` | 7 dots, Monday-first or last-7-days (last 7 days, today at the right). |
| `UnreadBadge` | Primary-colored circle, 20 dp, number capped at "9+". |
| `UploadChip` | States: sending, sent, failed. Fixed at the top of S05. |
| `EmptyState` | Title, one line of body, optional button. No illustrations in v1. |
| `AppBanner` | Used for S14 and the offline notice. |

## 8. Interaction, motion, feedback

- Page swipe: 250 ms, `Curves.easeOutCubic`.
- Shutter: light haptic + 120 ms white flash overlay.
- Send success: success haptic (medium) on Android.
- New timeline items fade in (150 ms). Respect "reduce motion" (disable the flash animation and fades).
- No custom page transitions between routes beyond the platform default.

## 9. Reserved for v2 (calories) — render nothing in v1

- S05: slot below status bar for a daily calorie ring.
- S09: a "Calories" row (estimate + source: dietician / AI / you).
- S08: a daily total in each day header.
- Meal data already has nullable `calories` and `caloriesSource` fields (see TECH_SPEC).

## 10. Accessibility

- All icon buttons have semantic labels ("Flip camera", "Send meal", "Open history").
- Text contrast at least 4.5:1; never rely on color alone for meal tags (always show the text label).
- Support system font scaling up to 130% without clipping (rows grow in height).
- The shutter and send buttons must have the labels "Take photo" and "Send".

## 11. Microcopy (use these exact strings)

| Where | Text |
|---|---|
| Camera permission | "FoodSnap needs your camera to snap your meals" |
| Upload sending | "Sending…" |
| Upload success | "Sent ✓" |
| Upload failed | "Couldn't send · Retry" |
| Offline banner | "You're offline. Messages will send when you're back." |
| Empty timeline | "Your meals and messages will show up here. Swipe right to snap your first meal." |
| Empty history | "No meals yet. Your history starts with your first snap." |
| Empty clients | "No clients yet. Tap Add client to invite your first one." |
| Delete meal | "Delete this meal? This can't be undone." |
| Missed log chip | "No log today" |

## 12. Out of scope for v1

Filters or stickers, disappearing photos, video, voice notes, group chats, multiple dieticians per client, client-to-client features, calorie estimation or ML, weight tracking, meal plans, payments, account deletion UI, profile photos, multiple languages, tablet/desktop layouts.
