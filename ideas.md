# Feature Ideas

Ideas for features that keep picsort minimal but make it something no other photo app does.

---

### 1. Smart Suggest (on-device ML)

Use Apple's Vision framework to analyze what's already been sorted into each gallery, then **highlight the most likely gallery** when a new photo appears. If your "Beach" gallery has 40 coastal shots, the app learns that pattern and pre-highlights "Beach" when a similar photo comes up.

All processing stays on-device. No cloud, no API, no external dependencies. The suggestion is just a subtle visual hint on one panel — never automatic, never forced. The user always makes the final call.

**Why it's unique:** No swipe-to-sort app does on-device learning. This turns picsort from a tool into an assistant that gets better the more you use it.

---

### 2. Focus Sessions

A timed sorting mode. Tap "Sort for 5 minutes" and a minimal progress arc appears at the top. When time's up, the app shows a calm summary: photos sorted, photos deleted, galleries touched.

The insight is psychological — most people avoid photo cleanup because it feels infinite. A 5-minute session makes it feel like a small, completable task. Like a meditation timer, but for your camera roll.

**Why it's unique:** No photo app frames organization as a brief, intentional habit. This borrows from mindfulness UX patterns (Headspace, Calm) and applies them to a utility.

---

### 3. Time Capsule

Instead of picking a date manually, a "Rediscover" mode surfaces photos from exactly 1, 2, 3+ years ago today. Sorting becomes emotional — you're not just cleaning up, you're revisiting memories and deciding which ones deserve a home.

One button on the date picker: "On This Day." Shows photos from all matching dates across years, oldest first.

**Why it's unique:** Apple Photos has "On This Day" for viewing. No app uses it as the entry point for *organizing*. It turns a chore into a ritual.

---

### 4. Sorting Insights

A single, beautiful stats screen. No charts, no dashboards — just a few calm numbers:

- Total photos sorted (all time)
- Total storage reclaimed
- Your longest sorting streak (consecutive days)
- Most active gallery this week
- A simple "sorted / remaining" ratio for your library

Updates live as you sort. The goal is positive reinforcement through data — you see your library getting cleaner over time, which motivates you to keep going.

**Why it's unique:** Competitors show you photos. None of them show you *progress*. This makes the invisible work of organization feel visible and rewarding.

---

### 5. Gesture Vocabulary

Expand the swipe language beyond left/right:

- **Swipe up** — favorite the photo (adds to iOS Favorites)
- **Swipe down** — share instantly (opens the share sheet)

Each direction has a subtle color hint (gold shimmer for up, soft blue for down). The gestures are discoverable but not explained — they feel natural once found.

This keeps the screen completely clean (no buttons for favorite/share) while adding depth for power users. Two new actions, zero new UI elements.

**Why it's unique:** Every competitor has buttons. A pure gesture vocabulary with no visible controls is rare outside of games. It makes picsort feel physical.

---

### 6. Duplicate Sweep

A separate mode that finds visually similar photos (burst shots, retakes, slight angle changes) and presents them side by side. Tap to keep the best one, the rest get marked for deletion.

Uses Apple's Vision framework for perceptual similarity — all on-device, no network. Presented as pairs or small groups, not overwhelming grids.

Accessible from a simple toggle on the date picker: "Find duplicates instead."

**Why it's unique:** Dedicated duplicate finder apps exist, but they're cluttered and aggressive. Integrating it into picsort's calm swipe flow makes it feel like part of the same experience, not a separate tool.
