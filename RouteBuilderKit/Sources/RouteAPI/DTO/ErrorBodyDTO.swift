import Foundation

public struct ErrorBodyDTO: Decodable {
    public let error: String?

    private enum CodingKeys: String, CodingKey {
        case error
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        error = (try? c.decodeIfPresent(String.self, forKey: .error)) ?? nil
    }
}
