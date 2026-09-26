//! WH_KEYBOARD_LL 低级键盘钩子触发器（Windows）。
//! 约定：按住 Ctrl 超过阈值触发 Show（Ctrl 对位 macOS ⌘ 的使用习惯）；
//! 其它任意按键按下即取消；浮层可见期间由 UI 层接管输入。

use std::sync::{Arc, Mutex, OnceLock};
use std::time::{Duration, Instant};

use windows::Win32::Foundation::{LPARAM, LRESULT, WPARAM};
use windows::Win32::UI::WindowsAndMessaging::{
    CallNextHookEx, GetMessageW, HHOOK, KBDLLHOOKSTRUCT, LLKHF_UP, SetWindowsHookExW,
    UnhookWindowsHookEx, WH_KEYBOARD_LL,
};

use crate::trigger::{TriggerConfig, TriggerEngine, TriggerEvent};

const VK_LCONTROL: u32 = 0xA2;
const VK_RCONTROL: u32 = 0xA3;

type Callback = Box<dyn Fn(TriggerEvent) + Send + Sync>;

#[derive(PartialEq)]
enum Phase {
    Idle,
    Pressed,
}

struct State {
    phase: Phase,
    deadline: Option<Instant>,
    /// 浮层可见期间触发器静默（UI 关闭时回调 set_visible(false)）
    visible: bool,
}

struct Shared {
    state: Mutex<State>,
    callback: Mutex<Option<Callback>>,
    threshold: Mutex<Duration>,
}

static SHARED: OnceLock<Arc<Shared>> = OnceLock::new();
static HOOK: Mutex<Option<HHOOK>> = Mutex::new(None);

/// Ctrl 长按触发器
pub struct KeyboardHookTrigger;

impl KeyboardHookTrigger {
    /// 浮层可见期间静默触发器（UI 关闭浮层时调用）
    pub fn set_visible(&self, visible: bool) {
        if let Some(shared) = SHARED.get() {
            shared.state.lock().unwrap().visible = visible;
        }
    }
}

impl Default for KeyboardHookTrigger {
    fn default() -> Self {
        Self
    }
}

impl TriggerEngine for KeyboardHookTrigger {
    fn start(
        &mut self,
        config: TriggerConfig,
        on_event: Box<dyn Fn(TriggerEvent) + Send + Sync>,
    ) -> Result<(), String> {
        let shared = Arc::new(Shared {
            state: Mutex::new(State {
                phase: Phase::Idle,
                deadline: None,
                visible: false,
            }),
            callback: Mutex::new(Some(on_event)),
            threshold: Mutex::new(config.threshold),
        });
        if SHARED.set(shared.clone()).is_err() {
            return Err("KeyboardHookTrigger 已经启动".to_string());
        }

        // 钩子线程：装钩子 + 消息循环保持线程存活
        std::thread::Builder::new()
            .name("shortkey-hook".into())
            .spawn(move || unsafe {
                match SetWindowsHookExW(WH_KEYBOARD_LL, Some(hook_proc), HINSTANCE_DEFAULT, 0) {
                    Ok(hook) => {
                        *HOOK.lock().unwrap() = Some(hook);
                        let mut msg = MSG::default();
                        while GetMessageW(&mut msg, None, 0, 0).as_bool() {}
                    }
                    Err(err) => {
                        eprintln!("SetWindowsHookExW 失败: {err}");
                    }
                }
            })
            .map_err(|e| format!("启动钩子线程失败: {e}"))?;

        // 计时线程：10ms 轮询 deadline，到点触发 Show
        std::thread::spawn(move || loop {
            std::thread::sleep(Duration::from_millis(10));
            let event = {
                let mut state = shared.state.lock().unwrap();
                if state.phase == Phase::Pressed {
                    if let Some(deadline) = state.deadline {
                        if Instant::now() >= deadline {
                            state.phase = Phase::Idle;
                            state.deadline = None;
                            state.visible = true;
                            Some(TriggerEvent::Show)
                        } else {
                            None
                        }
                    } else {
                        None
                    }
                } else {
                    None
                }
            };
            if let Some(event) = event {
                if let Some(callback) = shared.callback.lock().unwrap().as_ref() {
                    callback(event);
                }
            }
        });

        Ok(())
    }

    fn stop(&mut self) {
        if let Some(hook) = HOOK.lock().unwrap().take() {
            unsafe {
                let _ = UnhookWindowsHookEx(hook);
            }
        }
    }
}

unsafe extern "system" fn hook_proc(code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
    if code >= 0 {
        let info = &*(lparam.0 as *const KBDLLHOOKSTRUCT);
        handle_key(info.vkCode, (info.flags & LLKHF_UP) != 0);
    }
    CallNextHookEx(None, code, wparam, lparam)
}

fn handle_key(vk: u32, is_up: bool) {
    let Some(shared) = SHARED.get() else { return };
    let mut state = shared.state.lock().unwrap();
    if state.visible {
        return;
    }
    let is_ctrl = vk == VK_LCONTROL || vk == VK_RCONTROL;
    if is_ctrl {
        if !is_up {
            if state.phase == Phase::Idle {
                let threshold = *shared.threshold.lock().unwrap();
                state.phase = Phase::Pressed;
                state.deadline = Some(Instant::now() + threshold);
            }
        } else {
            state.phase = Phase::Idle;
            state.deadline = None;
        }
    } else if !is_up {
        // 其它按键按下 = 真实快捷键，取消待触发
        state.phase = Phase::Idle;
        state.deadline = None;
    }
}
