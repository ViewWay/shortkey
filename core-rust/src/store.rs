//! 收藏 / 隐藏状态持久化（按应用 ID 分组），JSON 文件存储。
//! JSON 结构与 Swift 版 state.json 同构：
//! {"<app_id>": {"favorites": ["<条目id>"], "hidden": ["<条目id>"]}}

use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::path::PathBuf;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct AppState {
    #[serde(default)]
    pub favorites: HashSet<String>,
    #[serde(default)]
    pub hidden: HashSet<String>,
}

#[derive(Debug, Default)]
pub struct Store {
    path: Option<PathBuf>,
    states: HashMap<String, AppState>,
}

impl Store {
    /// 从磁盘加载；path 为 None 时仅在内存中工作
    pub fn load(path: Option<PathBuf>) -> Self {
        let mut store = Self {
            path,
            states: HashMap::new(),
        };
        if let Some(path) = &store.path {
            if let Ok(raw) = std::fs::read_to_string(path) {
                if let Ok(states) = serde_json::from_str(&raw) {
                    store.states = states;
                }
            }
        }
        store
    }

    pub fn state(&self, app_id: &str) -> AppState {
        self.states.get(app_id).cloned().unwrap_or_default()
    }

    pub fn toggle_favorite(&mut self, app_id: &str, item_id: &str) {
        let state = self
            .states
            .entry(app_id.to_string())
            .or_default();
        if state.favorites.contains(item_id) {
            state.favorites.remove(item_id);
        } else {
            state.favorites.insert(item_id.to_string());
        }
        self.save();
    }

    pub fn toggle_hidden(&mut self, app_id: &str, item_id: &str) {
        let state = self
            .states
            .entry(app_id.to_string())
            .or_default();
        if state.hidden.contains(item_id) {
            state.hidden.remove(item_id);
        } else {
            state.hidden.insert(item_id.to_string());
        }
        self.save();
    }

    fn save(&self) {
        if let Some(path) = &self.path {
            if let Some(parent) = path.parent() {
                let _ = std::fs::create_dir_all(parent);
            }
            if let Ok(json) = serde_json::to_string_pretty(&self.states) {
                let _ = std::fs::write(path, json);
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn temp_path(tag: &str) -> PathBuf {
        let nanos = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_nanos();
        std::env::temp_dir().join(format!("shortkey-store-test-{tag}-{nanos}.json"))
    }

    #[test]
    fn favorite_roundtrip() {
        let path = temp_path("fav");
        {
            let mut store = Store::load(Some(path.clone()));
            store.toggle_favorite("app.a", "item1");
            assert!(store.state("app.a").favorites.contains("item1"));
        }
        let reloaded = Store::load(Some(path.clone()));
        assert!(reloaded.state("app.a").favorites.contains("item1"));
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn hidden_roundtrip() {
        let path = temp_path("hid");
        let mut store = Store::load(Some(path.clone()));
        store.toggle_hidden("app.a", "item1");
        assert!(store.state("app.a").hidden.contains("item1"));
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn missing_app_returns_default() {
        let store = Store::load(None);
        assert!(store.state("nope").favorites.is_empty());
    }
}
