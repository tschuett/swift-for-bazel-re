import BazelRemoteAPI
import NIO
import NIOFoundationCompat
import GRPC
import TSCBasic
import Foundation

public class ByteStreamProvider: Google_Bytestream_ByteStreamProvider {

  enum ByteStreamProviderError: Error {
    case notyetimplemented
  }

  let fileMgr = FileManager.default

  let rootPath: String

  let ioThreadPool: NIOThreadPool
  let fileIO: NonBlockingFileIO

  public init(threadPool: NIOThreadPool) {
    self.ioThreadPool = threadPool
    self.fileIO = NonBlockingFileIO(threadPool: ioThreadPool)
    rootPath = fileMgr.currentDirectoryPath + "/data/CAS"
  }

  public func read(request: Google_Bytestream_ReadRequest,
            context: StreamingResponseCallContext<Google_Bytestream_ReadResponse>)
    -> EventLoopFuture<GRPCStatus> {
    return ReadFunction(rootPath: rootPath, threadPool: ioThreadPool,
                        context: context)
      .read(request: request)
   }

  public func write(context: UnaryResponseCallContext<Google_Bytestream_WriteResponse>)
    -> EventLoopFuture<(StreamEvent<Google_Bytestream_WriteRequest>) -> Void> {

    let writeFunction = WriteFunction(context: context, rootPath: rootPath,
                                      threadPool: ioThreadPool)

    return context.eventLoop.makeSucceededFuture(writeFunction.write)
  }

  public func queryWriteStatus(request: Google_Bytestream_QueryWriteStatusRequest,
                               context: StatusOnlyCallContext)
    -> EventLoopFuture<Google_Bytestream_QueryWriteStatusResponse> {
    // FIXME
    return context.eventLoop.makeFailedFuture(
      GRPCError.RPCNotImplemented(rpc: "queryWriteStatus is not implemented").makeGRPCStatus())

  }
}
