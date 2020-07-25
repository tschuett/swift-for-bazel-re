import XCTest
@testable import ByteStream

final class PerformanceTests: XCTestCase {

  func testByteStreamUtilities() throws {
    measure(metrics: [XCTClockMetric()]) {
      normalizeUploadPath("Instance/uploads/uuid/blobs/hash/5")
    }
  }

}
