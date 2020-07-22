import XCTest
import NIO
@testable import Capabilities
import GRPC
import BazelRemoteAPI

class CapabilitiesProviderTests: GRPCTestCase {
  private var group: MultiThreadedEventLoopGroup?
  private var server: Server?
  private var channel: ClientConnection?

  private func setUpServerAndChannel() throws -> ClientConnection {
    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    self.group = group

    let server = try Server.insecure(group: group)
      .withServiceProviders([CapabilitiesProvider()])
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

    super.tearDown()
  }

  func testUpdateWithRealClientAndServer() throws {
    let channel = try self.setUpServerAndChannel()
    let client = Build_Bazel_Remote_Execution_V2_CapabilitiesClient(channel: channel)

    var request = Build_Bazel_Remote_Execution_V2_GetCapabilitiesRequest()
    request.instanceName = "foo"
    let reply = client.getCapabilities(request)

    reply.response.whenComplete { result in
      switch result {
      case .success(let response):
        XCTAssertEqual(response.executionCapabilities.digestFunction, .sha256)
      case .failure(let _):
        break
      }
    }
  }

}
