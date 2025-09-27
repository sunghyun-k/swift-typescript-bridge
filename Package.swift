// swift-tools-version: 6.2
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "swift-typescript-bridge",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "TypeScriptBridge",
            targets: ["TypeScriptBridge"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0")
    ],
    targets: [
        .macro(
            name: "TypeScriptBridgeMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ]
        ),
        .target(
            name: "TypeScriptBridge",
            dependencies: ["TypeScriptBridgeMacros"]
        ),
        .testTarget(
            name: "TypeScriptBridgeTests",
            dependencies: ["TypeScriptBridge"]
        ),
    ]
)
