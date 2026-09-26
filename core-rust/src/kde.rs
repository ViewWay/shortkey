//! KDE 快捷键配置解析（纯逻辑，跨平台可测）。

use crate::accel::normalize_key_full;
use crate::model::{Modifiers, ShortcutItem};

/// 解析 KDE `~/.config/kglobalshortcutsrc`。
pub fn parse_kglobalshortcutsrc(text: &str) -> Vec<ShortcutItem> {
    let mut items = Vec::new();
    let mut section = String::from("KDE");
    for raw_line in text.lines() {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if line.starts_with('[') {
            section = line.trim_matches(['[', ']', '"']).replace("][", "/");
            continue;
        }
        let Some((action, rest)) = line.split_once('=') else {
            continue;
        };
        let parts: Vec<&str> = rest.split(',').collect();
        let shortcut = parts.get(1).unwrap_or(&"").trim();
        if shortcut.is_empty() || shortcut == "none" {
            continue;
        }
        let Some((modifiers, key)) = parse_shortcut_notation(shortcut) else {
            continue;
        };
        items.push(ShortcutItem {
            id: format!("kde\u{1f}{section}\u{1f}{action}"),
            title: format!("[{section}] {action}"),
            key,
            modifiers,
            group: "KDE".into(),
            path: vec!["KDE".into()],
            enabled: true,
            virtual_key: None,
        });
    }
    items
}

/// KDE 记法："Ctrl+Alt+T" / "Meta+Space"
pub fn parse_shortcut_notation(text: &str) -> Option<(Modifiers, String)> {
    let mut modifiers = Modifiers::default();
    let mut key = String::new();
    for token in text.split('+') {
        match token.trim().to_ascii_lowercase().as_str() {
            "ctrl" => modifiers.insert(Modifiers::CONTROL),
            "alt" => modifiers.insert(Modifiers::OPTION),
            "shift" => modifiers.insert(Modifiers::SHIFT),
            "meta" | "win" => modifiers.insert(Modifiers::COMMAND),
            _ => key = token.trim().to_string(),
        }
    }
    if key.is_empty() {
        return None;
    }
    normalize_key_full(&key).map(|(display, _)| (modifiers, display))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_kde_sections() {
        let text = "[Services][kdesu]\nlaunch=kdesu %u,Ctrl+Alt+K,none\n\n[KDE][kwin]\nKill Window=.Meta+W,none\n";
        let items = parse_kglobalshortcutsrc(text);
        assert_eq!(items.len(), 1); // Meta+W 在默认位 → none 跳过
        assert_eq!(items[0].key, "K");
        assert_eq!(items[0].modifiers, Modifiers::CONTROL | Modifiers::OPTION);
        assert!(items[0].title.starts_with("[Services/kdesu]"));
    }

    #[test]
    fn parses_meta_notation() {
        let (modifiers, key) = parse_shortcut_notation("Meta+Space").unwrap();
        assert_eq!(modifiers, Modifiers::COMMAND);
        assert_eq!(key, "␣");
    }
}
