import Foundation

@MainActor
final class NavigationDataService: ObservableObject {
    func activeFix(iPhoneFix: NavigationFix?, now: Date = Date()) -> NavigationFix? {
        iPhoneFix?.isUsablePosition == true ? iPhoneFix : nil
    }

    func sourceSummary(iPhoneFix: NavigationFix?, now: Date = Date()) -> NavigationSourceSummary {
        let active = activeFix(iPhoneFix: iPhoneFix, now: now)
        return NavigationSourceSummary(
            activeSource: active?.source,
            availableSources: active == nil ? [] : [.iPhoneGPS],
            lastUpdate: active?.timestamp,
            statusMessage: active == nil ? "No valid position" : nil
        )
    }

    func snapshot(to mark: Mark, iPhoneFix: NavigationFix?, now: Date = Date()) -> BearingSnapshot? {
        guard let fix = activeFix(iPhoneFix: iPhoneFix, now: now) else { return nil }
        return BearingSnapshot(fix: fix, mark: mark)
    }
}
