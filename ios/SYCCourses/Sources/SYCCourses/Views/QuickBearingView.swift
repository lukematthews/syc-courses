import CoreLocation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct QuickBearingView: View {
    @EnvironmentObject private var locationService: LocationService
    @AppStorage("lastSelectedMarkID") private var lastSelectedMarkID = "syc-4"
    @State private var selectedMapMark: Mark?
    private let marks = CourseDataLoader.marks()

    var body: some View {
        List {
            Section("Approximate Mark Locations") {
                MarkLocationMapView(marks: marks) { mark in
                    lastSelectedMarkID = mark.id
                    selectedMapMark = mark
                }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            }

            Section("Select Mark") {
                ForEach(marks) { mark in
                    NavigationLink {
                        MarkDetailView(mark: mark)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(mark.name)
                                    .font(.headline)
                                if let description = mark.description {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .simultaneousGesture(TapGesture().onEnded {
                        lastSelectedMarkID = mark.id
                    })
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

private struct MarkLocationMapView: View {
    let marks: [Mark]
    let onSelect: (Mark) -> Void

    private let hotspots: [MarkLocationHotspot] = [
        MarkLocationHotspot(markID: "rmys-g", x: 0.596, y: 0.135),
        MarkLocationHotspot(markID: "r3", x: 0.592, y: 0.308),
        MarkLocationHotspot(markID: "r2", x: 0.575, y: 0.432),
        MarkLocationHotspot(markID: "syc-7", x: 0.817, y: 0.535),
        MarkLocationHotspot(markID: "syc-3", x: 0.840, y: 0.567),
        MarkLocationHotspot(markID: "syc-6", x: 0.642, y: 0.604),
        MarkLocationHotspot(markID: "syc-2", x: 0.721, y: 0.604),
        MarkLocationHotspot(markID: "syc-4", x: 0.831, y: 0.617),
        MarkLocationHotspot(markID: "syc-1", x: 0.802, y: 0.703),
        MarkLocationHotspot(markID: "syc-5", x: 0.751, y: 0.789),
        MarkLocationHotspot(markID: "spoil-ground", x: 0.286, y: 0.833),
        MarkLocationHotspot(markID: "t2", x: 0.485, y: 0.867),
        MarkLocationHotspot(markID: "t1", x: 0.509, y: 0.867),
        MarkLocationHotspot(markID: "centre-m1", x: 0.265, y: 0.940),
        MarkLocationHotspot(markID: "carrum-no2", x: 0.922, y: 0.935),
    ]

    var body: some View {
        #if canImport(UIKit)
        if let image = loadImage() {
            GeometryReader { proxy in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        ForEach(hotspots) { hotspot in
                            if let mark = marks.first(where: { $0.id == hotspot.markID }) {
                                Button {
                                    onSelect(mark)
                                } label: {
                                    MarkLocationButton(markName: mark.name)
                                }
                                .buttonStyle(.plain)
                                .position(
                                    x: hotspot.x * proxy.size.width,
                                    y: hotspot.y * proxy.size.height
                                )
                            }
                        }
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
        Bundle.module.url(forResource: "mark-locations", withExtension: "png")
            .flatMap { UIImage(contentsOfFile: $0.path) }
    }
    #endif
}

private struct MarkLocationHotspot: Identifiable {
    let markID: String
    let x: CGFloat
    let y: CGFloat

    var id: String { markID }
}

private struct MarkLocationButton: View {
    let markName: String

    var body: some View {
        ZStack {
            Circle()
                .fill(.cyan.opacity(0.18))
                .frame(width: 44, height: 44)
            Circle()
                .stroke(.cyan, lineWidth: 3)
                .frame(width: 20, height: 20)
                .background(Circle().fill(.white.opacity(0.55)).frame(width: 20, height: 20))
        }
        .contentShape(Circle())
        .accessibilityLabel("Select \(markName)")
    }
}

struct MarkDetailView: View {
    @EnvironmentObject private var locationService: LocationService
    let mark: Mark

    private var snapshot: BearingSnapshot? {
        locationService.snapshot(to: mark)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let description = mark.description {
                    Text(description)
                        .foregroundStyle(.secondary)
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

                Button {
                    locationService.requestLocation()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
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
