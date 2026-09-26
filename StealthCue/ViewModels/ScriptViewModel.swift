import Foundation
import Observation

/// Owns the script library and the text currently being edited.
@MainActor
@Observable
final class ScriptViewModel {
    private(set) var scripts: [Script] = []
    private(set) var selectedID: Script.ID?
    private(set) var lastError: String?

    /// Live editor buffer. The teleprompter overlay reads `text` directly.
    var title = "My Script" { didSet { if title != oldValue { scheduleAutosave() } } }
    var text = "" { didSet { if text != oldValue { scheduleAutosave() } } }

    /// Edits are saved automatically this long after you stop typing (like VS Code's
    /// "auto save: after delay").
    private static let autosaveDelay: Duration = .milliseconds(800)

    @ObservationIgnored private let storage: ScriptStorageService
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var autosaveTask: Task<Void, Never>?

    init(storage: ScriptStorageService = ScriptStorageService()) {
        self.storage = storage
    }

    var selectedScript: Script? { scripts.first { $0.id == selectedID } }

    /// The title as it will be stored: trimmed, and never empty.
    private var storedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled Script" : trimmed
    }

    /// True when the editor differs from what is stored.
    var isDirty: Bool {
        if let selectedScript { return selectedScript.title != storedTitle || selectedScript.text != text }
        return !text.isEmpty
    }

    var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    // MARK: Loading

    func load() async {
        do {
            scripts = try await storage.load().sorted { $0.updatedAt > $1.updatedAt }
            // Reopen the script that was open when the app last closed: the one with the latest
            // "last opened" time. Scripts saved before that was recorded fall back to the most
            // recently modified one.
            let lastOpened = scripts
                .filter { $0.lastOpenedAt != nil }
                .max { ($0.lastOpenedAt ?? .distantPast) < ($1.lastOpenedAt ?? .distantPast) }
            if let script = lastOpened ?? scripts.first { open(script) }
        } catch {
            lastError = "Couldn't load scripts: \(error.localizedDescription)"
        }
    }

    // MARK: Editing actions

    func select(_ id: Script.ID?) {
        guard id != selectedID else { return }
        commitIfNeeded()
        if let script = scripts.first(where: { $0.id == id }) {
            open(script)
        } else {
            selectedID = nil
        }
    }

    func newScript() {
        commitIfNeeded()
        let script = Script(title: "Untitled Script")
        scripts.insert(script, at: 0)
        open(script)
        persist()
    }

    /// Saves right now (⌘S). Normally unnecessary: edits autosave shortly after you stop typing.
    func save() {
        autosaveTask?.cancel()
        commitIfNeeded()
    }

    /// Called when the app is about to quit: writes any pending edit *synchronously*.
    func flushForTermination() {
        autosaveTask?.cancel()
        if isDirty { applyEdits() }
        try? storage.saveSync(scripts)
    }

    func clear() {
        text = ""
    }

    /// Renames a saved script (used by the sidebar's "Edit Title"). Only the title changes — any
    /// unsaved text edits in the editor are left alone.
    func rename(_ id: Script.ID, to newTitle: String) {
        let clean = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, let index = scripts.firstIndex(where: { $0.id == id }),
              scripts[index].title != clean else { return }
        scripts[index].title = clean
        if id == selectedID { title = clean }
        persist()
    }

    func delete(_ id: Script.ID) {
        scripts.removeAll { $0.id == id }
        if selectedID == id {
            if let next = scripts.first { open(next) } else { selectedID = nil; title = "My Script"; text = "" }
        }
        persist()
    }

    // MARK: Private

    private func open(_ script: Script) {
        selectedID = script.id
        title = script.title
        text = script.text
        if let index = scripts.firstIndex(where: { $0.id == script.id }) {
            scripts[index].lastOpenedAt = .now   // powers "Last Opened" sorting
            persist()
        }
    }

    private func commitIfNeeded() {
        if isDirty { commit() }
    }

    /// Copies the editor buffer into the library (creating a script if none is selected).
    /// The title *buffer* is left as typed, so autosaving never edits text under the cursor.
    private func applyEdits() {
        if let index = scripts.firstIndex(where: { $0.id == selectedID }) {
            scripts[index].title = storedTitle
            scripts[index].text = text
            scripts[index].updatedAt = .now
        } else {
            let script = Script(title: storedTitle, text: text)
            scripts.insert(script, at: 0)
            selectedID = script.id
        }
    }

    private func commit() {
        applyEdits()
        persist()
    }

    /// Debounced: every edit restarts the timer, and the save happens once typing pauses.
    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            self?.commitIfNeeded()
        }
    }

    /// Saves are chained so an older snapshot can never overwrite a newer one.
    private func persist() {
        let snapshot = scripts
        let previous = saveTask
        saveTask = Task { [storage] in
            await previous?.value
            do {
                try await storage.save(snapshot)
            } catch {
                await MainActor.run { self.lastError = "Couldn't save: \(error.localizedDescription)" }
            }
        }
    }
}
