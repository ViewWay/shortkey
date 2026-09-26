//! ShortKey 跨平台核心骨架。
//!
//! 目标：把「与平台无关」的产品逻辑收敛在这里；macOS / Windows / 平台各提供一个薄壳，实现两个 trait 即可接入：
//! - [`trigger::TriggerEngine`]：全局键盘监听（长按修饰键触发浮层）
//! - [`source::ShortcutSource`]：枚举前台应用的快捷键
//!
//! 平台实现进度见 `src/platform/`，产品现状见仓库根目录 README。

pub mod accel;
pub mod fuzzy;
pub mod model;
pub mod platform;
pub mod source;
pub mod store;
pub mod trigger;

pub use fuzzy::fuzzy_match;
pub use model::{Modifiers, ShortcutItem};
pub use source::{Aggregator, ForegroundApp, ShortcutSource};
pub use store::Store;
pub use trigger::{TriggerConfig, TriggerEvent, TriggerEngine, TriggerMode};
