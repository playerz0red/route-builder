import Foundation

public struct RouteStopPayload: Codable, Sendable, Equatable {
    public let stopID: String
    public let packages: Int
    public let instructions: String

    public init(stopID: String, packages: Int, instructions: String) {
        self.stopID = stopID
        self.packages = packages
        self.instructions = instructions
    }

    private enum CodingKeys: String, CodingKey {
        case stopID = "stop_id"
        case packages
        case instructions
    }
}

public struct CreateRouteResponseDTO: Decodable {
    public let id: String
    public let stops: [RouteStopPayload]?
    public let status: String?
}
