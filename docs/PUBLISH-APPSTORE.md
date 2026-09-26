# Mac App Store 上架清单

## ⚠️ 先读：审核风险与 Plan B

核心功能依赖**辅助功能权限读取其他应用的菜单**。先例：
- ✅ Rectangle / Magnet / Moom —— 沙盒 + 辅助功能权限，在 MAS 上架成功（窗口管理类）
- ⚠️ 菜单读取类工具（KeyCue/CheatSheet）均为官网直发，MAS 无直接先例
- 结论：**可尝试，被拒有 Plan B**（Developer ID 直发 + 公证，`Scripts/notarize.sh` 已就绪）

## 一、证书（一次性）

1. [developer.apple.com](https://developer.apple.com) → Certificates → ➕ → **Apple Distribution**（需已加入 $99/年 计划）
2. 或 Xcode → Settings → Accounts → Manage Certificates → ➕ Apple Distribution
3. 验证：`security find-identity -v -p codesigning` 出现 "Apple Distribution"

## 二、App Store Connect（网页）

1. 我的 App → ➕ → 新建 App
   - Bundle ID: `app.shortkey.ShortKey`（首次需在 Identifiers 注册）
   - SKU: `shortkey-001`，语言：简体中文
2. 隐私政策 URL: `https://github.com/ViewWay/shortkey/blob/main/PRIVACY.md`
3. App 隐私标签：**不收集任何数据**
4. 分类：效率 / 工具；价格：免费

## 三、商店素材（复制即用）

**名称**：ShortKey - 快捷键速查
**副标题**：按住 ⌘，所有快捷键一目了然
**关键词**：快捷键,keyboard,shortcuts,效率,cheatsheet,keycue
**描述**：
> 还在菜单里翻快捷键？按住 ⌘ 一秒，当前应用的全部快捷键密排呈现，输入即筛选，回车即执行。
> · 应用菜单 · 系统热键 · 触控板手势 · skhd · 自定义
> · 收藏常用的，隐藏已会的
> · 毛玻璃浮层，KeyCue 式多列排版
> 全程本机处理，零数据上传。

**截图**（需 2560×1600 或 1440×900）：浮层在 Safari/Finder 前的截图 ×3

**审核备注模板**：
> ShortKey 需要"辅助功能"权限以读取前台应用的菜单栏快捷键（仅读取，不修改、不上传）。
> 测试步骤：1. 启动 App，按引导开启辅助功能；2. 打开 Safari；3. 按住 ⌘ 键约 0.5 秒；
> 4. 浮层显示 Safari 全部快捷键；输入"新"筛选；回车执行选中项。

## 四、构建与上传

```bash
Scripts/build_mas.sh        # 产出 build/ShortKey-mas.pkg（需 Apple Distribution 证书）
xcrun altool --upload-package -f build/ShortKey-mas.pkg \
  --apiKey <KEY_ID> --apiIssuer <ISSUER_ID>   # 或用 Transporter.app 拖入
```

## 五、MAS 版行为差异（沙盒导致，均为既定降级）

- skhd / Jitouch 配置读取：无权限 → 分组自动隐藏
- CLI `--export 路径`：改为弹出保存面板
- 自定义快捷键 JSON：位于容器目录，App 内「编辑自定义快捷键」仍可用
