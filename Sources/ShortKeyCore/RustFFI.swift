import Foundation

/// Rust 核心的 C ABI（libshortkey_core.a，构建见 Scripts/build_app.sh）。
/// 用 @_silgen_name 免 module map；仅 macOS 生效。
@_silgen_name("shortkey_fuzzy_match")
func shortkey_rust_fuzzy_match(_ query: UnsafePointer<CChar>?, _ target: UnsafePointer<CChar>?) -> Int32

@_silgen_name("shortkey_core_version")
func shortkey_rust_core_version() -> UnsafePointer<CChar>?

/// Rust 核心桥（第一步：模糊匹配评分；后续逐步迁移逻辑）
public enum RustCore {
    /// Rust 版模糊匹配评分；-1（不匹配）映射为 nil
    public static func fuzzyScore(query: String, target: String) -> Int? {
        query.withCString { queryPtr in
            target.withCString { targetPtr in
                let score = shortkey_rust_fuzzy_match(queryPtr, targetPtr)
                return score < 0 ? nil : Int(score)
            }
        }
    }

    public static var version: String? {
        guard let pointer = shortkey_rust_core_version() else { return nil }
        return String(cString: pointer)
    }
}
