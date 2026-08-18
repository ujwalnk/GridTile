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

    /// Which of the three background treatments to use for the uniform
    /// backdrop behind all tiles (background material addendum).
    var backgroundStyle: BackgroundStyle
    /// Used only when `backgroundStyle == .solidColor`.
    var backgroundColor: CodableColor
    var backgroundOpacity: Double
    /// Used only when `backgroundStyle == .macOSMaterial`.
    var backgroundMaterial: BackgroundMaterial
    /// Optional subtle tint over the material; kept low-range by the editor's
    /// slider so it can't compromise the native frosted-glass look.
    var backgroundMaterialTintColor: CodableColor
    var backgroundMaterialTintOpacity: Double

    init(
        fillColor: CodableColor,
        fillOpacity: Double,
        borderColor: CodableColor,
        borderOpacity: Double,
        borderWidth: Double,
        cornerRadius: Double,
        cellPadding: Double,
        textColor: CodableColor,
        textOpacity: Double,
        textSize: Double,
        fontName: String,
        selectionFillOpacity: Double,
        selectionBorderColor: CodableColor,
        backgroundStyle: BackgroundStyle = .transparent,
        backgroundColor: CodableColor = .darkFill,
        backgroundOpacity: Double = 0.4,
        backgroundMaterial: BackgroundMaterial = .hudWindow,
        backgroundMaterialTintColor: CodableColor = .darkFill,
        backgroundMaterialTintOpacity: Double = 0.0
    ) {
        self.fillColor = fillColor
        self.fillOpacity = fillOpacity
        self.borderColor = borderColor
        self.borderOpacity = borderOpacity
        self.borderWidth = borderWidth
        self.cornerRadius = cornerRadius
        self.cellPadding = cellPadding
        self.textColor = textColor
        self.textOpacity = textOpacity
        self.textSize = textSize
        self.fontName = fontName
        self.selectionFillOpacity = selectionFillOpacity
        self.selectionBorderColor = selectionBorderColor
        self.backgroundStyle = backgroundStyle
        self.backgroundColor = backgroundColor
        self.backgroundOpacity = backgroundOpacity
        self.backgroundMaterial = backgroundMaterial
        self.backgroundMaterialTintColor = backgroundMaterialTintColor
        self.backgroundMaterialTintOpacity = backgroundMaterialTintOpacity
    }

    /// Custom decoding so configuration files saved before the background
    /// style feature existed still load cleanly: the new fields simply fall
    /// back to their defaults (`.transparent`, i.e. today's behavior — an
    /// upgraded user's saved layouts don't change appearance) instead of
    /// failing to decode and losing the user's whole configuration (see
    /// `ConfigurationStore.load()`, which resets to defaults on any decode
    /// error).
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fillColor = try container.decode(CodableColor.self, forKey: .fillColor)
        fillOpacity = try container.decode(Double.self, forKey: .fillOpacity)
        borderColor = try container.decode(CodableColor.self, forKey: .borderColor)
        borderOpacity = try container.decode(Double.self, forKey: .borderOpacity)
        borderWidth = try container.decode(Double.self, forKey: .borderWidth)
        cornerRadius = try container.decode(Double.self, forKey: .cornerRadius)
        cellPadding = try container.decode(Double.self, forKey: .cellPadding)
        textColor = try container.decode(CodableColor.self, forKey: .textColor)
        textOpacity = try container.decode(Double.self, forKey: .textOpacity)
        textSize = try container.decode(Double.self, forKey: .textSize)
        fontName = try container.decode(String.self, forKey: .fontName)
        selectionFillOpacity = try container.decode(Double.self, forKey: .selectionFillOpacity)
        selectionBorderColor = try container.decode(CodableColor.self, forKey: .selectionBorderColor)

        let fallback = GridAppearance.defaultAppearance
        backgroundStyle = try container.decodeIfPresent(BackgroundStyle.self, forKey: .backgroundStyle) ?? .transparent
        backgroundColor = try container.decodeIfPresent(CodableColor.self, forKey: .backgroundColor) ?? fallback.backgroundColor
        backgroundOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundOpacity) ?? fallback.backgroundOpacity
        backgroundMaterial = try container.decodeIfPresent(BackgroundMaterial.self, forKey: .backgroundMaterial) ?? fallback.backgroundMaterial
        backgroundMaterialTintColor = try container.decodeIfPresent(CodableColor.self, forKey: .backgroundMaterialTintColor) ?? fallback.backgroundMaterialTintColor
        backgroundMaterialTintOpacity = try container.decodeIfPresent(Double.self, forKey: .backgroundMaterialTintOpacity) ?? fallback.backgroundMaterialTintOpacity
    }

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
            selectionBorderColor: CodableColor(red: 0.3, green: 0.65, blue: 1.0),
            backgroundStyle: .transparent,
            backgroundColor: .darkFill,
            backgroundOpacity: 0.4,
            backgroundMaterial: .hudWindow,
            backgroundMaterialTintColor: .darkFill,
            backgroundMaterialTintOpacity: 0.0
        )
    }

    var font: NSFont {
        NSFont(name: fontName, size: CGFloat(textSize))
            ?? NSFont.systemFont(ofSize: CGFloat(textSize), weight: .semibold)
    }
}
