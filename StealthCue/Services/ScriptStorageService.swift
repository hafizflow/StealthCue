import Foundation

/// Persists scripts as a single JSON file in Application Support.
///
/// (Inside the App Sandbox this resolves to the app's container.) Everything is local;
/// the app has no network entitlement.
actor ScriptStorageService {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("StealthCue", isDirectory: true)
        fileURL = base.appendingPathComponent("scripts.json")
    }

    func load() throws -> [Script] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([Script].self, from: data)
    }

    /// Synchronous variant for app termination, where an async task might never get to run.
    nonisolated func saveSync(_ scripts: [Script]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(scripts).write(to: fileURL, options: .atomic)
    }

    func save(_ scripts: [Script]) throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(scripts).write(to: fileURL, options: .atomic)
    }
}
