import Foundation

/// Decodes an array element by element, skipping elements that fail to decode.
public struct LossyArray<Element: Decodable>: Decodable {
    public let elements: [Element]
    public let skippedCount: Int

    public init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        var elements: [Element] = []
        var skipped = 0
        while !container.isAtEnd {
            do {
                elements.append(try container.decode(Element.self))
            } catch {
                skipped += 1
                // A failed decode does not advance the container; consume the element.
                _ = try? container.decode(DiscardedValue.self)
            }
        }
        self.elements = elements
        self.skippedCount = skipped
    }
}

extension LossyArray: Sendable where Element: Sendable {}

private struct DiscardedValue: Decodable {
    init(from decoder: Decoder) throws {}
}
