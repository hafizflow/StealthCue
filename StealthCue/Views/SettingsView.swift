import SwiftUI

/// Settings, organised into tabs with a live preview of the current text style on top.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    private enum Tab: Hashable { case window, text, appearance, shortcuts, stealth }
    @State private var tab: Tab = .window
    @State private var confirmingResetAll = false

    /// Factory defaults: a fresh `TeleprompterSettings()`. Every reset goes back to these.
    private static let defaults = TeleprompterSettings()

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

            resetAllBar(model.settings == Self.defaults) { model.settings = Self.defaults }
        }
        .animation(.easeInOut(duration: 0.15), value: tab)
        .frame(width: 560, height: 690)
        .background(Theme.background)
        .solidToolbar(Theme.bar)   // same colour as the home window's top bar
        .overlay(alignment: .top) { Theme.barBorder.frame(height: 1) }   // ...and the same border under it
        .themedWindow()   // dark appearance only; colours are the system's standard grouped-form colours
    }

    // MARK: Resetting

    /// A labelled row whose control has a reset-to-default icon on its left (next to the current
    /// value), shown only while the value differs from its default. Not used for on/off toggles: with
    /// only two values there's nothing worth resetting.
    private func labeledResettable<V: Equatable, C: View>(
        _ title: String,
        _ keyPath: WritableKeyPath<TeleprompterSettings, V>,
        _ s: Binding<TeleprompterSettings>,
        _ describe: @escaping (V) -> String,
        @ViewBuilder control: () -> C
    ) -> some View {
        let defaultValue = Self.defaults[keyPath: keyPath]
        return LabeledContent(title) {
            HStack(spacing: 8) {
                ResetSlot(isModified: s.wrappedValue[keyPath: keyPath] != defaultValue,
                          help: "Reset to default (\(describe(defaultValue)))") {
                    withAnimation(.smooth(duration: 0.25)) { s.wrappedValue[keyPath: keyPath] = defaultValue }
                }
                control()
            }
        }
    }

    private static func hex(_ color: RGBAColor) -> String {
        String(format: "#%02X%02X%02X", Int((color.red * 255).rounded()), Int((color.green * 255).rounded()), Int((color.blue * 255).rounded()))
    }

    /// The universal reset, always at the bottom of the window (disabled when nothing has changed).
    private func resetAllBar(_ isAllDefault: Bool, reset: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Theme.barBorder.frame(height: 1)
            HStack {
                Text(isAllDefault ? "All settings are at their defaults." : "Some settings differ from their defaults.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    confirmingResetAll = true
                } label: {
                    Label("Reset All to Defaults", systemImage: "arrow.counterclockwise")
                }
                .glassButtonStyle()
                .controlSize(.regular)
                .disabled(isAllDefault)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Theme.background)
        .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmingResetAll) {
            Button("Reset All", role: .destructive) {
                withAnimation(.smooth(duration: 0.3)) { reset() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Font, colours, speed, window behaviour and stealth mode all go back to how they were when you first installed the app. Your scripts aren't affected.")
        }
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
                               value: s.windowWidth, range: TeleprompterSettings.windowWidthRange, step: 10,
                               defaultValue: Self.defaults.windowWidth) { "\(Int($0))" }
                GlassSliderRow(title: "Height", systemImage: "arrow.up.and.down",
                               value: s.windowHeight, range: TeleprompterSettings.windowHeightRange, step: 10,
                               defaultValue: Self.defaults.windowHeight) { "\(Int($0))" }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)   // page colour is set explicitly below
        .background(Theme.background)
    }

    private func textTab(_ s: Binding<TeleprompterSettings>) -> some View {
        Form {
            Section("Font") {
                labeledResettable("Family", \.fontFamily, s, { $0.label }) {
                    Picker("Family", selection: s.fontFamily) {
                        ForEach(FontFamilyOption.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                }
                labeledResettable("Weight", \.fontWeight, s, { $0.label }) {
                    Picker("Weight", selection: s.fontWeight) {
                        ForEach(FontWeightOption.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                }
                GlassSliderRow(title: "Size", systemImage: "textformat.size",
                               value: s.fontSize, range: TeleprompterSettings.fontSizeRange, step: 1,
                               defaultValue: Self.defaults.fontSize) { "\(Int($0)) px" }
            }
            Section("Layout") {
                GlassSliderRow(title: "Line spacing", systemImage: "arrow.up.and.down.text.horizontal",
                               value: s.lineSpacing, range: TeleprompterSettings.lineSpacingRange, step: 1,
                               defaultValue: Self.defaults.lineSpacing) { "\(Int($0))" }
                labeledResettable("Alignment", \.textAlignment, s, { $0.label }) {
                    Picker("Alignment", selection: s.textAlignment) {
                        ForEach(TextAlignmentOption.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                }
            }
            Section("Scrolling") {
                GlassSliderRow(title: "Speed", systemImage: "gauge.with.needle",
                               value: s.wordsPerMinute, range: TeleprompterSettings.wordsPerMinuteRange, step: 5,
                               defaultValue: Self.defaults.wordsPerMinute) { "\(Int($0)) wpm" }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)   // page colour is set explicitly below
        .background(Theme.background)
    }

    private func appearanceTab(_ s: Binding<TeleprompterSettings>) -> some View {
        Form {
            Section("Colors") {
                labeledResettable("Text color", \.textColor, s, Self.hex) {
                    ColorPicker("Text color", selection: color(\.textColor, in: s), supportsOpacity: false)
                        .labelsHidden()
                }
                labeledResettable("Background color", \.backgroundColor, s, Self.hex) {
                    ColorPicker("Background color", selection: color(\.backgroundColor, in: s), supportsOpacity: false)
                        .labelsHidden()
                }
            }
            Section("Transparency") {
                GlassSliderRow(title: "Text opacity", systemImage: "textformat",
                               value: s.textOpacity, range: 0.1...1,
                               defaultValue: Self.defaults.textOpacity) { "\(Int(($0 * 100).rounded()))%" }
                GlassSliderRow(title: "Background opacity", systemImage: "circle.lefthalf.filled",
                               value: s.backgroundOpacity, range: 0.1...1,
                               defaultValue: Self.defaults.backgroundOpacity) { "\(Int(($0 * 100).rounded()))%" }
            }
            Section("Reading aids") {
                Toggle(isOn: s.showScrollIndicator) {
                    Label("Show scroll indicator", systemImage: "scroll")
                    Text("A slim position bar that appears while the script moves.")
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)   // page colour is set explicitly below
        .background(Theme.background)
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
                ShortcutRow("Save now (edits also autosave)", keys: ["⌘", "S"])
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
        .scrollContentBackground(.hidden)   // page colour is set explicitly below
        .background(Theme.background)
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
                } icon: { Image(systemName: "exclamationmark.triangle").foregroundStyle(Theme.secondaryText) }
                    .font(.callout)
                Label {
                    Text("It cannot hide the overlay from a camera pointed at your screen or a hardware capture device.")
                } icon: { Image(systemName: "video.slash").foregroundStyle(.secondary) }
                    .font(.callout)
                Label {
                    Text("Always run a test recording with the exact app you plan to use.")
                } icon: { Image(systemName: "checkmark.circle").foregroundStyle(.white) }
                    .font(.callout)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)   // page colour is set explicitly below
        .background(Theme.background)
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

    /// Font sizes the preview shows at true size.
    private static let previewRange: ClosedRange<Double> = 16...60
    private var previewSize: Double { min(max(settings.fontSize, Self.previewRange.lowerBound), Self.previewRange.upperBound) }

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

        Text("From the river to the sea, Palestine will be free")
            // True size for 16–60 px; the card grows to fit (never below its minimum height). Above 60 px
            // it stays at 60 px and says so, rather than shrinking the text unpredictably.
            .font(Font(settings.nsFont.withSize(previewSize)))
            .foregroundStyle(settings.textColor.color.opacity(settings.textOpacity))
            .multilineTextAlignment(multiline)
            .lineSpacing(settings.lineSpacing * (previewSize / settings.fontSize))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: alignment)
            .frame(minHeight: 104)   // the height the preview always had; it only grows from here
            // Backgrounds sit *behind* the text so the card's height is set by the text, not by them.
            .background {
                ZStack {
                    // A backdrop so background opacity is visible.
                    LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    settings.backgroundColor.color.opacity(settings.backgroundOpacity)
                }
            }
        .overlay(alignment: .bottomTrailing) {
            if settings.fontSize > Self.previewRange.upperBound {
                Text("Preview shows up to \(Int(Self.previewRange.upperBound)) px")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.black.opacity(0.45), in: Capsule())
                    .padding(8)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.18)))
        .animation(.smooth(duration: 0.2), value: previewSize)
        .animation(.smooth(duration: 0.2), value: settings.lineSpacing)
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
