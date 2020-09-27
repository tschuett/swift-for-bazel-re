import NIO
import SFBRBazelRemoteAPI
import Foundation
import GRPC
import TSCBasic
import BazelUtilities

public final class CASProvider : ContentAddressableStorageProvider {

  let ioThreadPool: NIOThreadPool
  let fileIO: NonBlockingFileIO
  let fileMgr:FileManager
  let rootPathCAS: String
  let fileUtilities: FileUtilities
  let casClient: Build_Bazel_Remote_Execution_V2_ContentAddressableStorageClient

  public init(threadPool: NIOThreadPool, channel: GRPCChannel) {
    self.ioThreadPool = threadPool
    self.fileIO = NonBlockingFileIO(threadPool: ioThreadPool)
    fileMgr = FileManager.default
    rootPathCAS = fileMgr.currentDirectoryPath + "/data/CAS"
    fileUtilities = FileUtilities(threadPool: ioThreadPool)
    casClient = Build_Bazel_Remote_Execution_V2_ContentAddressableStorageClient(channel: channel)
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

    var futures: [EventLoopFuture<()>] = []
    let promise = context.eventLoop.makePromise(of:
                            Build_Bazel_Remote_Execution_V2_BatchUpdateBlobsResponse.self)

    for updateRequest in request.requests {
      let path = AbsolutePath(self.rootPathCAS)
        .appending(RelativePath(request.instanceName))
        .appending(RelativePath(updateRequest.digest.hash))

      let allocator = ByteBufferAllocator()
      let data = updateRequest.data
      var buffer = allocator.buffer(capacity: data.count)
      buffer.writeBytes(data)

      let writeEvent = fileUtilities.writeFile(buffer: buffer, file: path,
                                               eventLoop: context.eventLoop)

      futures.append(writeEvent)
    }

    var response = BatchUpdateBlobsResponse()
    _ = EventLoopFuture.whenAllComplete(futures, on: context.eventLoop).map{
      arr in

      for i in 0..<arr.count {
        var res = BatchUpdateBlobsResponse.Response()
        res.digest = request.requests[i].digest

        switch arr[0] {
        case .success():
          var status = Google_Rpc_Status()
          status.code = 0
          status.message = "success"
          res.status = status
        case .failure(let error):
          var status = Google_Rpc_Status()
          status.code = 2
          status.message = error.localizedDescription
          res.status = status
        }

        response.responses.append(res)
      }

      promise.succeed(response)
    }

    return promise.futureResult
  }

  func readFile(path: AbsolutePath, context: StatusOnlyCallContext)
    -> EventLoopFuture<ByteBuffer> {
    let allocator = ByteBufferAllocator()
    let promise = context.eventLoop.makePromise(of: ByteBuffer.self)

    let openEvent = fileIO.openFile(path: path.pathString,
                                    eventLoop: context.eventLoop)

    openEvent.whenFailure() {
      error in

      promise.fail(error)
    }

    let readEvent = openEvent.flatMap{
      (handle, region) -> EventLoopFuture<(ByteBuffer, NIOFileHandle)> in
      return self.fileIO.read(fileRegion: region, allocator: allocator,
                              eventLoop: context.eventLoop).and(value: handle)
    }

    readEvent.whenFailure() {
      error in

      promise.fail(error)
    }

    readEvent.whenSuccess{
      (buffer, handle) in

      promise.succeed(buffer)

      do {
        try handle.close()
      } catch {
      }
    }

    return promise.futureResult
  }

  public func batchReadBlobs(request: Build_Bazel_Remote_Execution_V2_BatchReadBlobsRequest,
                             context: StatusOnlyCallContext)
    -> EventLoopFuture<Build_Bazel_Remote_Execution_V2_BatchReadBlobsResponse> {
    var futures: [EventLoopFuture<ByteBuffer>] = []
    for digest in request.digests {
      let path = AbsolutePath(rootPathCAS)
        .appending(RelativePath(request.instanceName))
        .appending(RelativePath(digest.hash))

      futures.append(context.eventLoop.flatSubmit(
                       {
                         return self.readFile(path: path, context: context)
                       }))
    }

    let promise = context.eventLoop.makePromise(of: BatchReadBlobsResponse.self)

    _ = EventLoopFuture.whenAllComplete(futures, on: context.eventLoop).map{
      array in

      var result = BatchReadBlobsResponse()

      for i in 0..<array.count {
        var res = BatchReadBlobsResponse.Response()
        res.digest = request.digests[i]

        switch array[i] {
        case .success(let data):
          res.data = Data()
          res.data.append(contentsOf: data.readableBytesView)
          var status = Google_Rpc_Status()
          status.code = 0
          status.message = "success"
          res.status = status
        case .failure(let error):
          var status = Google_Rpc_Status()
          status.code = 2
          status.message = error.localizedDescription
          res.status = status
        }
        result.responses.append(res)
      }
      promise.succeed(result)
    }

    return promise.futureResult
  }

  public func getTree(request: Build_Bazel_Remote_Execution_V2_GetTreeRequest,
                      context: StreamingResponseCallContext<Build_Bazel_Remote_Execution_V2_GetTreeResponse>)
    -> EventLoopFuture<GRPCStatus> {

    let promise = context.eventLoop.makePromise(of: GRPCStatus.self)

    let allocator = ByteBufferAllocator()
    let path = AbsolutePath(rootPathCAS)
      .appending(RelativePath(request.instanceName))
      .appending(RelativePath(request.rootDigest.hash))

    let openEvent = fileIO.openFile(path: path.pathString, eventLoop: context.eventLoop)

    openEvent.whenFailure{
      error in
      promise.fail(error)
    }

    let readEvent = openEvent.flatMap{
      (handle, region) -> EventLoopFuture<(ByteBuffer, NIOFileHandle)> in

      return self.fileIO.read(fileRegion: region, allocator: allocator,
                              eventLoop: context.eventLoop)
        .and(value: handle)
    }

    readEvent.whenFailure{
      error in
      promise.fail(error)
    }

    let asDirectoryEvent = readEvent.flatMapThrowing{
      (bytes, handle) -> Directory in

      var json = Data()
      json.append(contentsOf: bytes.readableBytesView)
      let directory = try Directory(serializedData: json)

      try handle.close()

      return directory
    }

    asDirectoryEvent.whenFailure{
      error in
      promise.fail(error)
    }

    let workingDirectory = AbsolutePath(fileMgr.currentDirectoryPath)

    let sendEvent = asDirectoryEvent.flatMap{
      directory -> EventLoopFuture<()> in

      return self.ioThreadPool.runIfActive(eventLoop: context.eventLoop,
                                      {
                                        return try collect(directory: directory,
                                                           workingDirectory: workingDirectory,
                                                           request: request, context: context,
                                                           casClient: self.casClient)
                                      })
    }

    sendEvent.whenFailure{
      error in
      promise.fail(error)
    }

    sendEvent.whenSuccess{
      () in
      promise.succeed(.ok)
    }

    return promise.futureResult
  }
}
