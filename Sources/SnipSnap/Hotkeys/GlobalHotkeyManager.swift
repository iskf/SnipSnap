import Cocoa
import Carbon
import ApplicationServices

public class GlobalHotkeyManager {
    public static let shared = GlobalHotkeyManager()
    
    public var onScreenshot: (() -> Void)?
    public var onPinClipboard: (() -> Void)?
    public var onScrollCapture: (() -> Void)?
    public var onSelectionTranslate: (() -> Void)?
    public var onQuickOCR: (() -> Void)?
    public var onToggleAllPins: (() -> Void)?
    public var onInputTranslate: (() -> Void)?
    
    // Carbon State
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var hotKeyHandlers: [UInt32: () -> Void] = [:]
    private var nextHotKeyId: UInt32 = 1
    
    // CGEventTap State (Highest Priority Hardware Interceptor)
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    
    // Registered shortcuts description for CGEventTap matching
    public struct RegisteredShortcut {
        public let action: String // "screenshot", "pin", "scrollCapture", "translate", "togglePins"
        public let keyCode: UInt32
        public let modifiers: UInt32
        public let handler: () -> Void
    }
    private var registeredShortcuts: [RegisteredShortcut] = []
    
    // Debounce to ensure seamless deduplication between CGEventTap and Carbon fallback
    private var lastTriggerTimes: [String: TimeInterval] = [:]
    
    // MARK: - Accessibility Helpers
    
    public static var isAccessibilityGranted: Bool {
        return AXIsProcessTrusted()
    }
    
    public static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    
    public static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public static func openKeyboardSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private init() {
        installCarbonEventHandler()
    }
    
    public func registerDefaultHotkeys() {
        reloadFromConfig()
    }
    
    public func checkAndReactivateEventTap() {
        if Self.isAccessibilityGranted && eventTap == nil {
            setupEventTap()
        }
    }
    
    public func reloadFromConfig() {
        unregisterAll()
        let config = AppConfig.load()
        
        // 1. Screenshot (F1)
        registerAction("screenshot", shortcutString: config.screenshotShortcut) { [weak self] in
            self?.onScreenshot?()
        }
        
        // 2. Pin from Clipboard (F2)
        registerAction("pin", shortcutString: config.pinShortcut) { [weak self] in
            self?.onPinClipboard?()
        }
        
        // 3. Scrolling Capture (F3)
        registerAction("scrollCapture", shortcutString: config.scrollCaptureShortcut) { [weak self] in
            self?.onScrollCapture?()
        }
        
        // 4. Selection Translate (F4)
        registerAction("translate", shortcutString: config.translateShortcut) { [weak self] in
            if let translate = self?.onSelectionTranslate {
                translate()
            } else {
                self?.onQuickOCR?()
            }
        }
        
        // 5. Toggle All Pins (F5)
        registerAction("togglePins", shortcutString: config.togglePinsShortcut) { [weak self] in
            self?.onToggleAllPins?()
        }
        
        // 6. In-Place Input Translate (⇧F4)
        registerAction("inputTranslate", shortcutString: config.inputTranslateShortcut) { [weak self] in
            self?.onInputTranslate?()
        }
        
        // Setup hardware level CGEventTap
        setupEventTap()
    }
    
    private func registerAction(_ action: String, shortcutString: String, handler: @escaping () -> Void) {
        guard let parsed = parseShortcutString(shortcutString) else { return }
        
        // Add to CGEventTap list
        registeredShortcuts.append(RegisteredShortcut(
            action: action,
            keyCode: parsed.keyCode,
            modifiers: parsed.modifiers,
            handler: handler
        ))
        
        // Add to Carbon engine
        registerCarbonHotKey(keyCode: parsed.keyCode, modifiers: parsed.modifiers, actionName: action, handler: handler)
    }
    
    // MARK: - Engine 1: CGEventTap (Hardware Level Highest Priority Interceptor)
    
    private func setupEventTap() {
        stopEventTap()
        
        guard Self.isAccessibilityGranted else {
            return
        }
        
        // KeyDown (10), KeyUp (11), NSSystemDefined (14)
        let mask = (1 << CGEventType.keyDown.rawValue) |
                   (1 << CGEventType.keyUp.rawValue) |
                   (1 << 14)
        
        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else {
                return Unmanaged.passUnretained(event)
            }
            let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            return manager.handleCGEvent(proxy: proxy, type: type, event: event)
        }
        
        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: selfPointer
        ) else {
            print("CGEventTap creation failed or not trusted")
            return
        }
        
        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    
    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            eventTap = nil
            runLoopSource = nil
        }
    }
    
    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Self-healing: if disabled by system timeout, automatically re-enable
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        
        // Case 1: Physical Media Keys (NSSystemDefined event subtype 8)
        // MacBook top-row keys pressed without fn: F1=Brightness Down (2), F2=Brightness Up (3), F3=Mission Control/Launchpad (30/14)
        if type.rawValue == 14 {
            if let nsEvent = NSEvent(cgEvent: event), nsEvent.type == .systemDefined, nsEvent.subtype.rawValue == 8 {
                let data1 = nsEvent.data1
                let keyCode = (data1 & 0xFFFF0000) >> 16
                let keyFlags = (data1 & 0x0000FFFF)
                let keyState = (keyFlags & 0xFF00) >> 8
                let isKeyDown = (keyState == 0xA)
                
                var matchedAction: String? = nil
                if keyCode == 2 { // Physical F1 (Brightness Down)
                    matchedAction = "screenshot"
                } else if keyCode == 3 { // Physical F2 (Brightness Up)
                    matchedAction = "pin"
                } else if keyCode == 30 || keyCode == 14 { // Physical F3 (Launchpad / Mission Control)
                    matchedAction = "scrollCapture"
                } else if keyCode == 31 || keyCode == 16 { // Physical F4 (Spotlight / App)
                    matchedAction = "translate"
                }
                
                if let action = matchedAction {
                    let config = AppConfig.load()
                    let isConfigured: Bool
                    switch action {
                    case "screenshot": isConfigured = (config.screenshotShortcut.uppercased() == "F1")
                    case "pin": isConfigured = (config.pinShortcut.uppercased() == "F2")
                    case "scrollCapture": isConfigured = (config.scrollCaptureShortcut.uppercased() == "F3")
                    case "translate": isConfigured = (config.translateShortcut.uppercased() == "F4")
                    default: isConfigured = false
                    }
                    
                    if isConfigured {
                        if isKeyDown {
                            triggerAction(action)
                        }
                        // Swallow event completely: prevents brightness adjustment or Mission Control
                        return nil
                    }
                }
            }
            return Unmanaged.passUnretained(event)
        }
        
        // Case 2: Standard KeyDown / KeyUp events
        if type == .keyDown || type == .keyUp {
            let keyCode = UInt32(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            
            var modifiers: UInt32 = 0
            if flags.contains(.maskControl) { modifiers |= UInt32(controlKey) }
            if flags.contains(.maskAlternate) { modifiers |= UInt32(optionKey) }
            if flags.contains(.maskShift) { modifiers |= UInt32(shiftKey) }
            if flags.contains(.maskCommand) { modifiers |= UInt32(cmdKey) }
            
            for sc in registeredShortcuts {
                if sc.keyCode == keyCode && sc.modifiers == modifiers {
                    if type == .keyDown {
                        triggerAction(sc.action, customHandler: sc.handler)
                    }
                    // Swallow event with highest priority
                    return nil
                }
            }
        }
        
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - Engine 2: Carbon Event Dispatcher (Global System Target)
    
    private func registerCarbonHotKey(keyCode: UInt32, modifiers: UInt32, actionName: String, handler: @escaping () -> Void) {
        let hotKeyIdNumber = nextHotKeyId
        nextHotKeyId += 1
        
        let hotKeyID = EventHotKeyID(signature: OSType(0x534E4950), id: hotKeyIdNumber) // 'SNIP'
        var hotKeyRef: EventHotKeyRef?
        
        // Use GetEventDispatcherTarget() instead of GetApplicationEventTarget() for system-wide dispatch
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status == noErr, let ref = hotKeyRef {
            hotKeyRefs.append(ref)
            hotKeyHandlers[hotKeyIdNumber] = { [weak self] in
                self?.triggerAction(actionName, customHandler: handler)
            }
        }
    }
    
    private func installCarbonEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { (_, event, _) -> OSStatus in
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                if status == noErr {
                    if let handler = GlobalHotkeyManager.shared.hotKeyHandlers[hotKeyID.id] {
                        handler()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )
    }
    
    // MARK: - Action Execution & Debounce
    
    private func triggerAction(_ action: String, customHandler: (() -> Void)? = nil) {
        let now = ProcessInfo.processInfo.systemUptime
        if let last = lastTriggerTimes[action], (now - last) < 0.35 {
            return // Debounce within 350ms to deduplicate tap and carbon
        }
        lastTriggerTimes[action] = now
        
        DispatchQueue.main.async { [weak self] in
            if let custom = customHandler {
                custom()
                return
            }
            switch action {
            case "screenshot":
                self?.onScreenshot?()
            case "pin":
                self?.onPinClipboard?()
            case "scrollCapture":
                self?.onScrollCapture?()
            case "translate":
                if let translate = self?.onSelectionTranslate {
                    translate()
                } else {
                    self?.onQuickOCR?()
                }
            case "togglePins":
                self?.onToggleAllPins?()
            case "inputTranslate":
                self?.onInputTranslate?()
            default:
                break
            }
        }
    }
    
    public func unregisterAll() {
        stopEventTap()
        registeredShortcuts.removeAll()
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        hotKeyHandlers.removeAll()
    }
    
    // MARK: - Shortcut Parsing
    
    private func parseShortcutString(_ str: String) -> (keyCode: UInt32, modifiers: UInt32)? {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        var modifiers: UInt32 = 0
        if trimmed.contains("⌃") { modifiers |= UInt32(controlKey) }
        if trimmed.contains("⌥") { modifiers |= UInt32(optionKey) }
        if trimmed.contains("⇧") { modifiers |= UInt32(shiftKey) }
        if trimmed.contains("⌘") { modifiers |= UInt32(cmdKey) }
        
        let keyPart = trimmed
            .replacingOccurrences(of: "⌃", with: "")
            .replacingOccurrences(of: "⌥", with: "")
            .replacingOccurrences(of: "⇧", with: "")
            .replacingOccurrences(of: "⌘", with: "")
            .uppercased()
        
        let keyCode: UInt32
        switch keyPart {
        case "A": keyCode = UInt32(kVK_ANSI_A)
        case "B": keyCode = UInt32(kVK_ANSI_B)
        case "C": keyCode = UInt32(kVK_ANSI_C)
        case "D": keyCode = UInt32(kVK_ANSI_D)
        case "E": keyCode = UInt32(kVK_ANSI_E)
        case "F": keyCode = UInt32(kVK_ANSI_F)
        case "G": keyCode = UInt32(kVK_ANSI_G)
        case "H": keyCode = UInt32(kVK_ANSI_H)
        case "I": keyCode = UInt32(kVK_ANSI_I)
        case "J": keyCode = UInt32(kVK_ANSI_J)
        case "K": keyCode = UInt32(kVK_ANSI_K)
        case "L": keyCode = UInt32(kVK_ANSI_L)
        case "M": keyCode = UInt32(kVK_ANSI_M)
        case "N": keyCode = UInt32(kVK_ANSI_N)
        case "O": keyCode = UInt32(kVK_ANSI_O)
        case "P": keyCode = UInt32(kVK_ANSI_P)
        case "Q": keyCode = UInt32(kVK_ANSI_Q)
        case "R": keyCode = UInt32(kVK_ANSI_R)
        case "S": keyCode = UInt32(kVK_ANSI_S)
        case "T": keyCode = UInt32(kVK_ANSI_T)
        case "U": keyCode = UInt32(kVK_ANSI_U)
        case "V": keyCode = UInt32(kVK_ANSI_V)
        case "W": keyCode = UInt32(kVK_ANSI_W)
        case "X": keyCode = UInt32(kVK_ANSI_X)
        case "Y": keyCode = UInt32(kVK_ANSI_Y)
        case "Z": keyCode = UInt32(kVK_ANSI_Z)
        case "0": keyCode = UInt32(kVK_ANSI_0)
        case "1": keyCode = UInt32(kVK_ANSI_1)
        case "2": keyCode = UInt32(kVK_ANSI_2)
        case "3": keyCode = UInt32(kVK_ANSI_3)
        case "4": keyCode = UInt32(kVK_ANSI_4)
        case "5": keyCode = UInt32(kVK_ANSI_5)
        case "6": keyCode = UInt32(kVK_ANSI_6)
        case "7": keyCode = UInt32(kVK_ANSI_7)
        case "8": keyCode = UInt32(kVK_ANSI_8)
        case "9": keyCode = UInt32(kVK_ANSI_9)
        case "F1": keyCode = UInt32(kVK_F1)
        case "F2": keyCode = UInt32(kVK_F2)
        case "F3": keyCode = UInt32(kVK_F3)
        case "F4": keyCode = UInt32(kVK_F4)
        case "F5": keyCode = UInt32(kVK_F5)
        case "F6": keyCode = UInt32(kVK_F6)
        case "F7": keyCode = UInt32(kVK_F7)
        case "F8": keyCode = UInt32(kVK_F8)
        case "F9": keyCode = UInt32(kVK_F9)
        case "F10": keyCode = UInt32(kVK_F10)
        case "F11": keyCode = UInt32(kVK_F11)
        case "F12": keyCode = UInt32(kVK_F12)
        case "SPACE": keyCode = UInt32(kVK_Space)
        default: return nil
        }
        
        return (keyCode, modifiers)
    }
}
