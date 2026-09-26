# ShortKey

**[English](#english)** | [中文](#shortkey)

类 KeyCue 的 macOS 快捷键提示工具：**长按 ⌘（或连续按两次 ⌘ 并按住）弹出当前应用的全部快捷键**，输入文字即可模糊筛选。鼠标点菜单太慢、快捷键记不住时的效率工具。

<a name="english"></a>
## English

ShortKey is a KeyCue-style shortcut cheat-sheet for macOS: **press and hold ⌘ (or double-tap ⌘ and hold) to pop up every shortcut of the frontmost app**, with instant fuzzy filtering. A Rust core (`core-rust/`) powers the cross-platform roadmap — Windows/Linux shells are in development.

- Trigger: hold / double-tap-and-hold ⌘ (configurable threshold & mode)
- Execute: press a listed combo, click a row, or hit ⏎ on the best match
- Sources: app menus (Accessibility API), macOS system hotkeys (dynamic), trackpad gestures, skhd, Jitouch, custom JSON
- Extras: favorites, hide-known, group collapse, Markdown export, CLI (`--show/--export/--quit`), login item, weekly update check
- Build: `swift run` · `Scripts/build_app.sh` · `swift test` · `cd core-rust && cargo test`

Licensed under the [MIT License](LICENSE).

类 KeyCue 的 macOS 快捷键提示工具：**长按 ⌘（或连续按两次 ⌘ 并按住）弹出当前应用的全部快捷键**，输入文字即可模糊筛选。鼠标点菜单太慢、快捷键记不住时的效率工具。

## 当前状态（M3 已完成）

- 触发：按住 ⌘ 或**连续按两次 ⌘ 并按住**（设置里切换）；纯 ⌘ 按住阈值 100–1000ms 可调
- **KeyCue 式多列密排浮层**：应用图标 + 名称在顶部，分组按体量均衡排进 3 列，底部搜索栏 + 符号图例（⌘=command ⌥=option …）
- 搜索框自动聚焦，输入即时模糊过滤（大小写不敏感、连续命中加权），命中字符高亮
- ⌃⌥⇧⌘ + 键帽样式渲染（F 键、方向键、⌫ 等特殊键已映射）
- 收藏快捷键（星标，按应用持久化，组内置顶）
- **分组折叠**：点分组标题收起/展开，状态全局记住
- **隐藏已知快捷键**：眼睛按钮隐藏条目（按应用持久化），搜索栏眼睛图标可临时查看已隐藏条目
- **导出 Markdown**：浮层右上角或菜单栏「导出当前应用快捷键…」，按菜单分组生成表格
- **设置窗口**：触发方式 / 阈值 / 外观（跟随系统/浅色/深色），改动即时生效
- **直接执行**：浮层里按下组合键 / 点击行 / 搜索后回车 → 执行对应命令
- **开机自启**（设置里开关）· **每周更新检查**（通知中心提醒）
- **CLI**：`--show` / `--export [路径]` / `--quit` / `--help`（已有常驻实例时自动转发）
- **系统热键动态覆盖**：用户改过系统快捷键后显示真实值
- **触控板手势表 · skhd 配置解析 · Jitouch 配置嗅探 · 自定义快捷键**
- 松开 ⌘ / Esc / 回车 / 点击其他应用 → 关闭浮层；浮层显示期间接管键盘，平时不拦截任何按键
- 菜单栏图标：手动唤起面板、权限状态与引导、退出
- 前台应用切换时自动关闭浮层

## 双轨架构

```
Sources/            Swift —— macOS 原生应用（本轮 MVP，体验最佳）
core-rust/          Rust —— 跨平台核心骨架（为 Windows / Linux 打地基）
```

`core-rust` 收敛与平台无关的产品逻辑（数据模型、模糊搜索、配置存储），平台各自实现两个 trait 即可接入：

- `TriggerEngine`（全局键盘监听）：macOS = CGEventTap（当前由 Swift 版实现）· Windows = `WH_KEYBOARD_LL` 钩子 · Linux = X11 XGrabKey / 桌面环境接口
- `ShortcutSource`（枚举当前应用快捷键）：macOS = Accessibility API（当前由 Swift 版实现）· Windows = Win32 菜单枚举（UWP/Electron 等现代应用支持有限）· Linux = 无统一 API，按桌面环境读取（GNOME gsettings / KDE kglobalshortcutsrc）

## 构建与运行

```bash
# macOS 原生版
swift run                     # 开发迭代
Scripts/build_app.sh          # 生成 ShortKey.app（release）
swift test                    # 单元测试

# Rust 跨平台核心（Xcode 27 的 lld 链接器有兼容问题，需强制经典 ld64）
cd core-rust
RUSTFLAGS="-C link-arg=-fuse-ld=ld" cargo +stable test
```

## 权限

- 需要 **辅助功能（Accessibility）** 权限：系统设置 → 隐私与安全性 → 辅助功能
  - 打包后运行：授权 **ShortKey**
  - `swift run` 调试：授权你的**终端 App**（Terminal / iTerm / VS Code 等）
  - 首次启动会弹系统授权提示；未授权时每 2 秒自动重试启用监听，也可从菜单栏点「辅助功能权限」打开系统设置
- 建议（后续版本）：通知中心权限，用于不打扰的更新提醒

## 自定义快捷键

编辑 `~/Library/Application Support/ShortKey/custom.json`（菜单栏 →「编辑自定义快捷键…」可直接打开）：

```json
[
  {
    "title": "打开终端",
    "key": "T",
    "modifiers": ["cmd", "shift"],
    "group": "我的命令",
    "appId": "com.apple.Terminal"
  }
]
```

`modifiers` 支持 cmd / alt / ctrl / shift；`key` 支持字母数字符号或键名（space / return / esc / tab / up / down / left / right / f1–f20 / delete 等）；`appId` 缺省为全局条目。保存后下次唤起浮层即生效。

## Roadmap（跨平台优先）

产品定位：开源、跨平台发布（macOS / Windows / Linux）。路线按平台覆盖排序：

- **M2（macOS 打磨）** ✅：双击 ⌘ 触发、阈值/外观设置、分组折叠、隐藏已知、导出 Markdown、鼠标驻留显示、组合键执行
- **M3（生态）** ✅：开机自启、回车/点击执行、CLI、动态系统热键、手势表、skhd、Jitouch、自定义快捷键、更新提醒
- **M3（Windows 壳）**：Rust 核心 + `WH_KEYBOARD_LL` 触发器 + Win32 菜单枚举来源；UI 采用 **egui**（纯 Rust、单 exe、无 WebView 依赖、低延迟浮层）；开发期在 macOS 上以 `rustup target add x86_64-pc-windows-msvc` + `cargo check --target` 持续做类型校验，CI 出真包
- **M4（Linux 壳）**：X11 先行（XRecord/XGrabKey + egui）；Wayland 受合成器限制，按桌面环境能力降级（KDE KGlobalAccel / GNOME 扩展）
- **M5（生态）**：skhd 热键、系统热键/手势表、自定义快捷键、CLI 参数；macOS 端逐步迁移到 Rust 核心（FFI），SwiftUI 只留壳

> 平台能力边界（诚实声明）：Windows 的 UWP/Electron 应用与 Linux 的 Wayland 环境没有统一的「枚举当前应用快捷键」系统 API，这些场景下工具能覆盖的范围会因应用而异；产品上通过多来源聚合（系统热键 + 常见应用配置文件 + 用户自定义）弥补。

## 目录结构

```
Sources/ShortKeyCore/    纯逻辑：模型、模糊匹配、键名映射（含单元测试）
Sources/ShortKey/
  ShortKeyApp.swift      入口 + 菜单栏 + 各模块装配
  Core/                  事件监听、权限、持久化、浮层控制器
  AX/                    菜单栏快捷键读取
  UI/                    浮层面板与 SwiftUI 视图
core-rust/               跨平台核心骨架（模型 / 搜索 / 存储 / 平台 trait）
Scripts/build_app.sh     打包 .app
Resources/Info.plist     bundle 配置（LSUIElement 菜单栏应用）
```
