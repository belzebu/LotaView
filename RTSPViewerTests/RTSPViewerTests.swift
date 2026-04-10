import XCTest
@testable import LotaView

final class LotaViewTests: XCTestCase {
    func testStreamStatusDisplayText() {
        XCTAssertEqual(StreamStatus.idle.displayText, "Ready")
        XCTAssertEqual(StreamStatus.connecting.displayText, "Connecting...")
        XCTAssertEqual(StreamStatus.playing.displayText, "Playing")
        XCTAssertEqual(StreamStatus.error("timeout").displayText, "Error: timeout")
        XCTAssertEqual(StreamStatus.stopped.displayText, "Stopped")
    }

    func testStreamStatusIsActive() {
        XCTAssertFalse(StreamStatus.idle.isActive)
        XCTAssertTrue(StreamStatus.connecting.isActive)
        XCTAssertTrue(StreamStatus.playing.isActive)
        XCTAssertFalse(StreamStatus.error("fail").isActive)
        XCTAssertFalse(StreamStatus.stopped.isActive)
    }
}
