import XCTest
import NIO
@testable import ActionCache
import GRPC
import BazelRemoteAPI
import CryptoKit

// FIXME: random exit code

class ActionCacheProviderTests: GRPCTestCase {
  private var group: MultiThreadedEventLoopGroup?
  private var server: Server?
  private var channel: ClientConnection?
  private var ioThreadPool: NIOThreadPool?

  private func setUpServerAndChannel() throws -> ClientConnection {
    self.ioThreadPool = NIOThreadPool(numberOfThreads: 1)
    self.ioThreadPool!.start()
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    self.group = group

    let server = try Server.insecure(group: group)
      .withServiceProviders([ActionCacheProvider(threadPool: ioThreadPool!)])
      .bind(host: "127.0.0.1", port: 0)
      .wait()

    self.server = server

    let channel = ClientConnection.insecure(group: group)
      .connect(host: "127.0.0.1", port: server.channel.localAddress!.port!)

    self.channel = channel

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
    let client = Build_Bazel_Remote_Execution_V2_ActionCacheClient(channel: channel)

    var actionResult = Build_Bazel_Remote_Execution_V2_ActionResult()
    actionResult.exitCode = 128

    var hasher = CryptoKit.SHA256()
    hasher.update(data: try actionResult.serializedData())

    var digest = Build_Bazel_Remote_Execution_V2_Digest()
    digest.hash = hasher.finalize().map { String(format: "%02hhx", $0) }.joined()
    digest.sizeBytes = try Int64(actionResult.serializedData().count)

    var updateResult = Build_Bazel_Remote_Execution_V2_UpdateActionResultRequest()
    updateResult.instanceName = "foo"
    updateResult.actionDigest = digest
    updateResult.actionResult = actionResult

    let replyUpdate = client.updateActionResult(updateResult)

    do {
      let payload = try replyUpdate.response.wait()
      XCTAssertEqual(payload.exitCode, 128)
    } catch {
      XCTFail("updateActionResult failed: \(error)")
    }

    var resultRequest = Build_Bazel_Remote_Execution_V2_GetActionResultRequest()
    resultRequest.instanceName = "foo"
    resultRequest.actionDigest = digest

    let replyGet = client.getActionResult(resultRequest)
    do {
      let payload = try replyGet.response.wait()
      XCTAssertEqual(payload.exitCode, 128)
    } catch {
      XCTFail("getActionResult failed: \(error)")
    }

  }
}

