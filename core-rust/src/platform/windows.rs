//! Windows 实现 —— 计划。
//! 触发：WH_KEYBOARD_LL 低级键盘钩子检测修饰键长按（无需额外权限）。
//! 快捷键来源：
//! - 经典 Win32 菜单：GetForegroundWindow → GetMenu → GetMenuItemInfo（含 "Ctrl+C" 文本）
//! - 局限：UWP / WinUI / Electron 等现代应用不暴露统一菜单 API
//! - 可选补充：读取常见软件自身配置（如 VS Code keybindings.json）

use crate::model::ShortcutItem;
use crate::source::{ForegroundApp, ShortcutSource};
use crate::trigger::{TriggerConfig, TriggerEngine, TriggerEvent};

/// Win32 菜单快捷键来源 —— TODO
pub struct Win32MenuSource;

impl ShortcutSource for Win32MenuSource {
    fn name(&self) -> &'static str {
        "win32-menus"
    }

    fn collect(&self, _app: &ForegroundApp) -> Vec<ShortcutItem> {
        // TODO: GetMenu / GetMenuItemInfo / 加速键文本解析
        Vec::new()
    }
}

/// WH_KEYBOARD_LL 长按触发 —— TODO
#[derive(Default)]
pub struct KeyboardHookTrigger;

impl TriggerEngine for KeyboardHookTrigger {
    fn start(
        &mut self,
        _config: TriggerConfig,
        _on_event: Box<dyn Fn(TriggerEvent) + Send + Sync>,
    ) -> Result<(), String> {
        // TODO: SetWindowsHookExW(WH_KEYBOARD_LL) + 消息循环
        Err("Windows KeyboardHookTrigger 尚未实现".to_string())
    }

    fn stop(&mut self) {}
}
