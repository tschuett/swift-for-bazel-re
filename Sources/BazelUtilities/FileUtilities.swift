//import SFBRBazelRemoteAPI
import TSCBasic
import NIO
import GRPC

public struct FileUtilities {
  let ioThreadPool: NIOThreadPool
  let fileIO: NonBlockingFileIO

  public init(threadPool: NIOThreadPool) {
    self.ioThreadPool = threadPool
    self.fileIO = NonBlockingFileIO(threadPool: ioThreadPool)
  }

  public func writeFile(buffer: ByteBuffer, file: AbsolutePath, eventLoop: EventLoop)
    -> EventLoopFuture<()> {

    let promise = eventLoop.makePromise(of: Void.self)

    let openEvent = fileIO.openFile(path: file.pathString,
                                    mode: NIOFileHandle.Mode.write,
                                    flags: NIOFileHandle.Flags.allowFileCreation(),
                                    eventLoop: eventLoop)
    openEvent.whenFailure() {
      error in
      print("open error in write: \(error)")
      //print(file.pathString)
      //let status = GRPCStatus(code: .unavailable, message: error.localizedDescription)
      promise.fail(error)
    }

    let writeEvent = openEvent.flatMap{
      handle -> EventLoopFuture<((), NIOFileHandle)> in
      return self.fileIO.write(fileHandle: handle,
                               toOffset: 0,
                               buffer: buffer,
                               eventLoop: eventLoop)
        .and(value: handle)
    }

    writeEvent.whenFailure() {
      error in
      print("write error: \(error)")
      print(file)
      promise.fail(error)
    }

    _ = writeEvent.flatMapThrowing{
      (_, handle) in
      try handle.close()
      promise.succeed(Void())
    }

    return promise.futureResult
  }

  public func readFile(file: AbsolutePath, eventLoop: EventLoop)
    -> EventLoopFuture<ByteBuffer> {

    let promise = eventLoop.makePromise(of: ByteBuffer.self)

    let openEvent = fileIO.openFile(path: file.pathString, eventLoop: eventLoop)

    let readEvent = openEvent.flatMap{
      (handle, region) -> EventLoopFuture<(ByteBuffer, NIOFileHandle)> in
      let allocator = ByteBufferAllocator()
      return self.fileIO.read(fileRegion: region, allocator: allocator,
                              eventLoop: eventLoop)
        .and(value: handle)
    }

    let closeEvent = readEvent.flatMapThrowing{
      (bytes, handle) -> ByteBuffer in
      try handle.close()
      return bytes
    }

    closeEvent.whenFailure() {
      error in

      promise.fail(error)
      //handleFailureEvent("readFile", error: error, promise: promise)
    }

    closeEvent.whenSuccess{
      (bytes) in
      promise.succeed(bytes)
    }

    return promise.futureResult
  }
}

