import SwiftUI

struct ScriptListView: View {
    @Environment(AppState.self) private var appState
    @State private var pendingDeletion: Script?

    var body: some View {
        let scripts = appState.scripts
        List(selection: Binding(get: { scripts.selectedID }, set: { scripts.select($0) })) {
            Section("Scripts") {
                ForEach(scripts.scripts) { script in
                    HStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(script.title).lineLimit(1)
                            Text(script.updatedAt, format: .dateTime.month().day().hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                    .tag(script.id)
                    .contextMenu {
                        Button("Delete…", systemImage: "trash", role: .destructive) { pendingDeletion = script }
                    }
                }
            }
        }
        .overlay {
            if scripts.scripts.isEmpty {
                ContentUnavailableView("No saved scripts", systemImage: "doc.text",
                                       description: Text("Write a script and press Save."))
            }
        }
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
}
