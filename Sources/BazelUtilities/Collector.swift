import Foundation
import TSCBasic
import CryptoKit
import SwiftProtobuf
import SFBRBazelRemoteAPI

public struct Collector {
  let fileMgr =  FileManager.default
  let casClient: Build_Bazel_Remote_Execution_V2_ContentAddressableStorageClient
  let instanceName: String

  public enum FileType {
    case directory, file, symlink
  }

  public init(instanceName: String,
              casClient: Build_Bazel_Remote_Execution_V2_ContentAddressableStorageClient) {
    self.instanceName = instanceName
    self.casClient = casClient
  }

  public func getAsDirectory(absolutePath: AbsolutePath,
                             relativePath: RelativePath)
    throws -> Build_Bazel_Remote_Execution_V2_Directory {
    var directory = Directory()

    for  entry in try fileMgr.contentsOfDirectory(
           atPath: absolutePath.pathString).sorted() {
      let absolutePath = absolutePath.appending(RelativePath(entry))
      let relativePath = relativePath.appending(components: entry)

      if let type = getFileType(atPath: absolutePath) {
        switch (type) {
        case .directory:
          directory.directories.append(
            try getAsDirectoryNode(absolutePath: absolutePath,
                                   relativePath: relativePath,
                                   name: entry))
        case .file:
          directory.files.append(
            try getAsFileNode(absolutePath: absolutePath,
                              relativePath: relativePath,
                              name: entry))
        case .symlink:
          directory.symlinks.append(
            try getAsSymlinkNode(absolutePath: absolutePath,
                                 relativePath: relativePath,
                                 name: entry))
        }
      }
    }

    directory.nodeProperties = try getNodeProperties(absolutePath)

    return directory;
  }

  struct CollectionFailed: Error {
    let s: String
    init(_ s: String) {
      self.s = s
    }
    var localizedDescription: String {
      return s
    }
  }

  public func getAsOutputFile(absolutePath: AbsolutePath, relativePath: RelativePath)
    throws -> Build_Bazel_Remote_Execution_V2_OutputFile {
    var outputFile = OutputFile()

    outputFile.path = relativePath.pathString
    outputFile.digest =  try getHash256Digest(absolutePath)
    outputFile.isExecutable = fileMgr.isExecutableFile(atPath: absolutePath.pathString)
    outputFile.nodeProperties = try getNodeProperties(absolutePath)

    guard let data = fileMgr.contents(atPath: absolutePath.pathString) else {
      throw CollectionFailed(absolutePath.pathString)
    }

    var fileRequest = Build_Bazel_Remote_Execution_V2_BatchUpdateBlobsRequest.Request()
    fileRequest.digest = outputFile.digest
    fileRequest.data = data

    var request = Build_Bazel_Remote_Execution_V2_BatchUpdateBlobsRequest()
    request.instanceName = instanceName
    request.requests = [fileRequest]

    let response = try casClient.batchUpdateBlobs(request).response.wait()

    for res in response.responses {
      if res.digest == outputFile.digest && res.status.code == 0 {
        return outputFile
      }
    }

    throw CollectionFailed(absolutePath.pathString)
  }

  public func getAsOutputSymlink(absolutePath: AbsolutePath,
                                 relativePath: RelativePath)
    throws -> Build_Bazel_Remote_Execution_V2_OutputSymlink {
    var outputSymlink = OutputSymlink()

    outputSymlink.path = relativePath.pathString
    outputSymlink.target = try fileMgr.destinationOfSymbolicLink(
      atPath: absolutePath.pathString)

    outputSymlink.nodeProperties = try getNodeProperties(absolutePath)
    // FIMXE: copy file to CAS

    return outputSymlink;
  }


  func getAsDirectoryNode(absolutePath: AbsolutePath,
                          relativePath: RelativePath, name: String) throws -> DirectoryNode {
    var directoryNode = DirectoryNode()

    let directory = try getAsDirectory(absolutePath: absolutePath,
                                       relativePath: relativePath)

    directoryNode.name = name
    directoryNode.digest = try getDigestOf(directory)

    // FIXME: copy file to CAS ???

    return directoryNode
  }

  func getAsFileNode(absolutePath: AbsolutePath,
                     relativePath: RelativePath, name: String) throws -> FileNode {
    var fileNode = FileNode()

    fileNode.name = name
    fileNode.digest = try getHash256Digest(absolutePath)
    fileNode.isExecutable = fileMgr.isExecutableFile(atPath: absolutePath.pathString)
    fileNode.nodeProperties = try getNodeProperties(absolutePath)

    // FIXME: copy file to CAS

    return fileNode
  }

  func getAsSymlinkNode(absolutePath: AbsolutePath,
                        relativePath: RelativePath, name: String) throws -> SymlinkNode {
    var symlinkNode = SymlinkNode()

    symlinkNode.name = name
    symlinkNode.target = try fileMgr.destinationOfSymbolicLink(
      atPath: absolutePath.pathString)
    symlinkNode.nodeProperties = try getNodeProperties(absolutePath)

    return symlinkNode;
  }

  public func getNodeProperties(_ file: AbsolutePath)
    throws -> Build_Bazel_Remote_Execution_V2_NodeProperties {
    var nodeProperties = NodeProperties()

    do {
      let attr = try fileMgr.attributesOfItem(atPath: file.pathString)
      let fileInfo = FileInfo(attr)

      nodeProperties.mtime = Google_Protobuf_Timestamp(date: fileInfo.modTime)
      // FIXME Int16 to UInt32 ???
      nodeProperties.unixMode = Google_Protobuf_UInt32Value(
        Google_Protobuf_UInt32Value.WrappedType.BaseType(
          fileInfo.posixPermissions))
    } catch {
    }

    return nodeProperties
  }

  func getDigestOf<Proto: Message>(_ proto: Proto) throws -> Digest {
    var hasher = CryptoKit.SHA256()
    var digest = Digest()

    hasher.update(data: try proto.serializedData())
    let stringHash = hasher.finalize().map { String(format: "%02hhx", $0) }.joined()

    digest.hash = stringHash
    digest.sizeBytes = Int64(try proto.serializedData().count)

    return digest
  }

  public func getFileType(atPath path: AbsolutePath) -> FileType? {
    do {
      let attr = try fileMgr.attributesOfItem(atPath: path.pathString)
      let fileInfo = FileInfo(attr)

      switch fileInfo.fileType {
        case FileAttributeType.typeDirectory: return .directory
        case FileAttributeType.typeRegular: return .file
        case FileAttributeType.typeSymbolicLink: return .symlink
        default:
          return nil
      }
    } catch {
      return nil
    }
  }

}
