import SwiftUI
import AppKit

/// Editor for every appearance property listed in §14, with a small live
/// preview cell so changes are visible without activating the real overlay.
struct AppearanceEditorView: View {
    @Binding var appearance: GridAppearance

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    section("Fill") {
                        ColorPicker("Color", selection: colorBinding(\.fillColor))
                        opacitySlider("Opacity", $appearance.fillOpacity)
                    }
                    section("Border") {
                        ColorPicker("Color", selection: colorBinding(\.borderColor))
                        opacitySlider("Opacity", $appearance.borderOpacity)
                        numberField("Width", $appearance.borderWidth, range: 0...6)
                    }
                    section("Geometry") {
                        numberField("Corner Radius", $appearance.cornerRadius, range: 0...30)
                        numberField("Cell Padding", $appearance.cellPadding, range: 0...30)
                    }
                    section("Text") {
                        ColorPicker("Color", selection: colorBinding(\.textColor))
                        opacitySlider("Opacity", $appearance.textOpacity)
                        numberField("Size", $appearance.textSize, range: 8...48)
                        TextField("Font", text: $appearance.fontName)
                            .textFieldStyle(.roundedBorder)
                    }
                    section("Background Style") {
                        backgroundStylePicker
                        backgroundStyleControls
                    }
                }
                .frame(width: 260)

                VStack {
                    Text("Preview").font(.caption).foregroundStyle(.secondary)
                    previewCell
                        .frame(width: 160, height: 110)
                    Spacer()
                }
            }
        }
    }

    private var previewCell: some View {
        ZStack {
            // A faint checkerboard-ish backdrop stands in for "whatever is
            // behind the overlay" so Transparent/macOS Material previews
            // read clearly even inside the opaque Settings window.
            Color.black.opacity(0.15)
            GridBackgroundView(appearance: appearance)
            RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                .fill(Color(appearance.fillColor.nsColor).opacity(appearance.fillOpacity))
                .overlay(
                    RoundedRectangle(cornerRadius: appearance.cornerRadius, style: .continuous)
                        .stroke(Color(appearance.borderColor.nsColor), lineWidth: appearance.borderWidth)
                        .opacity(appearance.borderOpacity)
                )
                .overlay(
                    Text("A")
                        .font(Font(appearance.font))
                        .foregroundColor(Color(appearance.textColor.nsColor).opacity(appearance.textOpacity))
                )
                .padding(appearance.cellPadding)
        }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var backgroundStylePicker: some View {
        Picker("", selection: $appearance.backgroundStyle) {
            ForEach(BackgroundStyle.allCases) { style in
                Text(style.displayName).tag(style)
            }
        }
        .pickerStyle(.radioGroup)
        .labelsHidden()
    }

    @ViewBuilder
    private var backgroundStyleControls: some View {
        switch appearance.backgroundStyle {
        case .transparent:
            EmptyView()

        case .solidColor:
            ColorPicker("Color", selection: colorBinding(\.backgroundColor))
            opacitySlider("Opacity", $appearance.backgroundOpacity)

        case .macOSMaterial:
            Picker("Material", selection: $appearance.backgroundMaterial) {
                ForEach(BackgroundMaterial.allCases) { material in
                    Text(material.displayName).tag(material)
                }
            }
            .pickerStyle(.menu)
            ColorPicker("Tint", selection: colorBinding(\.backgroundMaterialTintColor))
            // Capped well below 1.0 — this is meant as a subtle wash over the
            // native material, not a replacement for it.
            opacitySlider("Tint Amount", $appearance.backgroundMaterialTintOpacity, range: 0...0.5)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline).bold()
            content()
        }
        .padding(.bottom, 6)
    }

    private func opacitySlider(_ title: String, _ value: Binding<Double>, range: ClosedRange<Double> = 0...1) -> some View {
        HStack {
            Text(title).frame(width: 80, alignment: .leading)
            Slider(value: value, in: range)
            Text("\(Int(value.wrappedValue * 100))%").frame(width: 40, alignment: .trailing).font(.caption)
        }
    }

    private func numberField(_ title: String, _ value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Text(title).frame(width: 90, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: "%.0f", value.wrappedValue)).frame(width: 30, alignment: .trailing).font(.caption)
        }
    }

    private func colorBinding(_ keyPath: WritableKeyPath<GridAppearance, CodableColor>) -> Binding<Color> {
        Binding(
            get: { Color(appearance[keyPath: keyPath].nsColor) },
            set: { appearance[keyPath: keyPath] = CodableColor(nsColor: NSColor($0)) }
        )
    }
}
