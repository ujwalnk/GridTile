# GridTile

A native macOS keyboard-driven window tiling utility — a Swift/SwiftUI/AppKit
reimplementation of a Hammerspoon "two-keypress grid" workflow, built as a
proper menu-bar `.app` rather than a script.

## Requirements

- macOS 14 (Sonoma) or macOS 15 (Sequoia) — targets the two most recent major
  releases, per the project brief. (Bump `MACOSX_DEPLOYMENT_TARGET` in the
  project's build settings if you need to support an older OS.)
- Xcode 15.2 or later.

## Build & run

1. Open `GridTile.xcodeproj` in Xcode.
2. Select the **GridTile** scheme and build/run (⌘R).
3. On first launch GridTile has no Dock icon — look for its grid icon in the
   menu bar. It will also open Settings on the **Permissions** tab
   automatically, since it needs Accessibility access to move windows.
4. Click **Grant Access…**, allow GridTile in the system dialog (or via
   **Open System Settings** → Privacy & Security → Accessibility), then come
   back — the checkmark updates automatically.
5. Press **⌃⌥1** (the default Layout 1 shortcut) over any window. A grid
   overlay appears on the screen your mouse is on. Press a cell's key, then
   another cell's key — the original window resizes to span both cells.
   Press **Escape** at any point to cancel.

Configuration is saved as JSON at
`~/Library/Application Support/GridTile/configuration.json` and reloaded
automatically on next launch. Delete that file (or edit it directly) to reset
to defaults.

## Project layout

```
GridTile/
├── main.swift, AppDelegate.swift        — app entry, menu-bar/accessory setup
├── AppState.swift                       — coordinator: config + activation flow
├── MenuBarController.swift              — NSStatusItem + dynamic layouts menu
├── Models/                              — Codable data model (layouts, cells,
│                                          shortcuts, appearance, config)
├── Persistence/ConfigurationStore.swift — atomic JSON load/save + migration
├── Keyboard/                            — global hotkeys, shortcut recorder,
│                                          two-keypress selection state machine
├── Grid/                                — geometry math + the overlay window/
│                                          view/controller
├── WindowManagement/                    — AXUIElement move/resize + focus
│                                          capture/restore
├── Screen/ScreenManager.swift           — mouse/window → NSScreen resolution
├── Permissions/AccessibilityManager.swift — AX trust check + onboarding
├── Settings/                            — all SwiftUI settings UI
└── Errors/GridTileError.swift           — user-facing error strings
```

## Key architectural decisions

**Global activation shortcuts use Carbon's `RegisterEventHotKey`, not
`NSEvent` global monitors.** Carbon hotkeys fire regardless of Accessibility/
Input-Monitoring trust and don't require GridTile to have any window at all.
This is the same mechanism long-standing native tiling utilities use, and it
keeps "press ⌃⌥1 from anywhere" working even before the user has granted
Accessibility access — so GridTile can *tell* the user it needs that
permission (via the overlay/window-move failing gracefully) instead of the
global shortcut itself silently not firing.

**Cell-selection keys are captured with a local `NSEvent` monitor scoped to
the overlay window**, not a global one. Once GridTile activates itself and
the overlay becomes key window, a local monitor is sufficient, needs no extra
permission, and — critically — can swallow the event (return `nil`) so
letters/numbers typed during selection never leak through to the app
underneath.

**The originally-focused window is captured via `AXUIElementCopyAttributeValue`
on `NSWorkspace.shared.frontmostApplication` *before* GridTile calls
`NSApp.activate`.** The resulting `AXUIElement` reference is held for the rest
of the operation and never re-derived from "whatever's focused now" — so once
GridTile itself becomes frontmost/key, there's no ambiguity about which window
is the tiling target, and no risk of GridTile accidentally resizing its own
overlay.

**Window movement uses `AXUIElementSetAttributeValue` with `kAXPositionAttribute`
/ `kAXSizeAttribute`**, the only supported way to reposition another process's
window on modern macOS. This requires Accessibility permission and requires
disabling the App Sandbox (see `GridTile.entitlements`), which also means
GridTile should be distributed via direct download/notarization rather than
the Mac App Store — standard for this category of app.

**Coordinate systems** are centralized in `ScreenManager` and
`WindowManager`. AppKit (`NSScreen`, `NSWindow`, `NSEvent.mouseLocation`) uses
one global space: origin at the bottom-left of the primary display, points,
shared across every monitor regardless of arrangement. The Accessibility API
uses a different space: origin at the *top*-left of the primary display, y
increasing downward — the same convention as Core Graphics/`CGWindowListCopy-
WindowInfo`. `WindowManager.axFrame(fromCocoaFrame:)` / `cocoaFrame(fromAXFrame:)`
are the only two functions that convert between them; every other file works
in whichever space is native to the API it's calling. Grid geometry and tiled
window frames are always computed against a screen's `visibleFrame` (menu
bar/Dock/notch-safe-area already excluded), never its raw physical `frame`.

**Shortcuts use physical key codes (Carbon `kVK_*` constants), not
layout-mapped characters.** This is what makes `A` vs `⇧A` reliably distinct
and lets Tab/Space/arrows/function keys be assigned without any special-casing
in the recorder. The trade-off, shared with most keyboard-driven macOS
utilities (Hammerspoon included), is that key *positions* are fixed to the US
ANSI layout's names even on other physical layouts; the key that's
*physically* in the same place still works, it just may display an
unexpected label on non-US keyboards.

**Persistence is a single versioned JSON file, written atomically** (write to
a `.tmp` file, then `replaceItemAt`) so a crash mid-save can't corrupt the
user's configuration. A `VersionProbe` decode step reads just the `version`
field first so future schema changes can migrate old files instead of
discarding them; a genuinely corrupt/unreadable file is backed up as `.bak`
and replaced with defaults rather than crashing the app.

**Performance**: nothing polls. The overlay window and its key monitor are
created on activation and torn down immediately after selection or
cancellation. The only "timer" in the whole app is a 1-second poll used
solely while the Permissions settings tab is visible (there's no push
notification for Accessibility-trust changes), and it's stopped the moment
that tab isn't on screen. Global hotkeys and the menu bar status item are the
only things alive while GridTile is otherwise idle.

## Known limitations / follow-ups

- Key names are US-ANSI-layout based (see above).
- The shortcut recorder does not yet warn if a chosen *cell* shortcut
  collides with a system-wide shortcut belonging to another app (only
  activation-shortcut registration failures and in-layout duplicates are
  detected) — cell shortcuts are local to the overlay window, so this is a
  cosmetic warning gap rather than a functional one.
- No app icon asset is included (the asset catalog has an empty `AppIcon`
  set) — add one before distributing.
