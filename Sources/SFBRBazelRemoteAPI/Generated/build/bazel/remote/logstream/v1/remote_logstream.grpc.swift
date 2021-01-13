//
// DO NOT EDIT.
//
// Generated by the protocol buffer compiler.
// Source: build/bazel/remote/logstream/v1/remote_logstream.proto
//

//
// Copyright 2018, gRPC Authors All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
import GRPC
import NIO
import SwiftProtobuf


/// #### Introduction
///
/// The Log Stream API manages LogStream resources which are used to stream
/// writes and reads of an ordered sequence of bytes of unknown eventual length.
///
/// Note that this is an API Interface and not an API Service, per the definitons
/// at: https://cloud.google.com/apis/design/glossary
///
/// Log Stream API supports the reading of unfinalized LogStreams either by
/// seeking or in "tail" mode, for example by end-users browsing to a build
/// result UI interested in seeing logs from a build action as soon as they are
/// (or as they become) available.
///
/// Reads and Writes of LogStreams are done via the Byte Stream API:
/// https://cloud.google.com/dataproc/docs/reference/rpc/google.bytestream
/// https://github.com/googleapis/googleapis/blob/master/google/bytestream/bytestream.proto
///
/// #### Writing LogStreams
///
/// LogStreams are written to via the Byte Stream API's `Write` RPC. Bytes
/// written to LogStreams are expected to be committed and available for reading
/// within a reasonable period of time (implementation-defined). Committed bytes
/// to a LogStream cannot be overwritten, and finalized LogStreams - indicated by
/// setting `finish_write` field in the final WriteRequest - also cannot be
/// appended to.
///
/// When calling the Byte Stream API's `Write` RPC to write LogStreams, writers
/// must pass the `write_resource_name` of a LogStream as
/// `ByteStream.WriteRequest.resource_name` rather than the LogStream's `name`.
/// Separate resource names for reading and writing allows for broadcasting the
/// read resource name widely while simultaneously ensuring that only writer(s)
/// with knowledge of the write resource name may have written bytes to the
/// LogStream.
///
/// #### Reading LogStreams
///
/// Use the Byte Stream API's `Read` RPC to read LogStreams. When reading
/// finalized LogStreams the server will stream all contents of the LogStream
/// starting at `ByteStream.ReadRequest.read_offset`.
///
/// When reading unfinalized LogStreams the server must keep the streaming
/// `ByteStream.Read` RPC open and send `ByteStream.ReadResponse` messages as
/// more bytes become available or the LogStream is finalized.
///
/// #### Example Multi-Party Read/Write Flow
///
/// 1. LogStream Writer calls `CreateLogStream`
/// 2. LogStream Writer publishes `LogStream.name`
/// 3. LogStream Writer calls `ByteStream.Write` with
///    `LogStream.write_resource_name` as
///    `ByteStream.WriteRequest.resource_name`,
///    `ByteStream.WriteRequest.finish_write`=false.
/// 4. LogStream Reader(s) call `ByteStream.Read` with the published
///    `LogStream.name` as `ByteStream.ReadRequest.resource_name`.
/// 5. LogStream Service streams all committed bytes to LogStream Reader(s),
///    leave the stream open.
/// 6. LogStream Writer calls `ByteStream.Write` with
///    `LogStream.write_resource_name` as
///    `ByteStream.WriteRequest.resource_name`,
///    `ByteStream.WriteRequest.finish_write`=true.
/// 7. LogStream Service streams all remaining bytes to LogStream Reader(s),
///    terminates the stream.
///
/// Usage: instantiate `Build_Bazel_Remote_Logstream_V1_LogStreamServiceClient`, then call methods of this protocol to make API calls.
public protocol Build_Bazel_Remote_Logstream_V1_LogStreamServiceClientProtocol: GRPCClient {
  var serviceName: String { get }
  var interceptors: Build_Bazel_Remote_Logstream_V1_LogStreamServiceClientInterceptorFactoryProtocol? { get }

  func createLogStream(
    _ request: Build_Bazel_Remote_Logstream_V1_CreateLogStreamRequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Build_Bazel_Remote_Logstream_V1_CreateLogStreamRequest, Build_Bazel_Remote_Logstream_V1_LogStream>
}

extension Build_Bazel_Remote_Logstream_V1_LogStreamServiceClientProtocol {
  public var serviceName: String {
    return "build.bazel.remote.logstream.v1.LogStreamService"
  }

  /// Create a LogStream which may be written to.
  ///
  /// The returned LogStream resource name will include a `write_resource_name`
  /// which is the resource to use when writing to the LogStream.
  /// Callers of CreateLogStream are expected to NOT publish the
  /// `write_resource_name`.
  ///
  /// - Parameters:
  ///   - request: Request to send to CreateLogStream.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func createLogStream(
    _ request: Build_Bazel_Remote_Logstream_V1_CreateLogStreamRequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Build_Bazel_Remote_Logstream_V1_CreateLogStreamRequest, Build_Bazel_Remote_Logstream_V1_LogStream> {
    return self.makeUnaryCall(
      path: "/build.bazel.remote.logstream.v1.LogStreamService/CreateLogStream",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeCreateLogStreamInterceptors() ?? []
    )
  }
}

public protocol Build_Bazel_Remote_Logstream_V1_LogStreamServiceClientInterceptorFactoryProtocol {

  /// - Returns: Interceptors to use when invoking 'createLogStream'.
  func makeCreateLogStreamInterceptors() -> [ClientInterceptor<Build_Bazel_Remote_Logstream_V1_CreateLogStreamRequest, Build_Bazel_Remote_Logstream_V1_LogStream>]
}

public final class Build_Bazel_Remote_Logstream_V1_LogStreamServiceClient: Build_Bazel_Remote_Logstream_V1_LogStreamServiceClientProtocol {
  public let channel: GRPCChannel
  public var defaultCallOptions: CallOptions
  public var interceptors: Build_Bazel_Remote_Logstream_V1_LogStreamServiceClientInterceptorFactoryProtocol?

  /// Creates a client for the build.bazel.remote.logstream.v1.LogStreamService service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  ///   - interceptors: A factory providing interceptors for each RPC.
  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Build_Bazel_Remote_Logstream_V1_LogStreamServiceClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
    self.interceptors = interceptors
  }
}

/// #### Introduction
///
/// The Log Stream API manages LogStream resources which are used to stream
/// writes and reads of an ordered sequence of bytes of unknown eventual length.
///
/// Note that this is an API Interface and not an API Service, per the definitons
/// at: https://cloud.google.com/apis/design/glossary
///
/// Log Stream API supports the reading of unfinalized LogStreams either by
/// seeking or in "tail" mode, for example by end-users browsing to a build
/// result UI interested in seeing logs from a build action as soon as they are
/// (or as they become) available.
///
/// Reads and Writes of LogStreams are done via the Byte Stream API:
/// https://cloud.google.com/dataproc/docs/reference/rpc/google.bytestream
/// https://github.com/googleapis/googleapis/blob/master/google/bytestream/bytestream.proto
///
/// #### Writing LogStreams
///
/// LogStreams are written to via the Byte Stream API's `Write` RPC. Bytes
/// written to LogStreams are expected to be committed and available for reading
/// within a reasonable period of time (implementation-defined). Committed bytes
/// to a LogStream cannot be overwritten, and finalized LogStreams - indicated by
/// setting `finish_write` field in the final WriteRequest - also cannot be
/// appended to.
///
/// When calling the Byte Stream API's `Write` RPC to write LogStreams, writers
/// must pass the `write_resource_name` of a LogStream as
/// `ByteStream.WriteRequest.resource_name` rather than the LogStream's `name`.
/// Separate resource names for reading and writing allows for broadcasting the
/// read resource name widely while simultaneously ensuring that only writer(s)
/// with knowledge of the write resource name may have written bytes to the
/// LogStream.
///
/// #### Reading LogStreams
///
/// Use the Byte Stream API's `Read` RPC to read LogStreams. When reading
/// finalized LogStreams the server will stream all contents of the LogStream
/// starting at `ByteStream.ReadRequest.read_offset`.
///
/// When reading unfinalized LogStreams the server must keep the streaming
/// `ByteStream.Read` RPC open and send `ByteStream.ReadResponse` messages as
/// more bytes become available or the LogStream is finalized.
///
/// #### Example Multi-Party Read/Write Flow
///
/// 1. LogStream Writer calls `CreateLogStream`
/// 2. LogStream Writer publishes `LogStream.name`
/// 3. LogStream Writer calls `ByteStream.Write` with
///    `LogStream.write_resource_name` as
///    `ByteStream.WriteRequest.resource_name`,
///    `ByteStream.WriteRequest.finish_write`=false.
/// 4. LogStream Reader(s) call `ByteStream.Read` with the published
///    `LogStream.name` as `ByteStream.ReadRequest.resource_name`.
/// 5. LogStream Service streams all committed bytes to LogStream Reader(s),
///    leave the stream open.
/// 6. LogStream Writer calls `ByteStream.Write` with
///    `LogStream.write_resource_name` as
///    `ByteStream.WriteRequest.resource_name`,
///    `ByteStream.WriteRequest.finish_write`=true.
/// 7. LogStream Service streams all remaining bytes to LogStream Reader(s),
///    terminates the stream.
///
/// To build a server, implement a class that conforms to this protocol.
public protocol Build_Bazel_Remote_Logstream_V1_LogStreamServiceProvider: CallHandlerProvider {
  var interceptors: Build_Bazel_Remote_Logstream_V1_LogStreamServiceServerInterceptorFactoryProtocol? { get }

  /// Create a LogStream which may be written to.
  ///
  /// The returned LogStream resource name will include a `write_resource_name`
  /// which is the resource to use when writing to the LogStream.
  /// Callers of CreateLogStream are expected to NOT publish the
  /// `write_resource_name`.
  func createLogStream(request: Build_Bazel_Remote_Logstream_V1_CreateLogStreamRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Build_Bazel_Remote_Logstream_V1_LogStream>
}

extension Build_Bazel_Remote_Logstream_V1_LogStreamServiceProvider {
  public var serviceName: Substring { return "build.bazel.remote.logstream.v1.LogStreamService" }

  /// Determines, calls and returns the appropriate request handler, depending on the request's method.
  /// Returns nil for methods not handled by this service.
  public func handleMethod(
    _ methodName: Substring,
    callHandlerContext: CallHandlerContext
  ) -> GRPCCallHandler? {
    switch methodName {
    case "CreateLogStream":
      return CallHandlerFactory.makeUnary(
        callHandlerContext: callHandlerContext,
        interceptors: self.interceptors?.makeCreateLogStreamInterceptors() ?? []
      ) { context in
        return { request in
          self.createLogStream(request: request, context: context)
        }
      }

    default:
      return nil
    }
  }
}

public protocol Build_Bazel_Remote_Logstream_V1_LogStreamServiceServerInterceptorFactoryProtocol {

  /// - Returns: Interceptors to use when handling 'createLogStream'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeCreateLogStreamInterceptors() -> [ServerInterceptor<Build_Bazel_Remote_Logstream_V1_CreateLogStreamRequest, Build_Bazel_Remote_Logstream_V1_LogStream>]
}
