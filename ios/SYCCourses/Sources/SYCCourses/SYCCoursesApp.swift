import SwiftUI

public struct SYCCoursesRootView: View {
    @StateObject private var trialAccessStore = TrialAccessStore()
    @StateObject private var locationService = LocationService()
    @StateObject private var navigationDataService = NavigationDataService()
    @StateObject private var recentsStore = RecentCoursesStore()
    @StateObject private var raceTrackStore = RaceTrackStore()
    @StateObject private var activeRaceStore = ActiveRaceStore()
    @StateObject private var courseNavigationSurfaceCoordinator = CourseNavigationSurfaceCoordinator()

    public init() {}

    public var body: some View {
        Group {
            if trialAccessStore.isUnlocked {
                HomeView()
                    .environmentObject(locationService)
                    .environmentObject(navigationDataService)
                    .environmentObject(recentsStore)
                    .environmentObject(raceTrackStore)
                    .environmentObject(activeRaceStore)
                    .onAppear {
                        raceTrackStore.configure(locationService: locationService)
                        courseNavigationSurfaceCoordinator.configure(
                            activeRaceStore: activeRaceStore,
                            locationService: locationService
                        )
                    }
            } else {
                TrialAccessView(accessStore: trialAccessStore)
            }
        }
    }

}
