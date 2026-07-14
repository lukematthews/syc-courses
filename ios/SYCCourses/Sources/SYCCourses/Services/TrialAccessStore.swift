import Foundation

final class TrialAccessStore: ObservableObject {
    @Published private(set) var isUnlocked: Bool

    static let unlockedKey = "trialAccessUnlocked"

    private let defaults: UserDefaults
    private let expectedCode: String

    init(
        defaults: UserDefaults = .standard,
        expectedCode: String = TrialAccessConfiguration.sharedCode
    ) {
        self.defaults = defaults
        self.expectedCode = expectedCode

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetTrialAccess") {
            defaults.removeObject(forKey: Self.unlockedKey)
        }
        #endif

        isUnlocked = defaults.bool(forKey: Self.unlockedKey)
    }

    @discardableResult
    func unlock(with enteredCode: String) -> Bool {
        let candidate = enteredCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.isEmpty,
              candidate.caseInsensitiveCompare(expectedCode) == .orderedSame
        else { return false }

        defaults.set(true, forKey: Self.unlockedKey)
        isUnlocked = true
        return true
    }

    #if DEBUG
    func resetForDevelopment() {
        defaults.removeObject(forKey: Self.unlockedKey)
        isUnlocked = false
    }
    #endif
}
