import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct StartAssistView: View {
    @EnvironmentObject private var locationService: LocationService
    @AppStorage("lastStartOffsetMinutes") private var startOffsetMinutes = 10
    @State private var gunTime = Date()
    @State private var now = Date()
    @State private var hapticsFired: Set<Int> = []

    private let target = CourseDataLoader.findMark(named: "SYC 4")!
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var startTime: Date {
        gunTime.addingTimeInterval(TimeInterval(startOffsetMinutes * 60))
    }

    private var bearingSnapshot: BearingSnapshot? {
        locationService.snapshot(to: target)
    }

    private var assistSnapshot: StartAssistSnapshot {
        NavigationMath.timeToBurn(startTime: startTime, now: now, timeToMark: bearingSnapshot?.timeToMark)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Target: \(target.name)")
                    .font(.largeTitle.bold())

                DatePicker("Race gun time", selection: $gunTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)

                Stepper("Start offset: \(startOffsetMinutes) min", value: $startOffsetMinutes, in: 0...120)
                    .font(.headline)

                Button {
                    gunTime = Date()
                    now = gunTime
                    hapticsFired.removeAll()
                } label: {
                    Label("Sync Gun Now", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                MetricBlock(title: "Your Start", value: AppFormatters.clock(startTime))

                if let bearingSnapshot {
                    LocationSanityWarningView(snapshot: bearingSnapshot)
                    HStack(spacing: 12) {
                        MetricBlock(title: "Bearing", value: AppFormatters.bearing(bearingSnapshot.bearingTrue))
                        MetricBlock(title: "Distance", value: AppFormatters.distanceNm(bearingSnapshot.distanceNm))
                    }
                    HStack(spacing: 12) {
                        MetricBlock(title: "SOG", value: AppFormatters.speedKnots(bearingSnapshot.speedOverGroundKnots))
                        MetricBlock(title: "To Mark", value: AppFormatters.duration(bearingSnapshot.timeToMark))
                    }
                } else {
                    LocationUnavailableView(status: "Start Assist needs GPS to calculate the run to SYC 4.", error: locationService.errorMessage)
                }

                HStack(spacing: 12) {
                    MetricBlock(title: "To Start", value: signedDuration(assistSnapshot.timeToStart))
                    MetricBlock(title: "To Burn", value: burnLabel(assistSnapshot.timeToBurn))
                }

                Button {
                    locationService.requestLocation()
                } label: {
                    Label("Refresh GPS", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding()
        }
        .navigationTitle("Start Assist")
        .onAppear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
            locationService.startActiveUpdates()
        }
        .onDisappear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = false
            #endif
            locationService.stopActiveUpdates()
        }
        .onReceive(timer) { value in
            now = value
            fireHapticIfNeeded()
        }
    }

    private func burnLabel(_ interval: TimeInterval?) -> String {
        guard let interval else { return "--:--" }
        if abs(interval) <= 5 {
            return "ON TIME"
        }
        if interval > 0 {
            return "BURN \(AppFormatters.duration(interval))"
        }
        return "LATE \(AppFormatters.duration(interval))"
    }

    private func signedDuration(_ interval: TimeInterval) -> String {
        interval < 0 ? "-\(AppFormatters.duration(interval))" : AppFormatters.duration(interval)
    }

    private func fireHapticIfNeeded() {
        let wholeSeconds = Int(assistSnapshot.timeToStart.rounded())
        guard [60, 30, 10, 0].contains(wholeSeconds), !hapticsFired.contains(wholeSeconds) else {
            return
        }
        hapticsFired.insert(wholeSeconds)
        #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(wholeSeconds == 0 ? .success : .warning)
        #endif
    }
}
