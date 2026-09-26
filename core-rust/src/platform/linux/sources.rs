//! Linux 快捷键来源：KDE（core 解析器）+ GNOME（gsettings 子进程）。

use crate::kde;
use crate::model::ShortcutItem;

pub use crate::kde::parse_kglobalshortcutsrc;

/// GNOME：调 gsettings 枚举自定义键绑定
pub struct GnomeShortcutSource;

impl crate::source::ShortcutSource for GnomeShortcutSource {
    fn name(&self) -> &'static str {
        "gnome-gsettings"
    }

    fn collect(&self, _app: &crate::source::ForegroundApp) -> Vec<ShortcutItem> {
        let Ok(output) = std::process::Command::new("gsettings")
            .args(["get", "org.gnome.settings-daemon.plugins.media-keys", "custom-keybindings"])
            .output()
        else {
            return Vec::new();
        };
        let text = String::from_utf8_lossy(&output.stdout);
        let mut items = Vec::new();
        for path in text.split('\'').step_by(2).skip(1) {
            let base = path.trim_end_matches('/');
            let (Ok(name), Ok(binding)) = (
                std::process::Command::new("gsettings").args(["get", base, "name"]).output(),
                std::process::Command::new("gsettings").args(["get", base, "binding"]).output(),
            ) else {
                continue;
            };
            let name = String::from_utf8_lossy(&name.stdout).trim_matches('\'').to_string();
            let binding = String::from_utf8_lossy(&binding.stdout).trim_matches('\'').to_string();
            if name.is_empty() || binding.is_empty() {
                continue;
            }
            let notation = binding.replace('<', "").replace('>', "+");
            if let Some((modifiers, key)) = kde::parse_shortcut_notation(&notation) {
                items.push(ShortcutItem {
                    id: format!("gnome\u{1f}{base}\u{1f}{name}"),
                    title: name,
                    key,
                    modifiers,
                    group: "GNOME".into(),
                    path: vec!["GNOME".into()],
                    enabled: true,
                    virtual_key: None,
                });
            }
        }
        items
    }
}
