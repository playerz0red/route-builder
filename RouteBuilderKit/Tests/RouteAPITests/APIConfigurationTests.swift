import XCTest
@testable import RouteAPI

final class APIConfigurationTests: XCTestCase {
    func testValidHTTPURL() {
        let url = APIConfiguration.baseURL(fromInfoValue: "http://10.204.20.147:4000")
        XCTAssertNotNil(url)
        XCTAssertEqual(url?.host, "10.204.20.147")
        XCTAssertEqual(url?.port, 4000)
    }

    func testRejectsNil() {
        XCTAssertNil(APIConfiguration.baseURL(fromInfoValue: nil))
    }

    func testRejectsEmpty() {
        XCTAssertNil(APIConfiguration.baseURL(fromInfoValue: ""))
    }

    func testRejectsUnexpandedVariable() {
        XCTAssertNil(APIConfiguration.baseURL(fromInfoValue: "$(API_BASE_URL)"))
    }

    func testRejectsMissingScheme() {
        XCTAssertNil(APIConfiguration.baseURL(fromInfoValue: "10.204.20.147:4000"))
    }

    func testRejectsNonString() {
        XCTAssertNil(APIConfiguration.baseURL(fromInfoValue: 42))
    }
}
