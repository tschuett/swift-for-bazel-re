import TSCBasic
import NIO

struct FileUtilities {
  let ioThreadPool: NIOThreadPool
  let fileIO: NonBlockingFileIO

  public init(threadPool: NIOThreadPool) {
    self.ioThreadPool = threadPool
    self.fileIO = NonBlockingFileIO(threadPool: ioThreadPool)
  }

  func writeFile(buffer: ByteBuffer, file: AbsolutePath, eventLoop: EventLoop)
    -> EventLoopFuture<()> {

    let promise = eventLoop.makePromise(of: Void.self)

    let openEvent = fileIO.openFile(path: file.pathString,
                                    mode: NIOFileHandle.Mode.write,
                                    flags: NIOFileHandle.Flags.allowFileCreation(),
                                    eventLoop: eventLoop)
    openEvent.whenFailure() {
      error in
      print("open error: \(error)")
      print(file.pathString)
    }

    let writeEvent = openEvent.flatMap{
      handle -> EventLoopFuture<((), NIOFileHandle)> in
      return self.fileIO.write(fileHandle: handle,
                               toOffset: 0,
                               buffer: buffer,
                               eventLoop: eventLoop)
        .and(value: handle)
    }

    _ = writeEvent.flatMapThrowing{
      (_, handle) in
      try handle.close()
      promise.succeed(Void())
    }

    return promise.futureResult
  }

  func readFile(file: AbsolutePath, eventLoop: EventLoop)
    -> EventLoopFuture<ByteBuffer> {

    let promise = eventLoop.makePromise(of: ByteBuffer.self)

    let openEvent = fileIO.openFile(path: file.pathString, eventLoop: eventLoop)
    openEvent.whenFailure() {
      error in
      print("open error: \(error)")
      print(file)
    }

    let readEvent = openEvent.flatMap{
      (handle, region) -> EventLoopFuture<(ByteBuffer, NIOFileHandle)> in
      let allocator = ByteBufferAllocator()
      return self.fileIO.read(fileRegion: region, allocator: allocator,
                              eventLoop: eventLoop)
        .and(value: handle)
    }

    readEvent.whenFailure() {
      error in
      print("read error: \(error)")
      print(file)
    }

    _ = readEvent.flatMapThrowing{
      (bytes, handle) in
      try handle.close()
      promise.succeed(bytes)
    }

    return promise.futureResult
  }
}

