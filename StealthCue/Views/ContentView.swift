import SwiftUI

/// Main window: script library (sidebar), a calm editor, and a floating glass control dock.
///
/// Editing actions (Save / Clear / Preview) live in the toolbar; prompting actions
/// (show, play, reset, sliders, modes) live in the dock — so each kind of task has one obvious home.
struct ContentView: View {
    @Environment(AppState.self) private var appState
    @State private var showPreview = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ScriptListView(isSidebarVisible: columnVisibility != .detailOnly)
                .navigationSplitViewColumnWidth(min: 190, ideal: 230, max: 320)
        } detail: {
            VStack(spacing: 16) {
                ScriptEditorView(showPreview: $showPreview)
                TeleprompterControlsView()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            .padding(.top, 8)
            // The 1 px border under the top bar (the bar itself has no fill; see `transparentToolbar`).
            // Sits one point above the content's top edge, i.e. on the bar's bottom row.
            .overlay(alignment: .top) { Theme.barBorder.frame(height: 1).offset(y: -1) }
            // Animates the dock shrinking/growing (the stealth note appearing/disappearing) and the
            // editor filling the space it frees.
            .animation(.smooth(duration: 0.35), value: appState.teleprompter.settings.stealthMode)
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
        .background(Theme.background.ignoresSafeArea())
        .transparentToolbar()   // no separate top-bar colour: the page background shows through
        .themedWindow()
        .onAppear(perform: refreshSplitLayout)
        .frame(minWidth: 860, minHeight: 660)
        .task { await appState.scripts.load() }
        .sheet(isPresented: $showPreview) { PreviewSheet() }
    }

    /// On first launch macOS 26 can lay the top bar out so it stops at the sidebar's edge, and only
    /// corrects itself once the sidebar's state changes (which is why hiding and reopening the sidebar
    /// "fixed" it). Do that state change ourselves, immediately and without animation, so the window
    /// starts in the corrected layout.
    private func refreshSplitLayout() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { columnVisibility = .detailOnly }
        DispatchQueue.main.async {
            withTransaction(transaction) { columnVisibility = .all }
        }
        // Safety net: if SwiftUI ever coalesces those two changes badly, make sure the sidebar still
        // ends up open at launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withTransaction(transaction) { columnVisibility = .all }
        }
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
                    .primaryGlassButton()
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
