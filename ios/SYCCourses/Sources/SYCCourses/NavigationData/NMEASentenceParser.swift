import Foundation

struct ParsedNMEAUpdate: Equatable {
    var fix: NavigationFix?
    var sogKnots: Double?
    var cogDegrees: Double?
    var headingDegrees: Double?
    var validFix: Bool?
    var hdop: Double?
}

enum NMEASentenceParser {
    static func parse(_ sentence: String, now: Date = Date()) -> ParsedNMEAUpdate? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("$") || trimmed.hasPrefix("!") else { return nil }

        let withoutStart = String(trimmed.dropFirst())
        let body = withoutStart.split(separator: "*", maxSplits: 1).first.map(String.init) ?? withoutStart
        let fields = body.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard let talkerAndType = fields.first, talkerAndType.count >= 3 else { return nil }

        let type = String(talkerAndType.suffix(3))
        switch type {
        case "RMC": return parseRMC(fields, now: now)
        case "GGA": return parseGGA(fields, now: now)
        case "VTG": return parseVTG(fields)
        case "HDT", "HDM": return parseHeading(fields, valueIndex: 1)
        case "HDG": return parseHeading(fields, valueIndex: 1)
        default: return nil
        }
    }

    private static func parseRMC(_ fields: [String], now: Date) -> ParsedNMEAUpdate? {
        guard fields.count > 9 else { return nil }
        let valid = fields[2] == "A"
        guard let latitude = parseCoordinate(value: fields[3], hemisphere: fields[4]),
              let longitude = parseCoordinate(value: fields[5], hemisphere: fields[6])
        else {
            return ParsedNMEAUpdate(validFix: false)
        }
        let sog = Double(fields[7])
        let cog = Double(fields[8])
        let timestamp = parseDate(time: fields[1], date: fields[9]) ?? now
        let fix = NavigationFix(
            latitude: latitude,
            longitude: longitude,
            sogKnots: sog,
            cogDegrees: cog,
            headingDegrees: nil,
            timestamp: timestamp,
            source: .actisense,
            horizontalAccuracyMeters: nil,
            hdop: nil,
            validFix: valid
        )
        return ParsedNMEAUpdate(fix: fix, sogKnots: sog, cogDegrees: cog, validFix: valid)
    }

    private static func parseGGA(_ fields: [String], now: Date) -> ParsedNMEAUpdate? {
        guard fields.count > 8 else { return nil }
        let quality = Int(fields[6]) ?? 0
        let valid = quality > 0
        guard let latitude = parseCoordinate(value: fields[2], hemisphere: fields[3]),
              let longitude = parseCoordinate(value: fields[4], hemisphere: fields[5])
        else {
            return ParsedNMEAUpdate(validFix: false)
        }
        let hdop = Double(fields[8])
        let fix = NavigationFix(
            latitude: latitude,
            longitude: longitude,
            sogKnots: nil,
            cogDegrees: nil,
            headingDegrees: nil,
            timestamp: parseTimeToday(fields[1], now: now) ?? now,
            source: .actisense,
            horizontalAccuracyMeters: hdop.map { $0 * 5 },
            hdop: hdop,
            validFix: valid
        )
        return ParsedNMEAUpdate(fix: fix, validFix: valid, hdop: hdop)
    }

    private static func parseVTG(_ fields: [String]) -> ParsedNMEAUpdate? {
        guard fields.count > 7 else { return nil }
        return ParsedNMEAUpdate(
            sogKnots: Double(fields[5]),
            cogDegrees: Double(fields[1])
        )
    }

    private static func parseHeading(_ fields: [String], valueIndex: Int) -> ParsedNMEAUpdate? {
        guard fields.indices.contains(valueIndex), let heading = Double(fields[valueIndex]) else { return nil }
        return ParsedNMEAUpdate(headingDegrees: heading)
    }

    private static func parseCoordinate(value: String, hemisphere: String) -> Double? {
        guard let raw = Double(value), raw > 0 else { return nil }
        let degrees = floor(raw / 100)
        let minutes = raw - degrees * 100
        var decimal = degrees + minutes / 60
        if hemisphere == "S" || hemisphere == "W" {
            decimal = -decimal
        }
        return decimal
    }

    private static func parseDate(time: String, date: String) -> Date? {
        guard date.count == 6 else { return nil }
        var components = parseTimeComponents(time) ?? DateComponents()
        let start = date.startIndex
        components.day = Int(date[start..<date.index(start, offsetBy: 2)])
        components.month = Int(date[date.index(start, offsetBy: 2)..<date.index(start, offsetBy: 4)])
        if let year = Int(date[date.index(start, offsetBy: 4)..<date.index(start, offsetBy: 6)]) {
            components.year = year >= 80 ? 1900 + year : 2000 + year
        }
        components.timeZone = TimeZone(secondsFromGMT: 0)
        return Calendar(identifier: .gregorian).date(from: components)
    }

    private static func parseTimeToday(_ time: String, now: Date) -> Date? {
        guard var timeComponents = parseTimeComponents(time) else { return nil }
        let calendar = Calendar(identifier: .gregorian)
        let dateComponents = calendar.dateComponents(in: TimeZone(secondsFromGMT: 0)!, from: now)
        timeComponents.year = dateComponents.year
        timeComponents.month = dateComponents.month
        timeComponents.day = dateComponents.day
        timeComponents.timeZone = TimeZone(secondsFromGMT: 0)
        return calendar.date(from: timeComponents)
    }

    private static func parseTimeComponents(_ time: String) -> DateComponents? {
        guard time.count >= 6 else { return nil }
        let start = time.startIndex
        return DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            hour: Int(time[start..<time.index(start, offsetBy: 2)]),
            minute: Int(time[time.index(start, offsetBy: 2)..<time.index(start, offsetBy: 4)]),
            second: Int(time[time.index(start, offsetBy: 4)..<time.index(start, offsetBy: 6)])
        )
    }
}

