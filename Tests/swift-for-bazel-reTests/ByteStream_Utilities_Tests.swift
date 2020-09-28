import XCTest
@testable import SFBRByteStream

final class ByteStream_Utilities_Tests: XCTestCase {
  func testnormalizeUploadPath() throws {

    XCTAssertNil(normalizeUploadPath(""))
    XCTAssertNotNil(normalizeUploadPath("Instance/uploads/uuid/blobs/hash/5"))
    XCTAssertNotNil(normalizeUploadPath("uploads/uuid/blobs/hash/5"))

  }

  func testnormalizeDownloadPath() throws {

    XCTAssertNil(normalizeDownloadPath(""))
    XCTAssertNotNil(normalizeDownloadPath("Instance/blobs/hash/5"))
    XCTAssertNotNil(normalizeDownloadPath("blobs/hash/5"))

  }
}
