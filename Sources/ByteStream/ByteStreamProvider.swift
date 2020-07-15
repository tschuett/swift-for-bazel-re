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
  
  //let rootPathCAS = "/Users/schuett/Work/swift-for-bazel-re/data/CAS"
  let rootPathByteStream = "/Users/schuett/Work/swift-for-bazel-re/data/ByteStream"

  let ioThreadPool: NIOThreadPool

  public init(threadPool: NIOThreadPool) {
    self.ioThreadPool = threadPool
  }

  public func read(request: Google_Bytestream_ReadRequest,
            context: StreamingResponseCallContext<Google_Bytestream_ReadResponse>)
    -> EventLoopFuture<GRPCStatus> {
    print("ByteStreamProvider::read()")

    let fileIO = NonBlockingFileIO(threadPool: ioThreadPool)
    let path = AbsolutePath(rootPathByteStream)
      .appending(RelativePath(request.resourceName)).pathString
    let allocator = ByteBufferAllocator()

    let promise = context.eventLoop.makePromise(of: GRPCStatus.self)

    let openEvent = fileIO.openFile(path: path,eventLoop: context.eventLoop)
    openEvent.whenFailure() {
      error in
      print("open error: \(error)")
      print(path)
    }

    openEvent.flatMap{
      (handle, region) -> EventLoopFuture<(ByteBuffer, NIOFileHandle)> in
      if request.readLimit == 0 {
        let fileRegion = FileRegion(fileHandle: handle, readerIndex: Int(request.readOffset),
                                    endIndex: Int(region.endIndex))
        return fileIO.read(fileRegion: fileRegion, allocator: allocator,
                           eventLoop: context.eventLoop)
          .and(value: handle)
      } else {
        let fileRegion = FileRegion(fileHandle: handle,
                                    readerIndex: Int(request.readOffset),
                                    endIndex: min(Int(request.readLimit)
                                                    - Int(request.readOffset),
                                                  region.endIndex))
        return fileIO.read(fileRegion: fileRegion, allocator: allocator,
                           eventLoop: context.eventLoop)
          .and(value: handle)
      }
    }.flatMapThrowing{ (bytes, fileHandle) -> EventLoopFuture<()> in
      var response = ReadResponse()
      response.data = bytes.withUnsafeReadableBytes { ptr in
        return Data(bytes: ptr.baseAddress!, count: bytes.readableBytes)
      }
      try fileHandle.close()
      promise.succeed(.ok)
      return context.sendResponse(response)
    }

    return promise.futureResult
  }

  public func write(context: UnaryResponseCallContext<Google_Bytestream_WriteResponse>)
    -> EventLoopFuture<(StreamEvent<Google_Bytestream_WriteRequest>) -> Void> {

    let fileIO = NonBlockingFileIO(threadPool: ioThreadPool)
    let allocator = ByteBufferAllocator()
    var fileHandle: NIOFileHandle? = nil
    var committedSize: Int64 = 0

    var lastWriteEvent: EventLoopFuture<()> = context.eventLoop.makeSucceededFuture(())
    var finishedFirst = false
    var futures: [EventLoopFuture<(())>] = []

    return context.eventLoop.makeSucceededFuture(
      {event in
        switch event {
        case .message(let request): // WriteRequest
          if !finishedFirst {
            let path = AbsolutePath(self.rootPathByteStream)
              .appending(RelativePath(request.resourceName))
            do {
              try self.fileMgr.createDirectory(atPath: path.dirname,
                                               withIntermediateDirectories: true)
            } catch {
              print("fileMgr error: \(error)")
            }
            let openEvent = fileIO.openFile(path: path.pathString,
                                            mode: NIOFileHandle.Mode.write,
                                            flags: NIOFileHandle.Flags.allowFileCreation(),
                                            eventLoop: context.eventLoop)
            openEvent.whenFailure() {
              error in
              print("open error: \(error)")
              print(path.pathString)
              print(request.resourceName)
            }
            lastWriteEvent = openEvent.flatMap{
              (handle) -> EventLoopFuture<(())> in
              var buffer = allocator.buffer(capacity: request.data.count)
              buffer.writeBytes(request.data)
              committedSize += Int64(request.data.count)
              fileHandle = handle
              return fileIO.write(fileHandle: handle,
                                  toOffset: request.writeOffset,
                                  buffer: buffer,
                                  eventLoop: context.eventLoop)
            }
            lastWriteEvent.whenFailure() {
              error in
              print("write error: \(error)")
            }
            futures.append(lastWriteEvent)
            finishedFirst = true
          } else {
            // not chained !!!
            lastWriteEvent = lastWriteEvent.flatMap{
              _ -> EventLoopFuture<()> in
              var buffer = allocator.buffer(capacity: request.data.count)
              buffer.writeBytes(request.data)
              committedSize += Int64(request.data.count)
              return fileIO.write(fileHandle: fileHandle!,
                                  toOffset: request.writeOffset,
                                  buffer: buffer,
                                  eventLoop: context.eventLoop)
            }
            lastWriteEvent.whenFailure() {
              error in
              print("write error: \(error)")
            }
            futures.append(lastWriteEvent)
          }
        case .end:
          _ = EventLoopFuture.whenAllSucceed(futures, on: context.eventLoop).flatMapThrowing{
            arr in
            var response = WriteResponse()
            response.committedSize = committedSize
            context.responsePromise.succeed(response)
            try fileHandle!.close()
          }
        }})
  }

  public func queryWriteStatus(request: Google_Bytestream_QueryWriteStatusRequest,
                               context: StatusOnlyCallContext)
    -> EventLoopFuture<Google_Bytestream_QueryWriteStatusResponse> {
    // FIXME
    return context.eventLoop.makeFailedFuture(ByteStreamProviderError.notyetimplemented)
  }
}
