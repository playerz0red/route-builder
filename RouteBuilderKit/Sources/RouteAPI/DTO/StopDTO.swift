import Foundation

public struct StopDTO: Decodable, Sendable, Equatable {
    public let id: String
    public let name: String
    public let address: String
    public let phone: String
    public let packagesMax: Int?
    public let lastDeliveryAt: Date?
    public let zone: String?
    public let notes: String?

    public init(
        id: String,
        name: String,
        address: String = "",
        phone: String = "",
        packagesMax: Int? = nil,
        lastDeliveryAt: Date? = nil,
        zone: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.phone = phone
        self.packagesMax = packagesMax
        self.lastDeliveryAt = lastDeliveryAt
        self.zone = zone
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case phone
        case packagesMax = "packages_max"
        case lastDeliveryAt = "last_delivery_at"
        case zone
        case notes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)

        let id = try c.decode(String.self, forKey: .id)
        guard !id.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Empty stop id")
        }
        let name = try c.decode(String.self, forKey: .name)
        guard !name.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .name, in: c, debugDescription: "Empty stop name")
        }

        self.id = id
        self.name = name
        self.address = (try? c.decodeIfPresent(String.self, forKey: .address)) ?? ""
        self.phone = (try? c.decodeIfPresent(String.self, forKey: .phone)) ?? ""
        self.packagesMax = (try? c.decodeIfPresent(FlexibleInt.self, forKey: .packagesMax))?.value
        self.lastDeliveryAt = (try? c.decodeIfPresent(FlexibleDate.self, forKey: .lastDeliveryAt))?.value
        self.zone = (try? c.decodeIfPresent(String.self, forKey: .zone)) ?? nil
        self.notes = (try? c.decodeIfPresent(String.self, forKey: .notes)) ?? nil
    }
}
