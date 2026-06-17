import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum LineMode: String, CaseIterable, Identifiable {
    case start
    case finish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .start: "Start Line"
        case .finish: "Finish Line"
        }
    }

    var countdownLabel: String {
        switch self {
        case .start: "Time To Start"
        case .finish: "Time To Finish"
        }
    }
}

struct StartAssistView: View {
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var navigationDataService: NavigationDataService
    @AppStorage("lastStartOffsetMinutes") private var startOffsetMinutes = 10
    @AppStorage("lastRaceGunTime") private var storedGunTime = Date().timeIntervalSinceReferenceDate
    @State private var lineMode: LineMode = .start
    @State private var gunTime = Date()
    @State private var now = Date()
    @State private var hapticsFired: Set<Int> = []
    @State private var offsetEntry = "10"
    @State private var isOffsetPickerPresented = false
    @FocusState private var isOffsetFieldFocused: Bool

    private let lineStart = CourseDataLoader.findMark(named: "SYC 4")!
    private let lineEnd = CourseDataLoader.findMark(named: "SYC Tower")!
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let offsetRange = -5...25

    private var startTime: Date {
        gunTime.addingTimeInterval(TimeInterval(startOffsetMinutes * 60))
    }

    private var activeFix: NavigationFix? {
        navigationDataService.activeFix(iPhoneFix: locationService.navigationFix, now: now)
    }

    private var crossingResult: LineCrossingResult {
        LineCrossingCalculator.calculate(fix: activeFix, lineStart: lineStart, lineEnd: lineEnd)
    }

    private var sourceSummary: NavigationSourceSummary {
        navigationDataService.sourceSummary(iPhoneFix: locationService.navigationFix, now: now)
    }

    private var assistSnapshot: StartAssistSnapshot {
        NavigationMath.timeToBurn(startTime: startTime, now: now, timeToMark: crossingResult.timeToLine)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    header
                    modePicker
                    if lineMode == .start {
                        controls
                    }
                    mainCountdown
                    metricsGrid
                    statusCard
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
        }
        .navigationTitle("")
        .startAssistNavigationChrome()
        .onAppear {
            #if canImport(UIKit)
            UIApplication.shared.isIdleTimerDisabled = true
            #endif
            startOffsetMinutes = clampedOffset(startOffsetMinutes)
            offsetEntry = "\(startOffsetMinutes)"
            gunTime = Date(timeIntervalSinceReferenceDate: storedGunTime)
            locationService.startActiveUpdates()
            if navigationDataService.actisenseConfig.isConfigured,
               navigationDataService.actisenseStatus == .disconnected {
                Task { await navigationDataService.connectActisense() }
            }
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
        .onChange(of: startOffsetMinutes) { _, value in
            if !isOffsetFieldFocused {
                offsetEntry = "\(clampedOffset(value))"
            }
        }
        .onChange(of: gunTime) { _, value in
            storedGunTime = value.timeIntervalSinceReferenceDate
        }
        .sheet(isPresented: $isOffsetPickerPresented) {
            StartAssistOffsetPicker(selectedOffset: startOffsetMinutes, offsetRange: offsetRange) { value in
                setOffset(value)
                isOffsetPickerPresented = false
            }
            .presentationDragIndicator(.visible)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(lineMode.title)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Text("SYC 4 ↔ SYC Tower")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(StartAssistColors.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer()
            if lineMode == .start {
                Button {
                    syncGunNow()
                } label: {
                    Label("Sync", systemImage: "location.north.fill")
                        .font(.headline.weight(.bold))
                        .frame(height: 42)
                        .padding(.horizontal, 12)
                }
                .buttonStyle(StartAssistBlueButtonStyle())
            }
        }
    }

    private var modePicker: some View {
        Picker("Line mode", selection: $lineMode) {
            ForEach(LineMode.allCases) { mode in
                Text(mode.rawValue.capitalized).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .colorScheme(.dark)
    }

    private var controls: some View {
        HStack(alignment: .bottom, spacing: 24) {
            VStack(alignment: .leading, spacing: 4) {
                StartAssistLabel("Race Gun")
                DatePicker("", selection: $gunTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(.white)
                    .colorScheme(.dark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 42)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                StartAssistLabel("Offset")
                HStack(spacing: 8) {
                    TextField("0", text: $offsetEntry)
                        .startAssistOffsetKeyboard()
                        .focused($isOffsetFieldFocused)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .frame(width: 62)
                        .onSubmit(commitOffsetEntry)
                        .onChange(of: isOffsetFieldFocused) { _, focused in
                            if !focused {
                                commitOffsetEntry()
                            }
                        }
                    Spacer()
                    Button {
                        isOffsetFieldFocused = false
                        isOffsetPickerPresented = true
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                    }
                }
                .frame(height: 42)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var mainCountdown: some View {
        VStack(spacing: 4) {
            StartAssistLabel(lineMode.countdownLabel)
                .frame(maxWidth: .infinity, alignment: .center)
            Text(primaryCountdownText)
                .font(.system(size: 68, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
            if primaryCountdownText.contains(":") {
                HStack {
                    Text("MIN")
                        .frame(maxWidth: .infinity)
                    Text("SEC")
                        .frame(maxWidth: .infinity)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(StartAssistColors.secondaryText)
            }
        }
    }

    private var metricsGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                StartAssistTile(title: "Dist To Line", value: distanceToLineText, accent: .white)
                StartAssistTile(title: "SOG", value: sogText, accent: .white)
            }
            if lineMode == .start {
                HStack(spacing: 16) {
                    StartAssistTile(title: "Time To Line", value: timeToLineText, accent: StartAssistColors.blue)
                    StartAssistTile(title: "Time To Burn", value: burnTileText(assistSnapshot.timeToBurn), accent: burnColor(assistSnapshot.timeToBurn))
                }
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            StartAssistLabel("Status")
            Text(statusText)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(statusColor)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Image(systemName: "scope")
            Text(sourceSummary.statusMessage)
                .fontWeight(.semibold)
            if let lastUpdate = sourceSummary.lastUpdate {
                Text(lastUpdate.formatted(date: .omitted, time: .standard))
                    .monospacedDigit()
            }
        }
        .font(.subheadline)
        .foregroundStyle(StartAssistColors.secondaryText)
    }

    private var primaryCountdownText: String {
        switch lineMode {
        case .start:
            countdownText(assistSnapshot.timeToStart)
        case .finish:
            timeToLineText
        }
    }

    private var distanceToLineText: String {
        guard let meters = crossingResult.distanceMeters else { return "NO GPS" }
        return meters < 1000 ? "\(Int(meters.rounded())) m" : String(format: "%.2f km", meters / 1000)
    }

    private var sogText: String {
        guard activeFix != nil else { return "NO GPS" }
        guard let speed = activeFix?.sogKnots else { return "NO SOG" }
        return String(format: "%.1f kt", max(0, speed))
    }

    private var timeToLineText: String {
        guard let timeToLine = crossingResult.timeToLine else {
            return unavailableText(for: crossingResult.status)
        }
        return AppFormatters.duration(timeToLine)
    }

    private var statusText: String {
        switch crossingResult.status {
        case .approachingLine: "APPROACHING"
        case .crossingAhead: "CROSSING AHEAD"
        case .crossingOutsideSegment: "OUTSIDE LINE"
        case .parallel: "PARALLEL"
        case .movingAway: "MOVING AWAY"
        case .insufficientData: "NO DATA"
        }
    }

    private var statusColor: Color {
        switch crossingResult.status {
        case .approachingLine, .crossingAhead: .white
        case .insufficientData: StartAssistColors.secondaryText
        case .crossingOutsideSegment, .parallel, .movingAway: .orange
        }
    }

    private func unavailableText(for status: LineCrossingStatus) -> String {
        switch status {
        case .approachingLine, .crossingAhead: "--:--"
        case .crossingOutsideSegment: "OUTSIDE LINE"
        case .parallel: "PARALLEL"
        case .movingAway: "MOVING AWAY"
        case let .insufficientData(reason):
            switch reason {
            case .noGPS: "NO GPS"
            case .noCOG: "NO COG"
            case .noSOG: "NO SOG"
            }
        }
    }

    private func burnTileText(_ interval: TimeInterval?) -> String {
        guard let interval else { return "--:--" }
        if abs(interval) <= 5 {
            return "ON TIME"
        }
        if interval < 0 {
            return "EARLY \(AppFormatters.duration(interval))"
        }
        return AppFormatters.duration(interval)
    }

    private func burnColor(_ interval: TimeInterval?) -> Color {
        guard let interval else { return StartAssistColors.secondaryText }
        if abs(interval) <= 5 {
            return .green
        }
        return interval < 0 ? .red : StartAssistColors.blue
    }

    private func countdownText(_ interval: TimeInterval) -> String {
        let seconds = Int(abs(interval).rounded())
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func syncGunNow() {
        gunTime = Date()
        now = gunTime
        storedGunTime = gunTime.timeIntervalSinceReferenceDate
        hapticsFired.removeAll()
    }

    private func setOffset(_ value: Int) {
        let clamped = clampedOffset(value)
        startOffsetMinutes = clamped
        offsetEntry = "\(clamped)"
        isOffsetFieldFocused = false
    }

    private func commitOffsetEntry() {
        guard let value = Int(offsetEntry.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            offsetEntry = "\(startOffsetMinutes)"
            return
        }
        setOffset(value)
    }

    private func clampedOffset(_ value: Int) -> Int {
        min(max(value, offsetRange.lowerBound), offsetRange.upperBound)
    }

    private func refreshPosition() {
        locationService.requestLocation()
        if navigationDataService.actisenseConfig.isConfigured,
           navigationDataService.actisenseStatus == .disconnected {
            Task { await navigationDataService.connectActisense() }
        }
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

private struct StartAssistOffsetPicker: View {
    let selectedOffset: Int
    let offsetRange: ClosedRange<Int>
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                Text("Offset")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(offsetRange), id: \.self) { value in
                            Button {
                                onSelect(value)
                            } label: {
                                HStack {
                                    Text("\(value) min")
                                        .font(.title3.weight(value == selectedOffset ? .bold : .semibold))
                                        .monospacedDigit()
                                    Spacer()
                                    if value == selectedOffset {
                                        Image(systemName: "checkmark")
                                            .font(.headline.weight(.bold))
                                            .foregroundStyle(StartAssistColors.blue)
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 22)
                                .frame(height: 52)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .id(value)

                            if value != offsetRange.upperBound {
                                Divider()
                                    .overlay(StartAssistColors.border)
                                    .padding(.leading, 22)
                            }
                        }
                    }
                }
            }
            .background(Color.black)
            .onAppear {
                proxy.scrollTo(selectedOffset, anchor: .center)
            }
        }
    }
}

private enum StartAssistColors {
    static let card = Color.white.opacity(0.035)
    static let control = Color.white.opacity(0.025)
    static let border = Color.white.opacity(0.18)
    static let secondaryText = Color.white.opacity(0.62)
    static let blue = Color(red: 0.22, green: 0.45, blue: 1.0)
}

private struct StartAssistLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title.uppercased())
            .font(.caption.weight(.black))
            .tracking(0.8)
            .foregroundStyle(StartAssistColors.secondaryText)
    }
}

private struct StartAssistTile: View {
    let title: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            StartAssistLabel(title)
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(accent)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
    }
}

private struct StartAssistIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(.white.opacity(configuration.isPressed ? 0.16 : 0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(StartAssistColors.border, lineWidth: 1.2))
    }
}

private struct StartAssistBlueButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(StartAssistColors.blue)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

private extension View {
    @ViewBuilder
    func startAssistNavigationChrome() -> some View {
        #if canImport(UIKit)
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func startAssistOffsetKeyboard() -> some View {
        #if canImport(UIKit)
        self.keyboardType(.numbersAndPunctuation)
        #else
        self
        #endif
    }
}
