//! X11 触发器：轮询修饰键状态（x11-dl 动态加载，无链接期依赖）。
//! Wayland 下明确报错（需桌面环境配合）。

use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;
use std::time::{Duration, Instant};

use crate::trigger::{TriggerConfig, TriggerEngine, TriggerEvent};

static VISIBLE: AtomicBool = AtomicBool::new(false);
static RUNNING: AtomicBool = AtomicBool::new(false);
static DEADLINE: Mutex<Option<Instant>> = Mutex::new(None);

/// Ctrl 长按触发（轮询 XQueryKeymap）
pub struct PollTrigger;

impl PollTrigger {
    pub fn set_visible(&self, visible: bool) {
        VISIBLE.store(visible, Ordering::SeqCst);
    }
}

impl Default for PollTrigger {
    fn default() -> Self {
        Self
    }
}

impl TriggerEngine for PollTrigger {
    fn start(
        &mut self,
        config: TriggerConfig,
        on_event: Box<dyn Fn(TriggerEvent) + Send + Sync>,
    ) -> Result<(), String> {
        if std::env::var_os("WAYLAND_DISPLAY").is_some() && std::env::var_os("DISPLAY").is_none() {
            return Err("Wayland 环境暂不支持全局触发，请使用 X11 会话".into());
        }
        if RUNNING.swap(true, Ordering::SeqCst) {
            return Err("PollTrigger 已经启动".into());
        }
        let threshold = config.threshold;

        std::thread::spawn(move || unsafe {
            // 动态加载 Xlib
            let xlib = match x11_dl::xlib::Xlib::open() {
                Ok(lib) => lib,
                Err(err) => {
                    eprintln!("Xlib 加载失败（需要 libX11）: {err}");
                    RUNNING.store(false, Ordering::SeqCst);
                    return;
                }
            };
            unsafe {
                let display = (xlib.XOpenDisplay)(std::ptr::null());
                if display.is_null() {
                    eprintln!("无法连接 X display");
                    RUNNING.store(false, Ordering::SeqCst);
                    return;
                }
                // Ctrl = 0x25 (ControlMapIndex) / 0x25... keysym 转键码
                let ctrl_keycode = (xlib.XKeysymToKeycode)(display, 0xffe3 as _) as usize;
                let mut previous = [0u8; 32];
                loop {
                    if !RUNNING.load(Ordering::SeqCst) {
                        break;
                    }
                    let mut keys = [0u8; 32];
                    (xlib.XQueryKeymap)(display, keys.as_mut_ptr() as *mut i8);
                    let ctrl_down = keys[ctrl_keycode / 8] & (1 << (ctrl_keycode % 8)) != 0;
                    let was_down = previous[ctrl_keycode / 8] & (1 << (ctrl_keycode % 8)) != 0;
                    let now = Instant::now();

                    if ctrl_down && !was_down {
                        *DEADLINE.lock().unwrap() = Some(now + threshold);
                    } else if !ctrl_down && was_down {
                        *DEADLINE.lock().unwrap() = None;
                    } else if ctrl_down {
                        let mut deadline = DEADLINE.lock().unwrap();
                        if let Some(deadline_time) = *deadline {
                            if now >= deadline_time {
                                *deadline = None;
                                drop(deadline);
                                if !VISIBLE.load(Ordering::SeqCst) {
                                    VISIBLE.store(true, Ordering::SeqCst);
                                    on_event(TriggerEvent::Show);
                                }
                            }
                        }
                    }
                    previous = keys;
                    std::thread::sleep(Duration::from_millis(10));
                }
                (xlib.XCloseDisplay)(display);
            }
        });
        Ok(())
    }

    fn stop(&mut self) {
        RUNNING.store(false, Ordering::SeqCst);
    }
}
