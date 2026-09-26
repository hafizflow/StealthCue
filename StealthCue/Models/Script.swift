import Foundation

/// A saved teleprompter script.
struct Script: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var text: String
    var createdAt: Date
    var updatedAt: Date
    /// When the script was last opened in the editor (nil for scripts saved before this existed).
    var lastOpenedAt: Date?

    init(
        id: UUID = UUID(),
        title: String = "Untitled Script",
        text: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        lastOpenedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastOpenedAt = lastOpenedAt
    }

    var wordCount: Int { text.split(whereSeparator: \.isWhitespace).count }
}
