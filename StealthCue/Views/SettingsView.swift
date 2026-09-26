import SwiftUI

/// Settings, organised into tabs with a live preview of the current text style on top.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    private enum Tab: Hashable { case window, text, appearance, shortcuts, stealth }
    @State private var tab: Tab = .window

    var body: some View {
        @Bindable var model = appState.teleprompter

        VStack(spacing: 0) {
            // The live preview only matters where you're styling text.
            if tab == .text || tab == .appearance {
                StylePreviewCard(settings: model.settings)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .transition(.opacity)
            }

            TabView(selection: $tab) {
                windowTab($model.settings)
                    .tabItem { Label("Window", systemImage: "macwindow") }
                    .tag(Tab.window)
                textTab($model.settings)
                    .tabItem { Label("Text", systemImage: "textformat") }
                    .tag(Tab.text)
                appearanceTab($model.settings)
                    .tabItem { Label("Appearance", systemImage: "paintpalette") }
                    .tag(Tab.appearance)
                shortcutsTab
                    .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                    .tag(Tab.shortcuts)
                stealthTab($model.settings)
                    .tabItem { Label("Stealth", systemImage: "eye.slash") }
                    .tag(Tab.stealth)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: tab)
        .frame(width: 560, height: 640)
    }

    // MARK: Tabs

    private func windowTab(_ s: Binding<TeleprompterSettings>) -> some View {
        Form {
            Section("Behaviour") {
                Toggle(isOn: s.alwaysOnTop) { Label("Always on top", systemImage: "pin") }
                Toggle(isOn: s.clickThrough) {
                    Label("Click-through", systemImage: "cursorarrow.click")
                    Text("Mouse clicks pass through the overlay to the app underneath.")
                }
                Toggle(isOn: s.stealthMode) {
                    Label("Stealth mode", systemImage: "eye.slash")
                    Text("Ask macOS to exclude the overlay from screen capture.")
                }
                Toggle(isOn: s.lockPosition) { Label("Lock position", systemImage: "lock") }
            }
            Section("Size") {
                GlassSliderRow(title: "Width", systemImage: "arrow.left.and.right",
                               value: s.windowWidth, range: TeleprompterSettings.windowWidthRange, step: 10) { "\(Int($0))" }
                GlassSliderRow(title: "Height", systemImage: "arrow.up.and.down",
                               value: s.windowHeight, range: TeleprompterSettings.windowHeightRange, step: 10) { "\(Int($0))" }
            }
        }
        .formStyle(.grouped)
    }

    private func textTab(_ s: Binding<TeleprompterSettings>) -> some View {
        Form {
            Section("Font") {
                Picker("Family", selection: s.fontFamily) {
                    ForEach(FontFamilyOption.allCases) { Text($0.label).tag($0) }
                }
                Picker("Weight", selection: s.fontWeight) {
                    ForEach(FontWeightOption.allCases) { Text($0.label).tag($0) }
                }
                GlassSliderRow(title: "Size", systemImage: "textformat.size",
                               value: s.fontSize, range: TeleprompterSettings.fontSizeRange, step: 1) { "\(Int($0)) px" }
            }
            Section("Layout") {
                GlassSliderRow(title: "Line spacing", systemImage: "arrow.up.and.down.text.horizontal",
                               value: s.lineSpacing, range: TeleprompterSettings.lineSpacingRange, step: 1) { "\(Int($0))" }
                Picker("Alignment", selection: s.textAlignment) {
                    ForEach(TextAlignmentOption.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            Section("Scrolling") {
                GlassSliderRow(title: "Speed", systemImage: "gauge.with.needle",
                               value: s.wordsPerMinute, range: TeleprompterSettings.wordsPerMinuteRange, step: 5) { "\(Int($0)) wpm" }
            }
        }
        .formStyle(.grouped)
    }

    private func appearanceTab(_ s: Binding<TeleprompterSettings>) -> some View {
        Form {
            Section("Colors") {
                ColorPicker("Text color", selection: color(\.textColor, in: s), supportsOpacity: false)
                ColorPicker("Background color", selection: color(\.backgroundColor, in: s), supportsOpacity: false)
            }
            Section("Transparency") {
                GlassSliderRow(title: "Text opacity", systemImage: "textformat",
                               value: s.textOpacity, range: 0.1...1) { "\(Int(($0 * 100).rounded()))%" }
                GlassSliderRow(title: "Background opacity", systemImage: "circle.lefthalf.filled",
                               value: s.backgroundOpacity, range: 0.1...1) { "\(Int(($0 * 100).rounded()))%" }
            }
            Section("Reading aids") {
                Toggle(isOn: s.showScrollIndicator) {
                    Label("Show scroll indicator", systemImage: "scroll")
                    Text("A slim position bar that appears while the script moves.")
                }
            }
        }
        .formStyle(.grouped)
    }

    private var shortcutsTab: some View {
        Form {
            Section {
                ShortcutRow("Start / pause auto-scroll", keys: ["Space"])
                ShortcutRow("Scroll up / down one line", keys: ["↑"], alsoKeys: ["↓"])
                ShortcutRow("Faster / slower auto-scroll", keys: ["⌥", "↑"], alsoKeys: ["⌥", "↓"])
                ShortcutRow("Bigger / smaller text", keys: ["⌘", "+"], alsoKeys: ["⌘", "−"])
                ShortcutRow("Back to the start", keys: ["R"])
                ShortcutRow("Hide the overlay", keys: ["Esc"])
            } header: {
                Text("On the teleprompter overlay")
            } footer: {
                Text("Click the overlay once first. Clicking it doesn't take focus away from the app you're recording, but it lets the overlay receive these keys.")
            }

            Section("In the app") {
                ShortcutRow("New script", keys: ["⌘", "N"])
                ShortcutRow("Save script", keys: ["⌘", "S"])
                ShortcutRow("Show / hide teleprompter", keys: ["⇧", "⌘", "T"])
                ShortcutRow("Start / pause", keys: ["⌘", "↩"])
                ShortcutRow("Reset", keys: ["⌘", "R"])
                ShortcutRow("Faster / slower", keys: ["⌃", "⌘", "↑"], alsoKeys: ["⌃", "⌘", "↓"])
                ShortcutRow("Bigger / smaller text", keys: ["⌘", "="], alsoKeys: ["⌘", "−"])
                ShortcutRow("Toggle stealth mode", keys: ["⌥", "⌘", "S"])
                ShortcutRow("Settings", keys: ["⌘", ","])
            }
        }
        .formStyle(.grouped)
    }

    private func stealthTab(_ s: Binding<TeleprompterSettings>) -> some View {
        Form {
            Section {
                Toggle(isOn: s.stealthMode) { Label("Stealth mode", systemImage: "eye.slash") }
            }
            Section("How it works") {
                Text("Stealth mode sets NSWindow.sharingType = .none, a public AppKit API that asks macOS not to share this window's contents with other processes. You still see the overlay; capture clients that honor the flag do not.")
                    .font(.callout)
            }
            Section("Limits — please read") {
                Label {
                    Text("It is best-effort, not a guarantee. Support depends on the macOS version and on how the recorder captures the screen (older CoreGraphics capture vs. ScreenCaptureKit).")
                } icon: { Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange) }
                    .font(.callout)
                Label {
                    Text("It cannot hide the overlay from a camera pointed at your screen or a hardware capture device.")
                } icon: { Image(systemName: "video.slash").foregroundStyle(.secondary) }
                    .font(.callout)
                Label {
                    Text("Always run a test recording with the exact app you plan to use.")
                } icon: { Image(systemName: "checkmark.circle").foregroundStyle(.green) }
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
    }

    private func color(_ keyPath: WritableKeyPath<TeleprompterSettings, RGBAColor>,
                       in settings: Binding<TeleprompterSettings>) -> Binding<Color> {
        Binding(
            get: { settings.wrappedValue[keyPath: keyPath].color },
            set: { settings.wrappedValue[keyPath: keyPath] = RGBAColor($0) }
        )
    }
}

/// A miniature of the overlay using the current font, colours, opacity and alignment.
private struct StylePreviewCard: View {
    let settings: TeleprompterSettings

    var body: some View {
        let alignment: Alignment = switch settings.textAlignment {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }
        let multiline: TextAlignment = switch settings.textAlignment {
        case .left: .leading
        case .center: .center
        case .right: .trailing
        }

        ZStack {
            // A checkerboard-ish backdrop so background opacity is visible.
            LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
            settings.backgroundColor.color.opacity(settings.backgroundOpacity)
            Text("The quick brown fox jumps over the lazy dog.")
                .font(Font(settings.nsFont.withSize(min(settings.fontSize, 30))))
                .foregroundStyle(settings.textColor.color.opacity(settings.textOpacity))
                .multilineTextAlignment(multiline)
                .lineSpacing(settings.lineSpacing * min(1, 30 / settings.fontSize))
                .minimumScaleFactor(0.4)
                .padding(.horizontal, 18)
                .frame(maxWidth: .infinity, alignment: alignment)
        }
        .frame(height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.18)))
        .accessibilityLabel("Style preview")
    }
}


/// One row of the shortcut guide: a description on the left, key caps on the right.
/// `alsoKeys` shows a second combination (for paired actions such as up/down).
private struct ShortcutRow: View {
    let title: String
    let keys: [String]
    var alsoKeys: [String]? = nil

    init(_ title: String, keys: [String], alsoKeys: [String]? = nil) {
        self.title = title
        self.keys = keys
        self.alsoKeys = alsoKeys
    }

    var body: some View {
        LabeledContent(title) {
            HStack(spacing: 10) {
                KeyCombo(keys: keys)
                if let alsoKeys {
                    Text("/").foregroundStyle(.tertiary)
                    KeyCombo(keys: alsoKeys)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct KeyCombo: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(.callout, design: .rounded).weight(.medium))
                    .frame(minWidth: 22)
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(.primary.opacity(0.12)))
            }
        }
    }
}
