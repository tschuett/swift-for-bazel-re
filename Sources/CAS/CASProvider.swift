import NIO
import BazelRemoteAPI
import Foundation
import GRPC
import TSCBasic

public class CASProvider : ContentAddressableStorageProvider {

    enum CASProviderError: Error {
    case notyetimplemented
  }

  let ioThreadPool: NIOThreadPool
  let fileIO: NonBlockingFileIO
  let fileMgr:FileManager
  let rootPathCAS: String

  public init(threadPool: NIOThreadPool) {
    self.ioThreadPool = threadPool
    self.fileIO = NonBlockingFileIO(threadPool: ioThreadPool)
    fileMgr = FileManager.default
    rootPathCAS = fileMgr.currentDirectoryPath + "/data/CAS"
  }

  public func findMissingBlobs(request: Build_Bazel_Remote_Execution_V2_FindMissingBlobsRequest,
                               context: StatusOnlyCallContext)
    -> EventLoopFuture<Build_Bazel_Remote_Execution_V2_FindMissingBlobsResponse> {
    var futures: [EventLoopFuture<Bool>] = []

    let promise = context.eventLoop.makePromise(of: FindMissingBlobsResponse.self)

    for blob in request.blobDigests {
      futures.append(context.eventLoop.submit(
                       {
                         let path = AbsolutePath(self.rootPathCAS)
                           .appending(RelativePath(request.instanceName))
                           .appending(RelativePath(blob.hash))
                         return self.fileMgr.fileExists(atPath: path.pathString)
                       }))
    }

    _ = EventLoopFuture.whenAllComplete(futures, on: context.eventLoop).map{
      arr in
      var result = FindMissingBlobsResponse()

      for (bool, digest) in zip(arr, request.blobDigests) {
        switch bool {
        case .success(let value):
          if value {
            result.missingBlobDigests.append(digest)
          }
        case .failure(_):
          break
        }
      }

      promise.succeed(result)
    }

    return promise.futureResult
  }

  public func batchUpdateBlobs(request: Build_Bazel_Remote_Execution_V2_BatchUpdateBlobsRequest,
                               context: StatusOnlyCallContext)
    -> EventLoopFuture<Build_Bazel_Remote_Execution_V2_BatchUpdateBlobsResponse> {
    return context.eventLoop.makeFailedFuture(CASProviderError.notyetimplemented)
  }

  public func batchReadBlobs(request: Build_Bazel_Remote_Execution_V2_BatchReadBlobsRequest,
                             context: StatusOnlyCallContext)
    -> EventLoopFuture<Build_Bazel_Remote_Execution_V2_BatchReadBlobsResponse> {
    return context.eventLoop.makeFailedFuture(CASProviderError.notyetimplemented)
  }

  public func getTree(request: Build_Bazel_Remote_Execution_V2_GetTreeRequest,
                      context: StreamingResponseCallContext<Build_Bazel_Remote_Execution_V2_GetTreeResponse>)
    -> EventLoopFuture<GRPCStatus> {
    return context.eventLoop.makeFailedFuture(CASProviderError.notyetimplemented)
    }
}
