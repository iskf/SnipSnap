# SnipSnap 社区推广与曝光运营指南

本指南为 SnipSnap 在国内外各大极客、开发者社区获取第一批核心种子用户、提升 GitHub Star 与知名度而定制。

---

## 目录
1. [GitHub 仓库页面优化 Checklist](#1-github-仓库页面优化-checklist)
2. [V2EX「分享创造」节点发布草稿](#2-v2ex分享创造节点发布草稿)
3. [Reddit 发帖模板 (r/macapps & r/swift)](#3-reddit-发帖模板-rmacapps--rswift)
4. [Twitter / X 爆款推文文案](#4-twitter--x-爆款推文文案)
5. [Awesome 榜单收录 PR 提交模版](#5-awesome-榜单收录-pr-提交模版)

---

## 1. GitHub 仓库页面优化 Checklist

在前往各社区发帖前，请先确保 GitHub 仓库的门面配置完善：

- [ ] **设置 Social Preview 卡片**：
  1. 打开仓库页面 `https://github.com/iskf/SnipSnap/settings`
  2. 找到 **Social preview** 选项
  3. 上传本地已生成的 `docs/images/social_preview.png`（1280x640 标准高清卡片）
- [ ] **核对 Homebrew Tap**：
  确认 `brew install --cask iskf/snipsnap/snipsnap` 运行通畅。
- [ ] **确保 Release 资产正常**：
  访问 `https://github.com/iskf/SnipSnap/releases/latest`，确认 `SnipSnap-1.0.0.dmg` 下载可用。

---

## 2. V2EX「分享创造」节点发布草稿

> **建议节点**：`分享创造` 或 `macOS`  
> **最佳发布时间**：工作日上午 10:00 - 11:30 或 晚上 20:00 - 21:30  

### 标题参考
`[开源] SnipSnap：用 Swift/AppKit 原生手搓了一款 macOS 截图、贴图与原地翻译工具（0常驻内存，支持 Homebrew）`

### 正文内容

```markdown
各位 V 友大家好，

作为一名深度依赖截图贴图比对代码和界面的重度 Mac 用户，长期以来一直痛惜于目前 macOS 截图生态的割裂：
- 要么是基于 Electron / Chromium 封装的工具，动辄常驻几百兆内存，启动还有明显掉帧感；
- 要么是商业闭源工具，核心功能开始臃肿，或者各种依赖云端订阅；
- 在看外语技术文档或 API 时，很多时候只想临时对屏幕某块选区看一眼翻译，却要在截图、OCR、粘贴到翻译软件之间来回切换。

于是我利用业余时间，完全基于 Apple 原生技术栈（Swift + AppKit + SwiftUI + Apple Vision + Apple Translation Framework）从零手搓了这款工具 —— **SnipSnap**，目前正式开源并发布了首个版本。

### 核心特性
1. **纯血原生轻量**：没有 Electron，没有 Python 运行时。启动瞬间响应，平时在后台几乎为 0 资源占用。
2. **Snipaste 级顺手贴图**：一键将截图悬浮在桌面最顶层，支持鼠标滚轮缩放、双击缩略收起、透明度调节与阴影微光质感。
3. **Safari 风格原地屏幕翻译**：内置 Apple Translation 原生框架，截取外文区域后原地显示高保真翻译浮层，排版与原内容贴合，支持一键切换原文/译文。
4. **离线 OCR 与高精度放大镜**：依托 Apple Vision 引擎，文字就地高精度识别并支持即刻复制；自带像素级十字十字准星与取色器（HEX/RGB）。
5. **本地隐私优先**：所有图文数据均在本地内存流转，绝不上传任何云端服务器。

### 快速安装体验
已配置官方 Homebrew Tap，一行命令即可秒装：
```bash
brew install --cask iskf/snipsnap/snipsnap
```
或者前往 GitHub 下载原生 DMG 资产包：
- 项目地址：https://github.com/iskf/SnipSnap
- DMG 下载：https://github.com/iskf/SnipSnap/releases/latest

### 项目开源与后续计划
代码采用 MIT 协议完全开源，欢迎大家体验、提 Issue 或 PR！如果觉得对你有帮助，求个 Star 鼓励一下～ 感谢各位！
```

---

## 3. Reddit 发帖模板 (r/macapps & r/swift)

> **目标 Subreddit**：
> - `r/macapps` (Flair: `New App` or `Free / Open Source`)
> - `r/swift` (强调架构与技术细节)
> - `r/MacOS`

### Title
`[Open Source] SnipSnap – A lightweight, native macOS screenshot, tactile pinning, and Safari-style in-place translation utility (Swift & AppKit)`

### Post Body

```markdown
Hey everyone,

I built **SnipSnap**, a free and open-source macOS utility for precision screenshots, stepless pinning, and Safari-style in-place translation.

Like many developers, I love the pinning workflow of tools like Snipaste, but I wanted something that felt 100% native to modern macOS — without heavy Electron wrappers eating up hundreds of megabytes of RAM.

### Key Highlights
- **100% Swift & AppKit**: Instant launch, ~0% idle CPU, negligible memory footprint.
- **Tactile Pinning**: Pin screenshots as borderless floating windows, scale with scroll wheel, toggle opacity, and double-click to minimize.
- **Safari-Style In-Place Translation**: Powered by Apple's Translation framework. Select any screen region and see translated text seamlessly overlaid right in place.
- **On-Device Apple Vision OCR**: Zero cloud dependencies, fast and offline text recognition.
- **Precision Color Picker**: Pixel grid magnifier with HEX/RGB copy.

### Installation

Install via Homebrew:
```bash
brew install --cask iskf/snipsnap/snipsnap
```
Or grab the DMG from the release page:
https://github.com/iskf/SnipSnap/releases/latest

**GitHub Repository**: https://github.com/iskf/SnipSnap

Would love to hear your feedback, feature suggestions, or bug reports!
```

---

## 4. Twitter / X 爆款推文文案

### 推荐推文结构（附带 `docs/videos/inplace_translation.gif` 或短视频）

```text
🚀 Excited to open-source SnipSnap — a native macOS utility built with Swift & AppKit for precision screenshots, tactile pinning, and Safari-style in-place screen translation.

✨ Highlights:
• 0% idle footprint (No Electron)
• Seamless floating pin windows
• Apple Vision offline OCR
• Apple Translation framework overlay

🍺 Install via Homebrew:
brew install --cask iskf/snipsnap/snipsnap

⭐️ GitHub: https://github.com/iskf/SnipSnap

#macOS #Swift #OpenSource #Apple #DeveloperTools
```

---

## 5. Awesome 榜单收录 PR 提交模版

向各大知名 GitHub Awesome 榜单提交收录，是获得长期稳定自然搜索流量与 Star 增长的关键方式。

### 推荐提交的仓库：
1. **[jaywcjlove/awesome-mac](https://github.com/jaywcjlove/awesome-mac)** (Star > 73k)
   - 目标分类：`Developer Tools` / `Screen Capture / Recording`
2. **[serhii-londar/open-source-mac-os-apps](https://github.com/serhii-londar/open-source-mac-os-apps)** (Star > 43k)
   - 目标分类：`Utilities`

### 提交格式示例（Markdown）:

```markdown
- [SnipSnap](https://github.com/iskf/SnipSnap) - Native macOS screenshot, tactile pinning, offline OCR, and Safari-style in-place screen translation tool. [![Homebrew](https://img.shields.io/badge/homebrew-cask-orange?style=flat-square)](https://github.com/iskf/homebrew-snipsnap) `Free` `Open Source`
```
