import BazelRemoteAPI
import NIO
import GRPC
import Foundation
import TSCBasic
import BazelUtilities

class ActionCacheProvider: Build_Bazel_Remote_Execution_V2_ActionCacheProvider {

  let ioThreadPool: NIOThreadPool
  let fileIO: NonBlockingFileIO
  let fileMgr:FileManager
  let rootPathActionCache: String
  let fileUtilities: FileUtilities

  public init(threadPool: NIOThreadPool) {
    self.ioThreadPool = threadPool
    self.fileIO = NonBlockingFileIO(threadPool: ioThreadPool)
    fileMgr = FileManager.default
    rootPathActionCache = fileMgr.currentDirectoryPath + "/data/ActionCache"
    fileUtilities = FileUtilities(threadPool: ioThreadPool)
  }

  func getActionResult(request: Build_Bazel_Remote_Execution_V2_GetActionResultRequest,
                       context: StatusOnlyCallContext)
    -> EventLoopFuture<Build_Bazel_Remote_Execution_V2_ActionResult> {

    let path = AbsolutePath(rootPathActionCache)
      .appending(RelativePath(request.instanceName))
      .appending(RelativePath(request.actionDigest.hash))

    let promise = context.eventLoop.makePromise(of: ActionResult.self)

    let readEvent = fileUtilities.readFile(file: path,
                                           eventLoop: context.eventLoop)
    readEvent.whenFailure() {
      error in
      print(error)
      promise.fail(error)
    }

    _ = readEvent.flatMapThrowing{
      (bytes) in
      var json = Data()
      json.append(contentsOf: bytes.readableBytesView)
      let result = try ActionResult(serializedData: json)
      promise.succeed(result)
    }

    return promise.futureResult
  }

  func updateActionResult(request: Build_Bazel_Remote_Execution_V2_UpdateActionResultRequest,
                          context: StatusOnlyCallContext)
    -> EventLoopFuture<Build_Bazel_Remote_Execution_V2_ActionResult> {
    let allocator = ByteBufferAllocator()
    var buffer = allocator.buffer(capacity: 1)

    let path = AbsolutePath(rootPathActionCache)
      .appending(RelativePath(request.instanceName))
      .appending(RelativePath(request.actionDigest.hash))

    let promise = context.eventLoop.makePromise(of: ActionResult.self)

    do {
      try self.fileMgr.createDirectory(atPath: path.dirname,
                                       withIntermediateDirectories: true)
    } catch {
      print("fileMgr error: \(error)")
      promise.fail(GRPCError.InvalidState("createDirectory failed").makeGRPCStatus())
      return promise.futureResult
    }

    do {
      let allocator = ByteBufferAllocator()
      let jsonData = try request.actionResult.serializedData()
      buffer = allocator.buffer(capacity: jsonData.count)
      buffer.writeBytes(jsonData)
    } catch {
      // FIXME
      promise.fail(GRPCError.InvalidState("malformed input").makeGRPCStatus())
      return promise.futureResult
    }

    let writeEvent = fileUtilities.writeFile(buffer: buffer,
                                             file: path,
                                             eventLoop: context.eventLoop)
    writeEvent.whenFailure() {
      error in
      promise.fail(error)
    }

    _ = writeEvent.flatMapThrowing{
      () in
      promise.succeed(request.actionResult)
    }

    return promise.futureResult
  }
}
