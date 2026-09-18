import Cocoa
import SwiftUI
import ServiceManagement

public enum ControlCenterSubTab: String, CaseIterable, Identifiable {
    case general = "通用设置"
    case hotkeys = "快捷键"
    case capture = "截图与标注"
    case pinning = "贴图设置"
    case ocr = "OCR与翻译"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .hotkeys: return "keyboard.fill"
        case .capture: return "camera.viewfinder"
        case .pinning: return "pin.fill"
        case .ocr: return "character.book.closed.fill"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .general: return Color(nsColor: .systemGray)
        case .hotkeys: return Color(nsColor: .systemGreen)
        case .capture: return Color(nsColor: .systemBlue)
        case .pinning: return Color(nsColor: .systemPurple)
        case .ocr: return Color(nsColor: .systemIndigo)
        }
    }
}

public class MainControlViewModel: ObservableObject {
    @Published public var selectedTab: ControlCenterSubTab = .general
    
    public init(selectedTab: ControlCenterSubTab = .general) {
        self.selectedTab = selectedTab
    }
}

public class MainControlWindowController: NSWindowController {
    public static var shared: MainControlWindowController?
    public var viewModel: MainControlViewModel = MainControlViewModel()
    
    public static func show(tab: ControlCenterSubTab = .general) {
        if let existing = shared, let window = existing.window {
            existing.viewModel.selectedTab = tab
            existing.showWindow(nil)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "偏好设置"
        window.minSize = NSSize(width: 600, height: 440)
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        
        let vm = MainControlViewModel(selectedTab: tab)
        let hosting = NSHostingView(rootView: MainControlView(viewModel: vm))
        window.contentView = hosting
        
        let controller = MainControlWindowController(window: window)
        controller.viewModel = vm
        shared = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Unified Control Center View

public struct MainControlView: View {
    @ObservedObject var viewModel: MainControlViewModel
    @State private var config = AppConfig.load()
    @State private var showResetAlert: Bool = false
    @State private var deeplTestStatus: String? = nil
    @State private var isTestingDeepL: Bool = false
    @State private var deeplTestSuccess: Bool = false
    @State private var accessibilityGranted: Bool = GlobalHotkeyManager.isAccessibilityGranted
    
    public init(viewModel: MainControlViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            // Unified Left Sidebar (Compact Native Style)
            sidebarView
                .frame(width: 160)
            
            Divider()
                .opacity(0.35)
            
            // Right Content Area
            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 600, minHeight: 440)
        .alert("确认恢复全部默认设置？", isPresented: $showResetAlert) {
            Button("取消", role: .cancel) { }
            Button("确认恢复", role: .destructive) {
                config.resetToDefaults()
                GlobalHotkeyManager.shared.reloadFromConfig()
            }
        } message: {
            Text("所有通用配置、快捷键、标注偏好与贴图行为将重置为初始出厂设置。")
        }
        .onAppear {
            accessibilityGranted = GlobalHotkeyManager.isAccessibilityGranted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityGranted = GlobalHotkeyManager.isAccessibilityGranted
        }
    }
    
    // MARK: - Left Sidebar (Native macOS System Settings Compact Style)
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("偏好设置")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 4)
            
            // Sub-menu Navigation Items List
            VStack(spacing: 2) {
                ForEach(ControlCenterSubTab.allCases) { tab in
                    let isSelected = viewModel.selectedTab == tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.12)) {
                            viewModel.selectedTab = tab
                        }
                    }) {
                        HStack(spacing: 7) {
                            // Apple Settings Badge: 18x18 rounded rect with white SF Symbol
                            ZStack {
                                RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                                    .fill(tab.badgeColor)
                                    .frame(width: 18, height: 18)
                                
                                Image(systemName: tab.icon)
                                    .font(.system(size: 9.5, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(tab.rawValue)
                                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                                .foregroundColor(isSelected ? .white : .primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3.5)
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isSelected ? Color.accentColor : Color.clear)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(VisualEffectBlur(material: .sidebar))
    }
    
    // MARK: - Right Content Area
    
    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                switch viewModel.selectedTab {
                case .general:
                    generalSettingsView
                case .hotkeys:
                    hotkeysSettingsView
                case .capture:
                    captureSettingsView
                case .pinning:
                    pinningSettingsView
                case .ocr:
                    ocrSettingsView
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
        }
        .background(Color(NSColor.underPageBackgroundColor).opacity(0.4))
    }
    
    // MARK: - 1. General Settings View
    
    private var generalSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "启动与系统") {
                VStack(spacing: 12) {
                    toggleRow(title: "登录时自动启动 SnipSnap", isOn: $config.launchAtLogin) {
                        updateLaunchAtLogin(config.launchAtLogin)
                    }
                    Divider().opacity(0.3)
                    toggleRow(title: "菜单栏使用极简单色图标", isOn: $config.menuBarIconMonochrome) {
                        MenuBarController.shared.updateIconStyle(isMonochrome: config.menuBarIconMonochrome)
                    }
                    Divider().opacity(0.3)
                    toggleRow(title: "截图与复制成功后播放清脆提示音 (Tink)", isOn: $config.playSoundEffect)
                }
            }
            
            settingsCard(title: "存储与保存规则") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("默认保存目录")
                                .font(.system(size: 13, weight: .medium))
                            Text(config.defaultSavePath.isEmpty ? "桌面" : config.defaultSavePath)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button("更改目录...") {
                            chooseDefaultDirectory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Divider().opacity(0.3)
                    
                    HStack {
                        Text("图片保存格式")
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.imageSaveFormat) {
                            Text("PNG (无损)").tag("PNG")
                            Text("JPEG (紧凑)").tag("JPEG")
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 140)
                        .onChange(of: config.imageSaveFormat) { _ in
                            config.save()
                        }
                    }
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(title: "截图完成后自动保存到默认文件夹", isOn: $config.autoSaveAfterCapture)
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(title: "截图完成后自动复制到系统剪贴板", isOn: $config.autoCopyAfterCapture)
                }
            }
            
            settingsCard(title: "配置重置") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("恢复出厂默认设置")
                            .font(.system(size: 13, weight: .medium))
                        Text("重置所有通用配置、快捷键、截图标注偏好与贴图行为")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("恢复默认...") {
                        showResetAlert = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
    }
    
    // MARK: - 2. Hotkeys Settings View
    
    private var hotkeysSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "⚡ 全系统最高优先级拦截状态 (硬件级 CGEventTap)") {
                VStack(alignment: .leading, spacing: 8) {
                    if accessibilityGranted {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("最高优先级拦截引擎已激活")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("拦截层级位于 macOS HID 硬件驱动事件首位。顶排按键 (F1-F4) 可免按 fn 实体键直接呼出截屏/贴图，已智能阻止屏幕亮度调节与调度中心冲突。")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    } else {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 16))
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("最高优先级拦截待授权（当前运行于标准 Carbon 兼容模式）")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text("建议开启「辅助功能」权限，以激活硬件级最高优先级拦截，彻底杜绝 F1-F4 与 Mac 原生亮度或调度中心抢占。")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    Button("前往系统设置授权「辅助功能」 ↗") {
                                        GlobalHotkeyManager.requestAccessibilityPermission()
                                        GlobalHotkeyManager.openAccessibilitySettings()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    
                                    Button("键盘功能键设置 ↗") {
                                        GlobalHotkeyManager.openKeyboardSettings()
                                    }
                                    .buttonStyle(.link)
                                    .controlSize(.small)
                                }
                                .padding(.top, 2)
                            }
                            Spacer()
                        }
                    }
                }
            }
            
            settingsCard(title: "四大金刚核心全局热键 (F1-F4 极简单键体系)") {
                VStack(spacing: 12) {
                    HotkeyRecorderView(
                        title: "① 屏幕截图",
                        actionId: "screenshot",
                        shortcut: $config.screenshotShortcut,
                        config: config
                    ) { _ in
                        saveAndReloadHotkeys()
                    }
                    
                    Divider().opacity(0.3)
                    
                    HotkeyRecorderView(
                        title: "② 选区翻译",
                        actionId: "translate",
                        shortcut: $config.translateShortcut,
                        config: config
                    ) { _ in
                        saveAndReloadHotkeys()
                    }
                    
                    Divider().opacity(0.3)
                    
                    HotkeyRecorderView(
                        title: "③ 剪贴板贴图",
                        actionId: "pin",
                        shortcut: $config.pinShortcut,
                        config: config
                    ) { _ in
                        saveAndReloadHotkeys()
                    }
                    
                    Divider().opacity(0.3)
                    
                    HotkeyRecorderView(
                        title: "④ 隐藏/显示所有贴图",
                        actionId: "togglePins",
                        shortcut: $config.togglePinsShortcut,
                        config: config
                    ) { _ in
                        saveAndReloadHotkeys()
                    }
                }
            }
            
            settingsCard(title: "快捷键录制提示") {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text("系统默认已全面升级为 F1-F4 极简单功能键体系，单键直达无需组合键。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "escape")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text("点击按键框后可录制任意按键或功能键（F1-F12）；按 Esc 键可退出录制，按 ⌫ 清空。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text("如录入的按键已分配给其他功能，输入框将自动标红警示并提示冲突来源。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - 3. Capture & Annotation Settings View
    
    private var captureSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "放大镜取色器") {
                VStack(spacing: 12) {
                    toggleRow(title: "开启十字线中心取色放大镜跟随", isOn: $config.showLoupe)
                    
                    Divider().opacity(0.3)
                    
                    HStack {
                        Text("默认取色色彩格式")
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.loupeColorFormat) {
                            Text("HEX").tag("HEX")
                            Text("RGB").tag("RGB")
                            Text("HSL").tag("HSL")
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 150)
                        .onChange(of: config.loupeColorFormat) { _ in
                            config.save()
                        }
                    }
                }
            }
            
            settingsCard(title: "标注默认样式预设") {
                VStack(spacing: 12) {
                    HStack {
                        Text("默认画笔主色调")
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        HStack(spacing: 8) {
                            ForEach([
                                ("#FF3B30", Color(red: 1.0, green: 0.23, blue: 0.19)),
                                ("#FF9500", Color(red: 1.0, green: 0.58, blue: 0.0)),
                                ("#FFCC00", Color(red: 1.0, green: 0.8, blue: 0.0)),
                                ("#34C759", Color(red: 0.2, green: 0.78, blue: 0.35)),
                                ("#007AFF", Color(red: 0.0, green: 0.48, blue: 1.0)),
                                ("#AF52DE", Color(red: 0.69, green: 0.32, blue: 0.87))
                            ], id: \.0) { hex, color in
                                let isSelected = config.defaultStrokeColorHex == hex
                                Button(action: {
                                    config.defaultStrokeColorHex = hex
                                    config.save()
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 20, height: 20)
                                        if isSelected {
                                            Circle()
                                                .stroke(Color.white, lineWidth: 2)
                                                .frame(width: 20, height: 20)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Divider().opacity(0.3)
                    
                    HStack {
                        Text("默认线条粗细")
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.defaultStrokeWidth) {
                            Text("细 (2px)").tag(CGFloat(2.0))
                            Text("中 (4px)").tag(CGFloat(4.0))
                            Text("粗 (6px)").tag(CGFloat(6.0))
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 160)
                        .onChange(of: config.defaultStrokeWidth) { _ in
                            config.save()
                        }
                    }
                }
            }
            
            settingsCard(title: "快捷动作") {
                toggleRow(title: "完成截图时自动上屏贴图 (无需点击图钉按钮)", isOn: $config.autoPinAfterCapture)
            }
        }
    }
    
    // MARK: - 4. Pinning Settings View
    
    private var pinningSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "贴图窗口视觉外观") {
                VStack(spacing: 12) {
                    toggleRow(title: "启用贴图紫蓝光感悬浮阴影 (Apple Intelligence 风格)", isOn: $config.pinWindowBorder)
                    Divider().opacity(0.3)
                    toggleRow(title: "启用贴图窗口高级柔和悬浮阴影", isOn: $config.pinWindowShadow)
                    Divider().opacity(0.3)
                    toggleRow(title: "启用贴图窗口抗锯齿平滑圆角", isOn: $config.pinWindowRoundedCorners)
                }
            }
            
            settingsCard(title: "贴图交互与控制") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("默认初始透明度")
                                .font(.system(size: 13, weight: .regular))
                            Text("\(Int(config.pinInitialAlpha * 100))%")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Slider(value: $config.pinInitialAlpha, in: 0.3...1.0, step: 0.05) {
                            Text("")
                        }
                        .controlSize(.small)
                        .frame(width: 130)
                        .onChange(of: config.pinInitialAlpha) { _ in
                            config.save()
                        }
                    }
                    
                    Divider().opacity(0.3)
                    
                    HStack {
                        Text("双击贴图窗口行为")
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.doubleClickPinAction) {
                            Text("1:1 缩放").tag("zoom")
                            Text("关闭贴图").tag("close")
                            Text("标注贴图").tag("annotate")
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 190)
                        .onChange(of: config.doubleClickPinAction) { _ in
                            config.save()
                        }
                    }
                }
            }
            
            settingsCard(title: "贴图神技指南") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• 自由缩放：鼠标滚轮 或 双指捏合手势（10% ~ 800%）")
                    Text("• 调节透明度：Ctrl + 滚轮，或按键盘数字键 1~9 (0 恢复 100%)")
                    Text("• 1:1 还原：按键盘数字 0 键，一秒恢复原始 1:1 分辨率")
                    Text("• 外部拖拽：按住 ⌘ 拖动贴图，可作为文件直接丢入微信或访达")
                    Text("• 磁吸拼合：按住 ⇧ 拖动贴图吸附到临近贴图边缘拼接融合")
                    Text("• 二次标注：在贴图上右键选择「🎨 标注贴图」随时补画框写字")
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 5. OCR & Translation Settings View
    
    private var ocrSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: "Apple Vision 离线文字识别") {
                VStack(spacing: 12) {
                    HStack {
                        Text("优先识别语言")
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { config.ocrLanguages.first ?? "zh-Hans" },
                            set: { newVal in
                                config.ocrLanguages = [newVal, "en-US"]
                                config.save()
                            }
                        )) {
                            Text("简体中文 + 英文").tag("zh-Hans")
                            Text("繁体中文 + 英文").tag("zh-Hant")
                            Text("纯英文 (English)").tag("en-US")
                            Text("日语 + 英文").tag("ja-JP")
                            Text("韩语 + 英文").tag("ko-KR")
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    }
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(title: "文字识别完成后自动复制文本到剪贴板", isOn: $config.autoCopyOCRText)
                }
            }
            
            settingsCard(title: "智能翻译引擎") {
                VStack(spacing: 14) {
                    HStack {
                        Text("服务提供商")
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.translationProvider) {
                            Text("Apple 官方翻译 (系统原生)").tag("apple")
                            Text("DeepL 官方 API (高精度)").tag("deepl")
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)
                        .onChange(of: config.translationProvider) { _ in
                            config.save()
                        }
                    }
                    
                    if config.translationProvider == "apple" {
                        Divider().opacity(0.3)
                        
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                                .padding(.top, 1)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apple 离线翻译语言包")
                                    .font(.system(size: 13, weight: .medium))
                                Text("Apple 原生翻译依赖系统下载的离线语言包。若尚未下载，SnipSnap 将自动切换至在线多通道备用；您亦可前往 macOS 系统设置一键下载所有语言包。")
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Button("打开「系统设置 > 语言与地区」管理语言包 ↗") {
                                    InPlaceTranslateViewModel.openSystemTranslationSettings()
                                }
                                .buttonStyle(.link)
                                .font(.system(size: 11.5))
                                .padding(.top, 2)
                            }
                            Spacer()
                        }
                    }
                    
                    if config.translationProvider == "deepl" {
                        Divider().opacity(0.3)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("DeepL API Key")
                                    .font(.system(size: 13, weight: .regular))
                                Spacer()
                                SecureField("在此输入 DeepL 认证密钥", text: $config.deeplAuthKey)
                                    .textFieldStyle(.roundedBorder)
                                    .controlSize(.small)
                                    .frame(width: 200)
                                    .onChange(of: config.deeplAuthKey) { newKey in
                                        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
                                        if trimmed.hasSuffix(":fx") {
                                            config.deeplIsFreeAPI = true
                                        } else if trimmed.count >= 20 && !trimmed.hasSuffix(":fx") {
                                            config.deeplIsFreeAPI = false
                                        }
                                        config.save()
                                        deeplTestStatus = nil
                                    }
                            }
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("免费版 API 终端 (api-free.deepl.com)")
                                        .font(.system(size: 13, weight: .regular))
                                    Text("DeepL 免费版 Key 通常以 :fx 结尾，系统已支持自动适配")
                                        .font(.system(size: 10.5))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Toggle("", isOn: $config.deeplIsFreeAPI)
                                    .toggleStyle(.switch)
                                    .controlSize(.small)
                                    .onChange(of: config.deeplIsFreeAPI) { _ in
                                        config.save()
                                        deeplTestStatus = nil
                                    }
                            }
                            
                            HStack(spacing: 10) {
                                Button(action: testDeepLConnection) {
                                    HStack(spacing: 5) {
                                        if isTestingDeepL {
                                            ProgressView()
                                                .scaleEffect(0.5)
                                                .frame(width: 10, height: 10)
                                        } else {
                                            Image(systemName: "network")
                                        }
                                        Text(isTestingDeepL ? "正在测试..." : "测试连接")
                                    }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                .disabled(isTestingDeepL || config.deeplAuthKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                
                                if let status = deeplTestStatus {
                                    HStack(spacing: 4) {
                                        Image(systemName: deeplTestSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                            .foregroundColor(deeplTestSuccess ? .green : .orange)
                                            .font(.system(size: 11))
                                        Text(status)
                                            .font(.system(size: 11))
                                            .foregroundColor(deeplTestSuccess ? .green : .orange)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.top, 2)
                        }
                    }
                    
                    Divider().opacity(0.3)
                    
                    HStack {
                        Text("默认目标语言")
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.targetTranslateLanguage) {
                            Text("中文 (简体)").tag("zh-Hans")
                            Text("英语 (English)").tag("en-US")
                            Text("日语 (日本語)").tag("ja-JP")
                            Text("韩语 (한국어)").tag("ko-KR")
                            Text("法语 (Français)").tag("fr-FR")
                            Text("德语 (Deutsch)").tag("de-DE")
                            Text("西班牙语 (Español)").tag("es-ES")
                            Text("俄语 (Русский)").tag("ru-RU")
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)
                        .onChange(of: config.targetTranslateLanguage) { _ in
                            config.save()
                        }
                    }
                    
                    Divider().opacity(0.3)
                    
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.accentColor)
                            .font(.system(size: 12))
                        Text("智能语言匹配：截图中检测到中文将自动翻译为英文；检测到外文将自动翻译为中文。卡片内支持一键双向互换。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
    
    private func testDeepLConnection() {
        guard !config.deeplAuthKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isTestingDeepL = true
        deeplTestStatus = nil
        
        TranslationService.shared.testDeepLConnection(
            authKey: config.deeplAuthKey,
            isFree: config.deeplIsFreeAPI
        ) { result in
            DispatchQueue.main.async {
                self.isTestingDeepL = false
                switch result {
                case .success(let msg):
                    self.deeplTestSuccess = true
                    self.deeplTestStatus = msg
                case .failure(let err):
                    self.deeplTestSuccess = false
                    self.deeplTestStatus = "连接失败: \(err.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Helpers & Components
    
    private func settingsCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.35), lineWidth: 0.5)
            )
        }
    }
    
    private func toggleRow(title: String, isOn: Binding<Bool>, onToggled: (() -> Void)? = nil) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 13, weight: .regular))
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .onChange(of: isOn.wrappedValue) { _ in
                    config.save()
                    onToggled?()
                }
        }
    }
    
    private func chooseDefaultDirectory() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "选择"
        openPanel.title = "选择默认截图存储文件夹"
        
        openPanel.begin { response in
            if response == .OK, let url = openPanel.url {
                config.defaultSavePath = url.path
                config.save()
            }
        }
    }
    
    private func saveAndReloadHotkeys() {
        config.save()
        GlobalHotkeyManager.shared.reloadFromConfig()
    }
    
    private func updateLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    if SMAppService.mainApp.status != .enabled {
                        try SMAppService.mainApp.register()
                    }
                } else {
                    if SMAppService.mainApp.status == .enabled {
                        try SMAppService.mainApp.unregister()
                    }
                }
            } catch {
                print("SMAppService failed: \(error)")
            }
        }
    }
}

// MARK: - Visual Effect Helpers

struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

