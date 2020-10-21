import SFBRBazelRemoteAPI
import GRPC
import TSCBasic
import Foundation
import NIO
import BazelUtilities

final class WriteFunction {
  var requestCount = 0
  var failed = false
  var digest =  Build_Bazel_Remote_Execution_V2_Digest()
  var instanceName = ""
  var context: UnaryResponseCallContext<Google_Bytestream_WriteResponse>
  var rootPath: String
  let fileMgr = FileManager.default
  let fileIO: NonBlockingFileIO
  var lastWriteEvent: EventLoopFuture<()>
  var fileHandle: NIOFileHandle? = nil
  let allocator = ByteBufferAllocator()
  var committedSize: Int64 = 0

  init(context: UnaryResponseCallContext<Google_Bytestream_WriteResponse>,
       rootPath: String, threadPool: NIOThreadPool) {
    self.context = context
    self.rootPath = rootPath
    fileIO = NonBlockingFileIO(threadPool: threadPool)
    lastWriteEvent = context.eventLoop.makeSucceededFuture(())
  }

  deinit {
    do {
      if let fh = fileHandle {
        try fh.close()
      }
    } catch {
    }
  }

  func write(_ event: StreamEvent<Google_Bytestream_WriteRequest>) -> Void {
    if failed {
      return
    }
    switch event {
    case .message(let request): // WriteRequest
      handleWriteRequest(request)
    case .end:
      handleEndEvent()
    }
  }

  private func handleFirstWriteRequest(_ request: Google_Bytestream_WriteRequest) -> Void {
    if let (digest, instanceName) = normalizeUploadPath(request.resourceName) {
      self.digest = digest
      self.instanceName = instanceName

      let path = AbsolutePath(self.rootPath)
        .appending(RelativePath(instanceName))
        .appending(RelativePath(digest.hash))
      do {
        try self.fileMgr.createDirectory(atPath: path.dirname,
                                         withIntermediateDirectories: true)
      } catch {
        print("fileMgr error: \(error)")
        failed = true
        return
      }

      let openEvent = fileIO.openFile(path: path.pathString,
                                      mode: NIOFileHandle.Mode.write,
                                      flags: NIOFileHandle.Flags.allowFileCreation(),
                                      eventLoop: context.eventLoop)

      lastWriteEvent = openEvent.flatMap{
        (handle) -> EventLoopFuture<(())> in
        var buffer = self.allocator.buffer(capacity: request.data.count)
        buffer.writeBytes(request.data)
        self.committedSize += Int64(request.data.count)
        self.fileHandle = handle
        return self.fileIO.write(fileHandle: handle,
                                 toOffset: request.writeOffset,
                                 buffer: buffer,
                                 eventLoop: self.context.eventLoop)
      }
    } else {
      self.context.responsePromise.fail(GRPCError.InvalidState("malformed input").makeGRPCStatus())
      self.failed = true
    }
  }

  private func handleNormalWriteRequest(_ request: Google_Bytestream_WriteRequest) -> Void {
    lastWriteEvent = lastWriteEvent.flatMap{
      _ -> EventLoopFuture<()> in
      var buffer = self.allocator.buffer(capacity: request.data.count)
      buffer.writeBytes(request.data)
      self.committedSize += Int64(request.data.count)
      return self.fileIO.write(fileHandle: self.fileHandle!,
                               toOffset: request.writeOffset,
                               buffer: buffer,
                               eventLoop: self.context.eventLoop)
    }
  }

  private func handleWriteRequest(_ request: Google_Bytestream_WriteRequest) -> Void {
    if requestCount == 0 { // first event
      handleFirstWriteRequest(request)
    } else {
      handleNormalWriteRequest(request)
    }

    requestCount += 1
  }

  private func handleEndEvent() -> Void {
    lastWriteEvent.whenFailure() {
      error in

      handleFailureEvent("WriteFunction", error: error, promise: self.context.responsePromise)
    }

    lastWriteEvent.whenSuccess() {
      var response = WriteResponse()
      response.committedSize = self.committedSize
      self.context.responsePromise.succeed(response)
    }
  }
}
