import SwiftUI

/// Main editor window: script library, editor, and quick teleprompter controls.
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showPreview = false

    var body: some View {
        NavigationSplitView {
            ScriptListView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 300)
        } detail: {
            VStack(spacing: 0) {
                ScriptEditorView(showPreview: $showPreview)
                Divider()
                TeleprompterControlsView()
            }
        }
        .navigationTitle("StealthCue")
        .frame(minWidth: 820, minHeight: 600)
        .task { await appState.scripts.load() }
        .sheet(isPresented: $showPreview) { PreviewSheet() }
    }
}

/// A static, in-app look at how the script will render (never affected by stealth mode: it is part
/// of the normal editor window).
private struct PreviewSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TeleprompterScrollView(
                text: appState.scripts.text,
                settings: appState.teleprompter.settings,
                isPlaying: false,
                resetToken: appState.teleprompter.resetToken,
                manualScrollLines: 0,
                autoScroll: false
            )
            .background(appState.teleprompter.settings.backgroundColor.color
                .opacity(appState.teleprompter.settings.backgroundOpacity))
            HStack {
                Text("Scroll to preview").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(10)
        }
        .frame(width: 720, height: 420)
    }
}
