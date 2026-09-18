# SnipSnap

<p align="center">
  <img src="Resources/AppIcon.png" width="128" height="128" alt="SnipSnap Logo" />
</p>

<p align="center">
  <b>A blazing-fast, privacy-first, macOS native screenshot, pixel-perfect pinning, offline OCR, and in-place screen translation tool.</b>
</p>

<p align="center">
  <a href="https://apple.com"><img src="https://img.shields.io/badge/macOS-14.0%2B-black?style=flat-square&logo=apple" alt="macOS 14.0+" /></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9%20%2F%206.0-orange?style=flat-square&logo=swift" alt="Swift 5.9 / 6.0" /></a>
  <img src="https://img.shields.io/badge/Arch-Universal%20(Apple%20Silicon%20%2F%20Intel)-blue?style=flat-square" alt="Apple Silicon & Intel" />
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License MIT" /></a>
  <img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square" alt="PRs Welcome" />
</p>

<p align="center">
  <b>English</b> | <a href="README_zh.md">简体中文</a>
</p>

---

<p align="center">
  <img src="docs/images/hero_pin.png" width="520" alt="SnipSnap Floating Pin & Advanced Context Menu" />
  <br />
  <sub>📌 Floating Overlay · Apple Intelligence Ambient Glow · Native Context Actions</sub>
</p>

---

## 💡 Overview

**SnipSnap** is built from the ground up for macOS using pure native technologies: **Swift, AppKit, SwiftUI, Apple Vision, and the Apple Translation framework**. 

Unlike heavy Electron-based screen tools that consume hundreds of megabytes of RAM, SnipSnap launches instantly, idles with near-zero memory footprint, and requires zero external cloud dependencies. It brings the beloved, tactile pinning experience of *Snipaste* together with modern macOS Tahoe/Sonoma/Sequoia aesthetic standards, Apple Intelligence glow styling, and Safari-inspired in-place translation.

---

## 🖼️ Interface Previews

| 📸 Precision Capture & Grouped Toolbar | 🌐 Safari-Style In-Place Screen Translation |
| :---: | :---: |
| <img src="docs/images/annotation_toolbar.png" alt="Precision Viewfinder & Grouped Toolbar" width="460" /> | <img src="docs/images/inplace_translation.png" alt="In-Place Translation" width="460" /> |
| **Pixel-level reticle · 8x Loupe color picker · Divider-grouped toolbar** | **Offline Apple Vision OCR · In-situ replacement · [Original\|Translation] switcher** |

| 📌 Pixel-Perfect Floating Pin & Actions | ⚙️ macOS Native Control Center |
| :---: | :---: |
| <img src="docs/images/hero_pin.png" alt="Floating Pin & Context Menu" width="460" /> | <img src="docs/images/control_center.png" alt="Native Control Center" width="460" /> |
| **Independent NSPanel · Apple Intelligence glow · Right-click power menu** | **Pure Swift/AppKit architecture · Global hotkey recorder · Zero idle overhead** |

---

## ✨ Key Features

### 1. 📌 Superior Pinning Experience (*Snipaste Reimagined*)
- **Independent Floating Panel**: Pins stay on top across all Spaces, workspaces, and full-screen apps for seamless reference while coding or designing.
- **Fluid Zooming**: Smooth, stepless zooming from **10% to 800%** using mouse scroll wheel or two-finger trackpad pinch gestures.
- **Opacity Control**: Instant opacity adjustment using `Ctrl + Scroll` or direct number keys `1`–`9` (`0` restores 100% opacity).
- **Stepped Rotation & Mirroring**: Rotate in 90° increments with `R`, flip horizontally with `H`, or flip vertically with `V` with adaptive canvas re-centering.
- **🛡️ Mouse Pass-Through (Lock Mode)**: Toggle with `⌘L` or right-click to let mouse clicks pass straight through the pinned image to underlying applications.
- **External Floating Annotation Toolbar**: Secondary annotations (arrows, rectangles, mosaics, text) open on a dedicated floating panel attached to the pin, ensuring zero canvas clipping.
- **Clipboard Text to Card**: Press `F3` when text or code snippets are copied; SnipSnap automatically formats and renders them into an elegant, styled code/text card pinned to your screen.

### 2. 🌐 In-Place Screen Translation (*Safari Style*)
- **In-Situ Text Replacement**: Selected text is seamlessly translated and rendered directly over the original screen context without opening separate query windows.
- **Apple Intelligence Radiant Glow**: Features an ambient violet-blue radiant breathing glow outline around active translation frames.
- **Native Segmented Switcher `[ Original | Translation ]`**: Instant, zero-latency toggling between source and translated text.
- **Unified Frosted Glass Language Pair `[ Source ⇄ Target ▾ ]`**: On-the-fly language dropdown menu supporting English, Simplified Chinese, Japanese, Korean, French, German, Spanish, and Russian, with an instant one-click swap button (`⇄`).
- **Tri-Tier Translation Architecture**:
  1. **Apple Official Native Translation Engine** (macOS 15+ Sequoia offline models)
  2. **DeepL Official API** (User-configured high-accuracy neural translation)
  3. **Multi-Channel Fallback** (Instant failover with built-in circuit breaker)
- **Graceful Unrecognized Handling**: When text is blurry or empty, the original screenshot remains 100% visible and unblemished, accompanied by a gentle warning pill and retry action.

### 3. 🔍 100% Offline, Privacy-First OCR
- **Apple Vision Framework**: Optical character recognition is computed entirely on-device using Apple Neural Engine / GPU acceleration.
- **Zero Data Leakage**: Your screen contents never touch third-party servers.
- **Mixed-Language Support**: Accurately recognizes mixed English, Chinese, Japanese, Korean, Latin, and punctuation.
- **Smart Typographic Normalization**: Automatically repairs line breaks—merging soft-wrapped English sentences with single spaces while joining wrapped Chinese lines without awkward gaps.

### 4. 🎨 Complete Vector Annotation Toolkit
- **High-Contrast Grouped Toolbar**: Divided into 3 distinct functional clusters separated by crisp vertical divider lines:
  - **Annotation Tools**: Rectangle (`R`), Ellipse (`O`), Line (`L`), Arrow (`A`), Freehand Pen (`P`), Highlighter (`H`), Text (`T`), Pixelated Mosaic/Blur (`M`), Auto-Increment Counter Stamps ① ② ③ (`N`).
  - **History Controls**: Unlimited Undo (`⌘Z`) and Redo (`⇧⌘Z`).
  - **Session Actions**: Cancel (`Esc`), Save As (`⌘S`), Pin (`F3`), Done & Copy to Clipboard (`Enter`).
- **Color Palette & Stroke Sizes**: Quick presets (Red, Blue, Green, Orange, Purple, Yellow, White, Black) with 3 adjustable stroke weights.

### 5. 🔍 Pixel-Level Loupe & Color Picker
- **Real-Time 8x Magnifier**: Precision cursor tracking displaying a pixel grid with central reticle guide.
- **RGB / HEX Inspection**: Instant display of pixel coordinates and hexadecimal color codes.
- **One-Click Copy**: Press `C` to copy the current HEX color code directly to your clipboard.

### 6. ⚙️ Apple-Native Preferences & Global Hotkeys
- **Compact Native Sidebar**: Designed in strict accordance with Apple Human Interface Guidelines, featuring 160pt compact sidebar and SF Pro typography.
- **Customizable Shortcuts**: Carbon-level low-latency global hotkey registration for instant response even in heavy games or full-screen IDEs.
- **Lightweight Menu Bar Resident**: Lives silently in the menu bar with no dock clutter.

---

## ⌨️ Keyboard Shortcuts Cheat Sheet

### 📸 Capture & Annotation

| Shortcut | Action |
| :--- | :--- |
| `F1` / `⌥ A` | Start screen capture |
| `F2` / `⌥ O` | Area OCR & Screen Translation |
| `F3` / `⌥ P` | Pin image or convert clipboard text to card |
| `F4` | Quick translate clipboard text |
| `C` | Copy HEX color under cursor (Loupe mode) |
| `⌘ Z` | Undo annotation |
| `⇧ ⌘ Z` | Redo annotation |
| `⌘ S` | Save screenshot to file (Elevated modal dialog) |
| `Enter` | Complete annotation & copy image to clipboard |
| `Esc` | Cancel / Exit current capture or tool |

### 📌 Pinned Window

| Interaction | Action |
| :--- | :--- |
| **Scroll / Pinch** | Smooth zoom in / out (10% ~ 800%) |
| `Ctrl + Scroll` / `1`–`9` | Adjust opacity (10% ~ 90%); `0` restores 100% |
| `R` | Rotate 90° clockwise |
| `H` | Flip horizontally |
| `V` | Flip vertically |
| `⌘ L` | Toggle mouse pass-through (Lock mode) |
| `Double Click` | Close pinned window |
| `Right Click` | Open contextual menu (Secondary annotation, opacity, etc.) |

### 🌐 In-Place Translation HUD

| Interaction | Action |
| :--- | :--- |
| `Space` | Toggle between Original and Translated text |
| `Click [ ⇄ ]` | Swap source and target languages instantly |
| `Target Menu ▾` | Switch target language (English, Chinese, Japanese, etc.) |
| `Click 复制` | Copy translated text to clipboard |
| `Esc` / Click Outside | Dismiss translation overlay |

---

## 🏗️ Architecture & Project Structure

```
SnipSnap/
├── Package.swift                          # SPM Project manifest
├── build_app.sh                           # Production bundle & code signing script
├── Resources/
│   ├── AppIcon.icns                       # Application icon
│   └── Info.plist                         # Bundle configuration & permissions
└── Sources/
    └── SnipSnap/
        ├── App/                           # App lifecycle, NSApplicationDelegate, MenuBar
        │   ├── SnipSnapApp.swift
        │   ├── AppDelegate.swift
        │   └── MenuBarController.swift
        ├── Capture/                       # Full-screen overlay, window detection, loupe
        │   ├── ScreenCaptureService.swift
        │   ├── CaptureOverlayWindow.swift
        │   └── CaptureOverlayView.swift
        ├── Annotation/                    # Canvas renderer, vector elements, grouped toolbar
        │   ├── AnnotationCanvasView.swift
        │   ├── AnnotationToolbarView.swift
        │   └── ColorPalette.swift
        ├── Pin/                           # Pinned NSPanel, external toolbar, cardifier
        │   ├── PinWindowManager.swift
        │   ├── PinWindow.swift
        │   └── PinContentView.swift
        ├── Translation/                   # In-place HUD, Apple Translation, DeepL, fallback
        │   ├── InPlaceTranslateHUDView.swift
        │   ├── TranslateFloatingWindow.swift
        │   └── TranslationService.swift
        ├── OCR/                           # Vision.framework offline text recognizer
        │   ├── VisionOCRService.swift
        │   └── OCRResultWindow.swift
        ├── Hotkeys/                       # Carbon-based global hotkey manager
        │   └── GlobalHotkeyManager.swift
        ├── Models/                        # App configuration, annotations, OCR models
        │   ├── AppConfig.swift
        │   └── AnnotationElement.swift
        └── Views/                         # Native SwiftUI preferences, loupe magnifier
            ├── MainControlWindow.swift
            └── LoupeMagnifierView.swift
```

---

## 🛠️ Building & Installation

### Requirements
- **macOS 14.0 (Sonoma)** or later *(macOS 15.0+ Sequoia recommended for Apple Native Translation framework)*
- **Xcode 15.0+** or Swift 5.9+ toolchain
- **Apple Silicon (M1/M2/M3/M4) or Intel Mac**

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/SnipSnap.git
   cd SnipSnap
   ```

2. Build debug binary via Swift Package Manager:
   ```bash
   swift build
   ```

3. Package into `.app` bundle and sign with your local developer identity:
   ```bash
   ./build_app.sh
   ```

4. Launch SnipSnap:
   ```bash
   open build/SnipSnap.app
   ```

---

## 🔒 Permissions & Privacy

SnipSnap is designed with strict privacy standards:
- **Screen Recording Permission**: Required by macOS to capture screen contents. Prompted automatically on first launch or accessible via `System Settings -> Privacy & Security -> Screen & System Audio Recording`.
- **Accessibility Permission**: Required for registering low-latency global keyboard shortcuts (`F1`–`F4`). Accessible via `System Settings -> Privacy & Security -> Accessibility`.
- **No Analytics / No Tracking**: SnipSnap collects zero telemetries and sends no network requests, unless you explicitly configure a third-party translation provider like DeepL.

---

## 🤝 Contributing

Contributions, feature suggestions, and pull requests are warmly welcomed!
1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Crafted with ❤️ for macOS power users, developers, and designers.
</p>
