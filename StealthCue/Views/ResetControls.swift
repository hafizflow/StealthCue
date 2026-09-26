import SwiftUI

/// A small "reset to default" icon. It is always laid out (so rows don't shift when it appears) but
/// only visible — and only clickable — while the value differs from its default.
struct ResetSlot: View {
    let isModified: Bool
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isModified ? 1 : 0)
        .allowsHitTesting(isModified)
        .accessibilityHidden(!isModified)
        .accessibilityLabel("Reset to default")
        .help(help)
        .animation(.easeInOut(duration: 0.18), value: isModified)
    }
}
