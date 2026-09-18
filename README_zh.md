# SnipSnap

<p align="center">
  <img src="Resources/AppIcon.png" width="120" height="120" alt="SnipSnap 图标" />
</p>

<p align="center">
  <b>基于原生技术构建的 macOS 高性能截图、GIF 动图录制、无级贴图、本地离线 OCR 与 Safari 风格原地屏幕翻译工具。</b>
</p>

<p align="center">
  <a href="https://github.com/iskf/SnipSnap/releases/latest"><img src="https://img.shields.io/github/v/release/iskf/SnipSnap?style=flat-square&color=0071e3&label=Release" alt="最新版本" /></a>
  <a href="#1-通过-homebrew-cask-安装推荐"><img src="https://img.shields.io/badge/Homebrew-Cask-fbb040?style=flat-square&logo=homebrew" alt="Homebrew Cask" /></a>
  <a href="https://apple.com"><img src="https://img.shields.io/badge/macOS-14.0%2B-1c1c1e?style=flat-square&logo=apple" alt="macOS 14.0+" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9%20%2F%206.0-F05138?style=flat-square&logo=swift" alt="Swift 5.9 / 6.0" /></a>
  <img src="https://img.shields.io/badge/架构-Universal%20(Apple%20Silicon%20%2F%20Intel)-0071e3?style=flat-square" alt="Apple Silicon & Intel" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/许可证-MIT-34c759?style=flat-square" alt="License MIT" /></a>
  <img src="https://img.shields.io/badge/社区贡献-欢迎提交%20PR-28cd41?style=flat-square" alt="欢迎贡献" />
</p>

<p align="center">
  <a href="README.md">English</a> | <b>简体中文</b>
</p>

---

## 核心功能预览

### 精准取景与极致贴图

<p align="center">
  <a href="docs/videos/capture_and_pin.mp4">
    <img src="docs/videos/capture_and_pin.gif" alt="精准取景与极致贴图演示" width="100%" />
  </a>
</p>
<p align="center">
  <sub>点击动图可在线播放或下载完整高清 MP4 视频 (36s)</sub>
</p>

### Safari 风格原地屏幕翻译

<p align="center">
  <a href="docs/videos/inplace_translation.mp4">
    <img src="docs/videos/inplace_translation.gif" alt="Safari 风格原地屏幕翻译演示" width="100%" />
  </a>
</p>
<p align="center">
  <sub>点击动图可在线播放或下载完整高清 MP4 视频 (20s)</sub>
</p>

---

## 项目简介

**SnipSnap** 专为追求极致性能与设计质感的 macOS 深度用户、开发者与设计师打造，底层完全采用苹果官方原生技术栈开发（**Swift、AppKit、SwiftUI、Apple Vision 与 Apple Translation 框架**）。

拒绝动辄占用数百兆内存的 Electron 封装方案，SnipSnap 具备瞬时启动响应与极低的常驻内存消耗。它将 **Snipaste** 细腻自然的贴图操作习惯，与现代 macOS 苹果人机交互设计规范（HIG）、优雅的柔光质感及 Safari 风格的原地屏幕翻译深度融合。

---

## 界面预览

| 精准取景与分组式标注工具栏 | Safari 风格原地屏幕翻译 |
| :---: | :---: |
| <img src="docs/images/annotation_toolbar.png" alt="精准取景与标注工具栏" width="460" /> | <img src="docs/images/inplace_translation.png" alt="原地屏幕翻译" width="460" /> |
| **像素级十字准星 · 8倍放大镜色彩拾取 · 分组式工具条** | **离线 Apple Vision OCR · 视界原地覆盖 · 原文/译文秒级切换** |

| 桌面毛玻璃置顶贴图与高级菜单 | macOS 原生偏好设置面板 |
| :---: | :---: |
| <img src="docs/images/hero_pin.png" alt="毛玻璃置顶贴图" width="460" /> | <img src="docs/images/control_center.png" alt="原生控制中心" width="460" /> |
| **独立 NSPanel 浮窗 · 柔光阴影轮廓 · 完整右键菜单** | **纯原生 Swift/AppKit 架构 · 全局快捷键录制 · 菜单栏轻量常驻** |

---

## 核心特性

### 1. 贴图系统
- **独立悬浮置顶**：贴图基于系统独立 `NSPanel` 构建，跨虚拟桌面、Space 及全屏应用程序持续置顶，写代码、对稿比对设计无缝穿插。
- **平滑无级缩放**：支持鼠标滚轮与触控板双指捏合手势，在 **10% ~ 800%** 范围平滑缩放。
- **透明度调节**：按住 `Ctrl + 滚轮` 或直接敲击数字键 `1`–`9` 调节半透明度（按 `0` 瞬间恢复 100% 完全不透明）。
- **几何旋转与镜像**：按 `R` 键以 90 度步进顺时针旋转，按 `H` 水平镜像翻转，按 `V` 垂直翻转，画布智能自动居中对齐。
- **鼠标点击穿透 (锁定模式)**：通过快捷键 `Command + L` 或右键菜单开启穿透模式，贴图将变为纯背景参考层，鼠标点击可直接穿透操作底层窗口。
- **外挂悬浮二次标注栏**：在贴图上右键选择「标注贴图」时，工具栏以独立悬浮子窗口形式呈现于贴图外部，避免贴图边界被遮挡或裁切。
- **剪贴板文本卡片化 (`F3`)**：剪贴板中有图片时直接贴图；若复制了代码片段或文本，SnipSnap 将自动排版渲染为高质量的代码/文本磨砂卡片悬浮于屏幕中央。

### 2. GIF 动图录制  *(v1.0.2 新增)*
- **区域选框录制**：自由框选任意屏幕区域并直接录制为高品质、高度优化的 GIF 动图，录制完毕自动拷贝，即粘即用。
- **CFR 恒定帧率引擎**：基于 `DispatchSourceTimer` 构建的 15 FPS 恒定帧率驱动，彻底告别快进变相加速与卡顿丢帧，动图播放极为丝滑顺畅。
- **ScreenCaptureKit 硬件加速**：调用苹果现代 `SCStream` 底层录屏接口，硬件级低功耗录制，并支持像素级精准区域裁剪。
- **3-2-1 倒计时与流预热 (Pre-Warming)**：倒计时期间即在后台完成采集流预热并丢弃初始静默帧，倒计时结束瞬时启动录制，零启动延迟。
- **灵活暂停与继续**：录制过程中支持随心暂停与继续录制，暂停等待时间在最终导出的 GIF 中自动无缝切除。
- **风格统一的录制控制条**：采用与标注工具栏高度一致的设计语言——深色磨砂玻璃背景、圆角、点阵拖拽手柄及统一的微透高质感按钮。
- **自适应动态宽度与平滑动画**：控制条根据当前状态（准备、倒计时、录制中、暂停、压制中、完成）自适应调整宽度与按钮布局，并保持右侧锚定平滑展开。
- **采集层全隐形过滤**：录制选框及所有控制浮窗均启用 `sharingType = .none`，100% 杜绝工具栏与选框阴影泄漏至录制画面中。
- **智能导出机制**：完成录制后，GIF 数据以 `com.compuserve.gif` 及文件 URL 双重格式自动写入剪贴板，支持直接在聊天软件或编辑器中粘贴，亦可选择自动保存至指定目录。
- **偏好设置自由定制**：支持在偏好设置中自由调整录制帧率 (5–30 FPS)、最大时长 (5–120s)、鼠标光标录制、Retina 视网膜屏智能降采样、自动拷贝、自动保存路径及录制提示音效。

### 3. 原生级原地屏幕翻译
- **原地覆盖替换 (In-Situ Replacement)**：直接在用户框选的原图区域上进行文字识别与排版覆盖，无需弹出独立查询窗口。
- **原生分段控制**：支持鼠标点选或敲击空格键（Space）在原文与译文之间实现零延迟往返切换。
- **多语种实时互转**：支持中文、英文、日文、韩文、法文、德文、西班牙文、俄文等多语种实时下拉切换，附带一键互换翻译方向功能。
- **三层翻译保障引擎**：
  1. **Apple 官方原生翻译框架**：优先调用 macOS 15+ Sequoia 离线神经网络模型。
  2. **DeepL 官方 API 接口**：支持用户配置专属 Auth Key，获取学术级高精度翻译。
  3. **内置多通道回退**：自动熔断机制，保障极速响应与高可用。
- **温和优雅的降级处理**：当选区无文字或模糊时，原截图保持 100% 完整清晰（不遮挡原图），辅以温和的重试引导。

### 4. 本地离线高隐私 OCR
- **Apple Vision 框架全离线运算**：依托神经网络引擎（ANE）与 GPU 本地计算，文字识别耗时仅毫秒级。
- **本地安全保证**：截图识别全程无需联网，敏感代码、账号密码绝不上云。
- **多语言混合识别**：精准识别简繁中文、英文、日语、韩语、西欧字符及常用标点。
- **智能排版断行优化**：自动修正常见 OCR 缺陷——英语软断行智能追加空格拼接，中文断行无缝合并不产生多余空隙。

### 5. 矢量标注工具箱
- **分组式高对比度工具栏**：采用微透分割线划分为三大清晰功能区：
  - **绘图工具**：矩形 (`R`)、椭圆 (`O`)、直线 (`L`)、平滑箭头 (`A`)、手绘笔刷 (`P`)、荧光笔 (`H`)、文字 (`T`)、马赛克/模糊 (`M`)、自增编号印章 ① ② ③ (`N`)。
  - **历史记录**：无限次撤销 (`Command + Z`) 与重做 (`Shift + Command + Z`)。
  - **操作控制**：取消退出 (`Esc`)、录制 GIF 动图、保存为文件 (`Command + S`)、贴屏置顶 (`F3`)、完成并复制到剪贴板 (`Enter`)。
- **二级调色板**：精选常用配色色盘与 3 档线宽快速切换，紧凑下挂于工具栏。

### 6. 像素级放大镜与色彩拾取
- **8 倍实时放大镜**：跟随十字准星高刷新移动，网格化展示每一个微观像素。
- **RGB 与 HEX 实时监视**：清晰呈现鼠标所在像素的精确坐标及十六进制色彩数值。
- **一键复制色值**：在取色状态下按 `C` 键，立即将当前 HEX 色彩值复制到系统剪贴板。

### 7. 系统设置与全局热键
- **原生设计偏好设置**：严格遵循 macOS 设计规范，采用 160pt 原生侧边栏与 SF Pro 系统字体。
- **全局 Carbon 级系统热键**：全屏游戏或 IDE 重度编码场景下依然毫秒响应。
- **轻量常驻系统状态栏**：默认隐藏 Dock 栏图标，安静常驻于顶部系统状态栏。

---

## 快捷键速查表

### 截图与标注快捷键

| 快捷键 | 功能操作 |
| :--- | :--- |
| `F1` / `Option + A` | 唤起屏幕截图截取 |
| `F2` / `Option + O` | 选区 OCR 识别与原地翻译 |
| `F3` / `Option + P` | 剪贴板一键贴图 / 文本代码卡片化 |
| `F4` | 剪贴板内容快速翻译 |
| `C` | 复制准星处像素 HEX 颜色值（取色模式） |
| `Command + Z` | 撤销上一步标注 |
| `Shift + Command + Z` | 重做上一步标注 |
| `Command + S` | 保存为图片文件 |
| `Enter` | 完成当前标注并复制合成图至剪贴板 |
| `Esc` | 取消当前截图或退出工具 |

### GIF 动图录制  *(v1.0.2 新增)*

| 快捷键 / 操作 | 功能操作 |
| :--- | :--- |
| 工具栏 🔴 录制按钮 | 从当前框选区域开始录制 GIF |
| `Enter` | 完成录制并导出 GIF |
| `Esc` | 取消并放弃当前录制 |
| 暂停 ⏸ 按钮 | 暂停 / 继续录制 |
| 拖拽点阵手柄 | 自由拖拽调整录制控制条位置 |

### 贴图窗口交互

| 操作手势 / 按键 | 功能操作 |
| :--- | :--- |
| **滚轮 / 双指捏合** | 顺滑缩放贴图 (10% ~ 800%) |
| `Ctrl + 滚轮` / 数字 `1`–`9` | 调节贴图透明度 (10% ~ 90%)；`0` 恢复完全不透明 |
| `R` | 顺时针 90 度步进旋转 |
| `H` | 水平镜像翻转 |
| `V` | 垂直翻转 |
| `Command + L` | 开启 / 关闭鼠标点击穿透 (锁定模式) |
| **双击贴图** | 快速关闭当前贴图 |
| **右键点击** | 唤起右键菜单 (开启标注、修改透明度、翻转、缩放等) |

### 原地翻译操作

| 操作交互 | 功能说明 |
| :--- | :--- |
| `空格键 (Space)` | 在 原文 与 译文 之间原地秒级切换 |
| `点击 [ <-> ]` | 源语言与目标语言互换并立即重新翻译 |
| `点击目标语言菜单` | 切换目标语言（支持中、英、日、韩、法、德等） |
| `点击复制按钮` | 复制完整翻译文本至系统剪贴板 |
| `Esc` / 点击外部 | 关闭并退出翻译浮层 |

---

## 架构与工程结构

```
SnipSnap/
├── Package.swift                          # SPM 项目配置
├── build_app.sh                           # 正式版本打包与代码签名脚本
├── Resources/
│   ├── AppIcon.icns                       # 应用程序图标
│   └── Info.plist                         # Bundle 配置与系统权限声明
└── Sources/
    └── SnipSnap/
        ├── App/                           # 程序生命周期、AppDelegate、系统状态栏控制器
        ├── Capture/                       # 全屏取景覆盖层、窗口检测、放大镜取色、GIF 动图录制
        ├── Annotation/                    # 画布渲染器、矢量元素、分组式标注工具栏
        ├── Pin/                           # 贴图 NSPanel 窗口、外挂工具条、文本卡片化
        ├── Translation/                   # 原地翻译 HUD、Apple Translation、DeepL 引擎
        ├── OCR/                           # Apple Vision 框架离线 OCR 引擎
        ├── Hotkeys/                       # Carbon & CGEventTap 全局热键管理器
        ├── Models/                        # 应用配置数据、标注模型、历史记录管理
        └── Views/                         # 原生 SwiftUI 偏好设置、放大镜视图组件
```

---

## 安装与使用
 
### 1. 通过 Homebrew Cask 安装（推荐）

通过 SnipSnap 官方 Tap 一行命令直接安装：

```bash
brew install --cask iskf/snipsnap/snipsnap
```

或先添加 Tap 后安装：

```bash
brew tap iskf/snipsnap
brew install --cask snipsnap
```

后续如有新版本，可执行快速升级：

```bash
brew upgrade --cask snipsnap
```

### 2. 手动下载 DMG 镜像

1. 前往 [GitHub Releases](https://github.com/iskf/SnipSnap/releases/latest) 下载最新的 `SnipSnap-1.0.2.dmg`。
2. 双击打开 DMG，将 `SnipSnap.app` 拖入 `/Applications`（应用程序）文件夹。
3. 在启动台（Launchpad）或 Spotlight 聚焦搜索中启动 SnipSnap。

### 3. 从源码编译运行

#### 系统环境要求
- macOS 14.0 (Sonoma) 或更高版本 *(推荐 macOS 15.0+ Sequoia 以获得原生翻译框架完整体验)*
- Xcode 15.0+ 或 Swift 5.9+ 命令行工具链
- Apple Silicon (M1/M2/M3/M4) 或 Intel 架构 Mac

#### 编译打包步骤
1. 克隆本仓库：
   ```bash
   git clone https://github.com/iskf/SnipSnap.git
   cd SnipSnap
   ```

2. 自动构建并打包带有本地签名的 `.app` 应用程序：
   ```bash
   ./build_app.sh
   ```

3. 启动应用：
   ```bash
   open build/SnipSnap.app
   ```

---

## 权限与隐私说明

SnipSnap 遵循严格的本地隐私策略：
- **屏幕录制权限**：macOS 系统抓取屏幕缓冲区像素与录制 GIF 动图的基础权限。首次启动时系统将自动弹出授权提示，亦可在 `系统设置 -> 隐私与安全性 -> 屏幕与系统音频录制` 中开启。
- **辅助功能权限**：用于在系统全局层级监听并分发低延迟全局热键 (`F1`–`F4`)。可在 `系统设置 -> 隐私与安全性 -> 辅助功能` 中开启。
- **零数据采集**：SnipSnap 不包含任何打点追踪代码，不向外部发送任何网络请求（用户主动配置并使用 DeepL 等第三方翻译 API 场景除外）。

---

## 参与贡献

欢迎提交 Issue 或 Pull Request 共同改进项目。关于工程规范、代码风格与提交流程，请查阅 [CONTRIBUTING.md](CONTRIBUTING.md)。

---

## 开源协议

本项目采用 [MIT 许可证](LICENSE)。

<p align="center">
  <sub>专为 macOS 深度用户、开发者与设计师打造。</sub>
</p>
