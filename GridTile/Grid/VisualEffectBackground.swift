import SwiftUI
import AppKit

/// Thin `NSViewRepresentable` around `NSVisualEffectView`. This exists so the
/// "macOS Material" background option is the *real* system translucency
/// effect — sampling and blurring whatever is behind the window — rather
/// than an approximation built out of SwiftUI blur/opacity modifiers, which
/// never quite matches the native look and doesn't respond to what's behind
/// the window the way the system effect does.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        // `.active` (rather than `.followsWindowActiveState`) keeps the
        // material looking correct even though the overlay window is
        // shown/hidden rapidly and briefly steals key status — an inactive
        // appearance would read as visually "disabled" for an overlay that's
        // only ever on screen while it's the thing the user is looking at.
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
