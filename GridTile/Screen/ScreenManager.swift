import AppKit
import Foundation

/// Centralizes every place GridTile needs to reason about `NSScreen`s so
/// coordinate-system mistakes (§12) only have one place to be wrong.
///
/// AppKit screen coordinates are already "bottom-left origin, points, one
/// global space spanning every display" — the same space `NSWindow.setFrame`
/// and `NSEvent.mouseLocation` use. The one place that differs is the
/// Accessibility API (`AXUIElement`), which reports window positions in
/// **top-left-origin, main-display-relative** coordinates. `WindowManager`
/// is the only place that conversion happens.
enum ScreenManager {
    /// The screen containing the current mouse pointer, falling back to the
    /// main screen if the pointer is (implausibly) outside every display.
    static func screenUnderMouse() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    /// The screen whose frame contains (the majority of) the given global,
    /// bottom-left-origin AppKit rectangle.
    static func screen(containing rect: CGRect) -> NSScreen {
        var best: NSScreen?
        var bestArea: CGFloat = -1
        for screen in NSScreen.screens {
            let intersection = screen.frame.intersection(rect)
            let area = intersection.width * intersection.height
            if area > bestArea {
                bestArea = area
                best = screen
            }
        }
        return best ?? NSScreen.main ?? NSScreen.screens[0]
    }

    /// The "usable" frame for the given screen — excludes the menu bar, Dock,
    /// and any other reserved chrome (notch safe areas are already excluded
    /// from `visibleFrame` by AppKit on supported hardware). Grid geometry and
    /// tiled window frames are always computed relative to this, never the raw
    /// physical `frame` (§12).
    static func usableFrame(for screen: NSScreen) -> CGRect {
        screen.visibleFrame
    }
}
