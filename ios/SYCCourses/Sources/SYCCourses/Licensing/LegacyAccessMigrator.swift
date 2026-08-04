import Foundation

struct LegacyAccessRecord: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let packId: String
    let migratedAt: Date
    let sourcePreference: String
}

struct LegacyAccessMigrator {
    static let oldUnlockedKey = "trialAccessUnlocked"
    static let migrationVersionKey = "clubAccessMigrationVersion"
    let defaults: UserDefaults
    let recordURL: URL
    let now: @Sendable () -> Date

    func migrateIfNeeded(packId: String) -> LegacyAccessRecord? {
        if let existing = try? loadRecord() { return existing }
        guard defaults.object(forKey: Self.oldUnlockedKey) as? Bool == true else { return nil }
        let record = LegacyAccessRecord(schemaVersion: 1, packId: packId, migratedAt: now(), sourcePreference: Self.oldUnlockedKey)
        do {
            try FileManager.default.createDirectory(at: recordURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder.licensing.encode(record).write(to: recordURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            defaults.set(1, forKey: Self.migrationVersionKey)
            defaults.removeObject(forKey: Self.oldUnlockedKey)
            return record
        } catch { return nil }
    }

    func loadRecord() throws -> LegacyAccessRecord? {
        guard FileManager.default.fileExists(atPath: recordURL.path) else { return nil }
        return try JSONDecoder.licensing.decode(LegacyAccessRecord.self, from: Data(contentsOf: recordURL))
    }
}
