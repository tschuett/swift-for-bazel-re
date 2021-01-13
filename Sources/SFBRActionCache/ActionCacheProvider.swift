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

  // FIXME
  public var interceptors:
    Build_Bazel_Remote_Execution_V2_ActionCacheServerInterceptorFactoryProtocol? {
    get {
      return nil
    }
  }

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

      handleFailureEvent("getActionResult", error: error, promise: promise)
    }

    readEvent.whenSuccess{
      (bytes) in
      do {
        var data = Data()
        data.append(contentsOf: bytes.readableBytesView)
        let result = try ActionResult(jsonUTF8Data: data)
        promise.succeed(result)
      } catch {
        print("readEvent in catch: \(error)")
        promise.fail(GRPCError.InvalidState(error.localizedDescription).makeGRPCStatus())
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
      let dataData = try request.actionResult.jsonUTF8Data()
      buffer = allocator.buffer(capacity: dataData.count)
      buffer.writeBytes(dataData)
    } catch {
      // FIXME
      print("updateActionResult: \(error)")
      handleFailureEvent("updateActionResult", error: error, promise: promise)
      return promise.futureResult
    }

    let writeEvent = fileUtilities.writeFile(buffer: buffer,
                                             file: path,
                                             eventLoop: context.eventLoop)
    writeEvent.whenFailure() {
      error in
      print("writeEvent: \(error)")
      handleFailureEvent("updateActionResult", error: error, promise: promise)
    }

    writeEvent.whenSuccess{
      () in
      promise.succeed(request.actionResult)
    }

    return promise.futureResult
  }
}
