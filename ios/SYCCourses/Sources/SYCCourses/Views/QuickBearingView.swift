import CoreLocation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct QuickBearingView: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var navigationDataService: NavigationDataService
    @EnvironmentObject private var activeRaceStore: ActiveRaceStore
    @AppStorage("lastSelectedMarkID") private var lastSelectedMarkID = "syc-4"
    @State private var selectedMapMark: Mark?
    private let marks = CourseDataLoader.marks()

    private var sourceSummary: NavigationSourceSummary {
        navigationDataService.sourceSummary(iPhoneFix: locationService.navigationFix)
    }

    var body: some View {
        List {
            if sourceSummary.statusMessage != nil {
                Section {
                    NavigationSourceStatusLine(summary: sourceSummary)
                }
            }

            Section {
                MarkLocationMapView(
                    marks: marks,
                    activeCourseMarkIDs: Set(activeRaceStore.courseMarks.map(\.id)),
                    activeCourseLineMarkIDs: activeRaceStore.courseLineMarkIDs,
                    activeMarkID: activeRaceStore.activeMarkID
                ) { mark in
                    lastSelectedMarkID = mark.id
                    selectedMapMark = mark
                }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            if let activeMark = activeRaceStore.activeMark {
                Section("Active Mark") {
                    Button {
                        lastSelectedMarkID = activeMark.id
                        selectedMapMark = activeMark
                    } label: {
                        MarkSelectionRow(mark: activeMark, isInActiveCourse: true, isActiveMark: true)
                    }
                    .buttonStyle(.plain)
                }
            }

            Section("Select Mark") {
                ForEach(marks) { mark in
                    Button {
                        lastSelectedMarkID = mark.id
                        selectedMapMark = mark
                    } label: {
                        MarkSelectionRow(
                            mark: mark,
                            isInActiveCourse: activeRaceStore.courseMarks.contains { $0.id == mark.id },
                            isActiveMark: activeRaceStore.activeMarkID == mark.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .navigationTitle("Quick Bearing")
        .toolbar {
            Button {
                locationService.requestLocation()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        }
        .onAppear {
            locationService.requestLocation()
        }
        .navigationDestination(item: $selectedMapMark) { mark in
            MarkDetailView(mark: mark)
        }
    }
}

private struct MarkSelectionRow: View {
    let mark: Mark
    var isInActiveCourse = false
    var isActiveMark = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(mark.name)
                    .font(.headline)
                if let description = mark.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if isActiveMark {
                    Text("Active mark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                } else if isInActiveCourse {
                    Text("In active course")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 12)
            if isActiveMark {
                Image(systemName: "scope")
                    .foregroundStyle(.tint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, isInActiveCourse ? 8 : 0)
        .background(isActiveMark ? Color.accentColor.opacity(0.14) : (isInActiveCourse ? Color.secondary.opacity(0.08) : Color.clear))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

private struct MarkLocationMapView: View {
    let marks: [Mark]
    let activeCourseMarkIDs: Set<String>
    let activeCourseLineMarkIDs: [String]
    let activeMarkID: String?
    let onSelect: (Mark) -> Void

    @State private var selectedMapIndex = 1

    private var resources: CoursePackResources { CourseDataLoader.bundledPack.resources }
    private var maps: [QuickBearingMapResource] { resources.quickBearingMaps }
    private var selectedMap: QuickBearingMapResource {
        maps[min(selectedMapIndex, maps.count - 1)]
    }
    private var hotspots: [MarkLocationHotspot] {
        MarkLocationHotspot.loadBundled(selectedMap.hotspots)
    }

    var body: some View {
        #if canImport(UIKit)
        if let image = loadImage() {
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        ActiveCourseHotspotLine(
                            hotspots: hotspots,
                            activeCourseLineMarkIDs: activeCourseLineMarkIDs
                        )

                        ForEach(hotspots) { hotspot in
                            if let mark = marks.first(where: { $0.id == hotspot.markID }) {
                                if let labelFrame = hotspot.labelFrame(in: proxy.size) {
                                    Button {
                                        onSelect(mark)
                                    } label: {
                                        Color.clear
                                            .frame(
                                                width: max(44, labelFrame.width + 16),
                                                height: max(44, labelFrame.height + 16)
                                            )
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .position(x: labelFrame.midX, y: labelFrame.midY)
                                }

                                Button {
                                    onSelect(mark)
                                } label: {
                                    MarkLocationButton(
                                        markName: mark.name,
                                        isInActiveCourse: activeCourseMarkIDs.contains(mark.id),
                                        isActiveMark: activeMarkID == mark.id
                                    )
                                }
                                .buttonStyle(.plain)
                                .position(
                                    x: hotspot.x * proxy.size.width,
                                    y: hotspot.y * proxy.size.height
                                )
                            }
                        }

                        mapViewControl
                    }
            }
            .aspectRatio(1215.0 / 1680.0, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
        } else {
            ContentUnavailableView("Mark map unavailable", systemImage: "map")
        }
        #else
        ContentUnavailableView("Mark map available on iPhone", systemImage: "map")
        #endif
    }

    #if canImport(UIKit)
    private func loadImage() -> UIImage? {
        let name = URL(fileURLWithPath: selectedMap.image).deletingPathExtension().lastPathComponent
        return CourseResourceLocator.url(forResource: name, withExtension: "png")
            .flatMap { UIImage(contentsOfFile: $0.path) }
    }
    #endif

    @ViewBuilder
    private var mapViewControl: some View {
        if maps.count > 1 {
            VStack {
                HStack {
                    Spacer()
                    if maps.count == 2 {
                        Button {
                            selectedMapIndex = selectedMapIndex == 0 ? 1 : 0
                        } label: {
                            Image(systemName: selectedMapIndex == 0 ? "plus.magnifyingglass" : "minus.magnifyingglass")
                                .font(.title3.weight(.bold))
                                .frame(width: 44, height: 44)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(selectedMapIndex == 0 ? "Zoom in to \(maps[1].name)" : "Zoom out")
                    } else {
                        Menu {
                            ForEach(Array(maps.enumerated()), id: \.element.id) { index, map in
                                Button {
                                    selectedMapIndex = index
                                } label: {
                                    Label(map.name, systemImage: index == selectedMapIndex ? "checkmark" : "map")
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(selectedMap.name)
                                Image(systemName: "chevron.down")
                            }
                            .font(.subheadline.weight(.bold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 44)
                            .background(.regularMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Map area, \(selectedMap.name)")
                    }
                }
                Spacer()
            }
            .padding(10)
        }
    }
}

private struct ActiveCourseHotspotLine: View {
    let hotspots: [MarkLocationHotspot]
    let activeCourseLineMarkIDs: [String]

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                var didMove = false
                for markID in activeCourseLineMarkIDs {
                    guard let hotspot = hotspots.first(where: { $0.markID == markID }) else { continue }
                    let point = CGPoint(x: hotspot.x * proxy.size.width, y: hotspot.y * proxy.size.height)
                    if didMove {
                        path.addLine(to: point)
                    } else {
                        path.move(to: point)
                        didMove = true
                    }
                }
            }
            .stroke(.cyan.opacity(0.45), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round, dash: [7, 6]))
        }
    }
}

private struct MarkLocationHotspot: Identifiable, Decodable {
    let markID: String
    let x: CGFloat
    let y: CGFloat
    let labelLeft: CGFloat?
    let labelTop: CGFloat?
    let labelRight: CGFloat?
    let labelBottom: CGFloat?

    var id: String { markID }

    private enum CodingKeys: String, CodingKey {
        case markID = "markId"
        case x
        case y
        case labelLeft
        case labelTop
        case labelRight
        case labelBottom
    }

    func labelFrame(in size: CGSize) -> CGRect? {
        guard let labelLeft, let labelTop, let labelRight, let labelBottom else { return nil }
        return CGRect(
            x: labelLeft * size.width,
            y: labelTop * size.height,
            width: (labelRight - labelLeft) * size.width,
            height: (labelBottom - labelTop) * size.height
        )
    }

    static func loadBundled(_ resource: String) -> [MarkLocationHotspot] {
        let name = URL(fileURLWithPath: resource).deletingPathExtension().lastPathComponent
        guard let url = CourseResourceLocator.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let hotspots = try? JSONDecoder().decode([MarkLocationHotspot].self, from: data) else {
            return []
        }
        return hotspots
    }
}

private struct MarkLocationButton: View {
    let markName: String
    var isInActiveCourse = false
    var isActiveMark = false

    var body: some View {
        ZStack {
            Circle()
                .fill(.clear)
                .frame(width: 44, height: 44)
            Circle()
                .fill(.white.opacity(isActiveMark ? 0.95 : 0.78))
                .frame(width: isActiveMark ? 24 : 18, height: isActiveMark ? 24 : 18)
            Circle()
                .stroke(isActiveMark ? .orange : (isInActiveCourse ? .cyan : .cyan.opacity(0.65)), lineWidth: isActiveMark ? 4 : 3)
                .frame(width: isActiveMark ? 24 : 18, height: isActiveMark ? 24 : 18)
            Circle()
                .fill(.secondary.opacity(0.65))
                .frame(width: 7, height: 7)
        }
        .contentShape(Circle())
        .accessibilityLabel("Select \(markName)")
    }
}

struct MarkDetailView: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var navigationDataService: NavigationDataService
    @EnvironmentObject private var activeRaceStore: ActiveRaceStore
    let mark: Mark

    private var snapshot: BearingSnapshot? {
        navigationDataService.snapshot(to: mark, iPhoneFix: locationService.navigationFix)
    }

    private var sourceSummary: NavigationSourceSummary {
        navigationDataService.sourceSummary(iPhoneFix: locationService.navigationFix)
    }

    private var isOnActiveCourse: Bool {
        activeRaceStore.courseMarks.contains { $0.id == mark.id }
    }

    private var isActiveMark: Bool {
        activeRaceStore.activeMarkID == mark.id
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let description = mark.description {
                    Text(description)
                        .foregroundStyle(.secondary)
                }

                if sourceSummary.statusMessage != nil {
                    NavigationSourceStatusLine(summary: sourceSummary)
                }

                if let snapshot {
                    LocationSanityWarningView(snapshot: snapshot)
                    MetricBlock(title: "Bearing", value: AppFormatters.bearing(snapshot.bearingTrue))
                    MetricBlock(title: "Distance", value: AppFormatters.distanceNm(snapshot.distanceNm))
                    HStack(spacing: 12) {
                        MetricBlock(title: "SOG", value: AppFormatters.speedKnots(snapshot.speedOverGroundKnots))
                        MetricBlock(title: "Time", value: AppFormatters.duration(snapshot.timeToMark))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("GPS accuracy: \(Int(snapshot.horizontalAccuracyMeters.rounded())) m")
                        Text("Updated: \(snapshot.timestamp.formatted(date: .omitted, time: .standard))")
                    }
                    .foregroundStyle(.secondary)
                } else {
                    LocationUnavailableView(
                        status: statusText(locationService.authorizationStatus),
                        error: locationService.errorMessage
                    )
                }

                if isOnActiveCourse {
                    Button {
                        activeRaceStore.setActiveMark(mark)
                    } label: {
                        Label(isActiveMark ? "Going To" : "Go To", systemImage: "scope")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isActiveMark)
                }

                Button {
                    locationService.requestLocation()
                } label: {
                    Label("Refresh Position", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationTitle(mark.name)
        .onAppear {
            locationService.startActiveUpdates()
        }
        .onDisappear {
            locationService.stopActiveUpdates()
        }
    }

    private func statusText(_ status: CLAuthorizationStatus) -> String {
        switch status {
        case .denied, .restricted:
            "Location permission is off. Enable it in Settings to use bearing tools."
        case .notDetermined:
            "The app needs location permission to calculate bearing and distance."
        default:
            "Move into open sky if GPS is slow to settle."
        }
    }
}
