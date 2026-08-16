import Foundation
import AppKit

/// A `Codable`-friendly RGBA color. `NSColor` itself round-trips through `Codable`
/// awkwardly across color spaces, so we store plain component values instead.
struct CodableColor: Codable, Hashable, Equatable {
    var red: Double
    var green: Double
    var blue: Double

    var nsColor: NSColor {
        NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(nsColor: NSColor) {
        let c = nsColor.usingColorSpace(.deviceRGB) ?? nsColor
        self.red = Double(c.redComponent)
        self.green = Double(c.greenComponent)
        self.blue = Double(c.blueComponent)
    }

    static let darkFill = CodableColor(red: 0.05, green: 0.05, blue: 0.07)
    static let lightBorder = CodableColor(red: 0.85, green: 0.87, blue: 0.92)
    static let white = CodableColor(red: 1.0, green: 1.0, blue: 1.0)
}

/// All visual configuration for a single layout's overlay. Intentionally has no
/// shadow properties — the spec explicitly excludes shadows.
struct GridAppearance: Codable, Hashable, Equatable {
    var fillColor: CodableColor
    var fillOpacity: Double
    var borderColor: CodableColor
    var borderOpacity: Double
    var borderWidth: Double
    var cornerRadius: Double
    var cellPadding: Double
    var textColor: CodableColor
    var textOpacity: Double
    var textSize: Double
    var fontName: String

    /// Fill/border used for the currently selected first cell.
    var selectionFillOpacity: Double
    var selectionBorderColor: CodableColor

    static var defaultAppearance: GridAppearance {
        GridAppearance(
            fillColor: .darkFill,
            fillOpacity: 0.55,
            borderColor: .lightBorder,
            borderOpacity: 0.35,
            borderWidth: 1.0,
            cornerRadius: 8.0,
            cellPadding: 6.0,
            textColor: .white,
            textOpacity: 0.9,
            textSize: 18.0,
            fontName: "SF Pro Rounded",
            selectionFillOpacity: 0.85,
            selectionBorderColor: CodableColor(red: 0.3, green: 0.65, blue: 1.0)
        )
    }

    var font: NSFont {
        NSFont(name: fontName, size: CGFloat(textSize))
            ?? NSFont.systemFont(ofSize: CGFloat(textSize), weight: .semibold)
    }
}
