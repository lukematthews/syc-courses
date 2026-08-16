import SwiftUI

public struct SYCCoursesRootView: View {
    @StateObject private var accessStore = ClubAccessStore.application()
    @StateObject private var locationService = LocationService()
    @StateObject private var navigationDataService = NavigationDataService()
    @StateObject private var navigationOutputService = NavigationOutputService()
    @StateObject private var recentsStore = RecentCoursesStore()
    @StateObject private var raceTrackStore = RaceTrackStore()
    @StateObject private var activeRaceStore = ActiveRaceStore()
    @StateObject private var courseNavigationSurfaceCoordinator = CourseNavigationSurfaceCoordinator()

    public init() {}

    public var body: some View {
        Group {
            if accessStore.state.retainsDownloadedReferenceAccess {
                VStack(spacing: 0) {
                    accessNotice
                    HomeView()
                }
                    .environmentObject(locationService)
                    .environmentObject(navigationDataService)
                    .environmentObject(navigationOutputService)
                    .environmentObject(recentsStore)
                    .environmentObject(raceTrackStore)
                    .environmentObject(activeRaceStore)
                    .onAppear {
                        raceTrackStore.configure(locationService: locationService)
                        courseNavigationSurfaceCoordinator.configure(
                            activeRaceStore: activeRaceStore,
                            locationService: locationService,
                            navigationDataService: navigationDataService,
                            navigationOutputService: navigationOutputService
                        )
                    }
                    .task { await accessStore.refreshIfDue() }
            } else {
                ClubAccessView(accessStore: accessStore)
            }
        }
    }

    @ViewBuilder private var accessNotice: some View {
        switch accessStore.state {
        case .legacyBundledSnapshot:
            Text("Legacy access: bundled SYC course snapshot only. Updates require current club access.")
                .font(.caption).padding(8).frame(maxWidth: .infinity).background(.yellow.opacity(0.2))
        case .expired:
            Text("Club access has expired. Previously downloaded course information remains available but may no longer be current. Connect and refresh.")
                .font(.caption).padding(8).frame(maxWidth: .infinity).background(.orange.opacity(0.2))
        case .gracePeriod, .temporarilyUnableToRefresh:
            HStack { Text("Unable to confirm updates. Downloaded course information remains available."); Button("Retry") { Task { await accessStore.retryRefresh() } } }
                .font(.caption).padding(8).frame(maxWidth: .infinity).background(.yellow.opacity(0.2))
        default: EmptyView()
        }
    }

}
