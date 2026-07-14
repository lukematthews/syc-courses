import XCTest
@testable import SYCCourses

final class TrialAccessStoreTests: XCTestCase {
    private let expectedCode = "TEST-CODE"

    func testCorrectCodeUnlocksAndPersists() {
        withStore { store, defaults in
            XCTAssertTrue(store.unlock(with: expectedCode))
            XCTAssertTrue(store.isUnlocked)
            XCTAssertTrue(defaults.bool(forKey: TrialAccessStore.unlockedKey))
        }
    }

    func testIncorrectCodeDoesNotUnlock() {
        withStore { store, defaults in
            XCTAssertFalse(store.unlock(with: "NOT-THE-CODE"))
            XCTAssertFalse(store.isUnlocked)
            XCTAssertFalse(defaults.bool(forKey: TrialAccessStore.unlockedKey))
        }
    }

    func testComparisonIsCaseInsensitive() {
        withStore { store, _ in
            XCTAssertTrue(store.unlock(with: "test-code"))
        }
    }

    func testSurroundingWhitespaceIsIgnored() {
        withStore { store, _ in
            XCTAssertTrue(store.unlock(with: "  \nTEST-CODE\t "))
        }
    }

    func testEmptyInputDoesNotUnlock() {
        withStore { store, _ in
            XCTAssertFalse(store.unlock(with: "  \n\t "))
            XCTAssertFalse(store.isUnlocked)
        }
    }

    func testPersistedUnlockedStateBypassesGate() {
        withDefaults { defaults in
            defaults.set(true, forKey: TrialAccessStore.unlockedKey)

            let store = TrialAccessStore(defaults: defaults, expectedCode: expectedCode)

            XCTAssertTrue(store.isUnlocked)
        }
    }

    #if DEBUG
    func testDevelopmentResetClearsUnlockedState() {
        withStore { store, defaults in
            XCTAssertTrue(store.unlock(with: expectedCode))

            store.resetForDevelopment()

            XCTAssertFalse(store.isUnlocked)
            XCTAssertFalse(defaults.bool(forKey: TrialAccessStore.unlockedKey))
        }
    }
    #endif

    private func withStore(_ test: (TrialAccessStore, UserDefaults) -> Void) {
        withDefaults { defaults in
            test(TrialAccessStore(defaults: defaults, expectedCode: expectedCode), defaults)
        }
    }

    private func withDefaults(_ test: (UserDefaults) -> Void) {
        let suiteName = "TrialAccessStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        test(defaults)
    }
}
