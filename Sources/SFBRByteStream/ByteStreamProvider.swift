import SFBRBazelRemoteAPI
import NIO
import NIOFoundationCompat
import GRPC
import TSCBasic
import Foundation
import BazelUtilities

public final class ByteStreamProvider: Google_Bytestream_ByteStreamProvider {
  /// Threads capable of running futures.
  let group: EventLoopGroup

  enum ByteStreamProviderError: Error {
    case notyetimplemented
  }

  let fileMgr = FileManager.default
  let rootPath: String
  let ioThreadPool: NIOThreadPool
  let fileIO: NonBlockingFileIO

  public init(threadPool: NIOThreadPool, group: EventLoopGroup) {
    self.ioThreadPool = threadPool
    self.fileIO = NonBlockingFileIO(threadPool: ioThreadPool)
    self.group = group
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

    return group.next().makeSucceededFuture(writeFunction.write)
  }

  public func queryWriteStatus(request: Google_Bytestream_QueryWriteStatusRequest,
                               context: StatusOnlyCallContext)
    -> EventLoopFuture<Google_Bytestream_QueryWriteStatusResponse> {
    // FIXME
    return group.next().makeFailedFuture(
      GRPCError.RPCNotImplemented(rpc: "queryWriteStatus is not implemented").makeGRPCStatus())

  }
}
