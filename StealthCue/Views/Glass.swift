import SwiftUI

// MARK: - Liquid Glass helpers
//
// Liquid Glass (macOS 26+) is for the *control layer* that floats above content: toolbars, docks,
// transport buttons. Content (the script text, the script list) stays plain so it remains readable.
// On macOS 14–25 every helper falls back to a material, so the app looks native everywhere.

extension View {
    /// A floating glass surface (Liquid Glass on macOS 26+, thin material before).
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = 24) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.14), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
    }

    /// Glass button style; `prominent` is the tinted, primary variant.
    @ViewBuilder
    func glassButtonStyle(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) } else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) } else { self.buttonStyle(.bordered) }
        }
    }
}

/// Lets neighbouring glass shapes blend and morph together on macOS 26+.
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

// MARK: - Reusable controls

/// A labelled slider with an icon and a live value — used in the dock and in Settings.
struct GlassSliderRow: View {
    let title: String
    let systemImage: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    let format: (Double) -> String

    private var snapped: Binding<Double> {
        Binding(
            get: { value },
            set: { newValue in
                guard let step else { value = newValue; return }
                let snappedValue = (newValue / step).rounded() * step
                value = min(max((snappedValue * 1000).rounded() / 1000, range.lowerBound), range.upperBound)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
                Text(title).font(.callout.weight(.medium))
                Spacer(minLength: 4)
                Text(format(value))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            // A stepped `Slider(step:)` draws tick marks. Use a smooth slider and snap the value
            // ourselves, so the values are identical but the track stays clean.
            Slider(value: snapped, in: range)
                .tint(.primary.opacity(0.55))   // neutral: keep the accent colour for the one primary action
        }
        .accessibilityElement(children: .combine)
    }
}

/// An on/off option styled exactly like the editor's Save / Clear / Preview buttons (glass, icon +
/// label). "On" is a neutral gray fill rather than the accent colour, so the one primary action
/// (Start) stays the only blue thing. Same binding as a checkbox.
struct GlassChipToggle: View {
    let title: String
    let systemImage: String
    @Binding var isOn: Bool
    var help: String = ""

    var body: some View {
        Button { isOn.toggle() } label: {
            Label(title, systemImage: systemImage)
        }
        .glassButtonStyle(prominent: isOn)
        .tint(isOn ? Color.gray : nil)
        .controlSize(.regular)
        .labelStyle(.titleAndIcon)
        .help(help.isEmpty ? title : help)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}
