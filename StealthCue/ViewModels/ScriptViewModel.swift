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
    var title = "My Script"
    var text = ""

    @ObservationIgnored private let storage: ScriptStorageService
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(storage: ScriptStorageService = ScriptStorageService()) {
        self.storage = storage
    }

    var selectedScript: Script? { scripts.first { $0.id == selectedID } }

    /// True when the editor differs from what is stored.
    var isDirty: Bool {
        if let selectedScript { return selectedScript.title != title || selectedScript.text != text }
        return !text.isEmpty
    }

    var wordCount: Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    // MARK: Loading

    func load() async {
        do {
            scripts = try await storage.load().sorted { $0.updatedAt > $1.updatedAt }
            if let first = scripts.first { open(first) }
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

    func save() {
        commit()
    }

    func clear() {
        text = ""
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
    }

    private func commitIfNeeded() {
        if isDirty { commit() }
    }

    /// Writes the editor buffer into the library (creating a script if none is selected) and saves.
    private func commit() {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalTitle = cleanTitle.isEmpty ? "Untitled Script" : cleanTitle
        if let index = scripts.firstIndex(where: { $0.id == selectedID }) {
            scripts[index].title = finalTitle
            scripts[index].text = text
            scripts[index].updatedAt = .now
        } else {
            let script = Script(title: finalTitle, text: text)
            scripts.insert(script, at: 0)
            selectedID = script.id
        }
        title = finalTitle
        persist()
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
