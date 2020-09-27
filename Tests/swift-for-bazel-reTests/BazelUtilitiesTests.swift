import XCTest
import TSCBasic
import Foundation

@testable import BazelUtilities

final class BazelUtilities: XCTestCase {

  func testGetHash256Digest() throws {
    let file = "/bin/bash"
    let digest = try getHash256Digest(AbsolutePath(file))
    let attrs = try FileManager.default.attributesOfItem(atPath: file)
    XCTAssertEqual(attrs[FileAttributeKey.size] as! Int64, digest.sizeBytes)
  }
}
