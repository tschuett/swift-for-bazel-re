import NIO
import NIOTransportServices
import GRPC
import SFBRCapabilities
import SFBRByteStream
import SFBRCAS
import SFBRActionCache

let port = 8980

var eventLoopGroup = PlatformSupport.makeEventLoopGroup(loopCount: System.coreCount)

let ioThreadPool = NIOThreadPool(numberOfThreads: System.coreCount)
ioThreadPool.start()

let channel = ClientConnection.insecure(group: eventLoopGroup)
  .connect(host: "localhost", port: port)

let server = Server.insecure(group: eventLoopGroup)
  .withServiceProviders([
                          ActionCacheProvider(threadPool: ioThreadPool),
                          ByteStreamProvider(threadPool: ioThreadPool, group: eventLoopGroup),
                          CASProvider(threadPool: ioThreadPool, channel: channel),
                          CapabilitiesProvider(group: eventLoopGroup)
                        ])
  .bind(host: "localhost", port: port)

server.map {
  $0.channel.localAddress
}.whenSuccess { address in
  print("server started on port grpc://localhost:\(address!.port!)")
}

// Wait on the server's `onClose` future to stop the program from exiting.
_ = try server.flatMap {
  $0.onClose
}.wait()

defer {
  try! channel.close().wait()
  try! eventLoopGroup.syncShutdownGracefully()
}
