// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "RTMPNIO",
  dependencies: [
    .package(name: "swift-nio", url: "https://github.com/apple/swift-nio", from: "2.28.0"),
    .package(name: "swift-argument-parser", url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
  ],
  targets: [
    .executableTarget(
      name: "RTMPNIO",
      dependencies: [
        .product(name: "NIO", package: "swift-nio"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ]),
    .testTarget(
      name: "RTMPNIOTests",
      dependencies: ["RTMPNIO"]),
  ]
)
