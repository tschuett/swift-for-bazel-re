// swift-tools-version:5.2

import PackageDescription

let package = Package(
    name: "BazelServer",
    platforms: [
        .macOS(.v10_15),
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-nio.git",
               from: "2.22.0"),
      .package(url: "https://github.com/apple/swift-tools-support-core.git",
               .branch("master")),
      .package(url: "https://github.com/grpc/grpc-swift.git",
               .revision("640b0ef1d0be63bda0ada86786cfda678ab2aae9")), //from: "0.11.0"
      .package(url: "https://github.com/apple/swift-nio-transport-services.git",
               from: "1.6.0")
    ],
    targets: [
      .target(
        name: "BazelServer",
        dependencies: [
          .product(name: "NIO", package: "swift-nio"),
          .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
          .product(name: "GRPC", package: "grpc-swift"),
          "ActionCache",
          "ByteStream",
          "Capabilities",
          "CAS"
        ],
        exclude: ["main.swift~"]
      ),

      .target(
        name: "ByteStream",
        dependencies: ["BazelRemoteAPI",
                       .product(name: "SwiftToolsSupport-auto",
                                package: "swift-tools-support-core")],
        exclude: ["Utilities.swift~", "Typealias.swift~", "ByteStreamProvider.swift~",
                  "WriteFunction.swift~"]
      ),

      .target(
        name: "BazelRemoteAPI",
        dependencies: [
          .product(name: "GRPC", package: "grpc-swift"),
        ]),

      .target(
        name: "ActionCache",
        dependencies: [ "BazelRemoteAPI", "BazelUtilities",
                        .product(name: "SwiftToolsSupport-auto",
                                 package: "swift-tools-support-core")],
        exclude: ["ActionCacheProvider.swift~"]
      ),

      .target(
        name: "CAS",
        dependencies: ["BazelRemoteAPI", "BazelUtilities",
                       .product(name: "SwiftToolsSupport-auto",
                                package: "swift-tools-support-core")],
        exclude: ["Utilities.swift~", "Typealias.swift~", "CASProvider.swift~"]
      ),

      .target(
        name: "Capabilities",
        dependencies: ["BazelRemoteAPI"],
        exclude: ["CapabilitiesProvider.swift~"]
      ),

      .target(
        name: "BazelUtilities",
        dependencies: ["BazelRemoteAPI",
                       .product(name: "SwiftToolsSupport-auto",
                                package: "swift-tools-support-core")],
        exclude: ["Collector.swift~", "Crypto.swift~", "TypeAlias.swift~"]
      ),

      .testTarget(
        name: "swift-for-bazel-reTests",
        dependencies: ["BazelServer"]),
    ]
)
