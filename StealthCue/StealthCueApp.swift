import SwiftUI

@main
struct StealthCueApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        Window("StealthCue", id: "main") {
            ContentView()
                .environment(appState)
        }
        .defaultSize(width: 940, height: 680)
        .commands { StealthCueCommands(appState: appState) }

        MenuBarExtra("StealthCue", systemImage: "text.viewfinder") {
            MenuBarContent()
                .environment(appState)
        }

        Settings {
            SettingsView()
                .environment(appState)
        }
    }
}

/// Menu-bar dropdown.
private struct MenuBarContent: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        @Bindable var model = appState.teleprompter

        Button("Show Editor") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        Button(model.isWindowVisible ? "Hide Teleprompter" : "Show Teleprompter") {
            appState.toggleTeleprompter()
        }
        Divider()
        Button(model.isPlaying ? "Pause" : "Start") { appState.togglePlayback() }
        Button("Reset") { model.reset() }
        Divider()
        Toggle("Stealth Mode", isOn: $model.settings.stealthMode)
        Toggle("Click-through", isOn: $model.settings.clickThrough)
        SettingsLink { Text("Settings…") }
            .simultaneousGesture(TapGesture().onEnded { NSApp.activate(ignoringOtherApps: true) })
        Divider()
        Button("Quit StealthCue") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }
}

/// App-level shortcuts (active when StealthCue is the frontmost app). The overlay handles its own
/// keys — Space, R, ↑/↓, ⌘+/⌘-, Esc — locally while it is focused; no global key monitoring.
private struct StealthCueCommands: Commands {
    let appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Script") { appState.scripts.newScript() }
                .keyboardShortcut("n")
        }
        CommandMenu("Teleprompter") {
            Button("Show / Hide Teleprompter") { appState.toggleTeleprompter() }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Start / Pause") { appState.togglePlayback() }
                .keyboardShortcut(.return, modifiers: .command)
            Button("Reset") { appState.teleprompter.reset() }
                .keyboardShortcut("r")
            Divider()
            Button("Faster") { appState.perform(.faster) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .control])
            Button("Slower") { appState.perform(.slower) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .control])
            Button("Increase Font Size") { appState.perform(.biggerFont) }
                .keyboardShortcut("=")
            Button("Decrease Font Size") { appState.perform(.smallerFont) }
                .keyboardShortcut("-")
            Divider()
            Button("Toggle Stealth Mode") { appState.teleprompter.settings.stealthMode.toggle() }
                .keyboardShortcut("s", modifiers: [.command, .option])
        }
    }
}
