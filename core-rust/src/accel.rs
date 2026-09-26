//! Windows 菜单加速键文本解析：`"复制\tCtrl+C"` → 标题 + 组合键。
//! 纯逻辑，跨平台可测。

use crate::model::{Modifiers, ShortcutItem};

/// 解析 Win32 菜单项文本（含 \t 加速键后缀）。
/// 返回 None 表示该条目无加速键或为分隔符。
pub fn parse_menu_text(text: &str) -> Option<ShortcutItem> {
    let text = text.trim_matches('\0');
    if text.is_empty() {
        return None;
    }
    let (title, accel) = match text.split_once('\t') {
        Some((t, a)) => (t.trim(), a.trim()),
        None => return None,
    };
    if title.is_empty() {
        return None;
    }
    let (modifiers, key) = parse_accel(accel)?;
    Some(ShortcutItem::new(
        title,
        &key,
        modifiers,
        "菜单",
        vec!["菜单".to_string()],
        None,
    ))
}

/// 解析加速键描述："Ctrl+Shift+S" → (修饰键, 规范化键名)
pub fn parse_accel(accel: &str) -> Option<(Modifiers, String)> {
    let accel = accel.trim();
    if accel.is_empty() {
        return None;
    }
    let mut modifiers = Modifiers::default();
    let mut key_part: Option<String> = None;

    for token in accel.split('+') {
        let token = token.trim();
        if token.is_empty() {
            continue;
        }
        match token.to_ascii_lowercase().as_str() {
            "ctrl" | "control" => modifiers.insert(Modifiers::CONTROL),
            "alt" | "option" => modifiers.insert(Modifiers::OPTION),
            "shift" => modifiers.insert(Modifiers::SHIFT),
            "win" | "windows" => modifiers.insert(Modifiers::COMMAND),
            _ => key_part = Some(token.to_string()),
        }
    }
    let key = key_part?;
    let display = normalize_key(&key)?;
    Some((modifiers, display))
}

/// 键名规范化：特殊键名映射符号；字母转大写；F 键保持
fn normalize_key(key: &str) -> Option<String> {
    let lower = key.to_ascii_lowercase();
    let symbol = match lower.as_str() {
        "esc" | "escape" => "⎋",
        "enter" | "return" => "↩",
        "space" => "␣",
        "tab" => "⇥",
        "bksp" | "backspace" => "⌫",
        "del" | "delete" => "⌦",
        "ins" | "insert" => "⎀",
        "up" => "↑",
        "down" => "↓",
        "left" => "←",
        "right" => "→",
        "pgup" => "⇞",
        "pgdn" | "pagedown" => "⇟",
        "home" => "↖",
        "end" => "↘",
        _ => "",
    };
    if !symbol.is_empty() {
        return Some(symbol.to_string());
    }
    if lower.starts_with('f') && lower[1..].parse::<u8>().is_ok() {
        return Some(lower.to_uppercase());
    }
    let first = key.chars().next()?;
    if first.is_ascii_alphanumeric() {
        return Some(first.to_ascii_uppercase().to_string());
    }
    Some(key.to_string())
}

/// 键名 → (显示符号, 虚拟键码)；skhd / 自定义解析共用
pub fn normalize_key_full(name: &str) -> Option<(String, Option<u32>)> {
    let lower = name.to_ascii_lowercase();
    let special: Option<(&str, u32)> = match lower.as_str() {
        "esc" | "escape" => Some(("⎋", 53)),
        "enter" | "return" => Some(("↩", 36)),
        "space" => Some(("␣", 49)),
        "tab" => Some(("⇥", 48)),
        "bksp" | "backspace" => Some(("⌫", 51)),
        "del" | "delete" => Some(("⌦", 117)),
        "ins" | "insert" => Some(("⎀", 110)),
        "up" => Some(("↑", 126)),
        "down" => Some(("↓", 125)),
        "left" => Some(("←", 123)),
        "right" => Some(("→", 124)),
        "home" => Some(("↖", 115)),
        "end" => Some(("↘", 119)),
        "pgup" => Some(("⇞", 116)),
        "pgdn" | "pagedown" => Some(("⇟", 121)),
        _ => None,
    };
    if let Some((symbol, virtual_key)) = special {
        return Some((symbol.to_string(), Some(virtual_key)));
    }
    let display = normalize_key(name)?;
    let virtual_key = name
        .chars()
        .next()
        .and_then(char_key_code);
    Some((display, virtual_key))
}

/// ANSI 布局字符 → 虚拟键码
pub fn char_key_code(c: char) -> Option<u32> {
    let code = match c.to_ascii_lowercase() {
        'a' => 0, 's' => 1, 'd' => 2, 'f' => 3, 'h' => 4, 'g' => 5,
        'z' => 6, 'x' => 7, 'c' => 8, 'v' => 9, 'b' => 11, 'q' => 12,
        'w' => 13, 'e' => 14, 'r' => 15, 'y' => 16, 't' => 17,
        '1' => 18, '2' => 19, '3' => 20, '4' => 21, '6' => 22, '5' => 23,
        '=' => 24, '9' => 25, '7' => 26, '-' => 27, '8' => 28, '0' => 29,
        ']' => 30, 'o' => 31, 'u' => 32, '[' => 33, 'i' => 34, 'p' => 35,
        'l' => 37, 'j' => 38, '\'' => 39, 'k' => 40, ';' => 41, '\\' => 42,
        ',' => 44, '/' => 45, '.' => 46, '`' => 50, ' ' => 49,
        _ => return None,
    };
    Some(code)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_tab_accel() {
        let item = parse_menu_text("复制\tCtrl+C").unwrap();
        assert_eq!(item.title, "复制");
        assert_eq!(item.modifiers, Modifiers::CONTROL);
        assert_eq!(item.key, "C");
    }

    #[test]
    fn parses_shift_and_special_keys() {
        let item = parse_menu_text("保存\tCtrl+Shift+S").unwrap();
        assert_eq!(item.modifiers, Modifiers::CONTROL | Modifiers::SHIFT);
        assert_eq!(item.key, "S");

        let del = parse_menu_text("删除\tDel").unwrap();
        assert_eq!(del.key, "⌦");
        assert!(del.modifiers.is_empty());

        let f5 = parse_menu_text("刷新\tF5").unwrap();
        assert_eq!(f5.key, "F5");
    }

    #[test]
    fn ignores_items_without_accel() {
        assert!(parse_menu_text("无快捷键").is_none());
        assert!(parse_menu_text("").is_none());
        assert!(parse_menu_text("\tCtrl+C").is_none());
    }
}
