//! 平台实现层：每个平台提供快捷键来源 + 触发器。
//! 未完成的实现返回空结果 / 显式错误，保证 crate 在所有平台编译通过。

#[cfg(target_os = "macos")]
pub mod macos;

#[cfg(target_os = "windows")]
pub mod windows;

#[cfg(target_os = "linux")]
pub mod linux;
