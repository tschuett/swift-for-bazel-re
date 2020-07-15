import NIO
import NIOTransportServices
import GRPC
import Capabilities
import ByteStream

print("Hello, world!")

var group: EventLoopGroup

if #available(OSX 10.14, iOS 12.0, tvOS 12.0, watchOS 6.0, *) {
 group = NIOTSEventLoopGroup(loopCount:  System.coreCount)
} else {
  group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
}

defer {
  try! group.syncShutdownGracefully()
}

let ioThreadPool = NIOThreadPool(numberOfThreads: System.coreCount)
ioThreadPool.start()

let server = Server.insecure(group: group)
  .withServiceProviders([
                          ByteStreamProvider(threadPool: ioThreadPool),
                          CapabilitiesProvider()
                        ])
  .bind(host: "localhost", port: 8980)

server.map {
  $0.channel.localAddress
}.whenSuccess { address in
  print("server started on port \(address!.port!)")
}

// Wait on the server's `onClose` future to stop the program from exiting.
_ = try server.flatMap {
  $0.onClose
}.wait()
