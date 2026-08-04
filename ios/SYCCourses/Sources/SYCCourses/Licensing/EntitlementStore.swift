import Foundation

protocol EntitlementPersisting: Sendable {
    func load() throws -> EntitlementEnvelope?
    func save(_ envelope: EntitlementEnvelope) throws
}

struct EntitlementStore: EntitlementPersisting {
    let fileURL: URL

    static func applicationSupport(fileManager: FileManager = .default) throws -> EntitlementStore {
        let root = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let directory = root.appendingPathComponent("SYCCourses/Licensing", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return EntitlementStore(fileURL: directory.appendingPathComponent("entitlement-v1.json"))
    }

    func load() throws -> EntitlementEnvelope? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        return try JSONDecoder().decode(EntitlementEnvelope.self, from: Data(contentsOf: fileURL))
    }

    func save(_ envelope: EntitlementEnvelope) throws {
        try JSONEncoder().encode(envelope).write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
    }
}
