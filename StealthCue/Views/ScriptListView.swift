import SwiftUI

/// How the script list is ordered. Each option has a natural direction (dates: newest first,
/// name: A→Z, word count: longest first) that is used when you pick it.
enum ScriptSort: String, CaseIterable, Identifiable {
    case modified, created, name, lastOpened, wordCount

    var id: Self { self }

    var title: String {
        switch self {
        case .modified: "Date Modified"
        case .created: "Date Created"
        case .name: "Name"
        case .lastOpened: "Last Opened"
        case .wordCount: "Word Count"
        }
    }

    var symbol: String {
        switch self {
        case .modified: "pencil.circle"
        case .created: "calendar"
        case .name: "textformat"
        case .lastOpened: "clock"
        case .wordCount: "number"
        }
    }

    /// The direction that feels natural for this key.
    var naturalAscending: Bool { self == .name }

    static let defaultSort: ScriptSort = .modified
}

struct ScriptListView: View {
    @Environment(AppState.self) private var appState
    /// Whether the sidebar is currently open (drives how the "+" button is drawn).
    let isSidebarVisible: Bool
    @State private var query = ""
    @State private var renamingID: Script.ID?
    @State private var renameText = ""
    @FocusState private var renameFocused: Bool
    @State private var pendingDeletion: Script?

    // Remembered between launches.
    @AppStorage("sidebar.sortKey") private var sortRaw = ScriptSort.defaultSort.rawValue
    @AppStorage("sidebar.sortAscending") private var ascending = ScriptSort.defaultSort.naturalAscending

    /// Height shared by the search field and the filter button.
    private static let controlHeight: CGFloat = 30

    private var sort: ScriptSort { ScriptSort(rawValue: sortRaw) ?? .defaultSort }
    private var isDefaultOrder: Bool { sort == .defaultSort && ascending == ScriptSort.defaultSort.naturalAscending }

    var body: some View {
        let scripts = appState.scripts
        let visible = ordered(filtered(scripts.scripts))
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
                            subtitle(for: script)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 3)
                    // Rows that appear (a search is cleared / a sort brings them back) fade and ease in;
                    // rows that drop out (a search no longer matches) fade away.
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .leading)),
                        removal: .opacity))
                    .tag(script.id)
                    .contextMenu {
                        Button("Edit Title", systemImage: "pencil") { beginRename(script) }
                        Divider()
                        Button("Delete…", systemImage: "trash", role: .destructive) { pendingDeletion = script }
                    }
                }
            }
        }
        // One animation for every kind of change to the list: re-sorting slides rows to their new places,
        // searching fades rows in and out. Keyed on the visible order so any change triggers it.
        .animation(.smooth(duration: 0.45), value: visible.map(\.id))
        .safeAreaInset(edge: .top, spacing: 0) { searchBar }
        .overlay {
            if scripts.scripts.isEmpty {
                ContentUnavailableView("No saved scripts", systemImage: "doc.text",
                                       description: Text("Write a script and it saves automatically."))
            } else if visible.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .toolbar { NewScriptToolbarItem(hasOwnGlass: isSidebarVisible, action: { scripts.newScript() }) }
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

    // MARK: Search + sort bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search scripts", text: $query)
                    .textFieldStyle(.plain)
                    .onExitCommand { query = "" }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear search")
                }
            }
            .padding(.horizontal, 10)
            .frame(height: Self.controlHeight)
            .background(.quaternary.opacity(0.6), in: Capsule())

            sortMenu
        }
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 6)
    }

    /// The filter button: choose what the list is ordered by, and in which direction.
    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: Binding(
                get: { sort },
                set: { newValue in
                    sortRaw = newValue.rawValue
                    ascending = newValue.naturalAscending
                }
            )) {
                ForEach(ScriptSort.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.inline)

            Picker("Order", selection: $ascending) {
                Label("Ascending", systemImage: "arrow.up").tag(true)
                Label("Descending", systemImage: "arrow.down").tag(false)
            }
            .pickerStyle(.inline)

            if !isDefaultOrder {
                Divider()
                Button("Reset to Default", systemImage: "arrow.counterclockwise") {
                    sortRaw = ScriptSort.defaultSort.rawValue
                    ascending = ScriptSort.defaultSort.naturalAscending
                }
            }
        } label: {
            // Same height and fill as the search field beside it, so the two read as one matched pair.
            Image(systemName: isDefaultOrder ? "line.3.horizontal.decrease" : "line.3.horizontal.decrease.circle.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isDefaultOrder ? Color.secondary : Color.primary)
                .frame(width: Self.controlHeight, height: Self.controlHeight)
                .background(.quaternary.opacity(0.6), in: Circle())
                .contentShape(Circle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort scripts (currently \(sort.title), \(ascending ? "ascending" : "descending"))")
    }

    // MARK: Filtering & ordering

    /// Matches the title or the script text, ignoring case and accents.
    private func filtered(_ scripts: [Script]) -> [Script] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return scripts }
        return scripts.filter {
            $0.title.localizedStandardContains(term) || $0.text.localizedStandardContains(term)
        }
    }

    private func ordered(_ scripts: [Script]) -> [Script] {
        let sorted: [Script]
        switch sort {
        case .modified:
            sorted = scripts.sorted { $0.updatedAt < $1.updatedAt }
        case .created:
            sorted = scripts.sorted { $0.createdAt < $1.createdAt }
        case .name:
            sorted = scripts.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .lastOpened:
            // Scripts never opened count as oldest.
            sorted = scripts.sorted { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) }
        case .wordCount:
            let counts = Dictionary(uniqueKeysWithValues: scripts.map { ($0.id, $0.wordCount) })
            sorted = scripts.sorted { counts[$0.id, default: 0] < counts[$1.id, default: 0] }
        }
        return ascending ? sorted : sorted.reversed()
    }

    /// The second line of a row shows the value you're sorting by.
    @ViewBuilder
    private func subtitle(for script: Script) -> some View {
        switch sort {
        case .created:
            Text(script.createdAt, format: .dateTime.month().day().hour().minute())
        case .lastOpened:
            if let opened = script.lastOpenedAt {
                Text(opened, format: .dateTime.month().day().hour().minute())
            } else {
                Text("Never opened")
            }
        case .wordCount:
            Text("\(script.wordCount) words")
        case .modified, .name:
            Text(script.updatedAt, format: .dateTime.month().day().hour().minute())
        }
    }

    // MARK: Rename

    private func beginRename(_ script: Script) {
        renameText = script.title
        renamingID = script.id
        DispatchQueue.main.async { renameFocused = true }
    }

    private func commitRename(_ id: Script.ID) {
        appState.scripts.rename(id, to: renameText)   // ignores empty / unchanged titles
        renamingID = nil
    }
}


/// The "+" button.
///
/// With the sidebar **open**, macOS draws sidebar toolbar items as bare icons, so the button gets its own
/// glass circle to read clearly as a button. With the sidebar **closed**, macOS groups "+" and the sidebar
/// toggle into one shared glass capsule — a second ring inside it would look doubled, so it stays plain.
private struct NewScriptToolbarItem: ToolbarContent {
    let hasOwnGlass: Bool
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem { button }
    }

    @ViewBuilder
    private var button: some View {
        let base = Button(action: action) { Label("New Script", systemImage: "plus") }
            .help("New script (⌘N)")
        if hasOwnGlass {
            base
                .glassButtonStyle()
                .buttonBorderShape(.circle)
                .controlSize(.large)   // same size as the Settings button
        } else {
            base
        }
    }
}
