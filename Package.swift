// swift-tools-version:5.1

import PackageDescription

let package = Package(
    name: "swift-for-bazel-re",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
      .library(name: "SwiftForBazelRE", targets: ["SFBRActionCache", "SFBRByteStream",
                                                  "SFBRCAS", "SFBRCapabilities"]),
      .executable(name: "BazelServer", targets: ["BazelServer"]),
    ],
    dependencies: [
      .package(url: "https://github.com/apple/swift-nio.git",
               from: "2.22.0"),
      .package(url: "https://github.com/apple/swift-tools-support-core.git",
               .branch("main")),
      .package(url: "https://github.com/grpc/grpc-swift.git",
               .revision("efb67a324eaf1696b50e66bc471a53690e41fbf6")),
      .package(url: "https://github.com/apple/swift-nio-transport-services.git",
               from: "1.6.0"),
    ],
    targets: [
      .target(
        name: "BazelServer",
        dependencies: [
          .product(name: "NIO", package: "swift-nio"),
          .product(name: "NIOTransportServices", package: "swift-nio-transport-services"),
          .product(name: "GRPC", package: "grpc-swift"),
          "SFBRActionCache",
          "SFBRByteStream",
          "SFBRCapabilities",
          "SFBRCAS"
        ],
        exclude: ["main.swift~"]
      ),

      .target(
        name: "SFBRByteStream",
        dependencies: ["SFBRBazelRemoteAPI", "BazelUtilities",
                       .product(name: "SwiftToolsSupport-auto",
                                package: "swift-tools-support-core")],
        exclude: ["Utilities.swift~", "Typealias.swift~", "ByteStreamProvider.swift~",
                  "ReadFunction.swift~", "WriteFunction.swift~"]
      ),

      .target(
        name: "SFBRBazelRemoteAPI",
        dependencies: [
          .product(name: "GRPC", package: "grpc-swift"),
        ]),

      .target(
        name: "SFBRActionCache",
        dependencies: [ "SFBRBazelRemoteAPI", "BazelUtilities",
                        .product(name: "SwiftToolsSupport-auto",
                                 package: "swift-tools-support-core")],
        exclude: ["ActionCacheProvider.swift~"]
      ),

      .target(
        name: "SFBRCAS",
        dependencies: ["SFBRBazelRemoteAPI", "BazelUtilities",
                       .product(name: "SwiftToolsSupport-auto",
                                package: "swift-tools-support-core")],
        exclude: ["Utilities.swift~", "Typealias.swift~", "CASProvider.swift~"]
      ),

      .target(
        name: "SFBRCapabilities",
        dependencies: ["SFBRBazelRemoteAPI"],
        exclude: ["CapabilitiesProvider.swift~"]
      ),

      .target(
        name: "BazelUtilities",
        dependencies: ["SFBRBazelRemoteAPI",
                       .product(name: "GRPC", package: "grpc-swift"),
                       .product(name: "SwiftToolsSupport-auto",
                                package: "swift-tools-support-core")],
        exclude: ["Collector.swift~", "Crypto.swift~", "TypeAlias.swift~"]
      ),

      .testTarget(
        name: "swift-for-bazel-reTests",
        dependencies: ["SFBRBazelRemoteAPI", "SFBRCAS", "SFBRByteStream", "SFBRCapabilities",
                       "SFBRActionCache"]),
    ]
)
