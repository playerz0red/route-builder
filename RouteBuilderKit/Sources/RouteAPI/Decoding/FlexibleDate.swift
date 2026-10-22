import Foundation

/// Decodes a date from an ISO 8601 string (with or without fractional seconds,
/// with or without a time zone; no zone means UTC) or from a JSON number
/// (epoch seconds). Anything else becomes `nil`. Never throws.
public struct FlexibleDate: Decodable, Sendable {
    public let value: Date?

    public init(from decoder: Decoder) throws {
        guard let container = try? decoder.singleValueContainer() else {
            value = nil
            return
        }
        if let seconds = try? container.decode(Double.self) {
            value = Date(timeIntervalSince1970: seconds)
        } else if let string = try? container.decode(String.self) {
            value = FlexibleDate.parse(string)
        } else {
            value = nil
        }
    }

    static func parse(_ raw: String) -> Date? {
        var string = raw.trimmingCharacters(in: .whitespaces)
        guard !string.isEmpty else { return nil }
        if !hasTimeZone(string) { string += "Z" }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func hasTimeZone(_ string: String) -> Bool {
        if string.hasSuffix("Z") || string.hasSuffix("z") { return true }
        // An offset like +02:00 / -0500 can only appear after the time separator.
        guard let tIndex = string.firstIndex(where: { $0 == "T" || $0 == "t" }) else { return false }
        return string[tIndex...].contains { $0 == "+" || $0 == "-" }
    }
}
