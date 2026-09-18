import Cocoa
import SwiftUI
import ServiceManagement

public enum ControlCenterSubTab: String, CaseIterable, Identifiable {
    case general = "通用设置"
    case hotkeys = "快捷键"
    case capture = "截图与标注"
    case recording = "动图录制"
    case pinning = "贴图设置"
    case ocr = "OCR与翻译"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .general: return L10n("pref.tab.general")
        case .hotkeys: return L10n("pref.tab.hotkeys")
        case .capture: return L10n("pref.tab.capture")
        case .recording: return L10n("pref.tab.recording")
        case .pinning: return L10n("pref.tab.pinning")
        case .ocr: return L10n("pref.tab.ocr")
        }
    }
    
    public var icon: String {
        switch self {
        case .general: return "gearshape.fill"
        case .hotkeys: return "keyboard.fill"
        case .capture: return "camera.viewfinder"
        case .recording: return "record.circle.fill"
        case .pinning: return "pin.fill"
        case .ocr: return "character.book.closed.fill"
        }
    }
    
    public var badgeColor: Color {
        switch self {
        case .general: return Color(nsColor: .systemGray)
        case .hotkeys: return Color(nsColor: .systemGreen)
        case .capture: return Color(nsColor: .systemBlue)
        case .recording: return Color(nsColor: .systemRed)
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

public class MainControlWindowController: NSWindowController, NSWindowDelegate {
    public static var shared: MainControlWindowController?
    public var viewModel: MainControlViewModel = MainControlViewModel()
    
    public static func preload() {
        DispatchQueue.main.async {
            guard shared == nil else { return }
            _ = getOrCreateController(tab: .general)
        }
    }
    
    @discardableResult
    private static func getOrCreateController(tab: ControlCenterSubTab) -> MainControlWindowController {
        if let existing = shared {
            existing.viewModel.selectedTab = tab
            existing.window?.title = L10n("pref.title")
            return existing
        }
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 660, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = L10n("pref.title")
        window.minSize = NSSize(width: 600, height: 440)
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        
        let vm = MainControlViewModel(selectedTab: tab)
        let hosting = NSHostingView(rootView: MainControlView(viewModel: vm))
        window.contentView = hosting
        
        let controller = MainControlWindowController(window: window)
        controller.viewModel = vm
        window.delegate = controller
        shared = controller
        return controller
    }
    
    public static func show(tab: ControlCenterSubTab = .general) {
        let controller = getOrCreateController(tab: tab)
        controller.viewModel.selectedTab = tab
        controller.window?.title = L10n("pref.title")
        NSApp.setActivationPolicy(.regular)
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        controller.window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    public func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Unified Control Center View

public struct MainControlView: View {
    @ObservedObject var viewModel: MainControlViewModel
    @ObservedObject private var i18n = I18n.shared
    @State private var config = AppConfig.load()
    @State private var showResetAlert: Bool = false
    @State private var deeplTestStatus: String? = nil
    @State private var isTestingDeepL: Bool = false
    @State private var deeplTestSuccess: Bool = false
    @State private var accessibilityGranted: Bool = GlobalHotkeyManager.isAccessibilityGranted
    @State private var hoveredTab: ControlCenterSubTab? = nil
    
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
        .alert(L10n("pref.general.alert_title"), isPresented: $showResetAlert) {
            Button(L10n("pref.general.cancel"), role: .cancel) { }
            Button(L10n("pref.general.confirm_reset"), role: .destructive) {
                config.resetToDefaults()
                GlobalHotkeyManager.shared.reloadFromConfig()
            }
        } message: {
            Text(L10n("pref.general.alert_msg"))
        }
        .onAppear {
            accessibilityGranted = GlobalHotkeyManager.isAccessibilityGranted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityGranted = GlobalHotkeyManager.isAccessibilityGranted
        }
        .onReceive(NotificationCenter.default.publisher(for: I18n.languageDidChangeNotification)) { _ in
            MainControlWindowController.shared?.window?.title = L10n("pref.title")
        }
    }
    
    // MARK: - Left Sidebar (Native macOS System Settings Compact Style)
    
    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text(L10n("pref.title"))
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
                    let isHovered = hoveredTab == tab && !isSelected
                    
                    Button(action: {
                        // Instant zero-latency tab switch without heavy interpolation
                        viewModel.selectedTab = tab
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
                            
                            Text(tab.title)
                                .font(.system(size: 12, weight: isSelected ? .medium : .regular))
                                .foregroundColor(isSelected ? .white : .primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.06) : Color.clear))
                        )
                    }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        hoveredTab = hovering ? tab : nil
                    }
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
                case .recording:
                    recordingSettingsView
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
            settingsCard(title: L10n("pref.general.lang_card")) {
                HStack {
                    Text(L10n("pref.general.lang_label"))
                        .font(.system(size: 13, weight: .regular))
                    Spacer()
                    Picker("", selection: Binding(
                        get: { i18n.currentLanguage },
                        set: { newLang in
                            i18n.setLanguage(newLang)
                        }
                    )) {
                        ForEach(AppLanguage.allCases) { lang in
                            Text(lang.displayName).tag(lang)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(width: 190)
                }
            }
            
            settingsCard(title: L10n("pref.general.system_card")) {
                VStack(spacing: 12) {
                    toggleRow(title: L10n("pref.general.launch_at_login"), isOn: $config.launchAtLogin) {
                        updateLaunchAtLogin(config.launchAtLogin)
                    }
                    Divider().opacity(0.3)
                    toggleRow(title: L10n("pref.general.monochrome_icon"), isOn: $config.menuBarIconMonochrome) {
                        MenuBarController.shared.updateIconStyle(isMonochrome: config.menuBarIconMonochrome)
                    }
                    Divider().opacity(0.3)
                    toggleRow(title: L10n("pref.general.sound_effect"), isOn: $config.playSoundEffect)
                }
            }
            
            settingsCard(title: L10n("pref.general.storage_card")) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n("pref.general.default_path"))
                                .font(.system(size: 13, weight: .medium))
                            Text(config.defaultSavePath.isEmpty ? L10n("pref.general.desktop") : config.defaultSavePath)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button(L10n("pref.general.change_dir")) {
                            chooseDefaultDirectory()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    
                    Divider().opacity(0.3)
                    
                    HStack {
                        Text(L10n("pref.general.format"))
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.imageSaveFormat) {
                            Text("PNG").tag("PNG")
                            Text("JPEG").tag("JPEG")
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.small)
                        .frame(width: 140)
                        .onChange(of: config.imageSaveFormat) { _ in
                            config.save()
                        }
                    }
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(title: L10n("pref.general.auto_save"), isOn: $config.autoSaveAfterCapture)
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(title: L10n("pref.general.auto_copy"), isOn: $config.autoCopyAfterCapture)
                }
            }
            
            settingsCard(title: L10n("pref.general.reset_card")) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n("pref.general.reset_title"))
                            .font(.system(size: 13, weight: .medium))
                        Text(L10n("pref.general.reset_desc"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(L10n("pref.general.reset_btn")) {
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
            settingsCard(title: L10n("pref.hotkey.intercept_card")) {
                VStack(alignment: .leading, spacing: 8) {
                    if accessibilityGranted {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n("pref.hotkey.intercept_active"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(L10n("pref.hotkey.intercept_active_desc"))
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
                                Text(L10n("pref.hotkey.intercept_unauth"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(L10n("pref.hotkey.intercept_unauth_desc"))
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    Button(L10n("pref.hotkey.goto_accessibility")) {
                                        GlobalHotkeyManager.requestAccessibilityPermission()
                                        GlobalHotkeyManager.openAccessibilitySettings()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    
                                    Button(L10n("pref.hotkey.goto_keyboard")) {
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
            
            settingsCard(title: L10n("pref.hotkey.core_card")) {
                VStack(spacing: 12) {
                    HotkeyRecorderView(
                        title: L10n("pref.hotkey.action_screenshot"),
                        actionId: "screenshot",
                        shortcut: $config.screenshotShortcut,
                        config: config
                    ) { _ in
                        saveAndReloadHotkeys()
                    }
                    
                    Divider().opacity(0.3)
                    
                    HotkeyRecorderView(
                        title: L10n("pref.hotkey.action_translate"),
                        actionId: "translate",
                        shortcut: $config.translateShortcut,
                        config: config
                    ) { _ in
                        saveAndReloadHotkeys()
                    }
                    
                    Divider().opacity(0.3)
                    
                    HotkeyRecorderView(
                        title: L10n("pref.hotkey.action_pin"),
                        actionId: "pin",
                        shortcut: $config.pinShortcut,
                        config: config
                    ) { _ in
                        saveAndReloadHotkeys()
                    }
                    
                    Divider().opacity(0.3)
                    
                    HotkeyRecorderView(
                        title: L10n("pref.hotkey.action_toggle_pins"),
                        actionId: "togglePins",
                        shortcut: $config.togglePinsShortcut,
                        config: config
                    ) { _ in
                        saveAndReloadHotkeys()
                    }
                }
            }
            
            settingsCard(title: L10n("pref.hotkey.tips_card")) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text(L10n("pref.hotkey.tip1"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "escape")
                            .font(.system(size: 11))
                            .foregroundColor(.accentColor)
                        Text(L10n("pref.hotkey.tip2"))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text(L10n("pref.hotkey.tip3"))
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
            settingsCard(title: L10n("pref.capture.loupe_card")) {
                VStack(spacing: 12) {
                    toggleRow(title: L10n("pref.capture.show_loupe"), isOn: $config.showLoupe)
                    
                    Divider().opacity(0.3)
                    
                    HStack {
                        Text(L10n("pref.capture.color_format"))
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
            
            settingsCard(title: L10n("pref.capture.preset_card")) {
                VStack(spacing: 12) {
                    HStack {
                        Text(L10n("pref.capture.stroke_color"))
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
                        Text(L10n("pref.capture.stroke_width"))
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.defaultStrokeWidth) {
                            Text(L10n("pref.capture.stroke_thin")).tag(CGFloat(2.0))
                            Text(L10n("pref.capture.stroke_medium")).tag(CGFloat(4.0))
                            Text(L10n("pref.capture.stroke_thick")).tag(CGFloat(6.0))
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
            
            settingsCard(title: L10n("pref.capture.quick_action")) {
                toggleRow(title: L10n("pref.capture.auto_pin"), isOn: $config.autoPinAfterCapture)
            }
        }
    }
    
    // MARK: - 4. Recording Settings View
    
    private var recordingSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: L10n("pref.recording.quality_group")) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n("pref.recording.fps"))
                                .font(.system(size: 13, weight: .medium))
                            Text(L10n("pref.recording.fps_desc"))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $config.gifFrameRate) {
                            Text("10 FPS").tag(10)
                            Text("15 FPS (\(L10n("common.recommended")))").tag(15)
                            Text("20 FPS").tag(20)
                            Text("30 FPS").tag(30)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 170)
                        .onChange(of: config.gifFrameRate) { _ in config.save() }
                    }
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(
                        title: L10n("pref.recording.downsample"),
                        subtitle: L10n("pref.recording.downsample_desc"),
                        isOn: $config.gifDownsample
                    )
                }
            }
            
            settingsCard(title: L10n("pref.recording.control_group")) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n("pref.recording.duration"))
                                .font(.system(size: 13, weight: .medium))
                        }
                        Spacer()
                        Picker("", selection: $config.gifMaxDuration) {
                            Text("15s").tag(15)
                            Text("30s (\(L10n("common.recommended")))").tag(30)
                            Text("60s").tag(60)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 170)
                        .onChange(of: config.gifMaxDuration) { _ in config.save() }
                    }
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(
                        title: L10n("pref.recording.cursor"),
                        subtitle: L10n("pref.recording.cursor_desc"),
                        isOn: $config.gifCaptureCursor
                    )
                }
            }
            
            settingsCard(title: L10n("pref.recording.output_group")) {
                VStack(spacing: 12) {
                    toggleRow(
                        title: L10n("pref.recording.autocopy"),
                        isOn: $config.gifAutoCopy
                    )
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(
                        title: L10n("pref.recording.autosave"),
                        isOn: $config.gifAutoSave
                    )
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(
                        title: L10n("pref.recording.playsound"),
                        isOn: $config.gifPlaySound
                    )
                }
            }
        }
    }
    
    // MARK: - 5. Pinning Settings View
    
    private var pinningSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: L10n("pref.pin.appearance_card")) {
                VStack(spacing: 12) {
                    toggleRow(title: L10n("pref.pin.border"), isOn: $config.pinWindowBorder)
                    Divider().opacity(0.3)
                    toggleRow(title: L10n("pref.pin.shadow"), isOn: $config.pinWindowShadow)
                    Divider().opacity(0.3)
                    toggleRow(title: L10n("pref.pin.corners"), isOn: $config.pinWindowRoundedCorners)
                }
            }
            
            settingsCard(title: L10n("pref.pin.controls_card")) {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n("pref.pin.alpha"))
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
                        Text(L10n("pref.pin.double_click"))
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.doubleClickPinAction) {
                            Text(L10n("pref.pin.action_zoom")).tag("zoom")
                            Text(L10n("pref.pin.action_close")).tag("close")
                            Text(L10n("pref.pin.action_annotate")).tag("annotate")
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
            
            settingsCard(title: L10n("pref.pin.guide_card")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n("pref.pin.guide1"))
                    Text(L10n("pref.pin.guide2"))
                    Text(L10n("pref.pin.guide3"))
                    Text(L10n("pref.pin.guide4"))
                    Text(L10n("pref.pin.guide5"))
                    Text(L10n("pref.pin.guide6"))
                }
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 5. OCR & Translation Settings View
    
    private var ocrSettingsView: some View {
        VStack(spacing: 16) {
            settingsCard(title: L10n("pref.ocr.vision_card")) {
                VStack(spacing: 12) {
                    HStack {
                        Text(L10n("pref.ocr.preferred_lang"))
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: Binding(
                            get: { config.ocrLanguages.first ?? "zh-Hans" },
                            set: { newVal in
                                config.ocrLanguages = [newVal, "en-US"]
                                config.save()
                            }
                        )) {
                            Text(L10n("pref.ocr.lang_zh_hans")).tag("zh-Hans")
                            Text(L10n("pref.ocr.lang_zh_hant")).tag("zh-Hant")
                            Text(L10n("pref.ocr.lang_en_us")).tag("en-US")
                            Text(L10n("pref.ocr.lang_ja_jp")).tag("ja-JP")
                            Text(L10n("pref.ocr.lang_ko_kr")).tag("ko-KR")
                        }
                        .pickerStyle(.menu)
                        .controlSize(.small)
                    }
                    
                    Divider().opacity(0.3)
                    
                    toggleRow(title: L10n("pref.ocr.auto_copy"), isOn: $config.autoCopyOCRText)
                }
            }
            
            settingsCard(title: L10n("pref.ocr.engine_card")) {
                VStack(spacing: 14) {
                    HStack {
                        Text(L10n("pref.ocr.provider"))
                            .font(.system(size: 13, weight: .regular))
                        Spacer()
                        Picker("", selection: $config.translationProvider) {
                            Text(L10n("pref.ocr.provider_apple")).tag("apple")
                            Text(L10n("pref.ocr.provider_deepl")).tag("deepl")
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
                                Text(L10n("pref.ocr.apple_offline_title"))
                                    .font(.system(size: 13, weight: .medium))
                                Text(L10n("pref.ocr.apple_offline_desc"))
                                    .font(.system(size: 11.5))
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Button(L10n("pref.ocr.open_system_lang")) {
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
                                Text(L10n("pref.ocr.deepl_key"))
                                    .font(.system(size: 13, weight: .regular))
                                Spacer()
                                SecureField(L10n("pref.ocr.deepl_placeholder"), text: $config.deeplAuthKey)
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
                                    Text(L10n("pref.ocr.deepl_free_endpoint"))
                                        .font(.system(size: 13, weight: .regular))
                                    Text(L10n("pref.ocr.deepl_free_desc"))
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
                                        Text(isTestingDeepL ? L10n("pref.ocr.deepl_testing") : L10n("pref.ocr.deepl_test_btn"))
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
                        Text(L10n("pref.ocr.target_lang"))
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
                        Text(L10n("pref.ocr.smart_tip"))
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
    
    private func toggleRow(title: String, subtitle: String? = nil, isOn: Binding<Bool>, onToggled: (() -> Void)? = nil) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .regular))
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
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
        openPanel.prompt = L10n("pref.general.choose_panel_btn")
        openPanel.title = L10n("pref.general.choose_panel_title")
        
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

