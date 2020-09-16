import TSCBasic
import BazelRemoteAPI
import GRPC
import BazelUtilities
import Foundation

func collect(directory: Directory, workingDirectory: AbsolutePath,
             request: Build_Bazel_Remote_Execution_V2_GetTreeRequest,
             context: StreamingResponseCallContext<GetTreeResponse>)
  throws {

  let collector = Collector()

  let absolutePath = workingDirectory
  let relativePath = RelativePath("")

  var workingList: [Directory] = []
  for dir in directory.directories {
    let absPath = absolutePath.appending(RelativePath(dir.name))
    let relPath = relativePath.appending(RelativePath(dir.name))
    workingList.append(try collector.getAsDirectory(absolutePath: absPath,
                                                    relativePath: relPath))

    try recurseTree(absPath, relPath, &workingList, request.pageSize, context)
  }
  var response = GetTreeResponse()
  response.directories = workingList
  _ = context.sendResponse(response)
  workingList.removeAll()
}

func recurseTree(_ absolutePath: AbsolutePath, _ relativePath: RelativePath,
                 _ workingList: inout [Directory], _ pageSize: Int32,
                 _ context: StreamingResponseCallContext<GetTreeResponse>) throws {

  let fileMgr =  FileManager.default
  let collector = Collector()

  for entry in try fileMgr.contentsOfDirectory(atPath: absolutePath.pathString) {
    let attr = try fileMgr.attributesOfItem(atPath:
                                              absolutePath
                                              .appending(RelativePath(entry))
                                              .pathString)
    let fileInfo = FileInfo(attr)

    if fileInfo.fileType == FileAttributeType.typeDirectory {
      let absPath = absolutePath.appending(RelativePath(entry))
      let relPath = relativePath.appending(RelativePath(entry))

      workingList.append(try collector.getAsDirectory(absolutePath: absPath,
                                                      relativePath: relPath))

      if workingList.count > pageSize {
        var response = GetTreeResponse()
        response.directories = workingList
        _ = context.sendResponse(response)
        workingList.removeAll()
      }

      try recurseTree(absPath, relPath, &workingList, pageSize, context)
    }
  }
}
