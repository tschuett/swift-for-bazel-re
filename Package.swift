// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "BazelServer",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-nio.git", from: "2.14.0"),
      .package(url: "https://github.com/apple/swift-tools-support-core.git", .branch("master")),
      .package(url: "https://github.com/grpc/grpc-swift.git", .branch("master")),
      .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.3.0")
    ],
    targets: [
      .target(
        name: "BazelServer",
        dependencies: [
          .product(name: "NIO", package: "swift-nio"),
          .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
          .product(name: "GRPC", package: "grpc-swift"),
          "ByteStream", "Capabilities"
        ]),

      .target(
        name: "ByteStream",
        dependencies: ["BazelRemoteAPI",
                       .product(name: "SwiftToolsSupport-auto",
                                package: "swift-tools-support-core")]),

      .target(
        name: "BazelRemoteAPI",
        dependencies: [
          .product(name: "GRPC", package: "grpc-swift"),
        ]),

      .target(
        name: "Capabilities",
        dependencies: ["BazelRemoteAPI"]),

      .testTarget(
        name: "swift-for-bazel-reTests",
        dependencies: ["BazelServer"]),
    ]
)
