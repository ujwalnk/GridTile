
# CLAUDE.md — GridTile project memory

Compressed architectural context for AI-assisted work on GridTile. Read this
fully before opening source files. Optimized for information density, not
human prose style.

## What GridTile is

Native macOS menu-bar utility (Swift/SwiftUI/AppKit, no Dock icon,
`LSUIElement`). Keyboard-driven window tiling: user presses a global
activation shortcut (e.g. `⌃⌥1`) → full-screen grid overlay appears on one
screen → user presses two cell-key letters (first = one corner, second =
opposite corner of the span) → the window that was focused *before*
activation gets moved+resized via Accessibility API to span those cells →
focus returns to that window. Escape cancels at any point. Multiple
independently-configured "layouts" (grid shape, per-cell shortcuts,
appearance, own activation shortcut, own display-mode) are supported;
switching between them is just picking a different registered global
shortcut. Config persists as JSON. Sandbox disabled (required for AX).
Targets macOS 14/15, Xcode 15.2+.

Reimplementation of a prior Hammerspoon Lua "two-keypress grid" script — see
inline comments referencing "the Lua reference."

## Directory → responsibility map

```
main.swift, AppDelegate.swift   entry point, app lifecycle, global error alert sink
AppState.swift                  central coordinator: config CRUD, shortcut (re)registration,
                                 the activate→overlay→select→tile→restore flow
MenuBarController.swift         NSStatusItem + dynamic per-layout menu
Models/                         Codable data model (see below)
Persistence/ConfigurationStore.swift   atomic JSON load/save + version-gated migration
Keyboard/                       global hotkeys (Carbon), overlay key capture, key-code tables
Grid/                           pure geometry (GridCalculator) + overlay window/view/controller
WindowManagement/               AXUIElement move/resize + focused-window capture/restore
Screen/ScreenManager.swift      mouse/window → NSScreen resolution; usableFrame source of truth
Permissions/AccessibilityManager.swift   AX trust check/prompt/poll
Settings/                       all SwiftUI settings UI (tabs: Layouts, Permissions)
Errors/GridTileError.swift      every user-facing error string, LocalizedError
```

## Activation flow (the core control-flow path — trace this first)

`GlobalShortcutManager` fires (Carbon hotkey, works without AX trust) →
`AppState.activate(layoutID:)`:

1. Re-entrancy guard: ignore if overlay already visible.
2. `AccessibilityManager.shared.refresh()` — bail with `.accessibilityPermissionMissing` if untrusted.
3. **Capture focus first**: `FocusedWindowInfo.captureCurrentlyFocused()` reads
   `NSWorkspace.shared.frontmostApplication` + its `kAXFocusedWindowAttribute`
   *before* GridTile does anything that could steal focus. Stored in
   `AppState.pendingFocusedWindow`. This `AXUIElement` reference is used for
   the rest of the operation and **never re-derived** — critical invariant,
   guarantees GridTile can't accidentally resize its own overlay once it
   becomes frontmost.
4. Resolve target `NSScreen` from `layout.displayMode` (`.followMouse` →
   `ScreenManager.screenUnderMouse()`; `.followFocusedWindow` → screen
   containing the captured window's current AX frame, converted to Cocoa
   space).
5. `GridOverlayController.show(layout:on:)` — builds+shows a borderless
   `GridOverlayWindow` (`.screenSaver` level, spans `screen.visibleFrame`)
   hosting `GridOverlayView`, installs a **local** `NSEvent` key monitor
   scoped to the overlay (swallows every keydown while up — nothing leaks to
   the app underneath).
6. Each keydown → `GridKeyHandler.handle(event:)`, a pure 2-state FSM:
   `.ignored` / `.firstCellSelected` (highlight only) / `.selectionComplete`
   / `.cancelled` (Escape, unconditionally, even if bound to a cell).
7. On `.selectionComplete`: `GridOverlayController.process(outcome:)`
   recomputes cell rects via `GridCalculator.computeCells`, spans them
   (`GridCalculator.spanningRect`), insets by `cellPadding/2` (same inset the
   overlay itself renders, so the tiled window's gap from neighbors matches
   the overlay visually), flips SwiftUI's top-left-origin local space to
   AppKit's bottom-left-origin global space, hides the overlay, then invokes
   `onComplete(globalRect)`.
8. `AppState.completeTiling(rect:)` → `WindowManager.apply(frame:to:)` on the
   captured `FocusedWindowInfo`, then `focused.restoreFocus()`
   (`NSRunningApplication.activate` + `kAXMainAttribute` + `kAXRaiseAction`)
   regardless of whether `apply` threw. Errors surface through
   `AppState.lastError` (`@Published`) → `AppDelegate`'s Combine sink → modal
   `NSAlert`.

Cancel path: `.cancelled` → `AppState.cancelTiling()` → just restores focus,
no window mutation.

## Coordinate systems (§12 in original spec comments — get this wrong and
## everything silently misplaces)

Two distinct global spaces are in play, and exactly one file bridges them:

- **AppKit/Cocoa space**: origin bottom-left of the *primary* display
  (`NSScreen.screens[0]`, i.e. the one with the menu bar), y-up, one
  coordinate system spanning every monitor. Used by `NSScreen`, `NSWindow`,
  `NSEvent.mouseLocation`. `ScreenManager` and `GridOverlayController`'s
  final rect all operate here.
- **Accessibility/CoreGraphics space**: origin top-left of the primary
  display, y-down. Used by `kAXPositionAttribute`/`kAXSizeAttribute` and
  `CGWindowListCopyWindowInfo`.
- **SwiftUI/local overlay space**: top-left-origin, y-down, relative to
  `.zero` (the overlay window's own bounds) — what `GridCalculator` and
  `GridOverlayView` work in. Flipped to Cocoa global space only once, inside
  `GridOverlayController.process(outcome:)`, using the overlay's own
  `screenFrame` origin + `localBounds.height`.

`WindowManager.axFrame(fromCocoaFrame:)` / `.cocoaFrame(fromAXFrame:)` are
the **only** two conversion functions in the codebase; every other file
works exclusively in whichever space is native to the API it calls. Both
assume `NSScreen.screens.first` is the primary/menu-bar display (true per
AppKit's documented ordering) and flip using *that* screen's height — not
the target screen's — since AX space is relative to the primary display
regardless of which physical screen the window is actually on.

Grid geometry and tiled-window frames are always computed against a
screen's `visibleFrame` (`ScreenManager.usableFrame`), never its raw
`frame` — this excludes menu bar/Dock/notch safe area. Never substitute
`.frame` for `.visibleFrame` in this codebase.

## WindowManagement/ — AXUIElement move/resize (recently debugged; read carefully)

`FocusedWindowInfo` (struct): holds `axWindow`, `axApplication`,
`runningApplication`, `pid`, captured once at activation time.
`stillExists` cheaply probes `kAXPositionAttribute`. `restoreFocus()` is
best-effort (return values of the AX calls are ignored — there's nothing
useful to do if they fail).

`WindowManager.apply(frame:to:)` is the only place that writes to a
window's AX position/size. Sequence:
1. Re-check AX trust + `window.stillExists`.
2. Convert target Cocoa-space rect → AX-space via `axFrame(fromCocoaFrame:)`.
3. Set `kAXPositionAttribute` **then** `kAXSizeAttribute` (in that order —
   see rationale below). Both must report `.success` or the whole call
   throws `.windowMoveFailed`.
4. Read back the resulting AX position via `currentFrame(of:)` and, **only
   if it drifted from the requested origin** (tolerance 0.5pt), re-issue a
   single corrective `kAXPositionAttribute` write.

### Known historical bug (fixed) — intermittent "moved but not resized"

Symptom: GridTile's position write always took effect; the size write
intermittently silently didn't (no thrown error — `AXUIElementSetAttributeValue`
reported `.success` for both calls; the window just kept its old size).

Root cause: the previous implementation set position, then size, then
**unconditionally** re-issued the position write a third time immediately
afterward (intended to correct for apps that clamp size in a way that
shifts position as a side effect). For apps whose AX size handler applies
the resize asynchronously (deferred to their own next layout/display pass
rather than synchronously inside the AX call), that immediate, unconditional
third write raced with the pending resize: if the app processed the
redundant position write before its own resize had committed internally, it
re-derived the window's frame from its still-stale size while handling the
move, discarding the pending resize. Because the relative timing of "app's
internal resize completes" vs. "app processes the next AX message" isn't
deterministic, the failure was intermittent.

Fix: removed the unconditional third write. The corrective position write
is now conditional — only sent if reading the window's actual resulting AX
frame back shows position genuinely drifted from what was requested. This
still handles the "app clamped size and shifted position" case the original
code was guarding against, without the redundant blind write that raced
with async resizers. Position-before-size ordering was kept (not the cause
of the bug) because it's independently useful: apps that validate a
requested size against the window's *current* position (to keep it from
being placed off-screen) evaluate the size request against the frame's new
origin rather than a stale one.

**Invariant for future changes to this function**: never add an
unconditional AX attribute write that immediately follows another write to
the *same* element without an intervening read-back check — that pattern is
exactly what caused this bug, and it's easy to reintroduce by, e.g., adding
another "just in case" corrective write. If a correction is needed, verify
first, correct only if actually wrong.

`currentFrame(of:)` reads current position+size via
`AXUIElementCopyAttributeValue` and converts back to Cocoa space; used both
by the fix above and by `AppState`'s `.followFocusedWindow` display-mode
resolution.

## Grid/ — pure geometry + overlay adapter

`GridCalculator` (enum, no AppKit/SwiftUI import — deliberately pure/testable):
- `computeCells(rows:columns:rowWeights:columnWeights:in:)` — distributes
  `bounds` into a weighted grid. Weights normalized internally (don't need
  to sum to 1). Returns rects in **top-left-origin, y-down** space matching
  `bounds` directly (mirrors the SwiftUI/local convention above). Guards:
  returns `[]` if row/column counts don't match weight-array counts or any
  weight is `<= 0`.
- `spanningRect(_:_:)` — bounding box of two cell rects, order-independent.
- Both mirror the original Lua reference's `sum()`/`getRect()` helpers.

`GridOverlayController` — owns exactly one `GridOverlayWindow` per
activation; nothing polls or persists while idle (§27 invariant — verify
any new feature here doesn't add a timer/observer that outlives one
activation). `hide()` tears down window/hostingView/keyHandler/keyMonitor
together; always call before creating a new overlay (`show()` calls it
defensively first — "never stack two overlays").

`GridOverlayWindow` — borderless, `.screenSaver` level,
`collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle,
.fullScreenAuxiliary]`, overrides `canBecomeKey`/`canBecomeMain` (both
`true` — borderless windows can't become key by default, but GridTile needs
key status to receive keydowns).

`GridOverlayView` (SwiftUI) — renders `GridBackgroundView` (backdrop) +
one view per cell via `ForEach(cells, id: \.hashID)`. Cell padding
(`appearance.cellPadding`) is applied identically here (`insetBy(dx:
padding/2, dy: padding/2)`) and in `GridOverlayController.process(outcome:)`
when computing the final tiled-window rect — **these two insets must stay
in sync**; if you change one, change the other, or the visual grid and the
actual resulting window frame will disagree.

`GridBackgroundView` / `VisualEffectBackground` — three interchangeable
backdrop styles (`.transparent`, `.solidColor`, `.macOSMaterial` via real
`NSVisualEffectView`, not a SwiftUI blur approximation). Shared between the
live overlay and `AppearanceEditorView`'s settings preview so they can't
drift apart.

## Models/

- `GridLayoutModel` — one fully self-contained layout: geometry
  (rows/columns/weights), `[GridCell]` (row/column → `KeyboardShortcut`,
  sparse-friendly), `GridAppearance`, its own `activationShortcut`, its own
  `displayMode`. `resize(rows:columns:)` preserves surviving `(row,column)`
  cells/weights and assigns fresh shortcuts (via `DefaultKeyAssignment`) to
  new cells only — never scrambles the surviving NxN block.
- `GridCell` — `(row, column, shortcut)`, `id = "row-column"`.
- `GridDisplayMode` — `.followMouse` | `.followFocusedWindow`.
- `KeyboardShortcut` — `(keyCode: UInt16, modifierFlagsRaw: UInt)`. Uses
  **physical key codes** (`kVK_*`), not layout-mapped characters —
  deliberate (see README "Known limitations": US-ANSI key *names* shown on
  other layouts, but the physical key position is what's bound). Modifier
  flags are masked to just command/option/control/shift at construction
  time (caps-lock/fn stripped). `carbonModifiers` for hotkey registration;
  `displayString` for UI (e.g. `⌃⌥⇧A`). `KeyCodeMap` is the bidirectional
  key-code↔name table plus the reverse lookup used only for building the
  generated default layout from plain characters.
- `GridAppearance` — all per-layout visual config (fill/border/text
  colors+opacities, corner radius, cell padding, font, selection
  fill/border, background style + its style-specific fields). Custom
  `init(from:)` decoder: background-style fields (`backgroundStyle`,
  `backgroundColor`, etc.) are `decodeIfPresent`-with-fallback so configs
  saved before that feature existed still decode (fall back to
  `.transparent`, preserving pre-upgrade appearance) rather than tripping
  `ConfigurationStore`'s all-or-nothing decode-failure→reset-to-defaults
  path. **Any future new field on this struct needs the same
  `decodeIfPresent` treatment in `init(from:)`, or old configs will fail to
  decode entirely** (not gracefully degrade).
- `CodableColor` — plain RGBA doubles (NSColor doesn't round-trip Codable
  cleanly across color spaces).
- `BackgroundStyle` / `BackgroundMaterial` — `.transparent` /
  `.solidColor` / `.macOSMaterial`; `BackgroundMaterial` is a curated subset
  of `NSVisualEffectView.Material` (not the full enum — only materials that
  make sense full-screen).
- `AppConfiguration` — versioned root: `version`, `GlobalSettings`
  (currently just `defaultDisplayMode`, applied to newly-created layouts
  only — per-layout `displayMode` is the actual source of truth at runtime),
  `[GridLayoutModel]`.
- `DefaultKeyAssignment.generator(excluding:)` — lazy candidate stream:
  lowercase letters → digits → uppercase letters → (exhausted) Control+Command
  letter fallback. Used both for the built-in default 8×5 layout and for
  auto-assigning shortcuts to newly-added grid cells.

## Persistence

`ConfigurationStore` (singleton): JSON at
`~/Library/Application Support/GridTile/configuration.json`, pretty-printed
+ sorted keys. **Atomic write**: encode → write to `.tmp` → `replaceItemAt`.
Load: probe just `version` first (`VersionProbe`), then
`migrate(data:fromVersion:)` (currently a no-op passthrough for
`currentVersion`; add a real case per historical version as schema
evolves — do not delete the `default:` best-effort-decode fallback, it's
what lets *unknown* future versions still attempt a load instead of
resetting). Any decode failure anywhere in this path → back up the corrupt
file as `.bak`, fall back to `AppConfiguration.defaultConfiguration`, save
that as the new file. Missing file (first launch) takes the same
defaults-and-save path.

## Keyboard/

- `GlobalShortcutManager` (singleton) — Carbon `RegisterEventHotKey`, not
  `NSEvent` global monitors. Deliberate: Carbon hotkeys fire regardless of
  Accessibility/Input-Monitoring trust and don't require GridTile to have
  any window — this is what lets GridTile *tell* the user it needs AX
  permission (via a graceful window-move failure) rather than the global
  shortcut itself silently doing nothing pre-permission. One shared Carbon
  event handler installed once; dispatches by `EventHotKeyID.id` to a
  `[UInt32: () -> Void]` handler table. `register` returns `nil` (no
  throw) on conflict with another app's claimed shortcut — caller
  (`AppState.registerAllShortcuts`) surfaces `.shortcutConflict`.
- `GridKeyHandler` — pure 2-state FSM (see Activation flow above), one
  instance per activation, AppKit-free enough to be trivially testable
  except for its `NSEvent` input type.
- `ShortcutRecorder` (`ShortcutRecorderNSView`) — invisible focusable
  `NSView` that captures the *next* raw keydown via `keyDown`/
  `performKeyEquivalent` override (bypasses normal responder-chain
  key-equivalent handling so Tab/Space/Return are capturable instead of
  triggering focus-change/button-press). Escape-with-no-modifiers cancels
  recording instead of being captured as a shortcut.

## Permissions

`AccessibilityManager` (singleton, `ObservableObject`): wraps
`AXIsProcessTrusted()` / `AXIsProcessTrustedWithOptions(prompt)`. `refresh()`
re-checks and publishes `isTrusted` only on change. No push notification
exists for AX-trust changes, so a 1s poll timer runs **only** while the
Permissions settings tab is on screen (`startObservingWhileVisible()` /
`stopObserving()`) — idle CPU stays zero otherwise. `requestPermission()`
must only be called from explicit user action (a button), not silently at
launch — the system prompt has a one-shot-per-decision quality users find
confusing if triggered unprompted.

## Screen

`ScreenManager` — all `NSScreen` reasoning funnels through here:
`screenUnderMouse()` (falls back `NSScreen.main` → `.screens[0]`),
`screen(containing:)` (max intersection-area match, same fallback chain),
`usableFrame(for:)` (`= screen.visibleFrame`, the single source of truth
used everywhere geometry is computed — never substitute raw `.frame`).

## Errors

`GridTileError: LocalizedError` — one case per user-facing failure mode,
each carrying enough context for a complete, actionable message (no
generic "something went wrong" fallback exists in this codebase by design).
Surfaced exclusively through `AppState.lastError` → `AppDelegate`'s
Combine `.sink` → modal `NSAlert`. New failure modes should get a new case
here rather than being force-mapped onto an existing one or swallowed.

## Concurrency

Almost entirely synchronous/single-threaded (main thread, AppKit/SwiftUI).
The **only** asynchronous code in the whole app is `Updates/UpdateChecker`
(a single non-blocking `URLSession` request, hopping back to
`DispatchQueue.main.async` for its two completion points) — update-check
logic, not part of the core tiling flow. Nothing in `AppState`,
`WindowManager`, `GridOverlayController`, or the Keyboard/ files uses
`DispatchQueue`/`async`/`Task`. Keep it that way for the core flow unless
there's a specific, well-understood reason (see the WindowManagement bug
above for what an unguarded extra synchronous AX call already causes — an
actual `async`/dispatch addition to that path would need even more care).

## Build/run

Open `GridTile.xcodeproj` in Xcode 15.2+, run the `GridTile` scheme (⌘R).
No SPM/CocoaPods dependencies beyond system frameworks (AppKit,
`ApplicationServices`/AX, `Carbon.HIToolbox`, SwiftUI, Combine, `os.log`).
Entitlements disable App Sandbox (`GridTile.entitlements`) — required for
cross-process AX window control; means Mac App Store distribution isn't
viable, direct-download+notarization is the intended distribution path.
`LSUIElement` set in `Info.plist` (no Dock icon/app-switcher entry);
`AppDelegate` also calls `NSApp.setActivationPolicy(.accessory)`
redundantly at launch as a belt-and-suspenders in case the plist value is
ever ignored by the launch context.

## Known limitations (as of this file)

- Shortcut key *names* shown in UI are US-ANSI-layout labels regardless of
  the user's actual keyboard layout (physical key position is what's bound
  and works correctly; only the displayed label can be "wrong" on
  non-US layouts).
- Cell-level shortcut collisions with *other apps'* system-wide shortcuts
  aren't detected (only activation-shortcut registration failures and
  in-layout duplicate-cell-shortcut warnings are) — cosmetic gap, not
  functional, since cell shortcuts are only live while the overlay itself
  is key window.
- No app icon asset included in the shipped `Assets.xcassets` (empty
  `AppIcon` set) — add before distributing. (Two separate `.icon` bundles —
  `gridTile.icon/`, `icon.icon/` — exist in the repo as design-tool
  artifacts/exports, not the wired-up app icon.)
