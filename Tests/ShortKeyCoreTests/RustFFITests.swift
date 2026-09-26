import XCTest
@testable import ShortKeyCore

/// 验证 Swift ↔ Rust 静态库链路与算法一致性
final class RustFFITests: XCTestCase {
    func testVersionSmoke() {
        XCTAssertEqual(RustCore.version, "0.1.0")
    }

    func testFuzzyScoreParityWithSwift() {
        let cases: [(String, String)] = [
            ("sv", "Save"),
            ("fil", "File Name"),
            ("文件", "新建文件"),
            ("zz", "Save"),
        ]
        for (query, target) in cases {
            let rust = RustCore.fuzzyScore(query: query, target: target)
            let swift = FuzzyMatcher.match(query: query, target: target)?.score
            // 命中与否必须一致；命中时分数一致（同一套算法）
            if swift == nil {
                XCTAssertNil(rust)
            } else {
                XCTAssertEqual(rust, swift)
            }
        }
    }
}
