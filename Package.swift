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
      .package(url: "https://github.com/apple/swift-nio-transport-services.git", from: "1.3.0"),
      .package(url: "https://github.com/swift-server/swift-service-lifecycle.git", .branch("master"))
    ],
    targets: [
      .target(
        name: "BazelServer",
        dependencies: [
          .product(name: "NIO", package: "swift-nio"),
          .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
          .product(name: "GRPC", package: "grpc-swift"),
          .product(name: "Lifecycle", package: "swift-service-lifecycle"),
          "ActionCache",
          "ByteStream",
          "Capabilities",
          "CAS"
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
        name: "ActionCache",
        dependencies: [ "BazelRemoteAPI", "BazelUtilities",
                        .product(name: "SwiftToolsSupport-auto",
                                 package: "swift-tools-support-core")]),

      .target(
        name: "CAS",
        dependencies: ["BazelRemoteAPI", "BazelUtilities",
                       .product(name: "SwiftToolsSupport-auto",
                                package: "swift-tools-support-core")]),

      .target(
        name: "Capabilities",
        dependencies: ["BazelRemoteAPI"]),

      .target(
        name: "BazelUtilities",
        dependencies: [.product(name: "SwiftToolsSupport-auto",
                                package: "swift-tools-support-core")]),

      .testTarget(
        name: "swift-for-bazel-reTests",
        dependencies: ["BazelServer"]),
    ]
)
