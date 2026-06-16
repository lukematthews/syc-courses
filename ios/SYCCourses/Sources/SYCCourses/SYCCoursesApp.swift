import SwiftUI

public struct SYCCoursesRootView: View {
    @StateObject private var locationService = LocationService()
    @StateObject private var recentsStore = RecentCoursesStore()

    public init() {}

    public var body: some View {
        HomeView()
            .environmentObject(locationService)
            .environmentObject(recentsStore)
    }
}
