import Foundation

@MainActor
final class ClubAccessStore: ObservableObject {
    @Published private(set) var state: AccessState = .noAccess
    @Published private(set) var isWorking = false
    @Published private(set) var message: String?

    private let configuration: LicensingConfiguration
    private let identityStore: InstallationIdentityStore
    private let credentialStore: RefreshCredentialStore
    private let entitlementStore: EntitlementPersisting
    private let verifier: EntitlementVerifier
    private let policy = AccessPolicyEvaluator()
    private let api: LicensingAPIClient
    private let migrator: LegacyAccessMigrator
    private let now: @Sendable () -> Date
    private var retryCount = 0
    private var nextAttemptAt: Date?

    static func application() -> ClubAccessStore {
        let configuration = LicensingConfiguration.application
        let keychain = KeychainStore(service: Bundle.main.bundleIdentifier ?? "au.com.syc.courses")
        let support = (try? FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)) ?? FileManager.default.temporaryDirectory
        let entitlementStore = (try? EntitlementStore.applicationSupport()) ?? EntitlementStore(fileURL: support.appendingPathComponent("entitlement-v1.json"))
        let legacyURL = support.appendingPathComponent("SYCCourses/Licensing/legacy-access-v1.json")
        return ClubAccessStore(
            configuration: configuration,
            identityStore: InstallationIdentityStore(storage: keychain),
            credentialStore: RefreshCredentialStore(storage: keychain),
            entitlementStore: entitlementStore,
            api: LicensingAPIClient(endpoint: configuration.endpoint, session: .shared),
            migrator: LegacyAccessMigrator(defaults: .standard, recordURL: legacyURL, now: { Date() }),
            now: { Date() }
        )
    }

    init(
        configuration: LicensingConfiguration,
        identityStore: InstallationIdentityStore,
        credentialStore: RefreshCredentialStore,
        entitlementStore: EntitlementPersisting,
        api: LicensingAPIClient,
        migrator: LegacyAccessMigrator,
        now: @escaping @Sendable () -> Date
    ) {
        self.configuration = configuration; self.identityStore = identityStore; self.credentialStore = credentialStore
        self.entitlementStore = entitlementStore; self.verifier = EntitlementVerifier(publicKeys: configuration.publicKeys)
        self.api = api; self.migrator = migrator; self.now = now
        loadLocalAccess()
    }

    private func loadLocalAccess() {
        if let envelope = try? entitlementStore.load() {
            do {
                let installationId = try identityStore.identifier()
                let verified = try verifier.verify(envelope, installationId: installationId, expectedClubId: configuration.expectedClubId, expectedPackId: configuration.expectedPackId, now: now())
                state = policy.evaluate(verified, now: now())
                return
            } catch { state = .invalid }
        }
        if let legacy = migrator.migrateIfNeeded(packId: configuration.expectedPackId), legacy.packId == configuration.expectedPackId {
            state = .legacyBundledSnapshot
        } else if state != .invalid { state = .noAccess }
    }

    func refreshIfDue() async {
        guard state.needsRefresh, !isWorking else { return }
        if let nextAttemptAt, now() < nextAttemptAt { return }
        await refresh(explicit: false)
    }

    func activate(invitationCode: String) async {
        guard !isWorking else { return }
        isWorking = true; message = nil
        defer { isWorking = false }
        do {
            let installationId = try identityStore.identifier()
            let response = try await api.activate(code: invitationCode.trimmingCharacters(in: .whitespacesAndNewlines), installationId: installationId, appVersion: Self.appVersion, platform: Self.platform)
            let verified = try verifier.verify(response.entitlement, installationId: installationId, expectedClubId: configuration.expectedClubId, expectedPackId: configuration.expectedPackId, now: now(), allowExpiredReferenceAccess: false)
            try entitlementStore.save(response.entitlement)
            try credentialStore.save(response.refreshCredential)
            state = policy.evaluate(verified, now: now()); retryCount = 0; nextAttemptAt = nil
        } catch {
            message = activationMessage(for: error)
        }
    }

    func retryRefresh() async { await refresh(explicit: true) }

    private func refresh(explicit: Bool) async {
        guard !isWorking else { return }
        isWorking = true; message = nil
        defer { isWorking = false }
        do {
            let installationId = try identityStore.identifier()
            guard let credential = try credentialStore.credential() else { throw LicensingAPIError.invalidResponse }
            let response = try await api.refresh(credential: credential, installationId: installationId, appVersion: Self.appVersion)
            let verified = try verifier.verify(response.entitlement, installationId: installationId, expectedClubId: configuration.expectedClubId, expectedPackId: configuration.expectedPackId, now: now(), allowExpiredReferenceAccess: false)
            try entitlementStore.save(response.entitlement)
            state = policy.evaluate(verified, now: now()); retryCount = 0; nextAttemptAt = nil
        } catch {
            retryCount += 1
            let delay = min(configuration.maximumRetryDelay, configuration.minimumRetryDelay * pow(2, Double(retryCount - 1)))
            let retryAt = now().addingTimeInterval(delay); nextAttemptAt = retryAt
            if case .valid(let value) = state { state = .temporarilyUnableToRefresh(value, retryAt: retryAt) }
            else if case .refreshDue(let value) = state { state = .temporarilyUnableToRefresh(value, retryAt: retryAt) }
            message = explicit ? "Unable to refresh right now. Downloaded course information remains available." : nil
        }
    }

    private func activationMessage(for error: Error) -> String {
        if case LicensingAPIError.server(let code) = error {
            switch code {
            case "INVALID_INVITATION", "INVITATION_INACTIVE", "INVITATION_EXPIRED": return "That club invitation cannot be used. Ask your club for a current invitation."
            case "RATE_LIMITED": return "Too many attempts. Please wait before trying again."
            case "UNSUPPORTED_APP_VERSION": return "Update the app before activating."
            default: break
            }
        }
        return "Unable to contact the club licensing service. Check your connection and try again."
    }

    private static var appVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0" }
    private static var platform: String {
        #if os(iOS)
        "ios"
        #else
        "macos"
        #endif
    }
}
