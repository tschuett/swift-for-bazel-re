import SFBRBazelRemoteAPI
import TSCBasic

// https://github.com/bazelbuild/remote-apis/blob/master/build/bazel/remote/execution/v2/remote_execution.proto#L210-L236

func normalizeUploadPath(_ resourceName: String)
  -> (Build_Bazel_Remote_Execution_V2_Digest, String)? {
  let relativePath = RelativePath(resourceName)
  let components = relativePath.components
  if components.count == 6 {
    // instance_name, "uploads", uuid, "blobs", hash, size
    var digest = Build_Bazel_Remote_Execution_V2_Digest()
    digest.hash = components[4]
    digest.sizeBytes = Int64(components[5])!
    return (digest, components[0])
  } else if components.count == 5 {
    // "uploads", uuid, "blobs", hash, size
    var digest = Build_Bazel_Remote_Execution_V2_Digest()
    digest.hash = components[3]
    digest.sizeBytes = Int64(components[4])!
    return (digest, "")
  }

  return nil
}

func normalizeDownloadPath(_ resourceName: String)
  -> (Build_Bazel_Remote_Execution_V2_Digest, String)? {
  let relativePath = RelativePath(resourceName)
  let components = relativePath.components
  if components.count == 4 {
    // instance_name, "blobs", hash, size
    var digest = Build_Bazel_Remote_Execution_V2_Digest()
    digest.hash = components[2]
    digest.sizeBytes = Int64(components[3])!
    return (digest, components[0])
  } else if components.count == 3 {
    // "blobs", hash, size
    var digest = Build_Bazel_Remote_Execution_V2_Digest()
    digest.hash = components[1]
    digest.sizeBytes = Int64(components[2])!
    return (digest, "")
  }

  return nil
}
