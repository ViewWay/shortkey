//! ShortKey 跨平台 GUI 壳（eframe/egui）。
//! - Windows：Ctrl 长按触发（WH_KEYBOARD_LL）+ Win32 菜单枚举 + 浮层搜索
//! - macOS：预览/开发模式（F1 手动切换浮层；触发由 Swift 版负责）
//!
//! 浮层为无边框置顶透明窗口，不抢焦点。钩子为 listen-only：
//! 浮层显示期间真实按键仍直达前台应用（天然「组合键直通」语义）。

#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};

use shortkey_core::model::ShortcutItem;
use shortkey_core::source::{ForegroundApp, ShortcutSource, StaticSource};
use shortkey_core::store::Store;

#[cfg(target_os = "windows")]
use shortkey_core::platform::windows::{KeyboardHookTrigger, Win32MenuSource};

/// Windows 专属：托盘 / 鼠标定位 / 开机自启
#[cfg(target_os = "windows")]
mod winextras {
    use std::sync::Arc;
    use tray_icon::menu::{Menu, MenuEvent, MenuItem};
    use tray_icon::TrayIconBuilder;

    const TRAY_RGBA: &[u8] = include_bytes!("../../assets/tray.rgba");
    const RUN_KEY: &str = r"HKCU\Software\Microsoft\Windows\CurrentVersion\Run";

    /// 托盘常驻：显示 / 开机自启 / 退出
    pub fn setup_tray(bridge: Arc<super::Bridge>) {
        let show_item = MenuItem::with_id("show", "显示 ShortKey", true, None);
        let autostart_item = MenuItem::with_id("autostart", "开机自启", true, None);
        let quit_item = MenuItem::with_id("quit", "退出", true, None);
        let mut menu = Menu::new();
        let _ = menu.append(&show_item);
        let _ = menu.append(&autostart_item);
        let _ = menu.append(&quit_item);

        let icon = tray_icon::Icon::from_rgba(TRAY_RGBA.to_vec(), 32, 32)
            .expect("托盘图标解码失败");
        let tray = TrayIconBuilder::new()
            .with_icon(icon)
            .with_tooltip("ShortKey — 按住 Ctrl 弹出快捷键")
            .with_menu(Box::new(menu))
            .build()
            .expect("托盘创建失败");
        std::mem::forget(tray); // 常驻保活

        std::thread::spawn(move || {
            for event in MenuEvent::receiver() {
                if event.id() == "show" {
                    bridge.request_show();
                } else if event.id() == "autostart" {
                    let enable = !autostart_enabled();
                    let _ = set_autostart(enable);
                } else if event.id() == "quit" {
                    std::process::exit(0);
                }
            }
        });
    }

    pub fn cursor_position() -> Option<(f32, f32)> {
        use windows::Win32::Foundation::POINT;
        use windows::Win32::UI::WindowsAndMessaging::GetCursorPos;
        let mut point = POINT::default();
        unsafe {
            GetCursorPos(&mut point).ok()?;
        }
        Some((point.x as f32, point.y as f32))
    }

    pub fn autostart_enabled() -> bool {
        std::process::Command::new("reg")
            .args(["query", RUN_KEY, "/v", "ShortKey"])
            .output()
            .map(|output| output.status.success())
            .unwrap_or(false)
    }

    pub fn set_autostart(enable: bool) -> bool {
        let Ok(exe) = std::env::current_exe() else { return false };
        let path = exe.display().to_string();
        let mut command = std::process::Command::new("reg");
        if enable {
            command.args(["add", RUN_KEY, "/v", "ShortKey", "/d", &path, "/f"]);
        } else {
            command.args(["delete", RUN_KEY, "/v", "ShortKey", "/f"]);
        }
        command.output().map(|output| output.status.success()).unwrap_or(false)
    }
}

#[cfg(not(target_os = "windows"))]
mod winextras {
    pub fn cursor_position() -> Option<(f32, f32)> {
        None
    }
}

/// 触发线程 → UI 的桥
struct Bridge {
    show: AtomicBool,
    ctx: Mutex<Option<egui::Context>>,
}

impl Bridge {
    fn request_show(&self) {
        self.show.store(true, Ordering::SeqCst);
        if let Some(ctx) = self.ctx.lock().unwrap().as_ref() {
            ctx.request_repaint();
        }
    }
}

struct ShortKeyApp {
    bridge: Arc<Bridge>,
    visible: bool,
    query: String,
    items: Vec<ShortcutItem>,
    selected: usize,
    store: Store,
    source: Box<dyn ShortcutSource>,
    app: ForegroundApp,
    #[allow(dead_code)]
    autostart: bool,
}

fn demo_system_items() -> Vec<ShortcutItem> {
    let entries = [
        ("Spotlight 搜索", "⌘␣"),
        ("锁定屏幕", "⌃⌘Q"),
        ("强制退出应用", "⌥⌘⎋"),
        ("调度中心", "⌃↑"),
        ("切换输入源", "⌃␣"),
        ("截屏与录屏选项", "⇧⌘5"),
    ];
    entries
        .iter()
        .map(|(title, keys)| ShortcutItem {
            id: format!("demo:{title}"),
            title: (*title).to_string(),
            key: (*keys).to_string(),
            modifiers: shortkey_core::model::Modifiers::default(),
            group: "系统".into(),
            path: vec!["系统".into()],
            enabled: true,
            virtual_key: None,
        })
        .collect()
}

/// 背景来源：演示系统表 + skhd + 自定义 JSON
fn background_items() -> Vec<ShortcutItem> {
    let mut items = demo_system_items();
    let home = std::env::var("HOME").unwrap_or_default();
    for path in [format!("{home}/.config/skhd/skhdrc"), format!("{home}/.skhdrc")] {
        if let Ok(text) = std::fs::read_to_string(&path) {
            items.extend(shortkey_core::skhd::parse(&text));
        }
    }
    let custom = format!("{home}/Library/Application Support/ShortKey/custom.json");
    if let Ok(data) = std::fs::read(&custom) {
        items.extend(shortkey_core::custom::parse(&data));
    }
    items
}

#[cfg(target_os = "windows")]
fn make_source() -> Box<dyn ShortcutSource> {
    Box::new(Win32MenuSource)
}

#[cfg(not(target_os = "windows"))]
fn make_source() -> Box<dyn ShortcutSource> {
    Box::new(StaticSource(background_items()))
}

/// 修饰键类别色：与 macOS 端 ShortcutRow 一致（取 Apple 深色模式系统色，浮层恒为深色底）
fn modifier_color(glyph: char) -> egui::Color32 {
    match glyph {
        '⌃' => egui::Color32::from_rgb(48, 209, 88),   // green
        '⌥' => egui::Color32::from_rgb(191, 90, 242), // purple
        '⇧' => egui::Color32::from_rgb(255, 159, 10), // orange
        '⌘' => egui::Color32::from_rgb(10, 132, 255), // blue
        _ => egui::Color32::from_rgb(120, 170, 255),
    }
}

fn main() -> eframe::Result<()> {
    let bridge = Arc::new(Bridge {
        show: AtomicBool::new(false),
        ctx: Mutex::new(None),
    });

    let store = Store::load(None);
    let app = ShortKeyApp::new(bridge.clone(), store, make_source());

    #[cfg(target_os = "windows")]
    {
        start_windows_trigger(bridge.clone());
        winextras::setup_tray(bridge.clone());
    }

    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default()
            .with_decorations(false)
            .with_always_on_top()
            .with_active(false)
            .with_inner_size([1180.0, 720.0]),
        ..Default::default()
    };

    eframe::run_native(
        "ShortKey",
        options,
        Box::new(move |cc| {
            *bridge.ctx.lock().unwrap() = Some(cc.egui_ctx.clone());
            Ok(Box::new(app))
        }),
    )
}

#[cfg(target_os = "windows")]
fn start_windows_trigger(bridge: Arc<Bridge>) {
    use shortkey_core::trigger::{TriggerConfig, TriggerEngine, TriggerEvent};
    let mut trigger = KeyboardHookTrigger;
    trigger
        .start(
            TriggerConfig::default(),
            Box::new(move |event| {
                if event == TriggerEvent::Show {
                    bridge.request_show();
                }
            }),
        )
        .expect("WH_KEYBOARD_LL 钩子启动失败");
}

impl eframe::App for ShortKeyApp {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        let show_requested = self.bridge.show.swap(false, Ordering::SeqCst);
        if show_requested && !self.visible {
            self.visible = true;
            self.items = self.source.collect(&self.app);
            #[cfg(target_os = "windows")]
            {
                self.autostart = winextras::autostart_enabled();
                if let Some((x, y)) = winextras::cursor_position() {
                    let px = (x - 590.0).max(8.0);
                    let py = (y - 740.0).max(8.0);
                    ctx.send_viewport_cmd(egui::ViewportCommand::OuterPosition(egui::pos2(px, py)));
                }
            }
            for item in background_items() {
                if !self.items.iter().any(|existing| existing.id == item.id) {
                    self.items.push(item);
                }
            }
            self.query.clear();
            self.selected = 0;
            ctx.send_viewport_cmd(egui::ViewportCommand::Visible(true));
            ctx.send_viewport_cmd(egui::ViewportCommand::Focus);
        }

        if !self.visible {
            ctx.request_repaint_after(std::time::Duration::from_millis(150));
            return;
        }

        let mut hide = false;

        if ctx.input(|i| i.key_pressed(egui::Key::Escape)) {
            hide = true;
        }
        let rows = self.filtered();
        if ctx.input(|i| i.key_pressed(egui::Key::ArrowDown)) && !rows.is_empty() {
            self.selected = (self.selected + 1).min(rows.len() - 1);
        }
        if ctx.input(|i| i.key_pressed(egui::Key::ArrowUp)) {
            self.selected = self.selected.saturating_sub(1);
        }
        if ctx.input(|i| i.key_pressed(egui::Key::Enter)) && !rows.is_empty() {
            let item = &rows[self.selected.min(rows.len() - 1)];
            let combo = format!("{}{}", item.modifiers.symbols(), item.key);
            if let Ok(mut clipboard) = arboard::Clipboard::new() {
                let _ = clipboard.set_text(combo);
            }
            hide = true;
        }

        egui::CentralPanel::default()
            .frame(
                egui::Frame::none()
                    .fill(egui::Color32::from_black_alpha(235))
                    .rounding(14.0),
            )
            .show(ctx, |ui| {
                ui.add_space(10.0);
                egui::Frame::none()
                    .fill(egui::Color32::from_gray(40))
                    .rounding(10.0)
                    .inner_margin(egui::Margin::symmetric(10.0, 7.0))
                    .show(ui, |ui| {
                        ui.horizontal(|ui| {
                            ui.label("🔍");
                            ui.add(
                                egui::TextEdit::singleline(&mut self.query)
                                    .hint_text("搜索快捷键…")
                                    .desired_width(f32::INFINITY)
                                    .lock_focus(true),
                            );
                        });
                    });
                ui.add_space(8.0);

                let rows = self.filtered();
                egui::ScrollArea::vertical().show(ui, |ui| {
                    if rows.is_empty() {
                        ui.label("  没有匹配的结果");
                    } else {
                        egui::Grid::new("results")
                            .num_columns(3)
                            .spacing([20.0, 2.0])
                            .show(ui, |ui| {
                                for (index, item) in rows.iter().enumerate() {
                                    let selected = index == self.selected;
                                    ui.horizontal(|ui| {
                                        ui.set_min_width(ui.available_width() / 3.0 - 30.0);
                                        let title =
                                            egui::RichText::new(&item.title).size(13.0).color(
                                                if selected {
                                                    egui::Color32::WHITE
                                                } else {
                                                    egui::Color32::from_gray(200)
                                                },
                                            );
                                        let response = ui.selectable_label(selected, title);
                                        if response.clicked() {
                                            self.selected = index;
                                        }
                                    });
                                    ui.label(
                                        egui::RichText::new(&item.group)
                                            .size(11.0)
                                            .color(egui::Color32::from_gray(130)),
                                    );
                                    // 修饰键按类别着色（与 macOS 端一致）：⌃ 绿 · ⌥ 紫 · ⇧ 橙 · ⌘ 蓝
                                    ui.horizontal(|ui| {
                                        for glyph in item.modifiers.symbols().chars() {
                                            ui.label(
                                                egui::RichText::new(glyph.to_string())
                                                    .size(12.5)
                                                    .color(modifier_color(glyph)),
                                            );
                                        }
                                        ui.label(
                                            egui::RichText::new(&item.key)
                                                .size(12.5)
                                                .color(egui::Color32::from_rgb(120, 170, 255)),
                                        );
                                    });
                                    ui.end_row();
                                }
                            });
                    }
                });

                ui.add_space(6.0);
                ui.label(
                    egui::RichText::new("⏎ 复制组合键 · Esc 关闭 · ↑↓ 选择 · 真实按键直达前台应用")
                        .size(11.0)
                        .color(egui::Color32::from_gray(120)),
                );
                #[cfg(target_os = "windows")]
                {
                    ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
                        let mut enabled = self.autostart;
                        if ui.checkbox(&mut enabled, "开机自启").changed() {
                            let _ = winextras::set_autostart(enabled);
                            self.autostart = winextras::autostart_enabled();
                        }
                    });
                }
            });

        if hide {
            self.bridge.show.store(false, Ordering::SeqCst);
            ctx.send_viewport_cmd(egui::ViewportCommand::Visible(false));
        }
        ctx.request_repaint_after(std::time::Duration::from_millis(150));
    }
}

impl ShortKeyApp {
    fn new(bridge: Arc<Bridge>, store: Store, source: Box<dyn ShortcutSource>) -> Self {
        Self {
            bridge,
            visible: false,
            query: String::new(),
            items: Vec::new(),
            selected: 0,
            store,
            source,
            app: ForegroundApp {
                pid: 0,
                name: "system".into(),
                app_id: "system".into(),
            },
            autostart: false,
        }
    }

    /// 模糊过滤 + 评分排序
    fn filtered(&self) -> Vec<ShortcutItem> {
        let query = self.query.trim();
        if query.is_empty() {
            return self.items.clone();
        }
        let mut ranked: Vec<(ShortcutItem, i32)> = self
            .items
            .iter()
            .filter_map(|item| {
                shortkey_core::fuzzy_match(query, &item.title).map(|m| (item.clone(), m.score))
            })
            .collect();
        ranked.sort_by(|a, b| b.1.cmp(&a.1));
        ranked.into_iter().map(|(item, _)| item).collect()
    }
}

// macOS 预览模式下抑制未使用告警
#[allow(unused)]
fn _unused(_: &Store) {}
