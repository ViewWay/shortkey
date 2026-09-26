//! skhd 配置解析（与 Swift 版 SkhdParser 保持同构）。

use crate::model::{Modifiers, ShortcutItem};

/// 解析 skhd 配置文本，行格式：`cmd + shift - r : <command>`
pub fn parse(text: &str) -> Vec<ShortcutItem> {
    let mut items: Vec<ShortcutItem> = Vec::new();
    let mut seen = std::collections::HashSet::new();

    for raw_line in text.split('\n') {
        let line = raw_line.trim();
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        let Some((spec, command)) = line.split_once(':') else {
            continue;
        };
        let command = command.trim();
        if command.is_empty() {
            continue;
        }
        let Some((mods_part, key_part)) = spec.split_once('-') else {
            continue;
        };

        let mut modifiers = Modifiers::default();
        for token in mods_part.split('+') {
            match token.trim().to_ascii_lowercase().as_str() {
                "cmd" | "command" => modifiers.insert(Modifiers::COMMAND),
                "alt" | "option" => modifiers.insert(Modifiers::OPTION),
                "ctrl" | "control" => modifiers.insert(Modifiers::CONTROL),
                "shift" => modifiers.insert(Modifiers::SHIFT),
                "hyper" => modifiers
                    .insert(Modifiers::COMMAND | Modifiers::OPTION | Modifiers::CONTROL | Modifiers::SHIFT),
                "meh" => modifiers.insert(Modifiers::COMMAND | Modifiers::OPTION | Modifiers::CONTROL),
                _ => {}
            }
        }

        let key_name = key_part.trim();
        let Some((display, virtual_key)) = crate::accel::normalize_key_full(key_name) else {
            continue;
        };

        let title = command.to_string();
        let id = format!("skhd\u{1f}{title}\u{1f}{}{display}", modifiers.symbols());
        if !seen.insert(id.clone()) {
            continue;
        }

        items.push(ShortcutItem {
            id,
            title,
            key: display,
            modifiers,
            group: "skhd".into(),
            path: vec!["skhd".into()],
            enabled: true,
            virtual_key,
        });
    }
    items
}
