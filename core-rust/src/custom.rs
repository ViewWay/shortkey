//! 自定义快捷键 JSON 解析（与 Swift 版同构）。
//! 结构：[{"title": "...", "key": "T", "modifiers": ["cmd","shift"], "group": "...", "appId": "..."}]

use crate::accel::normalize_key_full;
use crate::model::{Modifiers, ShortcutItem};

pub fn parse(data: &[u8]) -> Vec<ShortcutItem> {
    #[derive(serde::Deserialize)]
    struct Entry {
        title: String,
        key: String,
        modifiers: Option<Vec<String>>,
        group: Option<String>,
        #[serde(default)]
        _app_id: Option<String>,
    }

    let Ok(entries) = serde_json::from_slice::<Vec<Entry>>(data) else {
        return Vec::new();
    };

    entries
        .into_iter()
        .filter(|entry| !entry.title.is_empty() && !entry.key.is_empty())
        .map(|entry| {
            let mut modifiers = Modifiers::default();
            for name in entry.modifiers.unwrap_or_default() {
                match name.to_ascii_lowercase().as_str() {
                    "cmd" | "command" => modifiers.insert(Modifiers::COMMAND),
                    "alt" | "option" => modifiers.insert(Modifiers::OPTION),
                    "ctrl" | "control" => modifiers.insert(Modifiers::CONTROL),
                    "shift" => modifiers.insert(Modifiers::SHIFT),
                    _ => {}
                }
            }
            let (display, virtual_key) = normalize_key_full(&entry.key)
                .unwrap_or((entry.key.clone(), None));
            ShortcutItem {
                id: format!("custom\u{1f}{}\u{1f}{}{}", entry.title, modifiers.symbols(), display),
                title: entry.title,
                key: display,
                modifiers,
                group: entry.group.unwrap_or_else(|| "自定义".into()),
                path: vec!["自定义".into()],
                enabled: true,
                virtual_key,
            }
        })
        .collect()
}
