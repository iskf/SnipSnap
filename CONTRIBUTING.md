# Contributing to SnipSnap

Thank you for your interest in contributing to **SnipSnap**! We welcome contributions from developers of all skill levels to help make SnipSnap the best native screenshot, pinning, and translation tool for macOS.

---

## 🛠️ Architecture & Tech Stack

SnipSnap is designed with performance, native user experience, and low memory consumption in mind:
- **Language**: Swift 5.9+ / Swift 6.0
- **Frameworks**:
  - `AppKit` & `SwiftUI` (Hybrid native architecture)
  - `Vision` (Apple offline on-device OCR)
  - `Translation` (Apple on-device offline translation, macOS 15+)
  - `ScreenCaptureKit` & `CoreGraphics` (Precision screen capture)
  - `Carbon` & `CGEventTap` (System-wide global hotkey interception)
- **Build System**: Swift Package Manager (`Package.swift`)

---

## 💻 Development Setup

### Prerequisites
- macOS Sonoma (14.0) or Sequoia (15.0+)
- Xcode 15.0+ or Command Line Tools (`xcode-select --install`)
- Swift 5.9+

### Quick Start
1. Fork and clone the repository:
   ```bash
   git clone https://github.com/iskf/SnipSnap.git
   cd SnipSnap
   ```

2. Build and run in debug mode:
   ```bash
   swift run
   ```

3. Build a release macOS `.app` bundle:
   ```bash
   bash build_app.sh
   open build/SnipSnap.app
   ```

---

## 📋 Contribution Workflow

1. **Check Existing Issues**: Before starting work on major changes, open an issue or comment on an existing one to discuss your ideas.
2. **Create a Feature Branch**:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```
3. **Commit Your Changes**: Follow [Conventional Commits](https://www.conventionalcommits.org/):
   - `feat:` for new features
   - `fix:` for bug fixes
   - `perf:` for performance optimizations
   - `refactor:` for code refactoring
   - `docs:` for documentation updates
4. **Test Thoroughly**:
   - Ensure the app compiles cleanly with `swift build -c release`.
   - Test screen capture, pinning, shortcuts, OCR, and annotation features locally.
5. **Open a Pull Request**:
   - Submit your PR against the `main` branch.
   - Describe what the PR accomplishes and link any relevant issues.

---

## 📜 Code of Conduct & Licensing

By contributing to SnipSnap, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
