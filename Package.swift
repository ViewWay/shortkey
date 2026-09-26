// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ShortKey",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "ShortKey", targets: ["ShortKey"]),
        .library(name: "ShortKeyCore", targets: ["ShortKeyCore"]),
    ],
    targets: [
        // 纯逻辑：模型 / 模糊匹配 / 键名映射（可单测，不依赖 AppKit）
        // macOS 下链入 Rust 核心（core-rust/target/release/libshortkey_core.a，见 build_app.sh）
        .target(
            name: "ShortKeyCore",
            linkerSettings: [
                .unsafeFlags(["-L", "core-rust/target/release"], .when(platforms: [.macOS])),
                .linkedLibrary("shortkey_core", .when(platforms: [.macOS])),
                .linkedFramework("Security", .when(platforms: [.macOS])),
                .linkedFramework("CoreFoundation", .when(platforms: [.macOS])),
            ]
        ),
        // 主程序：事件监听、AX 读取、浮层 UI
        .executableTarget(
            name: "ShortKey",
            dependencies: ["ShortKeyCore"],
            path: "Sources/ShortKey"
        ),
        .testTarget(
            name: "ShortKeyCoreTests",
            dependencies: ["ShortKeyCore"],
            path: "Tests/ShortKeyCoreTests"
        ),
    ]
)
