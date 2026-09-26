//! 快捷键数据模型（与 Swift 版 ShortKeyCore/ShortcutItem.swift 保持同构）。

use serde::{Deserialize, Serialize};

/// 修饰键集合。位定义与 macOS AXMenuItemCmdModifiers 解析兼容。
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default, Serialize, Deserialize)]
pub struct Modifiers(pub u8);

impl Modifiers {
    pub const CONTROL: Self = Self(1 << 0);
    pub const OPTION: Self = Self(1 << 1);
    pub const SHIFT: Self = Self(1 << 2);
    pub const COMMAND: Self = Self(1 << 3);

    pub fn contains(self, other: Self) -> bool {
        self.0 & other.0 == other.0
    }

    pub fn insert(&mut self, other: Self) {
        self.0 |= other.0;
    }

    /// ⌃⌥⇧⌘ 顺序的符号串
    pub fn symbols(&self) -> String {
        let mut s = String::new();
        if self.contains(Self::CONTROL) { s.push('⌃'); }
        if self.contains(Self::OPTION) { s.push('⌥'); }
        if self.contains(Self::SHIFT) { s.push('⇧'); }
        if self.contains(Self::COMMAND) { s.push('⌘'); }
        s
    }

    /// 解析 macOS AXMenuItemCmdModifiers 位掩码：shift=1, option=2, control=4, bit3=无 ⌘
    pub fn from_ax_modifiers(value: i64) -> Self {
        let mut m = Self::default();
        if value & 1 != 0 { m.insert(Self::SHIFT); }
        if value & 2 != 0 { m.insert(Self::OPTION); }
        if value & 4 != 0 { m.insert(Self::CONTROL); }
        if value & 8 == 0 { m.insert(Self::COMMAND); }
        m
    }
}

/// 一条快捷键
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ShortcutItem {
    pub id: String,
    pub title: String,
    pub key: String,
    pub modifiers: Modifiers,
    pub group: String,
    /// 完整菜单路径，如 ["文件", "导出", "导出为 PDF"]
    pub path: Vec<String>,
    pub enabled: bool,
}

impl ShortcutItem {
    pub fn new(title: &str, key: &str, modifiers: Modifiers, group: &str, path: Vec<String>) -> Self {
        let symbols = modifiers.symbols();
        let id = format!("{}\u{1f}{}\u{1f}{}{}", path.join("/"), title, symbols, key);
        Self {
            id,
            title: title.to_string(),
            key: key.to_string(),
            modifiers,
            group: group.to_string(),
            path,
            enabled: true,
        }
    }
}
