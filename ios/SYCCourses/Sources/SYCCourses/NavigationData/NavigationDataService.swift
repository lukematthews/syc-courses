import Combine
import Foundation

@MainActor
final class NavigationDataService: ObservableObject {
    @Published var actisenseConfig: ActisenseInputConfig {
        didSet {
            persistConfig()
            actisenseProvider.configure(actisenseConfig)
        }
    }
    @Published private(set) var actisenseProvider: ActisenseNMEAProvider

    private let defaults: UserDefaults
    private var cancellable: AnyCancellable?

    init(defaults: UserDefaults = .standard, actisenseProvider: ActisenseNMEAProvider? = nil) {
        self.defaults = defaults
        let config = defaults.actisenseInputConfig
        actisenseConfig = config
        self.actisenseProvider = actisenseProvider ?? ActisenseNMEAProvider(config: config)
        self.actisenseProvider.configure(config)
        cancellable = self.actisenseProvider.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var actisenseStatus: NavigationSourceStatus {
        return actisenseProvider.status
    }

    var canConnectActisense: Bool {
        actisenseConfig.isConfigured
    }

    func connectActisense() async {
        guard actisenseConfig.isConfigured else { return }
        await actisenseProvider.connect()
    }

    func disconnectActisense() {
        actisenseProvider.disconnect()
    }

    func activeFix(iPhoneFix: NavigationFix?, now: Date = Date()) -> NavigationFix? {
        if actisenseConfig.isEnabled,
           let actisenseFix = actisenseProvider.latestFix,
           actisenseFix.isUsablePosition,
           actisenseProvider.isFresh(now: now) {
            return actisenseFix
        }
        return iPhoneFix?.isUsablePosition == true ? iPhoneFix : nil
    }

    func sourceSummary(iPhoneFix: NavigationFix?, now: Date = Date()) -> NavigationSourceSummary {
        let active = activeFix(iPhoneFix: iPhoneFix, now: now)
        var available: [NavigationSource] = []
        if iPhoneFix?.isUsablePosition == true {
            available.append(.iPhoneGPS)
        }
        if let actisenseFix = actisenseProvider.latestFix, actisenseFix.isUsablePosition, actisenseProvider.isFresh(now: now) {
            available.append(.actisense)
        }

        let message: String
        if active?.source == .actisense {
            message = "Source: NMEA2000"
        } else if actisenseConfig.isEnabled,
                  actisenseProvider.latestFix != nil,
                  !actisenseProvider.isFresh(now: now),
                  iPhoneFix?.isUsablePosition == true {
            message = "Actisense stale - using iPhone GPS"
        } else if active?.source == .iPhoneGPS {
            message = "Source: iPhone GPS"
        } else {
            message = "No valid position"
        }

        return NavigationSourceSummary(
            activeSource: active?.source,
            availableSources: available,
            lastUpdate: active?.timestamp,
            statusMessage: message
        )
    }

    func snapshot(to mark: Mark, iPhoneFix: NavigationFix?, now: Date = Date()) -> BearingSnapshot? {
        guard let fix = activeFix(iPhoneFix: iPhoneFix, now: now) else { return nil }
        return BearingSnapshot(fix: fix, mark: mark)
    }

    private func persistConfig() {
        defaults.actisenseInputConfig = actisenseConfig
    }
}

private extension UserDefaults {
    var actisenseInputConfig: ActisenseInputConfig {
        get {
            guard let data = data(forKey: "actisenseInputConfig"),
                  let config = try? JSONDecoder().decode(ActisenseInputConfig.self, from: data)
            else {
                return ActisenseInputConfig()
            }
            return config
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                set(data, forKey: "actisenseInputConfig")
            }
        }
    }
}
