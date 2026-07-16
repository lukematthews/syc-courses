import SwiftUI

public struct SYCCoursesRootView: View {
    @StateObject private var trialAccessStore = TrialAccessStore()
    @StateObject private var instrumentAccessStore = InstrumentAccessStore()
    @StateObject private var locationService = LocationService()
    @StateObject private var navigationDataService: NavigationDataService
    @StateObject private var navigationOutputService: NavigationOutputService
    @StateObject private var recentsStore = RecentCoursesStore()
    @StateObject private var raceTrackStore = RaceTrackStore()
    @StateObject private var activeRaceStore = ActiveRaceStore()

    public init() {
        _navigationDataService = StateObject(wrappedValue: NavigationDataService(hasInstrumentAccess: false))
        _navigationOutputService = StateObject(wrappedValue: NavigationOutputService(hasInstrumentAccess: false))
    }

    public var body: some View {
        Group {
            if trialAccessStore.isUnlocked {
                HomeView()
                    .environmentObject(locationService)
                    .environmentObject(instrumentAccessStore)
                    .environmentObject(navigationDataService)
                    .environmentObject(navigationOutputService)
                    .environmentObject(recentsStore)
                    .environmentObject(raceTrackStore)
                    .environmentObject(activeRaceStore)
                    .onAppear {
                        raceTrackStore.configure(locationService: locationService)
                    }
                    .task {
                        await instrumentAccessStore.start()
                        applyInstrumentAccess(instrumentAccessStore.hasAccess)
                    }
                    .onChange(of: instrumentAccessStore.hasAccess) { _, hasAccess in
                        applyInstrumentAccess(hasAccess)
                    }
            } else {
                TrialAccessView(accessStore: trialAccessStore)
            }
        }
    }

    private func applyInstrumentAccess(_ hasAccess: Bool) {
        navigationDataService.setInstrumentAccess(hasAccess)
        navigationOutputService.setInstrumentAccess(hasAccess)
    }
}
