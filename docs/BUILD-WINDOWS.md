# Windows 构建与真机验证指南

## 获取 exe

**方式 A（推荐）**：GitHub Actions 自动构建
- 推送到 main 后，Actions → `CI` → `rust-core (windows-latest)` → Artifacts 下载 `ShortKey-windows/shortkey.exe`

**方式 B**：Windows 机器上本地构建
```powershell
git clone https://github.com/ViewWay/shortkey.git
cd shortkey/core-rust
cargo build --release --features gui
# 产物: target\release\shortkey.exe
```

## 运行

双击 `shortkey.exe`（托盘出现白色 ⌘ 图标）→ **按住 Ctrl 约 0.3 秒** 弹出快捷键浮层。

- 输入即筛选，↑↓ 选择，⏎ 复制组合键，Esc 关闭
- 浮层显示期间真实按键**直达前台应用**（listen-only 语义，天然不干扰）
- 托盘右键：显示 / 开机自启 / 退出

## 已知边界（实机验证重点）

| 项 | 说明 |
|---|---|
| Win32 菜单应用 | 记事本/资源管理器/大多数原生应用可枚举 ✓ |
| UWP / WinUI / Electron 自绘 | 枚举不到（无 Win32 菜单）——平台本质限制 |
| 管理员权限窗口 | 低级钩子收不到其按键（UIPI），需以管理员运行 ShortKey |
| Wayland | 不支持（Linux 侧同因），Windows 无此问题 |

## 问题反馈

提交 issue 时附上：前台应用名、期望的快捷键、实际显示内容。
