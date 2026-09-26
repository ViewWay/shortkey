//! Windows 平台实现。
pub mod menu;
pub mod trigger;

pub use menu::Win32MenuSource;
pub use trigger::KeyboardHookTrigger;
