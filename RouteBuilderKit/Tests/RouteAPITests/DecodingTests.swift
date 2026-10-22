import XCTest
@testable import RouteAPI

final class DecodingTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    private let decoder = JSONDecoder()

    func testFlexibleIntVariants() throws {
        let json = #"[5, "7", null, "abc", 0, -3]"#
        let values = try decoder.decode([FlexibleInt].self, from: Data(json.utf8)).map(\.value)
        XCTAssertEqual(values, [5, 7, nil, nil, nil, nil])
    }

    func testFlexibleDateVariants() throws {
        let json = #"["2026-10-22T08:37:32.584Z", "2026-10-22T08:37:32.584", 1792651052, "yesterday"]"#
        let values = try decoder.decode([FlexibleDate].self, from: Data(json.utf8)).map(\.value)
        XCTAssertEqual(values.count, 4)
        let withZ = try XCTUnwrap(values[0])
        let withoutZ = try XCTUnwrap(values[1])
        XCTAssertEqual(withZ, withoutZ)
        XCTAssertEqual(withZ.timeIntervalSince1970, 1792658252.584, accuracy: 0.001)
        XCTAssertEqual(values[2], Date(timeIntervalSince1970: 1792651052))
        XCTAssertNil(values[3])
    }

    func testRealPageDecodesAll24() throws {
        let page = try decoder.decode(StopsPageDTO.self, from: try fixture("stops_page1_size50"))
        XCTAssertEqual(page.items.count, 24)
        XCTAssertEqual(page.skippedCount, 0)
        XCTAssertEqual(page.page, 1)

        let s1000 = try XCTUnwrap(page.items.first { $0.id == "stp_1000" })
        XCTAssertNil(s1000.packagesMax)
        XCTAssertNil(s1000.notes)

        let s1003 = try XCTUnwrap(page.items.first { $0.id == "stp_1003" })
        XCTAssertEqual(s1003.packagesMax, 7)

        let s1002 = try XCTUnwrap(page.items.first { $0.id == "stp_1002" })
        XCTAssertNotNil(s1002.lastDeliveryAt)
    }

    func testNullItemsBecomesEmpty() throws {
        let page = try decoder.decode(StopsPageDTO.self, from: try fixture("search_sov_null"))
        XCTAssertTrue(page.items.isEmpty)
        XCTAssertEqual(page.skippedCount, 0)
    }

    func testLossyArraySkipsInvalid() throws {
        let page = try decoder.decode(StopsPageDTO.self, from: try fixture("stops_lossy"))
        XCTAssertEqual(page.items.count, 2)
        XCTAssertEqual(page.skippedCount, 2)
        let garbage = try XCTUnwrap(page.items.last)
        XCTAssertEqual(garbage.id, "stp_9004")
        XCTAssertNil(garbage.packagesMax)
        XCTAssertNil(garbage.lastDeliveryAt)
    }

    func testRouteCreatedDecodes() throws {
        let dto = try decoder.decode(CreateRouteResponseDTO.self, from: try fixture("route_created"))
        XCTAssertEqual(dto.id, "rt_2000")
        XCTAssertEqual(dto.stops?.first?.stopID, "stp_1002")
        XCTAssertEqual(dto.status, "draft")
    }

    func testPayloadEncodesSnakeCase() throws {
        let payload = RouteStopPayload(stopID: "stp_1", packages: 2, instructions: "Ring twice")
        let json = String(decoding: try JSONEncoder().encode(payload), as: UTF8.self)
        XCTAssertTrue(json.contains("\"stop_id\""))
        XCTAssertFalse(json.contains("stopID"))
    }
}
