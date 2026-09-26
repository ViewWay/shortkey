//! Linux 平台实现。
pub mod sources;
pub mod trigger;

pub use crate::kde::parse_kglobalshortcutsrc;
pub use sources::GnomeShortcutSource;
pub use trigger::PollTrigger;
