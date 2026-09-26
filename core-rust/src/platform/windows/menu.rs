//! Win32 菜单枚举：前台窗口 → HMENU → 平铺菜单树。
//! 加速键文本解析交给 core 的 accel 模块。

use std::mem::size_of;

use windows::core::PWSTR;
use windows::Win32::Foundation::HMENU;
use windows::Win32::UI::WindowsAndMessaging::{
    GetForegroundWindow, GetMenu, GetMenuItemCount, GetMenuItemInfoW, GetSubMenu,
    MENUITEMINFOW, MIIM_STRING,
};

use crate::accel::parse_menu_text;
use crate::model::ShortcutItem;
use crate::source::{ForegroundApp, ShortcutSource};

/// Win32 菜单快捷键来源（经典 Win32 菜单的应用可枚举；
/// UWP/Electron 自绘界面不支持——这是平台边界，不是实现缺陷）
pub struct Win32MenuSource;

impl ShortcutSource for Win32MenuSource {
    fn name(&self) -> &'static str {
        "win32-menus"
    }

    fn collect(&self, _app: &ForegroundApp) -> Vec<ShortcutItem> {
        unsafe { collect_foreground() }
    }
}

unsafe fn collect_foreground() -> Vec<ShortcutItem> {
    let hwnd = GetForegroundWindow();
    if hwnd.is_invalid() {
        return Vec::new();
    }
    let hmenu = GetMenu(hwnd);
    if hmenu.is_invalid() {
        return Vec::new();
    }

    let mut items = Vec::new();
    let count = GetMenuItemCount(hmenu);
    for index in 0..count {
        let text = item_text(hmenu, index).unwrap_or_default();
        let sub = GetSubMenu(hmenu, index);
        if sub.is_invalid() {
            continue;
        }
        let group = text.split('\t').next().unwrap_or("").trim().to_string();
        walk(sub, &group, 1, &mut items);
    }
    items
}

unsafe fn walk(hmenu: HMENU, group: &str, depth: u32, out: &mut Vec<ShortcutItem>) {
    if depth > 8 {
        return;
    }
    let count = GetMenuItemCount(hmenu);
    for index in 0..count {
        let text = item_text(hmenu, index).unwrap_or_default();
        let sub = GetSubMenu(hmenu, index);
        if !sub.is_invalid() {
            let title = text.split('\t').next().unwrap_or("").trim().to_string();
            walk(sub, &title, depth + 1, out);
        } else if !text.is_empty() {
            if let Some(mut item) = parse_menu_text(&text) {
                item.group = group.to_string();
                item.path = vec![group.to_string()];
                out.push(item);
            }
        }
    }
}

/// 两段式读取菜单项文本（先探长度，再取内容）
unsafe fn item_text(hmenu: HMENU, index: u32) -> Option<String> {
    let mut info = MENUITEMINFOW {
        cbSize: size_of::<MENUITEMINFOW>() as u32,
        fMask: MIIM_STRING,
        ..Default::default()
    };
    if !GetMenuItemInfoW(hmenu, index, true, &mut info).as_bool() {
        return None;
    }
    if info.cch == 0 {
        return Some(String::new());
    }
    let mut buffer = vec![0u16; info.cch as usize + 1];
    info.dwTypeData = Some(PWSTR(buffer.as_mut_ptr()));
    info.cch += 1;
    if !GetMenuItemInfoW(hmenu, index, true, &mut info).as_bool() {
        return None;
    }
    Some(String::from_utf16_lossy(&buffer[..(info.cch as usize - 1).min(buffer.len())]))
}
