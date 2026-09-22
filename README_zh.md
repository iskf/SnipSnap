# SnipSnap

<p align="center">
  <img src="Resources/AppIcon.png" width="120" height="120" alt="SnipSnap 图标" />
</p>

<p align="center">
  <b>基于原生技术构建的 macOS 轻量级效率工具。集精准截图、矢量标注、长截图拼接、GIF 录制、无级贴图、本地离线 OCR 与就地屏幕/输入框翻译于一体。</b>
</p>

<p align="center">
  <a href="https://github.com/iskf/SnipSnap/releases/latest"><img src="https://img.shields.io/github/v/release/iskf/SnipSnap?style=flat-square&color=0071e3&label=Release" alt="最新版本" /></a>
  <a href="#1-通过-homebrew-cask-安装推荐"><img src="https://img.shields.io/badge/Homebrew-Cask-fbb040?style=flat-square&logo=homebrew" alt="Homebrew Cask" /></a>
  <a href="https://apple.com"><img src="https://img.shields.io/badge/macOS-14.0%2B-1c1c1e?style=flat-square&logo=apple" alt="macOS 14.0+" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9%20%2F%206.0-F05138?style=flat-square&logo=swift" alt="Swift 5.9 / 6.0" /></a>
  <img src="https://img.shields.io/badge/架构-Universal%20(Apple%20Silicon%20%2F%20Intel)-0071e3?style=flat-square" alt="Apple Silicon & Intel" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/许可证-MIT-34c759?style=flat-square" alt="License MIT" /></a>
</p>

<p align="center">
  <a href="README.md">English</a> | <b>简体中文</b>
</p>

---


## 界面一览

| 精准取景与分组式标注工具栏 | 丰富矢量标注与二级调色盘 |
| :---: | :---: |
| <img src="docs/images/annotation_toolbar.png" alt="精准取景与标注工具栏" width="460" /> | <img src="docs/images/annotation_toolbar_sub.png" alt="二级调色盘与标注样式" width="460" /> |
| **发丝级准星 · 放大镜取色 · 核心操作栏** | **几何图形 · 步骤印章 · 调色与画笔字号** |

| Safari 风格原地屏幕翻译 | 输入框就地翻译与替换 |
| :---: | :---: |
| <img src="docs/images/inplace_translation.png" alt="原地屏幕翻译" width="460" /> | <img src="docs/images/input_Translate.png" alt="输入框就地翻译与替换" width="460" /> |
| **离线 Apple Vision OCR · 原位排版覆盖 · 语言对快切** | **聚焦即刻翻译 · Enter 一键覆写替换 · 剪贴板自动保护** |

| 桌面毛玻璃置顶贴图 | 原生控制中心与快捷键 |
| :---: | :---: |
| <img src="docs/images/hero_pin.png" alt="毛玻璃置顶贴图" width="460" /> | <img src="docs/images/control_center.png" alt="原生控制中心" width="460" /> |
| **独立置顶浮窗 · 无级缩放透明度 · 文本卡片化** | **纯原生 Swift/AppKit 架构 · 全局快捷键录制 · 菜单栏常驻** |

---

## 主要功能

### 1. 📸 精准截图与矢量标注
- **像素级精准取景**：发丝级十字准星与 8 倍动态放大镜，实时查看像素坐标与 HEX 色彩，按 `C` 键一键拷贝色值。
- **完备标注工具**：矩形、椭圆、直线、箭头、涂鸦画笔、荧光笔、文字批注、马赛克/模糊与自增步骤印章 ① ② ③。
- **撤销与重做**：支持多步撤销（`⌘Z`）与重做（`⇧⌘Z`），一键保存文件或复制到剪贴板。

### 2. 📜 长截图智能拼接
- **滚动连续拼接**：框选目标滚动区域后连续滚动页面，自动进行重叠计算与无缝拼接，轻松捕获长网页、长代码、长文档与聊天记录。
- **实时画卷预览**：折叠胶囊态展示当前高度与帧数，悬浮即可展开全景高清缩略预览。

### 3. 🎞️ 区域 GIF 动图录制
- **选框即录**：自由框选屏幕任意区域，15 FPS 恒定帧率硬件加速录制，杜绝丢帧与快进感。
- **灵活录制控制**：支持随心暂停与继续录制，录制完成自动写入剪贴板及指定目录，即粘即用。

### 4. 📌 无级贴图与文本卡片化
- **桌面置顶参考**：截图或剪贴板图片独立置顶悬浮于所有窗口及全屏应用之上，支持多贴图并存。
- **自由手势变换**：支持触控板/滚轮平滑缩放（10%–800%）、调节透明度（数字键 `1`–`9`）、旋转（`R`）与镜像翻转（`H`/`V`）。
- **鼠标穿透模式**：按 `⌘L` 开启鼠标点击穿透，贴图作为参考图时不阻碍底层应用操作。
- **文本/代码卡片化**：剪贴板复制文本或代码后按 `F3`，自动渲染为排版优雅的高对比度磨砂卡片置顶展示。

### 5. 🔍 本地离线 OCR 与选区翻译
- **100% 本地离线识别**：依托 Apple Vision 框架与神经引擎离线秒级文字识别，敏感数据绝不上云。
- **Safari 风格原地翻译**：识别内容直接原地排版覆盖原图，按 `空格键` 在原文与译文之间无缝闪切。
- **多翻译引擎接入**：支持 Apple 原生离线翻译、DeepL 官方 API 及自定 AI 翻译（DeepSeek / OpenAI / Ollama）。

### 6. ✍️ 输入框就地翻译与替换
- **光标聚焦即译**：在任意输入框中聚焦（或选中文本），按快捷键（默认 `⇧F4`）或状态栏菜单呼出翻译浮窗。
- **一键覆写替换**：按下 `Enter` 键或点击「替换」按钮，自动将译文覆写回原输入框；替换完毕后自动恢复原始剪贴板，干净利落。

### 7. ⚡ 纯原生极简体验
- **轻量低耗**：完全基于 Swift、AppKit 与 SwiftUI 原生开发，拒绝重型 Webview 封装，毫秒级冷启动，常驻内存极小。
- **菜单栏常驻与热键定制**：支持后台静默运行与状态栏托盘，所有功能快捷键均可在设置面板中自由录制。

---

## 常用快捷键速查

| 快捷键 | 功能操作 |
| :--- | :--- |
| `F1` / `⌥A` | 唤起标准屏幕截图 |
| `⌥F1` / `⌥S` | 唤起长截图拼接模式 |
| `⇧F1` / `F2` / `⌥O` | 选区 OCR 识别与原地翻译 |
| `⇧F4` | 输入框就地翻译与替换 |
| `F3` / `⌥P` | 剪贴板贴图 / 文本代码卡片化 |
| `F4` | 剪贴板内容快捷翻译 |
| `C` | 取景模式下复制准星处 HEX 颜色代码 |
| `⌘L` | 贴图开启 / 关闭鼠标点击穿透 (锁定模式) |
| `空格 (Space)` | 翻译状态下在 原文 与 译文 之间快速切换 |
| `Enter` | 确认完成标注 / 翻译替换回写 / 完成录制 |
| `Esc` | 取消当前操作并退出 |

> *注：上述所有快捷键均可在应用的「偏好设置 -> 快捷键」中自由修改。*

---

## 安装方式

### 1. 通过 Homebrew Cask 安装（推荐）

```bash
brew install --cask iskf/snipsnap/snipsnap
```

后续升级：
```bash
brew upgrade --cask snipsnap
```

### 2. 手动下载 DMG

前往 [GitHub Releases](https://github.com/iskf/SnipSnap/releases/latest) 下载最新的 `.dmg` 安装包，打开后将 `SnipSnap.app` 拖入「应用程序」文件夹即可。

### 3. 从源码编译

要求 macOS 14.0+，安装 Xcode 15+ 命令行工具：

```bash
git clone https://github.com/iskf/SnipSnap.git
cd SnipSnap
./build_app.sh
open build/SnipSnap.app
```

---

## 权限与隐私

- **屏幕录制权限**：macOS 抓取屏幕图像、长截图与录制 GIF 所必需的系统权限。
- **辅助功能权限**：用于在系统全局监听并派发快捷键，以及在输入框翻译时读取与回写目标输入框。
- **零隐私追踪**：SnipSnap 不含任何分析埋点或数据收集代码，文字识别与基础翻译完全在本地完成。

---

## 开源协议

本项目采用 [MIT 许可证](LICENSE)。
