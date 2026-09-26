//! C ABI：供 Swift/macOS 壳直接复用 Rust 核心（第一步：模糊匹配评分）。

/// 模糊匹配评分：>=0 为命中分数，-1 为不匹配。
/// 入参均为 UTF-8 C 字符串。
#[no_mangle]
pub extern "C" fn shortkey_fuzzy_match(query: *const std::os::raw::c_char, target: *const std::os::raw::c_char) -> i32 {
    if query.is_null() || target.is_null() {
        return -1;
    }
    let query = unsafe { std::ffi::CStr::from_ptr(query) };
    let target = unsafe { std::ffi::CStr::from_ptr(target) };
    let Ok(query) = query.to_str() else { return -1 };
    let Ok(target) = target.to_str() else { return -1 };
    match crate::fuzzy::fuzzy_match(query, target) {
        Some(matched) => matched.score,
        None => -1,
    }
}

/// 核心版本号（冒烟/链路验证用）
#[no_mangle]
pub extern "C" fn shortkey_core_version() -> *const std::os::raw::c_char {
    b"0.1.0\0".as_ptr() as *const std::os::raw::c_char
}
