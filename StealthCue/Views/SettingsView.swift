import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var model = appState.teleprompter

        Form {
            Section("Window") {
                Toggle("Always on top", isOn: $model.settings.alwaysOnTop)
                Toggle("Click-through (mouse passes through the overlay)", isOn: $model.settings.clickThrough)
                Toggle("Stealth mode (exclude from screen capture)", isOn: $model.settings.stealthMode)
                Toggle("Lock position", isOn: $model.settings.lockPosition)
                LabeledContent("Width") {
                    Slider(value: $model.settings.windowWidth, in: TeleprompterSettings.windowWidthRange, step: 10)
                    Text("\(Int(model.settings.windowWidth))").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                LabeledContent("Height") {
                    Slider(value: $model.settings.windowHeight, in: TeleprompterSettings.windowHeightRange, step: 10)
                    Text("\(Int(model.settings.windowHeight))").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }

            Section("Text") {
                Picker("Font", selection: $model.settings.fontFamily) {
                    ForEach(FontFamilyOption.allCases) { Text($0.label).tag($0) }
                }
                Picker("Weight", selection: $model.settings.fontWeight) {
                    ForEach(FontWeightOption.allCases) { Text($0.label).tag($0) }
                }
                LabeledContent("Size") {
                    Slider(value: $model.settings.fontSize, in: TeleprompterSettings.fontSizeRange, step: 1)
                    Text("\(Int(model.settings.fontSize))").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                LabeledContent("Line spacing") {
                    Slider(value: $model.settings.lineSpacing, in: TeleprompterSettings.lineSpacingRange, step: 1)
                    Text("\(Int(model.settings.lineSpacing))").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                Picker("Alignment", selection: $model.settings.textAlignment) {
                    ForEach(TextAlignmentOption.allCases) { Label($0.label, systemImage: $0.symbol).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Appearance") {
                ColorPicker("Text color", selection: color(\.textColor, in: $model.settings), supportsOpacity: false)
                ColorPicker("Background color", selection: color(\.backgroundColor, in: $model.settings), supportsOpacity: false)
                LabeledContent("Text opacity") {
                    Slider(value: $model.settings.textOpacity, in: 0.1...1)
                    Text(model.settings.textOpacity, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                LabeledContent("Background opacity") {
                    Slider(value: $model.settings.backgroundOpacity, in: 0.1...1)
                    Text(model.settings.backgroundOpacity, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }

            Section("Scrolling") {
                LabeledContent("Speed") {
                    Slider(value: $model.settings.speed, in: TeleprompterSettings.speedRange, step: 0.1)
                    Text(model.settings.speed, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }

            Section("About Stealth mode") {
                Text("""
                Stealth mode sets NSWindow.sharingType = .none, a public AppKit API that asks macOS not to \
                share this window's contents with other processes. You still see the overlay; capture \
                clients that honor the flag do not.

                It is best-effort, not a guarantee. Support depends on the macOS version and on how the \
                recorder captures the screen (older CoreGraphics capture vs. ScreenCaptureKit), and it \
                cannot hide the overlay from a camera pointed at your screen or a hardware capture device. \
                Always run a test recording with the exact app you plan to use.
                """)
                .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 720)
    }

    private func color(_ keyPath: WritableKeyPath<TeleprompterSettings, RGBAColor>,
                       in settings: Binding<TeleprompterSettings>) -> Binding<Color> {
        Binding(
            get: { settings.wrappedValue[keyPath: keyPath].color },
            set: { settings.wrappedValue[keyPath: keyPath] = RGBAColor($0) }
        )
    }
}
