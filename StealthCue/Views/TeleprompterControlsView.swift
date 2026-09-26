import SwiftUI

/// The quick controls strip at the bottom of the main window.
struct TeleprompterControlsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var model = appState.teleprompter

        VStack(alignment: .leading, spacing: 12) {
            Text("Teleprompter").font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Font Size")
                    Slider(value: $model.settings.fontSize, in: TeleprompterSettings.fontSizeRange, step: 1)
                    Text("\(Int(model.settings.fontSize))").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                GridRow {
                    Text("Speed")
                    Slider(value: $model.settings.speed, in: TeleprompterSettings.speedRange, step: 0.1)
                    Text(model.settings.speed, format: .number.precision(.fractionLength(1)))
                        .monospacedDigit().frame(width: 44, alignment: .trailing)
                }
                GridRow {
                    Text("Opacity")
                    Slider(value: $model.settings.backgroundOpacity, in: 0.1...1)
                    Text(model.settings.backgroundOpacity, format: .percent.precision(.fractionLength(0)))
                        .monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }

            HStack {
                Button { appState.start() } label: { Label("Start", systemImage: "play.fill") }
                    .disabled(model.isPlaying)
                Button { model.pause() } label: { Label("Pause", systemImage: "pause.fill") }
                    .disabled(!model.isPlaying)
                Button { model.reset() } label: { Label("Reset", systemImage: "backward.end.fill") }
            }

            HStack(spacing: 20) {
                Toggle("Always on top", isOn: $model.settings.alwaysOnTop)
                Toggle("Click-through", isOn: $model.settings.clickThrough)
                Toggle("Stealth mode", isOn: $model.settings.stealthMode)
                Toggle("Lock position", isOn: $model.settings.lockPosition)
            }
            .toggleStyle(.checkbox)

            if model.settings.stealthMode {
                Label("Requests exclusion from screen capture. Recorder-dependent — test yours (see Settings).",
                      systemImage: "info.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
