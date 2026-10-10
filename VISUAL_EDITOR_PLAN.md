# Visual Editor ("Launch with Editor") — Plan

Status: **proposed** — not started.
Supersedes nothing; builds on the post-completion Editor (the mini-IDE tab).

## 1. Problem

Today, once a project's build is `completed`, the User Stories tab morphs into
the **Editor**: a mini-IDE (file tree + code panel + chat sidebar + Launch
button). Editing is *chat-driven*: the user types a request, the coding agent
attempts it. That has three problems for our target customer — **people who do
not want to interact with code**:

1. A file tree and a code panel are invisible to them.
2. Chat is vague — there is no shared visual reference, so "make the header
   bigger" is a prayer, not an instruction.
3. The coding agent is our weakest component; ambiguous visual asks are its
   worst case.

**Goal:** a visual editor where the user *sees the app* (running, or as its
real screens), points at a part (right-click) or drags it (Shift+drag), and the
change lands in the code — committed, reversible, and CI-checked — without them
ever seeing code.

## 2. What we already have (foundations)

| Asset | Reuse |
|---|---|
| `EditorWorkspaceView` (post-build tab) + chat sidebar (`StoriesChatSidebar`, editorMode) | The shell to extend; chat stays as the escape hatch |
| `LaunchProjectDialog` (web → Docker container / windows → exe) | Proves the "run the generated app" pipeline exists |
| Generated app conventions: `lib/app_routes.dart` (ALL routes), `lib/features/task_N_*/…_page.dart`, `main.dart` MaterialApp | The screen map is derivable from routes; pages are file-scoped |
| Design pass (done): theme, real lobby, art in `assets/`, imageModel resolved (`c793bcf`) | "Insert image" can pick generated art or generate new |
| `http` + `web_socket_channel` deps already in pubspec | Preview serving + edit bridge, no new deps needed |
| VHD workspace + git + commit history panel | Every visual op = a commit; undo = revert |
| CI + analyzer (project is green at completion) | Guardrail: an edit that breaks the build is detectable + auto-rollback-able |

Key insight: the generated app is **agent-written, not a fixed template** —
so anything we need *inside* the app (bridge, harness) must be **injected by
the studio at preview time**, or mandated via the Templater prompt. Prefer
injection (zero changes to the app the user "owns").

## 3. Architecture — three layers

```
┌──────────────────────────────────────────────────────────────────┐
│ EDITING LAYER   ops → code applier → commit → re-preview         │
│                 (deterministic first, coding agent for the tail) │
├──────────────────────────────────────────────────────────────────┤
│ PICKING LAYER   cursor point ⇄ Region {widgetType, sourceFile:   │
│                 line, rect, screen} — one shared region model    │
├──────────────────────────────────────────────────────────────────┤
│ PREVIEW LAYER   B: screenshot harness (pseudo-run, MVP)          │
│                 A: live web build in browser/webview (phase 2)   │
└──────────────────────────────────────────────────────────────────┘
```

### 3.1 Preview layer

**Option B — Screen map (pseudo-run) — the MVP.**
A screenshot **harness** (a `flutter test` the studio injects into the
workspace, debug mode) that:

1. reads the generated app's `app_routes.dart` route table,
2. pumps the app and navigates to each route,
3. captures each screen (RepaintBoundary → PNG) into `/.nexus/screens/*.png`,
4. walks the RenderObject tree per screen and dumps **region JSON**
   (see 3.2) into `/.nexus/screens/*.regions.json`.

The editor renders a **storyboard player**: a rail of real screen
thumbnails + navigation arrows (the routes graph). Click a screen → large
view with interactive regions. No Docker, no webview, works on any platform,
per-screen re-capture is seconds.

**Option A — Live run — phase 2.**
Build the generated app for **web (debug)** and serve it locally
(`flutter build web` + static server on localhost — `http` is already a dep;
Docker stays the alternative for "Launch", not required here). Display via:

- **preferred: the user's browser** — zero new platform dependencies. The
  studio window is the tooling panel; the browser is the canvas; the two
  talk over a localhost WebSocket.
- later/optional: embed `webview_flutter` (WebView2 on Windows,
  WebKitGTK on Linux) for a single-window experience.

The app runs with `?nexus_edit=1`; an **edit bridge** (injected: the studio
wraps `main.dart` at preview time in a preview host that imports the app —
or a small package the harness adds) walks the live RenderObject tree and
streams region boxes to the studio over the WebSocket as layout changes.

*Debug* web build is mandatory (release minifies away source locations).

### 3.2 Picking layer — the Region model

One record shape, produced identically by the harness (B) and the bridge (A):

```json
{
  "id": "s3-042",
  "screen": "/task-60-blackjack_vs_house",
  "widgetType": "DecoratedBox",
  "label": "Container[Card]",
  "sourceFile": "lib/features/task_60_blackjack_vs_house/blackjack_vs_house_page.dart",
  "sourceLine": 128,
  "rect": { "x": 412, "y": 88, "w": 520, "h": 340 },
  "style": { "color": "#0E3B2E", "padding": [16,12,16,12] }   // when extractable
}
```

Source locations come from the debug-mode element creation stack
(`debugGetCreateStack` / `RenderObject` debug info) — available in any debug
build, which is all we ever preview. Hover → outline + tooltip
("Card — blackjack_page.dart:128"); right-click hit-tests the point against
region rects (deepest/smallest wins).

### 3.3 Editing layer — ops, applier, guardrails

**Op vocabulary (kept small on purpose):**

| Op | Widgets it applies to |
|---|---|
| `set_color` | any decorated surface / theme'd widget |
| `set_text` | Text / buttons / titles |
| `insert_image` / `replace_image` | backgrounds, tiles, heroes, Image widgets |
| `move` (Shift+drag → dx,dy) | any positioned block |
| `set_padding` / `resize` | containers (phase 3) |
| `delete` | decorative blocks |

**Applier — two-tier:**

1. **Deterministic:** the region carries `sourceFile:sourceLine` and the
   surrounding code. Known patterns (a `Color(0xFF…)`, `EdgeInsets…`,
   `Text('…')`, `alignment:`, `Positioned(left:…)` on/near that line) get a
   surgical `edit_file`. Fast, exact, no model in the loop.
2. **Agent fallback:** the op is packaged — screen PNG with the region
   outlined, the region JSON, the ±40 lines of source, and the op — and sent
   to the existing editor-chat machinery as a *precise* task. This is the
   same coding agent as today, but it finally gets a picture and a line
   number instead of prose.

**Guardrails (the app is green at completion — edits must keep it green):**

- after each op: `flutter analyze` on the touched files → error = **auto
  `git revert`** of that op's commit + "couldn't do that safely" toast;
- commit message convention: `Visual edit: <op> on <screen> (<file>:<line>)`
  → shows in the existing source-control panel; undo button = revert;
- async CI re-run in the background for the full guarantee (non-blocking,
  like the green rule).

**Refresh:** B → re-run the harness for that one screen (seconds) → swap the
PNG live. A → web hot-restart.

## 4. UX

**Entry point:** Overview tab → when `orchestrationState == 'completed'`,
the Orchestration card gains a prominent **"Launch with Editor"** button
(distinct from the Launch tab's builds/sites). It opens the Visual Editor
(full takeover of the project pane; the old mini-IDE moves to a "Code"
sub-tab for power users — it is not deleted).

**Layout:**

```
┌────────────────────────────────────────────────────────────────────┐
│ ▤ screens rail │            screen (large)                         │
│ [1] lobby      │  hover: region outline + tooltip                  │
│ [2] blackjack◄─│  right-click: Insert image… / Change color…       │
│ [3] roulette   │            Replace image… / Edit text / Delete    │
│ [4] …          │  shift+drag: move                                  │
├────────────────────────────────────────┴───────────────────────────┤
│ [Code sub-tab] [Inspector (ph3)]        │  chat sidebar (kept)     │
└────────────────────────────────────────────────────────────────────┘
```

**Insert image** dialog: pick from project assets (the design pass's art) →
generate new (imageModel is wired now) → or choose a local file. The applier
copies the bytes into `assets/` and writes the code.

## 5. Phases

| Phase | Scope | Exit criteria |
|---|---|---|
| **0 — Screen map + shell** | "Launch with Editor" button; editor shell; harness (screenshots + region JSON); storyboard player; hover outlines; right-click → *View code* (jumps code panel to file:line) | A user can browse every real screen of a completed project, see what is clickable, and jump to the source |
| **1 — First real ops** | `set_color`, `set_text`, `insert/replace_image`, `move`; two-tier applier; commit + analyze + rollback; single-screen re-capture | A non-coder restyles a screen (colors, texts, images, one moved block) with every change committed and the app still green |
| **2 — Live preview** | web debug build + local serve + edit bridge (WebSocket) + browser canvas; ops apply to the live app with hot-restart | "Edit while it runs" — right-click/drag on the actual running app |
| **3 — Depth** | Inspector panel (padding/color/font of the selection); `set_padding`/`resize`; undo stack UI; "apply to all screens with this widget"; multi-screen consistency | Property-level visual editing, Figma-adjacent comfort |

Each phase is shippable on its own; Phase 0+1 delivers the product promise.

### Status (2026-07-12)
- **Phase 0 — DONE** (`6d3f07d`). Implemented as the **screenshot harness**
  (pseudo-run): `debugGetCreateStack` was removed in Flutter 3.47.5, so the
  harness records text + color + widget-chain per render object and Studio
  resolves source lines with heuristics; the agent fallback covers misses.
- **Phase 1 — DONE** (same commit): pick, color/text/image/move ops,
  two-tier applier, commit + analyze + rollback, per-HEAD screen-map cache,
  "Launch with Editor" entry on the Overview tab, Code/Visual toggle.
- **Phase 2 — DONE** (`2bd53fc`): **browser tab** canvas (per your decision —
  zero new platform deps): `LivePreviewSession` serves a
  `flutter build web --debug` from the materialized workspace with an injected
  bridge script (WebSocket) reporting hover/right-click/viewport; edits apply
  to the real app, then rebuild-and-reload shows the result.
- **Phase 3 — PARTIAL** (`2bd53fc`): setPadding op ✓, apply-to-all-screens
  for repeated widgets ✓, inspector ✓; inline font-size edit pending.
- **Capture fix** (`06d041c`): the generated harness was written against older
  Flutter APIs and never actually ran end-to-end. Fixed for Flutter 3.47.5
  (`visitAncestorElements` for the widget chain, `InlineSpan.toPlainText()`,
  `rendering.dart` import, `OffsetLayer.toImage` inside `tester.runAsync` —
  the fake-async zone deadlocked the raster). Harness now DRAINS per-pump
  exceptions so a buggy app screen (e.g. an `Expanded` inside `Padding`) is
  captured + recorded as a per-screen error instead of failing the run. Added
  visible `[ScreenMap]`/`[VisualEditor]` logging + log tail in the error UI.
- **Space/UX pass** (`ead7b56`): in **Visual** mode the file tree (code) is
  hidden — the canvas *is* the code view — and the Agent chat auto-collapses
  to a slim rail. All panel borders are drag-resizable (new shared
  `DraggableVerticalDivider`: file-tree/code, code/Agent-chat, and the
  screens-rail/preview/inspector inside the visual editor). "Code" mode
  relabeled **Agent** (user-input-first, agent in the side). Also wrapped the
  editor's main `Row` in `Expanded` — it had unbounded height, which bled the
  canvas paint over the adjacent panels (the "glitching over other panels").
- **Capture fidelity** (`5145418`): `pushNamed` left the previous route
  painted beneath the new one, so the region walk captured the hidden
  route-list. Switched to `pushReplacementNamed` (each screen is the sole
  route). Region colour is now **pixel-sampled** from the rasterized image
  (captures painted backgrounds from AppBar/ColoredBox/Container/buttons/
  any widget, not just `RenderDecoratedBox`), and each text region records
  its **glyph colour** (`textColor`) and each box its **first descendant
  text** (`childText`) — both are strong source anchors.
- **Deterministic edits without the AI** (`5145418`): simple changes — set
  colour, retype text, nudge spacing — are now surgical one-line source edits
  applied **instantly**, no agent round-trip. The agent is the fallback only
  when no confident, well-anchored pattern exists. Matching is
  **whole-file nearest-to-anchor** (replaced the fixed ±14-line window +
  first-match that mis-targeted repeated colours); added text-colour and
  background-colour ops with broad colour forms (`const Color`, `Colors.x`
  [`.shadeN`], `Theme.of(...).colorScheme.x`). The pure String→String edit
  ops live in `deterministic_edit_ops.dart` and are unit-tested against
  realistic generated source. Post-edit guard is a ~50 ms `dart format`
  parse-check (replaced materialize + `pub get` + `flutter analyze`).
- **Real-time feel — optimistic overlays + single-screen re-capture**
  (`603693d`): the moment a colour/text edit lands, the new value is
  **pre-painted on the canvas** (solid fill for a box's background,
  translucent tint for a text region) so the change is visible *instantly*,
  before the true re-capture replaces it — the "semi-real time" ask. After an
  edit only the **touched route** is re-pumped (`recaptureOneScreen`); the
  other screens are seeded from the most recent prior capture so the map
  stays complete without re-running every one (falls back to a full capture
  on any failure). Overlays clear only for the screens actually re-captured,
  and a busy-skipped re-capture is **re-armed** so quick successive edits
  always converge. Also fixed a latent bug: `_resolveSources` returned the
  re-resolved map that `_load`/`_recapture` were then overwriting with the
  unresolved capture (regions lost their source lines after any re-capture).
- **Colour edits that actually land + screen-background option** (this pass):
  the old colour ops only matched a fixed set of colour *literals* (`Color(0x…)`,
  `Colors.x`, `Theme.of().colorScheme.x`) inside `TextStyle(`/`backgroundColor:`,
  so they missed the forms the generator actually emits — text colour set via
  `textTheme.x?.copyWith(color: …)`, and colours that are theme constants
  (`CasinoTheme.gold`), `…withValues(alpha: 0.15)`, or `scheme.onSurface`.
  The colour ops are now **value-span based**: they find the `color:` / `backgroundColor:`
  property and replace the value *whatever form it is in* by scanning to the
  matching comma/paren (so any value token is handled, and we never need to
  know the colour's source). Text colour now recognises `.copyWith(…)` as a
  text-style container (not just `TextStyle(`), inserts a `color:` when a style
  has none, and a box colour never mistakes a text-style colour for a fill.
  Added a **screen-background** op: a "Set background…" menu item (the app's
  own background can't be clicked to target it) that sets the page Scaffold's
  `backgroundColor:` — matched at the Scaffold's **top depth level** so a nested
  `Container(backgroundColor:…)` is never hit; a background **image** is offered
  too and routes to the assistant (it's a structural wrap, not a one-line edit).
  The **Edit-text** dialog now **pre-fills the current rendered text** (own text
  or the box's first child text) so you confirm you picked the right element.
  Diagnostics: the apply path now logs each op's target + whether a
  deterministic match was found. Honest limit: **parameterised widgets** (e.g.
  `_GameTile(title: 'Roulette')`) carry their rendered text as data, so the
  locator anchors at the call site — far from the widget's style — and those
  still fall through to the assistant. Six new unit tests cover the real forms.
  83 tests pass, analyze clean.

## 6. Risks & honest hard parts

1. **Widget→source fidelity.** Debug creation stacks give *a* file:line, but
   deep widget trees can attribute a region to a line further out than the
   user expects. Mitigation: attribute regions to the nearest line that owns
   an *editable construct* (decorator/text/color), and always show the
   attributed source in the tooltip so it's auditable.
2. **Deterministic applier coverage.** Agent-written code is heterogeneous;
   not every `set_color` finds a clean pattern. Mitigation: small op
   vocabulary + agent fallback + analyze/rollback guard. Measure the
   deterministic hit-rate per op; expand patterns from real misses.
3. **"Move" in a constraint-based layout.** Flutter positions are
   declarative (Row/Column/Stack/alignment) — a free dx/dy must be translated
   into padding/margin/`Positioned`/alignment changes. Start with
   Stack-positioned and margin-safe cases; the long tail goes to the agent.
   *This is the single hardest op — it is deliberately in Phase 1 but scoped
   to "shift by spacing", not freeform Figma drag.*
4. **Live-mode platform deps.** Solved by making the browser the canvas
   (zero new deps); webview embedding stays optional.
5. **Harness cost.** One debug test build per project (minutes) + seconds per
   screen refresh. Acceptable; cache per git HEAD.
6. **Preview host injection.** Wrapping an agent-written `main.dart` can
   collide with app-specific setup (plugins, channels). Mitigation: the
   harness runs the app's *real* `main` in a test where possible
   (`main()` then route-pump); the live bridge falls back to a generated
   wrapper only when needed, and preview-time injection never touches the
   committed app files (it lives in `/.nexus/` or a sibling preview dir).

## 7. Non-goals (for now)

- Creating new screens / freeform canvas design (that's a page-builder,
  different product).
- Editing game logic (the coding agent + chat remain the path for that).
- Mobile emulation, multi-device side-by-side.
- Replacing the mini-IDE (it becomes a sub-tab).

## 8. Open questions (decide before Phase 0 kickoff)

1. Preview host: **browser tab** (no deps, two windows) vs webview embed
   (one window, platform deps) — recommendation: browser for Phase 2, revisit   webview later.
2. Should the harness/regions be produced **on demand** (first open of
   the Visual Editor) or **at completion** (background job after the build
   Phase-0 cost paid up front)? Recommendation: on demand + a
   "Refresh screens stale — refresh" indicator per git HEAD.
3. Region granularity: every RenderBox is noisy; decide the filter (keep a
   screen to ≤ N interactive regions, dedupe same-rect nesting).

## 9. Rough sizing

Phase 0 is the big chunk (harness + shell); Phase 1 is the product; Phases 2–3
are incremental. Suggest committing to **Phase 0+1 as a program of 2–3 focused
iterations**, then reviewing against real usage before Phase 2.

## 10. Bugs found & fixed during live testing (log)

- **Non-ASCII file corruption on save (serious, fixed f2c7d83).** The
deterministic-edit save path wrote `content.codeUnits` (UTF-16 code units) as
raw bytes, corrupting every non-ASCII char (`–`, `×`, `·`, `…`, `é`) into a lone
high byte → an **invalid-UTF-8 file that no longer compiled**. Each subsequent
edit re-decoded the broken bytes to U+FFFD (→ byte `0xfd`) and re-corrupted
further, so the damage cascaded across saves. Fix: write valid UTF-8
(`utf8.encode`) in the file save, the parse-gate, and the pubspec save.
  - Guard: `visual_editor_pubspec_asset_test.dart` → "round-trips a non-ASCII
    file" (the in-memory WS decodes strictly, so a regression to `codeUnits`
    throws → the test fails).
  - Recovery note: this had silently corrupted 2 live-project pages (task_13,
    ebay). Because the cascade is lossy (chars → U+FFFD), the only reliable
    repair is the **clean git blob** in `git_objects` (pick the largest
    valid-UTF-8 blob that parses). After direct DB repair you MUST also update
    `nodes.size` (the cached length) or git `status()` throws a `RangeError`.
    The VHD working tree is the `blocks` table; `readString` uses
    `decodeUtf8Lossy` (the cascade amplifier).
- **"Clear background image" on an image-less screen (fixed 204951c).**
  When a page's Scaffold body has no background image, the op correctly had
  nothing to remove but fell through to the assistant (confusing). Now
  `_clearBackgroundImage` pre-checks and shows a "no background image to clear"
  toast instead. (Clearing still goes to the assistant only for backgrounds set
  in a non-Stack form, e.g. by the assistant itself.)
