import Foundation
import PLFaith

/// Editorial vocabulary: content themes and how check-in moods map onto them.
///
/// Kept in data (`taxonomy.json`) so editors can tune it without code changes.
public struct ContentTaxonomy: Codable, Hashable, Sendable {
    public struct Theme: Codable, Hashable, Identifiable, Sendable {
        public var id: ThemeID
        public var name: LocalizedText

        public init(id: ThemeID, name: LocalizedText) {
            self.id = id
            self.name = name
        }
    }

    public var themes: [Theme]
    public var moodThemes: [Mood: [ThemeID]]

    public init(themes: [Theme], moodThemes: [Mood: [ThemeID]]) {
        self.themes = themes
        self.moodThemes = moodThemes
    }

    public func themes(for mood: Mood) -> [ThemeID] { moodThemes[mood] ?? [] }

    public func theme(_ id: ThemeID) -> Theme? { themes.first { $0.id == id } }
}

extension Mood: CodingKeyRepresentable {}
