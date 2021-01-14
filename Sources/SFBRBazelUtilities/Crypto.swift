import CryptoKit
import Foundation
import TSCBasic
import SFBRBazelRemoteAPI

func getSHA256(_ path: AbsolutePath) -> String {
  let blockSize = 1024 * 1024
  let buffer = UnsafeMutablePointer<UInt8>
    .allocate(capacity: blockSize)

  var hasher = CryptoKit.SHA256()

  if let stream = InputStream(fileAtPath: path.pathString) {
    stream.open()
    while stream.hasBytesAvailable {
      let read = stream.read(buffer, maxLength: blockSize)
      let bufferPointer = UnsafeRawBufferPointer(start: buffer,
                                                 count: read)
      hasher.update(bufferPointer: bufferPointer)
    }
    stream.close()
    let digest = hasher.finalize()
    let stringHash = digest.map { String(format: "%02hhx", $0) }.joined()
    return stringHash
  }

  // FIXME
  return ""
}

public func getHash256Digest(_ absolutePath: AbsolutePath)
  throws -> Build_Bazel_Remote_Execution_V2_Digest {
  var digest = Build_Bazel_Remote_Execution_V2_Digest()
  digest.hash = getSHA256(absolutePath)

  let attr = try FileManager.default.attributesOfItem(atPath: absolutePath.pathString)
  let fileInfo = FileInfo(attr)
  digest.sizeBytes = Int64(fileInfo.size)

  return digest
}
