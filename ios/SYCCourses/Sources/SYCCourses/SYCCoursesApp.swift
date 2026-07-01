import SwiftUI

public struct SYCCoursesRootView: View {
    @StateObject private var locationService = LocationService()
    @StateObject private var navigationDataService = NavigationDataService()
    @StateObject private var navigationOutputService = NavigationOutputService()
    @StateObject private var recentsStore = RecentCoursesStore()
    @StateObject private var raceTrackStore = RaceTrackStore()
    @StateObject private var activeRaceStore = ActiveRaceStore()

    public init() {}

    public var body: some View {
        HomeView()
            .environmentObject(locationService)
            .environmentObject(navigationDataService)
            .environmentObject(navigationOutputService)
            .environmentObject(recentsStore)
            .environmentObject(raceTrackStore)
            .environmentObject(activeRaceStore)
            .onAppear {
                raceTrackStore.configure(locationService: locationService)
            }
    }
}
