//
// DO NOT EDIT.
//
// Generated by the protocol buffer compiler.
// Source: google/bytestream/bytestream.proto
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
/// The Byte Stream API enables a client to read and write a stream of bytes to
/// and from a resource. Resources have names, and these names are supplied in
/// the API calls below to identify the resource that is being read from or
/// written to.
///
/// All implementations of the Byte Stream API export the interface defined here:
///
/// * `Read()`: Reads the contents of a resource.
///
/// * `Write()`: Writes the contents of a resource. The client can call `Write()`
///   multiple times with the same resource and can check the status of the write
///   by calling `QueryWriteStatus()`.
///
/// #### Service parameters and metadata
///
/// The ByteStream API provides no direct way to access/modify any metadata
/// associated with the resource.
///
/// #### Errors
///
/// The errors returned by the service are in the Google canonical error space.
///
/// Usage: instantiate `Google_Bytestream_ByteStreamClient`, then call methods of this protocol to make API calls.
public protocol Google_Bytestream_ByteStreamClientProtocol: GRPCClient {
  var serviceName: String { get }
  var interceptors: Google_Bytestream_ByteStreamClientInterceptorFactoryProtocol? { get }

  func read(
    _ request: Google_Bytestream_ReadRequest,
    callOptions: CallOptions?,
    handler: @escaping (Google_Bytestream_ReadResponse) -> Void
  ) -> ServerStreamingCall<Google_Bytestream_ReadRequest, Google_Bytestream_ReadResponse>

  func write(
    callOptions: CallOptions?
  ) -> ClientStreamingCall<Google_Bytestream_WriteRequest, Google_Bytestream_WriteResponse>

  func queryWriteStatus(
    _ request: Google_Bytestream_QueryWriteStatusRequest,
    callOptions: CallOptions?
  ) -> UnaryCall<Google_Bytestream_QueryWriteStatusRequest, Google_Bytestream_QueryWriteStatusResponse>
}

extension Google_Bytestream_ByteStreamClientProtocol {
  public var serviceName: String {
    return "google.bytestream.ByteStream"
  }

  /// `Read()` is used to retrieve the contents of a resource as a sequence
  /// of bytes. The bytes are returned in a sequence of responses, and the
  /// responses are delivered as the results of a server-side streaming RPC.
  ///
  /// - Parameters:
  ///   - request: Request to send to Read.
  ///   - callOptions: Call options.
  ///   - handler: A closure called when each response is received from the server.
  /// - Returns: A `ServerStreamingCall` with futures for the metadata and status.
  public func read(
    _ request: Google_Bytestream_ReadRequest,
    callOptions: CallOptions? = nil,
    handler: @escaping (Google_Bytestream_ReadResponse) -> Void
  ) -> ServerStreamingCall<Google_Bytestream_ReadRequest, Google_Bytestream_ReadResponse> {
    return self.makeServerStreamingCall(
      path: "/google.bytestream.ByteStream/Read",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeReadInterceptors() ?? [],
      handler: handler
    )
  }

  /// `Write()` is used to send the contents of a resource as a sequence of
  /// bytes. The bytes are sent in a sequence of request protos of a client-side
  /// streaming RPC.
  ///
  /// A `Write()` action is resumable. If there is an error or the connection is
  /// broken during the `Write()`, the client should check the status of the
  /// `Write()` by calling `QueryWriteStatus()` and continue writing from the
  /// returned `committed_size`. This may be less than the amount of data the
  /// client previously sent.
  ///
  /// Calling `Write()` on a resource name that was previously written and
  /// finalized could cause an error, depending on whether the underlying service
  /// allows over-writing of previously written resources.
  ///
  /// When the client closes the request channel, the service will respond with
  /// a `WriteResponse`. The service will not view the resource as `complete`
  /// until the client has sent a `WriteRequest` with `finish_write` set to
  /// `true`. Sending any requests on a stream after sending a request with
  /// `finish_write` set to `true` will cause an error. The client **should**
  /// check the `WriteResponse` it receives to determine how much data the
  /// service was able to commit and whether the service views the resource as
  /// `complete` or not.
  ///
  /// Callers should use the `send` method on the returned object to send messages
  /// to the server. The caller should send an `.end` after the final message has been sent.
  ///
  /// - Parameters:
  ///   - callOptions: Call options.
  /// - Returns: A `ClientStreamingCall` with futures for the metadata, status and response.
  public func write(
    callOptions: CallOptions? = nil
  ) -> ClientStreamingCall<Google_Bytestream_WriteRequest, Google_Bytestream_WriteResponse> {
    return self.makeClientStreamingCall(
      path: "/google.bytestream.ByteStream/Write",
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeWriteInterceptors() ?? []
    )
  }

  /// `QueryWriteStatus()` is used to find the `committed_size` for a resource
  /// that is being written, which can then be used as the `write_offset` for
  /// the next `Write()` call.
  ///
  /// If the resource does not exist (i.e., the resource has been deleted, or the
  /// first `Write()` has not yet reached the service), this method returns the
  /// error `NOT_FOUND`.
  ///
  /// The client **may** call `QueryWriteStatus()` at any time to determine how
  /// much data has been processed for this resource. This is useful if the
  /// client is buffering data and needs to know which data can be safely
  /// evicted. For any sequence of `QueryWriteStatus()` calls for a given
  /// resource name, the sequence of returned `committed_size` values will be
  /// non-decreasing.
  ///
  /// - Parameters:
  ///   - request: Request to send to QueryWriteStatus.
  ///   - callOptions: Call options.
  /// - Returns: A `UnaryCall` with futures for the metadata, status and response.
  public func queryWriteStatus(
    _ request: Google_Bytestream_QueryWriteStatusRequest,
    callOptions: CallOptions? = nil
  ) -> UnaryCall<Google_Bytestream_QueryWriteStatusRequest, Google_Bytestream_QueryWriteStatusResponse> {
    return self.makeUnaryCall(
      path: "/google.bytestream.ByteStream/QueryWriteStatus",
      request: request,
      callOptions: callOptions ?? self.defaultCallOptions,
      interceptors: self.interceptors?.makeQueryWriteStatusInterceptors() ?? []
    )
  }
}

public protocol Google_Bytestream_ByteStreamClientInterceptorFactoryProtocol {

  /// - Returns: Interceptors to use when invoking 'read'.
  func makeReadInterceptors() -> [ClientInterceptor<Google_Bytestream_ReadRequest, Google_Bytestream_ReadResponse>]

  /// - Returns: Interceptors to use when invoking 'write'.
  func makeWriteInterceptors() -> [ClientInterceptor<Google_Bytestream_WriteRequest, Google_Bytestream_WriteResponse>]

  /// - Returns: Interceptors to use when invoking 'queryWriteStatus'.
  func makeQueryWriteStatusInterceptors() -> [ClientInterceptor<Google_Bytestream_QueryWriteStatusRequest, Google_Bytestream_QueryWriteStatusResponse>]
}

public final class Google_Bytestream_ByteStreamClient: Google_Bytestream_ByteStreamClientProtocol {
  public let channel: GRPCChannel
  public var defaultCallOptions: CallOptions
  public var interceptors: Google_Bytestream_ByteStreamClientInterceptorFactoryProtocol?

  /// Creates a client for the google.bytestream.ByteStream service.
  ///
  /// - Parameters:
  ///   - channel: `GRPCChannel` to the service host.
  ///   - defaultCallOptions: Options to use for each service call if the user doesn't provide them.
  ///   - interceptors: A factory providing interceptors for each RPC.
  public init(
    channel: GRPCChannel,
    defaultCallOptions: CallOptions = CallOptions(),
    interceptors: Google_Bytestream_ByteStreamClientInterceptorFactoryProtocol? = nil
  ) {
    self.channel = channel
    self.defaultCallOptions = defaultCallOptions
    self.interceptors = interceptors
  }
}

/// #### Introduction
///
/// The Byte Stream API enables a client to read and write a stream of bytes to
/// and from a resource. Resources have names, and these names are supplied in
/// the API calls below to identify the resource that is being read from or
/// written to.
///
/// All implementations of the Byte Stream API export the interface defined here:
///
/// * `Read()`: Reads the contents of a resource.
///
/// * `Write()`: Writes the contents of a resource. The client can call `Write()`
///   multiple times with the same resource and can check the status of the write
///   by calling `QueryWriteStatus()`.
///
/// #### Service parameters and metadata
///
/// The ByteStream API provides no direct way to access/modify any metadata
/// associated with the resource.
///
/// #### Errors
///
/// The errors returned by the service are in the Google canonical error space.
///
/// To build a server, implement a class that conforms to this protocol.
public protocol Google_Bytestream_ByteStreamProvider: CallHandlerProvider {
  var interceptors: Google_Bytestream_ByteStreamServerInterceptorFactoryProtocol? { get }

  /// `Read()` is used to retrieve the contents of a resource as a sequence
  /// of bytes. The bytes are returned in a sequence of responses, and the
  /// responses are delivered as the results of a server-side streaming RPC.
  func read(request: Google_Bytestream_ReadRequest, context: StreamingResponseCallContext<Google_Bytestream_ReadResponse>) -> EventLoopFuture<GRPCStatus>

  /// `Write()` is used to send the contents of a resource as a sequence of
  /// bytes. The bytes are sent in a sequence of request protos of a client-side
  /// streaming RPC.
  ///
  /// A `Write()` action is resumable. If there is an error or the connection is
  /// broken during the `Write()`, the client should check the status of the
  /// `Write()` by calling `QueryWriteStatus()` and continue writing from the
  /// returned `committed_size`. This may be less than the amount of data the
  /// client previously sent.
  ///
  /// Calling `Write()` on a resource name that was previously written and
  /// finalized could cause an error, depending on whether the underlying service
  /// allows over-writing of previously written resources.
  ///
  /// When the client closes the request channel, the service will respond with
  /// a `WriteResponse`. The service will not view the resource as `complete`
  /// until the client has sent a `WriteRequest` with `finish_write` set to
  /// `true`. Sending any requests on a stream after sending a request with
  /// `finish_write` set to `true` will cause an error. The client **should**
  /// check the `WriteResponse` it receives to determine how much data the
  /// service was able to commit and whether the service views the resource as
  /// `complete` or not.
  func write(context: UnaryResponseCallContext<Google_Bytestream_WriteResponse>) -> EventLoopFuture<(StreamEvent<Google_Bytestream_WriteRequest>) -> Void>

  /// `QueryWriteStatus()` is used to find the `committed_size` for a resource
  /// that is being written, which can then be used as the `write_offset` for
  /// the next `Write()` call.
  ///
  /// If the resource does not exist (i.e., the resource has been deleted, or the
  /// first `Write()` has not yet reached the service), this method returns the
  /// error `NOT_FOUND`.
  ///
  /// The client **may** call `QueryWriteStatus()` at any time to determine how
  /// much data has been processed for this resource. This is useful if the
  /// client is buffering data and needs to know which data can be safely
  /// evicted. For any sequence of `QueryWriteStatus()` calls for a given
  /// resource name, the sequence of returned `committed_size` values will be
  /// non-decreasing.
  func queryWriteStatus(request: Google_Bytestream_QueryWriteStatusRequest, context: StatusOnlyCallContext) -> EventLoopFuture<Google_Bytestream_QueryWriteStatusResponse>
}

extension Google_Bytestream_ByteStreamProvider {
  public var serviceName: Substring { return "google.bytestream.ByteStream" }

  /// Determines, calls and returns the appropriate request handler, depending on the request's method.
  /// Returns nil for methods not handled by this service.
  public func handle(
    method name: Substring,
    context: CallHandlerContext
  ) -> GRPCServerHandlerProtocol? {
    switch name {
    case "Read":
      return ServerStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Google_Bytestream_ReadRequest>(),
        responseSerializer: ProtobufSerializer<Google_Bytestream_ReadResponse>(),
        interceptors: self.interceptors?.makeReadInterceptors() ?? [],
        userFunction: self.read(request:context:)
      )

    case "Write":
      return ClientStreamingServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Google_Bytestream_WriteRequest>(),
        responseSerializer: ProtobufSerializer<Google_Bytestream_WriteResponse>(),
        interceptors: self.interceptors?.makeWriteInterceptors() ?? [],
        observerFactory: self.write(context:)
      )

    case "QueryWriteStatus":
      return UnaryServerHandler(
        context: context,
        requestDeserializer: ProtobufDeserializer<Google_Bytestream_QueryWriteStatusRequest>(),
        responseSerializer: ProtobufSerializer<Google_Bytestream_QueryWriteStatusResponse>(),
        interceptors: self.interceptors?.makeQueryWriteStatusInterceptors() ?? [],
        userFunction: self.queryWriteStatus(request:context:)
      )

    default:
      return nil
    }
  }
}

public protocol Google_Bytestream_ByteStreamServerInterceptorFactoryProtocol {

  /// - Returns: Interceptors to use when handling 'read'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeReadInterceptors() -> [ServerInterceptor<Google_Bytestream_ReadRequest, Google_Bytestream_ReadResponse>]

  /// - Returns: Interceptors to use when handling 'write'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeWriteInterceptors() -> [ServerInterceptor<Google_Bytestream_WriteRequest, Google_Bytestream_WriteResponse>]

  /// - Returns: Interceptors to use when handling 'queryWriteStatus'.
  ///   Defaults to calling `self.makeInterceptors()`.
  func makeQueryWriteStatusInterceptors() -> [ServerInterceptor<Google_Bytestream_QueryWriteStatusRequest, Google_Bytestream_QueryWriteStatusResponse>]
}
