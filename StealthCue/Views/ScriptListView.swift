import SwiftUI

struct ScriptListView: View {
    @Environment(AppState.self) private var appState
    @State private var pendingDeletion: Script?
    @State private var query = ""
    @State private var renamingID: Script.ID?
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool

    var body: some View {
        let scripts = appState.scripts
        let visible = filtered(scripts.scripts)
        List(selection: Binding(get: { scripts.selectedID }, set: { scripts.select($0) })) {
            Section("Scripts") {
                ForEach(visible) { script in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            if renamingID == script.id {
                                TextField("Script title", text: $renameText)
                                    .textFieldStyle(.roundedBorder)
                                    .focused($renameFocused)
                                    .onSubmit { commitRename(script.id) }
                                    .onExitCommand { renamingID = nil }   // Esc cancels
                                    .onChange(of: renameFocused) { _, focused in
                                        // Clicking elsewhere also commits.
                                        if !focused, renamingID == script.id { commitRename(script.id) }
                                    }
                            } else {
                                Text(script.title).lineLimit(1)
                            }
                            Text(script.updatedAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                    .tag(script.id)
                    .contextMenu {
                        Button("Edit Title", systemImage: "pencil") { beginRename(script) }
                        Divider()
                        Button("Delete…", systemImage: "trash", role: .destructive) { pendingDeletion = script }
                    }
                }
            }
        }
        .overlay {
            if scripts.scripts.isEmpty {
                ContentUnavailableView("No saved scripts", systemImage: "doc.text",
                                       description: Text("Write a script and it saves automatically."))
            } else if visible.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .searchable(text: $query, placement: .sidebar, prompt: "Search scripts")
        .toolbar {
            ToolbarItem {
                Button { scripts.newScript() } label: { Label("New Script", systemImage: "plus") }
                    .help("New script (⌘N)")
            }
        }
        .confirmationDialog(
            "Delete “\(pendingDeletion?.title ?? "")”?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { script in
            Button("Delete", role: .destructive) { scripts.delete(script.id) }
        } message: { _ in
            Text("This can't be undone.")
        }
    }

    private func beginRename(_ script: Script) {
        renameText = script.title
        renamingID = script.id
        DispatchQueue.main.async { renameFocused = true }
    }

    private func commitRename(_ id: Script.ID) {
        appState.scripts.rename(id, to: renameText)   // ignores empty / unchanged titles
        renamingID = nil
    }

    /// Matches the title or the script text, ignoring case and accents.
    private func filtered(_ scripts: [Script]) -> [Script] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return scripts }
        return scripts.filter {
            $0.title.localizedStandardContains(term) || $0.text.localizedStandardContains(term)
        }
    }
}
