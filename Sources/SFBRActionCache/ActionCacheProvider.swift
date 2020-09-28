import SFBRBazelRemoteAPI
import NIO
import GRPC
import Foundation
import TSCBasic
import BazelUtilities

public final class ActionCacheProvider: Build_Bazel_Remote_Execution_V2_ActionCacheProvider {

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

  public func getActionResult(request: Build_Bazel_Remote_Execution_V2_GetActionResultRequest,
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

    readEvent.whenSuccess{
      (bytes) in
      do {
        var data = Data()
        data.append(contentsOf: bytes.readableBytesView)
        let result = try ActionResult(serializedData: data)
        promise.succeed(result)
      } catch {
        promise.fail(error)
      }
    }

    return promise.futureResult
  }

  public func updateActionResult(request: Build_Bazel_Remote_Execution_V2_UpdateActionResultRequest,
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
      let dataData = try request.actionResult.serializedData()
      buffer = allocator.buffer(capacity: dataData.count)
      buffer.writeBytes(dataData)
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

    writeEvent.whenSuccess{
      () in
      promise.succeed(request.actionResult)
    }

    return promise.futureResult
  }
}
