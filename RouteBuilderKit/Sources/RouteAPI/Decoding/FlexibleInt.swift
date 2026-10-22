import Foundation

/// Decodes a positive integer that may arrive as a JSON number or a numeric string.
/// Anything else (null, garbage, zero, negatives) becomes `nil`. Never throws.
public struct FlexibleInt: Decodable, Sendable {
    public let value: Int?

    public init(from decoder: Decoder) throws {
        guard let container = try? decoder.singleValueContainer() else {
            value = nil
            return
        }
        let parsed: Int?
        if let int = try? container.decode(Int.self) {
            parsed = int
        } else if let string = try? container.decode(String.self) {
            parsed = Int(string.trimmingCharacters(in: .whitespaces))
        } else {
            parsed = nil
        }
        if let parsed, parsed > 0 {
            value = parsed
        } else {
            value = nil
        }
    }
}
