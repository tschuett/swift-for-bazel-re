import NIO
import GRPC
import SFBRBazelRemoteAPI
import TSCBasic
import Foundation
import SFBRBazelUtilities

final class ReadFunction {
  let rootPath: String
  let fileIO: NonBlockingFileIO
  let blockSize = 1_000_000
  let allocator = ByteBufferAllocator()
  let context: StreamingResponseCallContext<Google_Bytestream_ReadResponse>
  var fileHandle: NIOFileHandle? = nil
  var hash = ""

  init(rootPath: String, threadPool: NIOThreadPool,
       context: StreamingResponseCallContext<Google_Bytestream_ReadResponse>) {
    self.rootPath = rootPath
    self.fileIO = NonBlockingFileIO(threadPool: threadPool)
    self.context = context
  }

  deinit {
    do {
      if let fh = fileHandle {
        try fh.close()
      }
    } catch {
    }
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

    hash = digest.hash

    let openEvent = fileIO.openFile(path: path.pathString, eventLoop: context.eventLoop)

    let calculateFileInfo = openEvent.flatMap{
      (handle, region) -> EventLoopFuture<FileRegion> in
      var readerIndex: Int
      var endIndex: Int

      self.fileHandle = handle

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

      return self.context.eventLoop.makeSucceededFuture(fileRegion)
    }

    let readChunked = calculateFileInfo.flatMap{
      (fileRegion) -> EventLoopFuture<()> in
      return self.readFile(fileRegion)
    }

    readChunked.whenSuccess{
      _ in

      promise.succeed(.ok)
    }

    readChunked.whenFailure() {
      error in

      handleFailureEvent("ReadFunction", error: error, promise: promise)
    }

    return promise.futureResult
  }

  private func getSize(_ fileRegion: FileRegion) -> Int {
    return fileRegion.endIndex - fileRegion.readerIndex // +1
  }

  private func getChunkFileRegion(_ chunkSize: Int, _ fileRegion: FileRegion) -> FileRegion {
    return FileRegion(fileHandle: fileRegion.fileHandle,
                      readerIndex: fileRegion.readerIndex,
                      endIndex: fileRegion.endIndex + chunkSize - 1)
  }

  private func getRemainderFileRegion(_ chunkSize: Int, _ fileRegion: FileRegion) -> FileRegion {
    return FileRegion(fileHandle: fileRegion.fileHandle,
                                     readerIndex: fileRegion.readerIndex + chunkSize - 1,
                                     endIndex: fileRegion.endIndex)
  }

  private func readChunk(fileRegion: FileRegion) -> EventLoopFuture<FileRegion?> {
    let chunkSize = min(blockSize, getSize(fileRegion))

    if chunkSize == 0 {
      return context.eventLoop.makeSucceededFuture(nil)
    }

    let chunkRegion = getChunkFileRegion(chunkSize, fileRegion)

    let readChunk = fileIO.read(fileRegion: chunkRegion, allocator: allocator,
                                eventLoop: context.eventLoop)

    let responseEvent = readChunk.flatMap{
      (bytes) -> EventLoopFuture<FileRegion?> in
      var response = ReadResponse()
      response.data = Data()
      response.data.append(contentsOf: bytes.readableBytesView)

      _ = self.context.sendResponse(response)

      // FIXME: nil

      if chunkSize == self.getSize(fileRegion) {
        return self.context.eventLoop.makeSucceededFuture(nil)
      }


      return self.context.eventLoop.makeSucceededFuture(
        self.getRemainderFileRegion(chunkSize, fileRegion))
    }

    return responseEvent
  }

  private func readFile(_ fileRegion: FileRegion) -> EventLoopFuture<()> {
    let readEvent = readChunked(fileRegion: fileRegion)

    return readEvent.flatMap{
      _ -> EventLoopFuture<()> in

      self.context.eventLoop.makeSucceededFuture(())
    }
  }

  private func readChunked(fileRegion: FileRegion) -> EventLoopFuture<FileRegion?> {

    return readChunk(fileRegion: fileRegion).flatMap{
      region -> EventLoopFuture<FileRegion?> in
      if let fileRegion = region {
        return self.context.eventLoop.flatSubmit{
          return self.readChunked(fileRegion: fileRegion)
        }
      } else {
        return self.context.eventLoop.makeSucceededFuture(nil)
      }
    }
  }
}
