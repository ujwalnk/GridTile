import SwiftUI

/// Renders the uniform backdrop behind the grid tiles, per
/// `appearance.backgroundStyle`. Shared by `GridOverlayView` (the real
/// full-screen overlay) and `AppearanceEditorView`'s live preview, so the
/// preview always matches what actually gets shown.
///
/// This view is expected to be given the full tile-grid bounds by its
/// parent (it has no intrinsic size of its own) — see callers.
struct GridBackgroundView: View {
    let appearance: GridAppearance

    var body: some View {
        switch appearance.backgroundStyle {
        case .transparent:
            Color.clear

        case .solidColor:
            Color(appearance.backgroundColor.nsColor)
                .opacity(appearance.backgroundOpacity)

        case .macOSMaterial:
            ZStack {
                VisualEffectBackground(material: appearance.backgroundMaterial.nsMaterial)
                // Optional subtle tint on top of the material. Capped at the
                // model level (see `GridAppearance.backgroundMaterialTintOpacity`'s
                // slider range) so it can't be pushed high enough to wash out
                // the native frosted-glass look.
                if appearance.backgroundMaterialTintOpacity > 0 {
                    Color(appearance.backgroundMaterialTintColor.nsColor)
                        .opacity(appearance.backgroundMaterialTintOpacity)
                }
            }
        }
    }
}
