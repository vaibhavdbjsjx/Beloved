import Foundation
import PLCore

public enum FaithRegistryError: Error, Equatable, Sendable {
    case resourceMissing(String)
    case duplicateIdentifier(String)
}

/// Read-only lookup over all supported faiths, traditions, focuses, sources and editions.
///
/// Adding a faith is a data change (`faiths.json`), not a code change.
public struct FaithRegistry: Sendable {
    public let faiths: [Faith]

    private let faithsByID: [FaithID: Faith]
    private let traditionOwner: [TraditionID: FaithID]
    private let focusOwner: [FocusID: FaithID]
    private let sourcesByID: [SourceWorkID: SourceWork]
    private let editionsByID: [EditionID: (SourceWorkID, Edition)]

    public init(faiths: [Faith]) throws {
        self.faiths = faiths
        var faithsByID: [FaithID: Faith] = [:]
        var traditionOwner: [TraditionID: FaithID] = [:]
        var focusOwner: [FocusID: FaithID] = [:]
        var sourcesByID: [SourceWorkID: SourceWork] = [:]
        var editionsByID: [EditionID: (SourceWorkID, Edition)] = [:]

        for faith in faiths {
            guard faithsByID.updateValue(faith, forKey: faith.id) == nil else {
                throw FaithRegistryError.duplicateIdentifier(faith.id.rawValue)
            }
            for tradition in faith.traditions {
                guard traditionOwner.updateValue(faith.id, forKey: tradition.id) == nil else {
                    throw FaithRegistryError.duplicateIdentifier(tradition.id.rawValue)
                }
            }
            for focus in faith.focuses {
                guard focusOwner.updateValue(faith.id, forKey: focus.id) == nil else {
                    throw FaithRegistryError.duplicateIdentifier(focus.id.rawValue)
                }
            }
            for source in faith.sources {
                guard sourcesByID.updateValue(source, forKey: source.id) == nil else {
                    throw FaithRegistryError.duplicateIdentifier(source.id.rawValue)
                }
                for edition in source.editions {
                    guard editionsByID.updateValue((source.id, edition), forKey: edition.id) == nil else {
                        throw FaithRegistryError.duplicateIdentifier(edition.id.rawValue)
                    }
                }
            }
        }
        self.faithsByID = faithsByID
        self.traditionOwner = traditionOwner
        self.focusOwner = focusOwner
        self.sourcesByID = sourcesByID
        self.editionsByID = editionsByID
    }

    public init(jsonData: Data) throws {
        try self.init(faiths: JSONDecoder.prayerLock().decode([Faith].self, from: jsonData))
    }

    /// The registry bundled with the app (`Resources/faiths.json`).
    public static func bundled() throws -> FaithRegistry {
        guard let url = Bundle.module.url(forResource: "faiths", withExtension: "json") else {
            throw FaithRegistryError.resourceMissing("faiths.json")
        }
        return try FaithRegistry(jsonData: Data(contentsOf: url))
    }

    public func faith(_ id: FaithID) -> Faith? { faithsByID[id] }

    public func faith(owning tradition: TraditionID) -> FaithID? { traditionOwner[tradition] }

    public func faith(owning focus: FocusID) -> FaithID? { focusOwner[focus] }

    public func tradition(_ id: TraditionID) -> Tradition? {
        traditionOwner[id].flatMap { faithsByID[$0] }?.traditions.first { $0.id == id }
    }

    public func focus(_ id: FocusID) -> SpiritualFocus? {
        focusOwner[id].flatMap { faithsByID[$0] }?.focuses.first { $0.id == id }
    }

    public func source(_ id: SourceWorkID) -> SourceWork? { sourcesByID[id] }

    public func edition(_ id: EditionID) -> Edition? { editionsByID[id]?.1 }

    public func source(owning edition: EditionID) -> SourceWorkID? { editionsByID[edition]?.0 }

    /// Validates that a profile only references things that exist and belong together.
    public func isConsistent(_ profile: SpiritualProfile) -> Bool {
        guard let faithID = profile.faithID else {
            return profile.traditionID == nil && profile.focusIDs.isEmpty
        }
        guard faithsByID[faithID] != nil else { return false }
        if let tradition = profile.traditionID, traditionOwner[tradition] != faithID { return false }
        return profile.focusIDs.allSatisfy { focusOwner[$0] == faithID }
    }
}
