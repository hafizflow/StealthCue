import SwiftUI

/// Main window: script library (sidebar), a calm editor, and a floating glass control dock.
///
/// Editing actions (Save / Clear / Preview) live in the toolbar; prompting actions
/// (show, play, reset, sliders, modes) live in the dock — so each kind of task has one obvious home.
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showPreview = false

    var body: some View {
        NavigationSplitView {
            ScriptListView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 320)
        } detail: {
            VStack(spacing: 16) {
                ScriptEditorView(showPreview: $showPreview)
                TeleprompterControlsView()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 8)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    SettingsLink {
                        Label("Settings", systemImage: "gearshape")   // icon-only in the toolbar
                    }
                    .help("Open Settings (⌘,)")
                }
            }
        }
        .navigationTitle("StealthCue")
        .frame(minWidth: 860, minHeight: 660)
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
        let settings = appState.teleprompter.settings

        VStack(spacing: 0) {
            HStack {
                Label("Preview", systemImage: "eye").font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .glassButtonStyle(prominent: true)
            }
            .padding(14)

            TeleprompterScrollView(
                text: appState.scripts.text,
                settings: settings,
                isPlaying: false,
                resetToken: appState.teleprompter.resetToken,
                manualScrollLines: 0,
                autoScroll: false
            )
            .background(settings.backgroundColor.color.opacity(settings.backgroundOpacity))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 14)

            Text("Scroll to look through the script")
                .font(.caption).foregroundStyle(.secondary)
                .padding(10)
        }
        .frame(width: 740, height: 460)
    }
}
