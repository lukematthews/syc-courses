import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum AppColors {
    static var groupedBackground: Color {
        #if canImport(UIKit)
        Color(UIColor.systemGroupedBackground)
        #else
        Color.gray.opacity(0.08)
        #endif
    }
}

struct CourseCardView: View {
    let course: Course

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Text("Course \(course.courseNumber)")
                .font(.title2.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer()
            PennantHoistView(number: course.courseNumber)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.quaternary, lineWidth: 1)
        )
    }
}

struct PennantStripView: View {
    let number: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(String(number).enumerated()), id: \.offset) { _, digit in
                PennantView(digit: digit)
            }
        }
    }
}

struct PennantHoistView: View {
    let number: Int

    var body: some View {
        HStack(alignment: .top, spacing: 5) {
            Rectangle()
                .fill(.secondary.opacity(0.35))
                .frame(width: 2)
                .padding(.vertical, 2)

            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(String(number).enumerated()), id: \.offset) { _, digit in
                    PennantView(digit: digit)
                }
            }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Course \(number) pennants")
    }
}

struct PennantView: View {
    let digit: Character
    var width: CGFloat = 76
    var height: CGFloat = 29

    var body: some View {
        PennantArtwork(digit: digit)
            .frame(width: width, height: height)
            .accessibilityLabel("Numeral pennant \(String(digit))")
    }
}

private struct PennantArtwork: View {
    let digit: Character

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 240, proxy.size.height / 90)

            ZStack {
                switch digit {
                case "0":
                    flag(fill: .pennantYellow, stroke: .pennantGrey, scale: scale)
                    polygon([(65, 19.4), (126, 23.4), (126, 66.6), (65, 70.6)])
                        .fill(Color.pennantRed)
                    polygon([(126, 23.4), (226, 30), (226, 60), (126, 66.6)])
                        .fill(Color.pennantYellow)
                case "1":
                    flag(fill: .white, stroke: .pennantPinkStroke, scale: scale)
                    ellipse(cx: 78, cy: 45, rx: 31, ry: 24)
                        .fill(Color.pennantRed)
                case "2":
                    flag(fill: .pennantBlue, stroke: .pennantBlue, scale: scale)
                    ellipse(cx: 78, cy: 45, rx: 29, ry: 23)
                        .fill(Color.white)
                case "3":
                    flag(fill: .white, stroke: .pennantGrey, scale: scale)
                    ZStack {
                        polygon([(14, 16), (82, 20.5), (82, 69.5), (14, 74)])
                            .fill(Color.pennantRed)
                        polygon([(82, 20.5), (151, 25), (151, 65), (82, 69.5)])
                            .fill(Color.white)
                        polygon([(151, 25), (226, 30), (226, 60), (151, 65)])
                            .fill(Color.pennantBlue)
                    }
                    .clipShape(PennantFlagShape())
                case "4":
                    flag(fill: .pennantRed, stroke: .pennantRed, scale: scale)
                    ZStack {
                        polygon([(14, 39), (226, 43), (226, 52), (14, 51)])
                            .fill(Color.white)
                        polygon([(62, 16), (72, 16.7), (72, 72.4), (62, 73.1)])
                            .fill(Color.white)
                    }
                    .clipShape(PennantFlagShape())
                case "5":
                    flag(fill: .pennantBlue, stroke: .pennantGrey, scale: scale)
                    polygon([(14, 16), (108, 22.2), (108, 67.8), (14, 74)])
                        .fill(Color.pennantYellow)
                        .clipShape(PennantFlagShape())
                case "6":
                    flag(fill: .white, stroke: .pennantGrey, scale: scale)
                    polygon([(14, 16), (226, 30), (226, 45), (14, 45)])
                        .fill(Color.pennantBlack)
                        .clipShape(PennantFlagShape())
                case "7":
                    flag(fill: .pennantRed, stroke: .pennantGrey, scale: scale)
                    polygon([(14, 16), (226, 30), (226, 45), (14, 45)])
                        .fill(Color.pennantYellow)
                        .clipShape(PennantFlagShape())
                case "8":
                    flag(fill: .white, stroke: .pennantPinkStroke, scale: scale)
                    ZStack {
                        polygon([(14, 39), (226, 43), (226, 52), (14, 51)])
                            .fill(Color.pennantRed)
                        polygon([(62, 16), (72, 16.7), (72, 72.4), (62, 73.1)])
                            .fill(Color.pennantRed)
                    }
                    .clipShape(PennantFlagShape())
                case "9":
                    flag(fill: .pennantYellow, stroke: .pennantBlack, scale: scale)
                    ZStack {
                        polygon([(14, 16), (95, 21.3), (95, 45), (14, 45)])
                            .fill(Color.pennantBlack)
                        polygon([(95, 21.3), (226, 30), (226, 45), (95, 45)])
                            .fill(Color.white)
                        polygon([(14, 45), (95, 45), (95, 68.7), (14, 74)])
                            .fill(Color.pennantRed)
                        polygon([(95, 45), (226, 45), (226, 60), (95, 68.7)])
                            .fill(Color.pennantYellow)
                    }
                    .clipShape(PennantFlagShape())
                default:
                    flag(fill: .gray.opacity(0.25), stroke: .gray, scale: scale)
                }
            }
        }
        .aspectRatio(240 / 90, contentMode: .fit)
    }

    private func flag(fill: Color, stroke: Color, scale: CGFloat) -> some View {
        PennantFlagShape()
            .fill(fill)
            .overlay(PennantFlagShape().stroke(stroke, lineWidth: 4 * scale))
    }

    private func polygon(_ points: [(CGFloat, CGFloat)]) -> PennantPolygonShape {
        PennantPolygonShape(points: points)
    }

    private func ellipse(cx: CGFloat, cy: CGFloat, rx: CGFloat, ry: CGFloat) -> some Shape {
        ScaledEllipse(cx: cx, cy: cy, rx: rx, ry: ry)
    }
}

private struct PennantFlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        PennantPolygonShape(points: [(14, 16), (226, 30), (226, 60), (14, 74)])
            .path(in: rect)
    }
}

private struct PennantPolygonShape: Shape {
    let points: [(CGFloat, CGFloat)]

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 240
        let scaleY = rect.height / 90
        var path = Path()

        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: first.0 * scaleX, y: first.1 * scaleY))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: point.0 * scaleX, y: point.1 * scaleY))
        }
        path.closeSubpath()
        return path
    }
}

private struct ScaledEllipse: Shape {
    let cx: CGFloat
    let cy: CGFloat
    let rx: CGFloat
    let ry: CGFloat

    func path(in rect: CGRect) -> Path {
        let scaleX = rect.width / 240
        let scaleY = rect.height / 90
        let ellipseRect = CGRect(
            x: (cx - rx) * scaleX,
            y: (cy - ry) * scaleY,
            width: rx * 2 * scaleX,
            height: ry * 2 * scaleY
        )
        return Path(ellipseIn: ellipseRect)
    }
}

private extension Color {
    static let pennantRed = Color(red: 239 / 255, green: 23 / 255, blue: 64 / 255)
    static let pennantBlue = Color(red: 7 / 255, green: 21 / 255, blue: 143 / 255)
    static let pennantYellow = Color(red: 1, green: 224 / 255, blue: 27 / 255)
    static let pennantGrey = Color(red: 154 / 255, green: 160 / 255, blue: 166 / 255)
    static let pennantPinkStroke = Color(red: 231 / 255, green: 163 / 255, blue: 173 / 255)
    static let pennantBlack = Color(red: 5 / 255, green: 5 / 255, blue: 5 / 255)
}

struct ChartImageView: View {
    let chartImage: String

    var body: some View {
        #if canImport(UIKit)
        if let image = loadImage() {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ContentUnavailableView("Chart unavailable", systemImage: "photo")
        }
        #else
        ContentUnavailableView("Chart available on iPhone", systemImage: "photo")
        #endif
    }

    #if canImport(UIKit)
    private func loadImage() -> UIImage? {
        let fileName = URL(fileURLWithPath: chartImage).lastPathComponent
        let name = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        let url = Bundle.module.url(forResource: name, withExtension: "png", subdirectory: "course-charts")
            ?? Bundle.module.url(forResource: name, withExtension: "png")

        guard let url else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
    #endif
}

struct LocationSanityWarningView: View {
    let snapshot: BearingSnapshot

    var body: some View {
        if snapshot.distanceNm > 100 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Location looks far from SYC")
                    .font(.headline)
                Text("Current location: \(snapshot.currentLatitude.formatted(.number.precision(.fractionLength(5)))), \(snapshot.currentLongitude.formatted(.number.precision(.fractionLength(5))))")
                    .font(.subheadline.monospacedDigit())
                Text("Distance uses the simulator/device GPS location. In Simulator, set Features > Location to a position near Sandringham Yacht Club for race-day distances.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.orange.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct NavigationSourceStatusLine: View {
    let summary: NavigationSourceSummary

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: summary.activeSource == .actisense ? "antenna.radiowaves.left.and.right" : "location")
                .foregroundStyle(.secondary)
            Text(summary.statusMessage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
            if let lastUpdate = summary.lastUpdate {
                Text(lastUpdate.formatted(date: .omitted, time: .standard))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MetricBlock: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }
}

struct LocationUnavailableView: View {
    let status: String
    let error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Waiting for GPS")
                .font(.headline)
            Text(error ?? status)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.yellow.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
