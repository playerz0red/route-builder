import Foundation

public struct StopsPageDTO: Decodable, Sendable {
    public let items: [StopDTO]
    public let skippedCount: Int
    public let page: Int?

    public init(items: [StopDTO], skippedCount: Int = 0, page: Int? = nil) {
        self.items = items
        self.skippedCount = skippedCount
        self.page = page
    }

    // total / total_pages / has_more are intentionally not decoded (unreliable on the server).
    private enum CodingKeys: String, CodingKey {
        case items
        case page
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let lossy = (try? c.decodeIfPresent(LossyArray<StopDTO>.self, forKey: .items)) ?? nil {
            items = lossy.elements
            skippedCount = lossy.skippedCount
        } else {
            items = []
            skippedCount = 0
        }
        page = (try? c.decodeIfPresent(Int.self, forKey: .page)) ?? nil
    }
}
