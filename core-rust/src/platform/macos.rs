//! macOS 实现。
//! 现状：MVP 由仓库根目录的 Swift 原生应用实现（CGEventTap + Accessibility API）。
//! 计划：经 FFI 把本 crate 接入 Swift 壳，或用 objc2/core-foundation 纯 Rust 实现。

use crate::model::ShortcutItem;
use crate::source::{ForegroundApp, ShortcutSource};
use crate::trigger::{TriggerConfig, TriggerEngine, TriggerEvent};

/// 读取前台应用菜单栏快捷键（Accessibility API）—— TODO
pub struct MenuSource;

impl ShortcutSource for MenuSource {
    fn name(&self) -> &'static str {
        "macos-menus"
    }

    fn collect(&self, _app: &ForegroundApp) -> Vec<ShortcutItem> {
        // TODO: AXUIElementCreateApplication → AXMenuBar 递归遍历
        // （参考 Swift 版 MenuShortcutsReader.swift）
        Vec::new()
    }
}

/// CGEventTap 长按触发 —— TODO
#[derive(Default)]
pub struct EventTapTrigger;

impl TriggerEngine for EventTapTrigger {
    fn start(
        &mut self,
        _config: TriggerConfig,
        _on_event: Box<dyn Fn(TriggerEvent) + Send + Sync>,
    ) -> Result<(), String> {
        // TODO: CGEvent.tapCreate + flagsChanged 状态机（参考 Swift 版 EventTapController）
        Err("macOS EventTapTrigger 尚未实现".to_string())
    }

    fn stop(&mut self) {}
}
