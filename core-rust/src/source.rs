//! 快捷键来源抽象：每个平台实现 ShortcutSource，Aggregator 合并多个来源并去重。

use crate::model::ShortcutItem;

/// 前台应用信息
#[derive(Debug, Clone)]
pub struct ForegroundApp {
    pub pid: i32,
    pub name: String,
    /// macOS bundle id / Windows exe 路径 / Linux WM_CLASS，用作持久化 key
    pub app_id: String,
}

/// 一个平台的快捷键来源
pub trait ShortcutSource: Send + Sync {
    fn name(&self) -> &'static str;
    /// 枚举指定前台应用的快捷键
    fn collect(&self, app: &ForegroundApp) -> Vec<ShortcutItem>;
}

/// 合并多个来源并按条目 id 去重
pub struct Aggregator {
    sources: Vec<Box<dyn ShortcutSource>>,
}

impl Aggregator {
    pub fn new(sources: Vec<Box<dyn ShortcutSource>>) -> Self {
        Self { sources }
    }

    pub fn collect(&self, app: &ForegroundApp) -> Vec<ShortcutItem> {
        let mut items: Vec<ShortcutItem> = Vec::new();
        let mut seen = std::collections::HashSet::new();
        for source in &self.sources {
            for item in source.collect(app) {
                if seen.insert(item.id.clone()) {
                    items.push(item);
                }
            }
        }
        items
    }
}

/// 测试 / 无平台依赖场景用的静态来源
pub struct StaticSource(pub Vec<ShortcutItem>);

impl ShortcutSource for StaticSource {
    fn name(&self) -> &'static str {
        "static"
    }

    fn collect(&self, _app: &ForegroundApp) -> Vec<ShortcutItem> {
        self.0.clone()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::Modifiers;

    #[test]
    fn aggregator_dedupes() {
        let item = ShortcutItem::new("复制", "C", Modifiers::COMMAND, "编辑", vec!["编辑".to_string()]);
        let a = StaticSource(vec![item.clone()]);
        let b = StaticSource(vec![item]);
        let agg = Aggregator::new(vec![Box::new(a), Box::new(b)]);
        let app = ForegroundApp {
            pid: 1,
            name: "t".to_string(),
            app_id: "app.t".to_string(),
        };
        assert_eq!(agg.collect(&app).len(), 1);
    }
}
