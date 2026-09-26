import SwiftUI

/// The floating glass control dock: everything you need while prompting, in one place.
///
///     [ Show Prompt ]                              [ Reset ] [ ▶︎ ]
///     Font size ───●───   Speed ───●───   Opacity ───●───
///     [ Always on top ] [ Click-through ] [ Stealth ] [ Lock position ]
struct TeleprompterControlsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var model = appState.teleprompter

        GlassGroup(spacing: 14) {
            VStack(spacing: 16) {
                transportRow(model)

                HStack(alignment: .top, spacing: 26) {
                    GlassSliderRow(title: "Font size", systemImage: "textformat.size",
                                   value: $model.settings.fontSize,
                                   range: TeleprompterSettings.fontSizeRange, step: 1) { "\(Int($0))" }
                    GlassSliderRow(title: "Speed", systemImage: "gauge.with.needle",
                                   value: $model.settings.speed,
                                   range: TeleprompterSettings.speedRange, step: 0.1) { String(format: "%.1f", $0) }
                    GlassSliderRow(title: "Opacity", systemImage: "circle.lefthalf.filled",
                                   value: $model.settings.backgroundOpacity,
                                   range: 0.1...1) { "\(Int(($0 * 100).rounded()))%" }
                }

                HStack(spacing: 10) {
                    GlassChipToggle(title: "Always on top", systemImage: "pin",
                                    isOn: $model.settings.alwaysOnTop,
                                    help: "Keep the overlay above other windows")
                    GlassChipToggle(title: "Click-through", systemImage: "cursorarrow.click",
                                    isOn: $model.settings.clickThrough,
                                    help: "Let mouse clicks pass through the overlay")
                    GlassChipToggle(title: "Stealth", systemImage: "eye.slash",
                                    isOn: $model.settings.stealthMode,
                                    help: "Ask macOS to exclude the overlay from screen capture")
                    GlassChipToggle(title: "Lock position", systemImage: "lock",
                                    isOn: $model.settings.lockPosition,
                                    help: "Prevent the overlay from being moved")
                }

                // Always laid out (just invisible when stealth is off) so toggling never shifts the dock.
                Label("Stealth asks macOS to exclude the overlay from screen capture. It's recorder-dependent — test yours (see Settings ▸ Stealth).",
                      systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(model.settings.stealthMode ? 1 : 0)
                    .accessibilityHidden(!model.settings.stealthMode)
                    .animation(.easeInOut(duration: 0.2), value: model.settings.stealthMode)
            }
            .padding(18)
            .glassSurface(cornerRadius: 28)
        }
    }

    /// Show/hide on the left; reset + one big play/pause on the right.
    private func transportRow(_ model: TeleprompterViewModel) -> some View {
        HStack {
            Button { appState.toggleTeleprompter() } label: {
                Label(model.isWindowVisible ? "Hide Prompt" : "Show Prompt",
                      systemImage: model.isWindowVisible ? "rectangle.slash" : "text.viewfinder")
                    .font(.body.weight(.medium))
            }
            .glassButtonStyle(prominent: !model.isWindowVisible)
            .controlSize(.large)
            .help("Show or hide the floating teleprompter")

            Spacer()

            Button { model.reset() } label: {
                Label("Reset", systemImage: "backward.end.fill")
            }
            .glassButtonStyle()
            .controlSize(.large)
            .help("Jump back to the start of the script (R)")

            Button {
                model.isPlaying ? model.pause() : appState.start()
            } label: {
                Label(model.isPlaying ? "Pause" : "Start",
                      systemImage: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.body.weight(.semibold))
                    .frame(minWidth: 72)
            }
            .glassButtonStyle(prominent: true)
            .controlSize(.large)
            .help(model.isPlaying ? "Pause auto-scroll (Space)" : "Start auto-scroll (Space)")
        }
    }
}
