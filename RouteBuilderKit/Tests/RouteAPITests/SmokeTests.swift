import XCTest
@testable import RouteAPI

final class SmokeTests: XCTestCase {
    func testTaskSleeperThrowsWhenCancelled() async {
        let task = Task { try await TaskSleeper().sleep(seconds: 10) }
        task.cancel()
        let result = await task.result
        switch result {
        case .success:
            XCTFail("Expected CancellationError, but sleep completed")
        case .failure(let error):
            XCTAssertTrue(error is CancellationError, "Unexpected error: \(error)")
        }
    }
}
