import NIO
import SFBRBazelRemoteAPI
import GRPC

public final class CapabilitiesProvider : Build_Bazel_Remote_Execution_V2_CapabilitiesProvider {
  /// Threads capable of running futures.
  let group: EventLoopGroup

  public init(group: EventLoopGroup) {
    self.group = group
  }

  public func getCapabilities(request: Build_Bazel_Remote_Execution_V2_GetCapabilitiesRequest,
                              context: StatusOnlyCallContext)
    -> EventLoopFuture<Build_Bazel_Remote_Execution_V2_ServerCapabilities> {
    var caps: ServerCapabilities = ServerCapabilities()
    var action: ActionCacheUpdateCapabilities = ActionCacheUpdateCapabilities()
    var cacheCaps: CacheCapabilities = CacheCapabilities()
    var execCaps: ExecutionCapabilities = ExecutionCapabilities()
    var prio: PriorityCapabilities = PriorityCapabilities()
    var range: PriorityCapabilities.PriorityRange = PriorityCapabilities.PriorityRange()


    // FIXME request.instanceNname

    range.minPriority = 0
    range.maxPriority = 255
    prio.priorities = [range]

    action.updateEnabled = true

    cacheCaps.digestFunction = [.sha256]
    cacheCaps.actionCacheUpdateCapabilities = action
    cacheCaps.cachePriorityCapabilities = prio
    cacheCaps.maxBatchTotalSizeBytes = 1024*1024
    cacheCaps.symlinkAbsolutePathStrategy = SymlinkAbsolutePathStrategy.Value.disallowed

    execCaps.digestFunction = .sha256
    execCaps.execEnabled = true
    execCaps.executionPriorityCapabilities = prio
    execCaps.supportedNodeProperties = []

    var lowApiVersion = Build_Bazel_Semver_SemVer()
    lowApiVersion.major = 2
    lowApiVersion.minor = 0

    caps.cacheCapabilities = cacheCaps
    caps.executionCapabilities = execCaps
    caps.deprecatedApiVersion = lowApiVersion
    caps.lowApiVersion = lowApiVersion
    caps.highApiVersion = lowApiVersion

    //print(caps.textFormatString())

    return group.next().makeSucceededFuture(caps)
  }
}
