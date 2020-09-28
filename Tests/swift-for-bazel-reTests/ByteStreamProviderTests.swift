import XCTest
import NIO
@testable import ByteStream
import GRPC
import SFBRBazelRemoteAPI
import CryptoKit

class ByteStreamProviderTests: GRPCTestCase {
  private var group: MultiThreadedEventLoopGroup?
  private var server: Server?
  private var channel: ClientConnection?
  private var ioThreadPool: NIOThreadPool?

  private func setUpServerAndChannel() throws -> ClientConnection {
    self.ioThreadPool = NIOThreadPool(numberOfThreads: 1)
    self.ioThreadPool!.start()

    let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    self.group = group

    let server: Server = try Server.insecure(group: group)
      .withServiceProviders([ByteStreamProvider(threadPool: ioThreadPool!)])
      .bind(host: "127.0.0.1", port: 0)
      .wait()

    self.server = server

    let channel: ClientConnection = ClientConnection.insecure(group: group)
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

  func hash(_ data: Data) -> String {
    var hasher = CryptoKit.SHA256()
    hasher.update(data: data)
    return hasher.finalize().map { String(format: "%02hhx", $0) }.joined()
  }

  func readCollector(_ readResponse: Google_Bytestream_ReadResponse) -> Void {
    // FIXME
  }

  func testUpdateWithRealClientAndServer() throws {
    let channel = try self.setUpServerAndChannel()
    let client = Google_Bytestream_ByteStreamClient(channel: channel)

    let data: Data = "MyReallyImportantString".data(using: .utf8)!

    let resourceNameUpload = "foo/uploads/uuid/blobs/\(hash(data))/\(data.count)"
    let resourceNameDownload = "foo/blobs/\(hash(data))/\(data.count)"

    var readRequest = Google_Bytestream_ReadRequest()
    readRequest.resourceName = resourceNameDownload

    var writeRequest = Google_Bytestream_WriteRequest()
    writeRequest.resourceName = resourceNameUpload
    writeRequest.data = data

    let writeResult: ClientStreamingCall<Google_Bytestream_WriteRequest, Google_Bytestream_WriteResponse> = client.write()

    //let futureSendMsg: EventLoopFuture<Void> = writeResult.sendMessage(writeRequest)
    _ = writeResult.sendMessage(writeRequest)
//    do {
//      let response: Void = try futureSendMsg.wait() // leaks
//    } catch {
//      XCTFail("sendMessage failed: \(error)")
//    }
    //let futureSendEnd: EventLoopFuture<Void> = writeResult.sendEnd()
    _ = writeResult.sendEnd()
//    do {
//      try futureSendEnd.wait() //leaks
//    } catch {
//      XCTFail("sendEnd failed: \(error)")
//    }

    //let readResult = client.read(readRequest,
    //                             handler: {
    //                               self.readCollector($0)
    //                             }
    _ = client.read(readRequest,
                                 handler: {
                                   self.readCollector($0)
                                 }
    )

//    do {
//      let payload = try readResult.status.wait() //leaks
//      XCTAssert(payload.isOk)
//    } catch {
//      XCTFail("read failed: \(error)")
//    }

  }
}

