import NIO
import NIOTransportServices
import GRPC
import Capabilities
import ByteStream
import CAS
import ActionCache

let port = 8980
var eventLoopGroup: EventLoopGroup

if #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
 eventLoopGroup = NIOTSEventLoopGroup(loopCount:  System.coreCount)
} else {
  eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
}

let ioThreadPool = NIOThreadPool(numberOfThreads: System.coreCount)
ioThreadPool.start()

let channel = ClientConnection.insecure(group: eventLoopGroup)
  .connect(host: "localhost", port: port)

let server = Server.insecure(group: eventLoopGroup)
  .withServiceProviders([
                          ActionCacheProvider(threadPool: ioThreadPool),
                          ByteStreamProvider(threadPool: ioThreadPool),
                          CASProvider(threadPool: ioThreadPool, channel: channel),
                          CapabilitiesProvider()
                        ])
  .bind(host: "localhost", port: port)

server.map {
  $0.channel.localAddress
}.whenSuccess { address in
  print("server started on port \(address!.port!)")
}

// Wait on the server's `onClose` future to stop the program from exiting.
_ = try server.flatMap {
  $0.onClose
}.wait()

defer {
  try! channel.close().wait()
  try! eventLoopGroup.syncShutdownGracefully()
}
