import NIO
import SFBRBazelRemoteAPI
import GRPC

public final class CapabilitiesProvider : Build_Bazel_Remote_Execution_V2_CapabilitiesProvider {

  public init() {
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
    cacheCaps.symlinkAbsolutePathStrategy = SymlinkAbsolutePathStrategy.Value.disallowed

    execCaps.digestFunction = .sha256
    execCaps.execEnabled = true
    execCaps.executionPriorityCapabilities = prio
    execCaps.supportedNodeProperties = []

    caps.executionCapabilities = execCaps
    caps.cacheCapabilities = cacheCaps

    return context.eventLoop.makeSucceededFuture(caps)
  }
}
