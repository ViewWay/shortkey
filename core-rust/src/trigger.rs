//! 触发器抽象：全局监听修饰键，按配置产生显示/隐藏事件。
//! 平台实现：macOS CGEventTap / Windows WH_KEYBOARD_LL / Linux X11 / DE 接口。

use std::time::Duration;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TriggerMode {
    /// 按住超过阈值
    Hold,
    /// 双击并按住
    DoubleTapHold,
}

#[derive(Debug, Clone)]
pub struct TriggerConfig {
    pub mode: TriggerMode,
    /// 纯修饰键按住多久后触发
    pub threshold: Duration,
}

impl Default for TriggerConfig {
    fn default() -> Self {
        Self {
            mode: TriggerMode::Hold,
            threshold: Duration::from_millis(300),
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TriggerEvent {
    Show,
    Hide,
}

/// 平台触发器。实现须在独立线程 / 事件循环中监听，并通过回调上报事件。
pub trait TriggerEngine {
    fn start(
        &mut self,
        config: TriggerConfig,
        on_event: Box<dyn Fn(TriggerEvent) + Send + Sync>,
    ) -> Result<(), String>;

    fn stop(&mut self);
}
