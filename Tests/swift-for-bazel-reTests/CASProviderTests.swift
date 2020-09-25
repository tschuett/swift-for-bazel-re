import XCTest
import NIO
@testable import CAS
import GRPC
import BazelRemoteAPI
import CryptoKit

// FIXME: random exit code

class CASProviderTests: GRPCTestCase {
  private var group: MultiThreadedEventLoopGroup?
  private var server: Server?
  private var channel: ClientConnection?
  private var ioThreadPool: NIOThreadPool?

  private func setUpServerAndChannel() throws -> ClientConnection {
    self.ioThreadPool = NIOThreadPool(numberOfThreads: 1)
    self.ioThreadPool!.start()
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    self.group = group

    let port = 8981

    let channel = ClientConnection.insecure(group: group)
      .connect(host: "127.0.0.1", port: port)

    self.channel = channel

    let server = try Server.insecure(group: group)
      .withServiceProviders([CASProvider(threadPool: ioThreadPool!, channel: channel)])
      .bind(host: "127.0.0.1", port: port)
      .wait()

    self.server = server


    return channel
  }

  override func tearDown() {
    if let channel = self.channel {
      XCTAssertNoThrow(try channel.close().wait())
    }
    if let server = self.server {
      XCTAssertNoThrow(try server.close().wait())
    }
    if let group = self.group {
      XCTAssertNoThrow(try group.syncShutdownGracefully())
    }

    XCTAssertNoThrow(try ioThreadPool!.syncShutdownGracefully())

    super.tearDown()
  }

  func testUpdateWithRealClientAndServer() throws {
    let channel = try self.setUpServerAndChannel()
    let client = Build_Bazel_Remote_Execution_V2_ContentAddressableStorageClient(channel: channel)

    let randomString = UUID().uuidString
    let randomData = randomString.data(using: .utf8)!

    var hasher = CryptoKit.SHA256()
    hasher.update(data: randomData)

    var digest = Build_Bazel_Remote_Execution_V2_Digest()
    digest.hash = hasher.finalize().map { String(format: "%02hhx", $0) }.joined()
    digest.sizeBytes = Int64(randomData.count)

    var blobRequest = Build_Bazel_Remote_Execution_V2_BatchUpdateBlobsRequest.Request()
    blobRequest.digest = digest
    blobRequest.data = randomData

    var updateBlobs = Build_Bazel_Remote_Execution_V2_BatchUpdateBlobsRequest()
    updateBlobs.instanceName = "foo"
    updateBlobs.requests = [blobRequest]

    let replyUpdate = client.batchUpdateBlobs(updateBlobs)

    do {
      let response = try replyUpdate.response.wait()
      for res in response.responses {
        XCTAssertEqual(res.digest, digest)
        XCTAssertEqual(res.status.code, 0)
      }
    } catch {
      XCTFail("batchUpdateBlobs failed: \(error)")
    }

    var readRequest = Build_Bazel_Remote_Execution_V2_BatchReadBlobsRequest()
    readRequest.instanceName = "foo"
    readRequest.digests = [digest]

    let replyRead = client.batchReadBlobs(readRequest)
    do {
      let response = try replyRead.response.wait()
      for res in response.responses {
        XCTAssertEqual(res.digest, digest)
        XCTAssertEqual(res.data, randomData)
        XCTAssertEqual(res.status.code, 0)
      }
    } catch {
      XCTFail("batchReadBlobs failed: \(error)")
    }

  }
}
