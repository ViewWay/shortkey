import Foundation

/// 模糊匹配结果：评分 + 命中下标（用于高亮）
public struct FuzzyMatch: Sendable, Equatable {
    public let score: Int
    public let indices: [Int]

    public init(score: Int, indices: [Int]) {
        self.score = score
        self.indices = indices
    }
}

/// 极简模糊匹配：大小写不敏感的子序列匹配 + 简单评分
/// （连续命中、词首、无跳跃加分，越早匹配越好）。
/// 与 Rust 核心 `core-rust/src/fuzzy.rs` 保持同一套算法与分值。
public enum FuzzyMatcher {
    public static func match(query: String, target: String) -> FuzzyMatch? {
        let q = Array(query.lowercased())
        let t = Array(target.lowercased())
        guard !q.isEmpty, t.count >= q.count else { return nil }

        var indices: [Int] = []
        indices.reserveCapacity(q.count)
        var score = 0
        var ti = 0
        var previousIndex = -2

        for ch in q {
            guard let idx = t[ti...].firstIndex(of: ch) else { return nil }
            score += 10
            if idx == previousIndex + 1 { score += 8 }          // 连续命中
            if idx == 0 || isBoundary(t, at: idx) { score += 6 } // 词首
            if idx == ti { score += 2 }                          // 无跳跃
            indices.append(idx)
            previousIndex = idx
            ti = idx + 1
        }
        if let first = indices.first { score -= first }          // 越早匹配越好
        return FuzzyMatch(score: score, indices: indices)
    }

    private static func isBoundary(_ chars: [Character], at index: Int) -> Bool {
        guard index > 0 else { return true }
        switch chars[index - 1] {
        case " ", "-", "_", "…", "/", "(": return true
        default: return false
        }
    }
}
