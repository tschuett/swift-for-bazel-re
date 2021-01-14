import XCTest
@testable import SFBRByteStream

final class PerformanceTests: XCTestCase {

  func testByteStreamUtilities() throws {
    measure(metrics: [XCTClockMetric()]) {
      _ = normalizeUploadPath("Instance/uploads/uuid/blobs/hash/5")
    }
  }

}
