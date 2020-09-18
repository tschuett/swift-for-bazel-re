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
    print("ByteStreamProvider::read()")
    let promise = context.eventLoop.makePromise(of: GRPCStatus.self)

    guard let (digest, instanceName) = normalizeDownloadPath(request.resourceName) else {
      return context.eventLoop.makeFailedFuture(
        GRPCError.InvalidState("malformed resource name").makeGRPCStatus())
    }

    let path = AbsolutePath(rootPath)
      .appending(RelativePath(instanceName))
      .appending(RelativePath(digest.hash))
    let allocator = ByteBufferAllocator()

    let openEvent = fileIO.openFile(path: path.pathString, eventLoop: context.eventLoop)
    openEvent.whenFailure() {
      error in
      promise.fail(error)
    }

    // FIXME streaming

    let readEvent = openEvent.flatMap{
      (handle, region) -> EventLoopFuture<(ByteBuffer, NIOFileHandle)> in
      if request.readLimit == 0 {
        let fileRegion = FileRegion(fileHandle: handle, readerIndex: Int(request.readOffset),
                                    endIndex: Int(region.endIndex))
        return self.fileIO.read(fileRegion: fileRegion, allocator: allocator,
                                eventLoop: context.eventLoop)
          .and(value: handle)
      } else {
        let fileRegion = FileRegion(fileHandle: handle,
                                    readerIndex: Int(request.readOffset),
                                    endIndex: min(Int(request.readLimit)
                                                    - Int(request.readOffset),
                                                  region.endIndex))
        return self.fileIO.read(fileRegion: fileRegion, allocator: allocator,
                           eventLoop: context.eventLoop)
          .and(value: handle)
      }
    }

    readEvent.whenFailure() {
      error in
      promise.fail(error)
    }

    let sendEvent = readEvent.flatMapThrowing{ (bytes, fileHandle)  in
      var response = ReadResponse()
      response.data = Data()
      response.data.append(contentsOf: bytes.readableBytesView)

      _ = context.sendResponse(response)
      try fileHandle.close()
    }

    sendEvent.whenSuccess{
      promise.succeed(.ok)
    }
    sendEvent.whenFailure() {
      error in
      promise.fail(error)
    }

    return promise.futureResult
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
