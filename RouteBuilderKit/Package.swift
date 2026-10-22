// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "RouteBuilderKit",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "RouteAPI", targets: ["RouteAPI"]),
        .library(name: "RouteCore", targets: ["RouteCore"]),
    ],
    targets: [
        .target(name: "RouteAPI"),
        .target(name: "RouteCore", dependencies: ["RouteAPI"]),
        .testTarget(
            name: "RouteAPITests",
            dependencies: ["RouteAPI"],
            resources: [.copy("Fixtures")]
        ),
        .testTarget(name: "RouteCoreTests", dependencies: ["RouteCore"]),
        .testTarget(name: "RouteAPILiveTests", dependencies: ["RouteAPI"]),
    ]
)
