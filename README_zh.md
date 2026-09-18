# SnipSnap

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="SnipSnap Logo" />
</p>

<p align="center">
  <b>基于纯原生技术构建的 macOS 超高性能快捷截图、极致贴图、离线 OCR 与 Safari 级原地屏幕翻译工具。</b>
</p>

<p align="center">
  <a href="https://apple.com"><img src="https://img.shields.io/badge/macOS-14.0%2B-black?style=flat-square&logo=apple" alt="macOS 14.0+" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9%20%2F%206.0-orange?style=flat-square&logo=swift" alt="Swift 5.9 / 6.0" /></a>
  <img src="https://img.shields.io/badge/Arch-Universal%20(Apple%20Silicon%20%2F%20Intel)-blue?style=flat-square" alt="Apple Silicon & Intel" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License MIT" /></a>
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square" alt="PRs Welcome" />
</p>

<p align="center">
  <a href="README.md">English</a> | <b>简体中文</b>
</p>


---

## 💡 项目简介

**SnipSnap** 专为追求极致性能与设计质感的 macOS 深度用户、开发者与设计师打造，底层 100% 采用苹果官方原生技术栈开发（**Swift、AppKit、SwiftUI、Apple Vision 与 Apple Translation 框架**）。

拒绝动辄占用数百兆内存的 Electron 封装应用，SnipSnap 拥有毫秒级快速启动响应与近乎为零的空闲内存消耗。它将 **Snipaste** 备受赞誉的细腻贴图操作体验，与现代 macOS 苹果人机交互设计（HIG）、Apple Intelligence 流光质感及 Safari 原生原地翻译完美融合。

---

## 🖼️ 核心功能实机预览

| 📸 精准截图取景与 3 组式标注工具条 | 🌐 Safari 级原地双语屏幕翻译 |
| :---: | :---: |
| <img src="docs/images/annotation_toolbar.png" alt="精准取景与标注工具栏" width="460" /> | <img src="docs/images/inplace_translation.png" alt="原地屏幕翻译" width="460" /> |
| **像素级取景准心 · 放大镜色彩拾取 · 白色分割线分组工具条** | **离线 Apple Vision OCR · 局部擦除替换 · 原生 [原文\|译文] 瞬间切换** |

| 📌 桌面毛玻璃置顶贴图与高级菜单 | ⚙️ macOS 原生控制中心与快捷键 |
| :---: | :---: |
| <img src="docs/images/hero_pin.png" alt="毛玻璃置顶贴图" width="460" /> | <img src="docs/images/control_center.png" alt="原生控制中心" width="460" /> |
| **独立 NSPanel 浮窗 · Apple Intelligence 光晕 · 丰富右键操作** | **纯原生 Swift/AppKit 架构 · 全局热键录制 · 零内存占用常驻** |

---

## ✨ 核心特性

### 1. 📌 极致贴图体验 (媲美并增强 Snipaste)
- **独立悬浮置顶**：贴图基于系统独立 `NSPanel` 构建，跨 Space、虚拟桌面及全屏软件持续置顶，写代码、对稿比对设计无缝穿插。
- **平滑无级缩放**：支持鼠标滚轮与触控板双指捏合手势，在 **10% ~ 800%** 范围平滑缩放。
- **透明度调节**：按住 `Ctrl + 滚轮` 或直接按数字键 `1`–`9` 即可微调半透明度（按 `0` 瞬间恢复 100% 不透明）。
- **几何旋转与翻转**：按 `R` 键以 90° 步进顺时针旋转，按 `H` 水平镜像翻转，按 `V` 垂直翻转，画布智能自动居中对齐。
- **🛡️ 鼠标穿透 (Lock Mode)**：通过快捷键 `⌘L` 或右键菜单开启穿透模式，贴图将变为纯背景参考图，鼠标点击可直接穿透操作底层窗口。
- **外挂悬浮二次标注栏**：右键唤起「🎨 标注贴图」时，工具栏以独立悬浮子窗口形式呈现于贴图外部，彻底告别贴图边界被遮挡或裁切的烦恼。
- **剪贴板文本一键卡片化 (`F3`)**：剪贴板中有图片时直接贴图；若复制了代码段或长文本，SnipSnap 将自动排版渲染为精美磨砂代码卡片贴于屏幕中央！

### 2. 🌐 原生级原地屏幕翻译 (Safari Style)
- **原地覆盖替换 (In-Situ Replacement)**：直接在用户框选的原图区域上进行文本识别与智能覆盖排版，无需跳出外部弹窗。
- **Apple Intelligence 霓虹流光**：激活翻译时，选区周围环绕极具未来感的紫蓝流光呼吸光晕。
- **原生分段控制 `[ 原文 | 译文 ]`**：苹果原生磨砂胶囊分段组件，支持鼠标点选或敲击空格键（Space）瞬间零延迟往返切换。
- **一体化毛玻璃语言对 `[ 中 ⇄ 英 ▾ ]`**：支持中文、英文、日文、韩文、法文、德文、西文、俄文等多语种实时下拉切换，附带一键「⇄」互换翻译方向。
- **三层翻译保障引擎**：
  1. **Apple 官方原生翻译引擎**（优先调用 macOS 15+ Sequoia 离线神经网络模型）
  2. **DeepL 官方 API 接口**（支持配置专属 Auth Key 获取学术级高精度翻译）
  3. **内置多通道引擎**（智能熔断机制，保障极速响应与高可用）
- **未识别状态温和降级**：当截图无文字或模糊时，原截图保持 100% 完整清晰（绝不遮挡原图），工具栏以温和提示与「重试」按键进行引导。

### 3. 🔍 100% 本地离线、高隐私 OCR
- **Apple Vision 框架全离线运算**：依托神经网络引擎（ANE）与 GPU 本地计算，文本识别速度仅需毫秒级。
- **零数据泄露隐患**：截图识别全程无需联网，敏感代码、账号密码绝不上云。
- **多语言混合识别**：精准识别简繁中文、英文、日语、韩语、西欧字符及常用标点。
- **智能排版断行优化**：自动修正常见 OCR 缺陷——英语软断行智能追加空格拼接，中文断行无缝合并不产生多余空格。

### 4. 🎨 全功能矢量标注工具箱
- **3 组式高对比度分组工具栏**：采用白色微透分割线 `|` 划分为三大清晰功能区：
  - **标注绘图区**：矩形 (`R`)、椭圆 (`O`)、直线 (`L`)、平滑箭头 (`A`)、手绘笔刷 (`P`)、半透明荧光笔 (`H`)、可缩放换行文字 (`T`)、像素化马赛克/模糊 (`M`)、自增编号印章 ① ② ③ (`N`)。
  - **历史记录区**：无限次撤销 (`⌘Z`) 与重做 (`⇧⌘Z`)。
  - **操作控制区**：取消退出 (`Esc`)、保存为文件 (`⌘S`)、贴屏置顶 (`F3`)、完成并复制到剪贴板 (`Enter`)。
- **预设调色板与粗细控制**：经典 8 色色盘（红、蓝、绿、橙、紫、黄、白、黑）与 3 档线宽快速切换。

### 5. 🔍 像素级放大镜与色彩拾取器
- **8 倍实时超清放大镜**：跟随十字准星高刷新移动，网格化展示每一个微观像素。
- **RGB / HEX 坐标值实时监视**：清晰呈现鼠标所在像素的精确坐标及十六进制色彩数值。
- **一键复制色值**：在取色状态下按 `C` 键，立即将当前 HEX 色彩值复制到系统剪贴板。

### 6. ⚙️ 原生偏好设置与系统热键
- **精简原生侧边栏**：严格遵循 macOS 设计规范，采用 160pt 原生微型侧边栏与 SF Pro 系统字体。
- **全局 Carbon 级系统热键**：全屏 3D 游戏或 IDE 重度编码场景下依然毫秒响应。
- **常驻菜单栏与零 Dock 干扰**：默认隐藏 Dock 栏图标，安静常驻于顶部系统状态栏。

---

## ⌨️ 快捷键速查表

### 📸 截图与标注快捷键

| 快捷键 | 功能操作 |
| :--- | :--- |
| `F1` / `⌥ A` | 唤起屏幕截图截取 |
| `F2` / `⌥ O` | 选区 OCR 识别与原地翻译 |
| `F3` / `⌥ P` | 剪贴板一键贴图 / 文本代码卡片化 |
| `F4` | 剪贴板内容快速翻译 |
| `C` | 复制准星处像素 HEX 颜色值（取色模式） |
| `⌘ Z` | 撤销上一步标注 |
| `⇧ ⌘ Z` | 重做上一步标注 |
| `⌘ S` | 调起独立置顶保存面板保存为图片文件 |
| `Enter` | 完成当前标注并复制合成图至剪贴板 |
| `Esc` | 取消当前截图或退出工具 |

### 📌 贴图窗口专用交互

| 操作手势 / 按键 | 功能操作 |
| :--- | :--- |
| **滚轮 / 双指捏合** | 顺滑缩放贴图 (10% ~ 800%) |
| `Ctrl + 滚轮` / 数字 `1`–`9` | 调节贴图透明度 (10% ~ 90%)；`0` 恢复完全不透明 |
| `R` | 顺时针 90° 步进旋转 |
| `H` | 水平镜像翻转 |
| `V` | 垂直翻转 |
| `⌘ L` | 开启 / 关闭鼠标点击穿透 (Lock Mode) |
| `双击贴图` | 快速关闭当前贴图 |
| `右键点击` | 唤起右键菜单 (开启标注、修改透明度、翻转、复制等) |

### 🌐 原地翻译专属操作

| 操作交互 | 功能说明 |
| :--- | :--- |
| `空格键 (Space)` | 在 原文 与 译文 之间原地无缝秒切 |
| `点击 [ ⇄ ]` | 源语言与目标语言对调互换并立即重新翻译 |
| `点击目标语言 ▾` | 唤起下拉菜单切换目标语言（支持中、英、日、韩、法、德等） |
| `点击「复制」` | 复制完整翻译文本至系统剪贴板 |
| `Esc` / 点击外部 | 关闭并退出翻译浮层 |

---

## 🏗️ 目录结构与技术架构

```
SnipSnap/
├── Package.swift                          # SPM 配置文件
├── build_app.sh                           # 正式打包签名脚本
├── Resources/
│   ├── AppIcon.icns                       # 应用高分辨率图标
│   └── Info.plist                         # 权限与应用属性列表
└── Sources/
    └── SnipSnap/
        ├── App/                           # 应用生命周期、AppDelegate 与菜单栏控制器
        │   ├── SnipSnapApp.swift
        │   ├── AppDelegate.swift
        │   └── MenuBarController.swift
        ├── Capture/                       # 全屏截图覆盖层、窗口检测、放大镜取色器
        │   ├── ScreenCaptureService.swift
        │   ├── CaptureOverlayWindow.swift
        │   └── CaptureOverlayView.swift
        ├── Annotation/                    # 矢量标注绘制引擎、图元模型与 3 组式工具栏
        │   ├── AnnotationCanvasView.swift
        │   ├── AnnotationToolbarView.swift
        │   └── ColorPalette.swift
        ├── Pin/                           # 贴图 NSPanel 窗口、外挂工具栏与剪贴板卡片化
        │   ├── PinWindowManager.swift
        │   ├── PinWindow.swift
        │   └── PinContentView.swift
        ├── Translation/                   # Safari 级原地翻译悬浮窗、Apple 原生翻译与 DeepL 集成
        │   ├── InPlaceTranslateHUDView.swift
        │   ├── TranslateFloatingWindow.swift
        │   └── TranslationService.swift
        ├── OCR/                           # Apple Vision 原生离线识别引擎
        │   ├── VisionOCRService.swift
        │   └── OCRResultWindow.swift
        ├── Hotkeys/                       # Carbon 底层低延迟全局热键管理器
        │   └── GlobalHotkeyManager.swift
        ├── Models/                        # 偏好配置、标注图元与历史记录模型
        │   ├── AppConfig.swift
        │   └── AnnotationElement.swift
        └── Views/                         # 原生 SwiftUI 偏好设置面板与辅助视图
            ├── MainControlWindow.swift
            └── LoupeMagnifierView.swift
```

---

## 🛠️ 构建与本地运行

### 系统环境要求
- **macOS 14.0 (Sonoma)** 或更高版本 *(推荐 macOS 15.0+ Sequoia 以获得完整的 Apple 官方原生离线翻译体验)*
- **Xcode 15.0+** 或 Swift 5.9+ 开发工具链
- **架构**：全面适配 Apple Silicon (M1/M2/M3/M4 系列) 及 Intel 架构 Mac

### 源码编译步骤

1. 克隆代码仓库：
   ```bash
   git clone https://github.com/yourusername/SnipSnap.git
   cd SnipSnap
   ```

2. 使用 Swift Package Manager 进行 Debug 编译：
   ```bash
   swift build
   ```

3. 运行打包与签名脚本，生成标准 `.app` 应用：
   ```bash
   ./build_app.sh
   ```

4. 启动体验应用：
   ```bash
   open build/SnipSnap.app
   ```

---

## 🔒 系统权限说明与隐私承诺

SnipSnap 秉承隐私优先原则，不收集任何用户隐私数据：
- **屏幕录制权限 (Screen Recording)**：macOS 系统硬性安全要求，用于读取屏幕像素完成截图。初次启动将主动引导授予，亦可在 `系统设置 -> 隐私与安全性 -> 屏幕与系统音频录制` 中开启。
- **辅助功能权限 (Accessibility)**：用于监听全局系统快捷键（如 `F1`–`F4`）。可在 `系统设置 -> 隐私与安全性 -> 辅助功能` 中开启。
- **完全离线与无网络追踪**：默认状态下所有 OCR 识别与翻译均通过 Apple 本地引擎完成，零网络流量，绝不上报任何遥测追踪数据。

---

## 🤝 贡献指南

非常欢迎提交 Issue 反馈 Bug，或提交 Pull Request 贡献新特性！
1. Fork 本项目到您的 GitHub 仓库
2. 创建您的专属特性分支 (`git checkout -b feature/awesome-feature`)
3. 提交您的修改 (`git commit -m 'feat: 增加全新特性'`)
4. 推送至远程分支 (`git push origin feature/awesome-feature`)
5. 创建并提交 Pull Request

---

## 📄 开源许可证

本项目基于 **MIT License** 开源 - 详情参见 [LICENSE](LICENSE) 文件。

---

<p align="center">
  专为追求极致体验的 macOS 开发者与创作者精心打磨 ❤️
</p>
