import Foundation

struct LicensingConfiguration: Sendable {
    let endpoint: URL
    let expectedClubId: String?
    let expectedPackId: String
    let publicKeys: [String: Data]
    let minimumRetryDelay: TimeInterval
    let maximumRetryDelay: TimeInterval

    static var application: LicensingConfiguration {
        let info = Bundle.main.infoDictionary ?? [:]
        let endpoint = (info["LicensingAPIEndpoint"] as? String).flatMap(URL.init(string:))
            ?? URL(string: "https://licensing.invalid")!
        let keyId = info["LicensingKeyID"] as? String ?? "development-2026-01"
        let publicKey = (info["LicensingPublicKeyBase64"] as? String).flatMap { Data(base64Encoded: $0) }
        return LicensingConfiguration(
            endpoint: endpoint,
            expectedClubId: nil,
            expectedPackId: CourseDataLoader.bundledPack.packId,
            publicKeys: publicKey.map { [keyId: $0] } ?? [:],
            minimumRetryDelay: 15 * 60,
            maximumRetryDelay: 24 * 60 * 60
        )
    }
}
