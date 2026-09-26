import Foundation

/// A saved teleprompter script.
struct Script: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var text: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String = "Untitled Script",
        text: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
