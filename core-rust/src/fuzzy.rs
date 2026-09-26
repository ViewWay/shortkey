//! 模糊匹配：大小写不敏感子序列 + 评分。
//! 与 Swift 版 FuzzyMatcher 同一套算法与分值，保证两端行为一致。

/// 命中结果：评分 + 命中下标（用于高亮）
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FuzzyMatch {
    pub score: i32,
    pub indices: Vec<usize>,
}

pub fn fuzzy_match(query: &str, target: &str) -> Option<FuzzyMatch> {
    let q: Vec<char> = query.to_lowercase().chars().collect();
    let t: Vec<char> = target.to_lowercase().chars().collect();
    if q.is_empty() || t.len() < q.len() {
        return None;
    }

    let mut indices = Vec::with_capacity(q.len());
    let mut score: i32 = 0;
    let mut ti = 0usize;
    let mut previous: isize = -2;

    for ch in q {
        let found = (ti..t.len()).find(|&i| t[i] == ch)?;
        score += 10;
        if found as isize == previous + 1 { score += 8; }       // 连续命中
        if found == 0 || is_boundary(&t, found) { score += 6; } // 词首
        if found == ti { score += 2; }                          // 无跳跃
        indices.push(found);
        previous = found as isize;
        ti = found + 1;
    }
    score -= *indices.first().unwrap_or(&0) as i32;
    Some(FuzzyMatch { score, indices })
}

fn is_boundary(chars: &[char], index: usize) -> bool {
    matches!(chars[index - 1], ' ' | '-' | '_' | '…' | '/' | '(')
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn subsequence() {
        let m = fuzzy_match("sv", "Save").unwrap();
        assert_eq!(m.indices, vec![0, 2]);
    }

    #[test]
    fn case_insensitive() {
        assert!(fuzzy_match("SAVE", "save").is_some());
    }

    #[test]
    fn no_match() {
        assert!(fuzzy_match("zz", "Save").is_none());
        assert!(fuzzy_match("", "Save").is_none());
        assert!(fuzzy_match("saves", "Save").is_none());
    }

    #[test]
    fn consecutive_beats_spread() {
        let a = fuzzy_match("fil", "File Name").unwrap().score;
        let b = fuzzy_match("fne", "File Name").unwrap().score;
        assert!(a > b);
    }

    #[test]
    fn chinese() {
        assert!(fuzzy_match("文件", "文件").is_some());
        assert!(fuzzy_match("文", "新建文件").is_some());
    }
}
