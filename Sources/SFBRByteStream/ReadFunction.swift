import NIO
import GRPC
import SFBRBazelRemoteAPI
import TSCBasic
import Foundation

struct FileInfo {
  var region: FileRegion
  var fileHandle: NIOFileHandle
}

final class ReadFunction {
  let rootPath: String
  let fileIO: NonBlockingFileIO
  let blockSize = 1000000
  let allocator = ByteBufferAllocator()
  let context: StreamingResponseCallContext<Google_Bytestream_ReadResponse>

  init(rootPath: String, threadPool: NIOThreadPool,
       context: StreamingResponseCallContext<Google_Bytestream_ReadResponse>) {
    self.rootPath = rootPath
    self.fileIO = NonBlockingFileIO(threadPool: threadPool)
    self.context = context
  }

  func read(request: Google_Bytestream_ReadRequest) -> EventLoopFuture<GRPCStatus> {
    let promise = context.eventLoop.makePromise(of: GRPCStatus.self)

    guard let (digest, instanceName) = normalizeDownloadPath(request.resourceName) else {
      return context.eventLoop.makeFailedFuture(
        GRPCError.InvalidState("malformed resource name").makeGRPCStatus())
    }

    let path = AbsolutePath(rootPath)
      .appending(RelativePath(instanceName))
      .appending(RelativePath(digest.hash))

    let openEvent = fileIO.openFile(path: path.pathString, eventLoop: context.eventLoop)
    openEvent.whenFailure() {
      error in
      promise.fail(error)
    }

    let calculateFileInfo = openEvent.flatMap{
      (handle, region) -> EventLoopFuture<FileInfo> in
      var readerIndex: Int
      var endIndex: Int

      if request.readLimit == 0 {
        readerIndex = Int(request.readOffset)
        endIndex = region.endIndex
      } else {
        readerIndex = Int(request.readOffset)
        endIndex = min(Int(request.readLimit) - Int(request.readOffset),
                       region.endIndex)
      }

      let fileRegion = FileRegion(fileHandle: handle, readerIndex: readerIndex,
                                  endIndex: endIndex)
      let fileInfo = FileInfo(region: fileRegion, fileHandle: handle)
      return self.context.eventLoop.makeSucceededFuture(fileInfo)
    }

    calculateFileInfo.whenFailure{
      error in
      promise.fail(error)
    }

    let readChunked = calculateFileInfo.flatMap{
      (fileInfo) -> EventLoopFuture<GRPCStatus> in
      return self.readChunked(fileInfo)
    }

    readChunked.whenSuccess{
      _ in
      promise.succeed(.ok)
    }
    readChunked.whenFailure() {
      error in
      promise.fail(error)
    }

    return promise.futureResult
  }

  private func getSize(_ fileRegion: FileRegion) -> Int {
    return fileRegion.endIndex - fileRegion.readerIndex + 1
  }

  private func getChunkFileRegion(_ chunkSize: Int, _ fileRegion: FileRegion) -> FileRegion {
    return FileRegion(fileHandle: fileRegion.fileHandle,
                      readerIndex: fileRegion.readerIndex,
                      endIndex: fileRegion.readerIndex + chunkSize - 1)
  }

  private func getRemainderFileRegion(_ chunkSize: Int, _ fileRegion: FileRegion) -> FileRegion {
    return FileRegion(fileHandle: fileRegion.fileHandle,
                                     readerIndex: fileRegion.readerIndex + chunkSize - 1,
                                     endIndex: fileRegion.readerIndex)
  }

  private func readChunk(fileRegion: FileRegion)
    -> EventLoopFuture<FileRegion?> {
    let promise = context.eventLoop.makePromise(of: FileRegion?.self)
    let chunkSize = min(blockSize, getSize(fileRegion))

    if chunkSize == 0 {
      return context.eventLoop.makeSucceededFuture(nil)
    }

    let chunkRegion = getChunkFileRegion(chunkSize, fileRegion)

    let readChunk = fileIO.read(fileRegion: chunkRegion, allocator: allocator,
                                eventLoop: context.eventLoop)
    readChunk.whenFailure{
      error in
      promise.fail(error)
    }

    let sendEvent = readChunk.map{
      (bytes) in
      var response = ReadResponse()
      response.data = Data()
      response.data.append(contentsOf: bytes.readableBytesView)

      _ = self.context.sendResponse(response)
      promise.succeed(self.getRemainderFileRegion(chunkSize, fileRegion))
    }

    sendEvent.whenFailure{
      error in
      promise.fail(error)
    }

    return promise.futureResult
  }

  private func readChunked(_ fileInfo: FileInfo) -> EventLoopFuture<GRPCStatus> {

    return readChunk(fileRegion: fileInfo.region).flatMap{
      region -> EventLoopFuture<GRPCStatus> in
      if let fileRegion = region {
        return self.context.eventLoop.submit{
          return self.readChunk(fileRegion: fileRegion)
        }.flatMap{
          _ -> EventLoopFuture<GRPCStatus> in
          return self.context.eventLoop.makeSucceededFuture(.ok)
        }
      } else {
        return self.context.eventLoop.makeSucceededFuture(.ok)
      }
    }
  }
}
