//! Linux 实现 —— 计划。
//! 触发：X11 用 XGrabKey / XRecord；Wayland 无统一全局监听接口，
//!       需桌面环境配合（KDE KGlobalAccel / GNOME Shell 扩展 / xdg-desktop-portal）。
//! 快捷键来源：无统一 API，按桌面环境读取：
//! - GNOME: gsettings org.gnome.* keybindings
//! - KDE: ~/.config/kglobalshortcutsrc / khotkeysrc
//! - 应用自身配置（终端、编辑器等）

use crate::model::ShortcutItem;
use crate::source::{ForegroundApp, ShortcutSource};
use crate::trigger::{TriggerConfig, TriggerEngine, TriggerEvent};

/// 桌面环境快捷键来源 —— TODO
pub struct DesktopShortcutSource;

impl ShortcutSource for DesktopShortcutSource {
    fn name(&self) -> &'static str {
        "linux-desktop"
    }

    fn collect(&self, _app: &ForegroundApp) -> Vec<ShortcutItem> {
        // TODO: 检测 XDG_CURRENT_DESKTOP → 读取对应配置
        Vec::new()
    }
}

/// X11 长按触发 —— TODO
#[derive(Default)]
pub struct X11Trigger;

impl TriggerEngine for X11Trigger {
    fn start(
        &mut self,
        _config: TriggerConfig,
        _on_event: Box<dyn Fn(TriggerEvent) + Send + Sync>,
    ) -> Result<(), String> {
        // TODO: XRecord / XGrabKey；Wayland 环境下明确报错
        Err("Linux X11Trigger 尚未实现".to_string())
    }

    fn stop(&mut self) {}
}
