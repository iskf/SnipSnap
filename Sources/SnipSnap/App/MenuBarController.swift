import Cocoa

public class MenuBarController: NSObject, NSMenuDelegate {
    public static let shared = MenuBarController()
    
    private var statusItem: NSStatusItem!
    
    private var snapItem: NSMenuItem?
    private var pinItem: NSMenuItem?
    private var ocrItem: NSMenuItem?
    private var togglePinsItem: NSMenuItem?
    private var unlockPinsItem: NSMenuItem?
    private var closePinsItem: NSMenuItem?
    
    private override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(languageDidChange), name: I18n.languageDidChangeNotification, object: nil)
    }
    
    @objc private func languageDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.rebuildMenu()
        }
    }
    
    public func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold)
            if let image = NSImage(systemSymbolName: "viewfinder.rectangular", accessibilityDescription: "SnipSnap")?.withSymbolConfiguration(config) {
                image.isTemplate = true
                button.image = image
            }
        }
        rebuildMenu()
    }
    
    public func rebuildMenu() {
        if let button = statusItem?.button {
            button.toolTip = L10n("menu.tooltip")
        }
        
        let menu = NSMenu()
        menu.delegate = self
        
        // 1. Core Actions
        let snap = makeMenuItem(title: L10n("menu.screenshot"), icon: "camera.viewfinder", action: #selector(actionScreenshot))
        self.snapItem = snap
        menu.addItem(snap)
        
        let pin = makeMenuItem(title: L10n("menu.pin_clipboard"), icon: "pin", action: #selector(actionPinClipboard))
        self.pinItem = pin
        menu.addItem(pin)
        
        let translate = makeMenuItem(title: L10n("menu.selection_translate"), icon: "translate", action: #selector(actionSelectionTranslate))
        self.ocrItem = translate
        menu.addItem(translate)
        
        menu.addItem(NSMenuItem.separator())
        
        // 3. Pin Window Management (Dynamic)
        let togglePins = makeMenuItem(title: L10n("menu.hide_all_pins"), icon: "eye.slash", action: #selector(actionTogglePins))
        self.togglePinsItem = togglePins
        menu.addItem(togglePins)
        
        let unlockPins = makeMenuItem(title: L10n("menu.unlock_all_pins"), icon: "lock.open", action: #selector(actionUnlockAllPins))
        self.unlockPinsItem = unlockPins
        menu.addItem(unlockPins)
        
        let closePins = makeMenuItem(title: L10n("menu.close_all_pins"), icon: "xmark.circle", action: #selector(actionCloseAllPins))
        self.closePinsItem = closePins
        menu.addItem(closePins)
        
        menu.addItem(NSMenuItem.separator())
        
        // 4. Preferences & Quit
        let prefItem = makeMenuItem(title: L10n("menu.preferences"), icon: "gearshape", action: #selector(actionPreferences), keyEquivalent: ",", modifiers: [.command])
        menu.addItem(prefItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = makeMenuItem(title: L10n("menu.quit"), icon: "power", action: #selector(actionQuit), keyEquivalent: "q", modifiers: [.command])
        menu.addItem(quitItem)
        
        statusItem.menu = menu
        updateDynamicMenuItems()
    }
    
    // MARK: - NSMenuDelegate (Dynamic State Refresh)
    
    public func menuWillOpen(_ menu: NSMenu) {
        updateDynamicMenuItems()
    }
    
    private func updateDynamicMenuItems() {
        let pinMgr = PinWindowManager.shared
        let pinCount = pinMgr.pinWindows.count
        
        // Dynamic pin controls
        if pinCount > 0 {
            closePinsItem?.title = "\(L10n("menu.close_all_pins")) (\(pinCount))"
            closePinsItem?.isEnabled = true
            
            togglePinsItem?.title = pinMgr.arePinsHidden ? L10n("menu.show_all_pins") : L10n("menu.hide_all_pins")
            setMenuItemIcon(togglePinsItem, symbol: pinMgr.arePinsHidden ? "eye" : "eye.slash")
            togglePinsItem?.isEnabled = true
            
            let hasPassThrough = pinMgr.pinWindows.contains { $0.isMousePassThrough }
            unlockPinsItem?.isEnabled = hasPassThrough
        } else {
            closePinsItem?.title = L10n("menu.close_all_pins")
            closePinsItem?.isEnabled = false
            
            togglePinsItem?.title = L10n("menu.hide_all_pins")
            setMenuItemIcon(togglePinsItem, symbol: "eye.slash")
            togglePinsItem?.isEnabled = false
            
            unlockPinsItem?.isEnabled = false
        }
        
        // Dynamic hotkey bindings from AppConfig
        let config = AppConfig.load()
        if let item = snapItem {
            applyShortcut(to: item, shortcutString: config.screenshotShortcut)
        }
        if let item = pinItem {
            applyShortcut(to: item, shortcutString: config.pinShortcut)
        }
        if let item = ocrItem {
            applyShortcut(to: item, shortcutString: config.translateShortcut)
        }
        if let item = togglePinsItem {
            applyShortcut(to: item, shortcutString: config.togglePinsShortcut)
        }
    }
    
    // MARK: - UI Helpers
    
    private func makeMenuItem(title: String, icon: String, action: Selector?, keyEquivalent: String = "", modifiers: NSEvent.ModifierFlags = []) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        setMenuItemIcon(item, symbol: icon)
        return item
    }
    
    private func setMenuItemIcon(_ item: NSMenuItem?, symbol: String) {
        guard let item = item else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        if let img = NSImage(systemSymbolName: symbol, accessibilityDescription: item.title)?.withSymbolConfiguration(config) {
            img.isTemplate = true
            item.image = img
        }
    }
    
    private func applyShortcut(to item: NSMenuItem, shortcutString: String) {
        var modifiers: NSEvent.ModifierFlags = []
        
        if shortcutString.contains("⌃") { modifiers.insert(.control) }
        if shortcutString.contains("⌥") { modifiers.insert(.option) }
        if shortcutString.contains("⇧") { modifiers.insert(.shift) }
        if shortcutString.contains("⌘") { modifiers.insert(.command) }
        
        let cleanKey = shortcutString
            .replacingOccurrences(of: "⌃", with: "")
            .replacingOccurrences(of: "⌥", with: "")
            .replacingOccurrences(of: "⇧", with: "")
            .replacingOccurrences(of: "⌘", with: "")
            .trimmingCharacters(in: .whitespaces)
        
        let key: String
        switch cleanKey.uppercased() {
        case "F1":
            key = String(UnicodeScalar(NSF1FunctionKey)!)
        case "F2":
            key = String(UnicodeScalar(NSF2FunctionKey)!)
        case "F3":
            key = String(UnicodeScalar(NSF3FunctionKey)!)
        case "F4":
            key = String(UnicodeScalar(NSF4FunctionKey)!)
        case "F5":
            key = String(UnicodeScalar(NSF5FunctionKey)!)
        case "F6":
            key = String(UnicodeScalar(NSF6FunctionKey)!)
        case "F7":
            key = String(UnicodeScalar(NSF7FunctionKey)!)
        case "F8":
            key = String(UnicodeScalar(NSF8FunctionKey)!)
        case "SPACE":
            key = " "
        default:
            key = cleanKey.lowercased()
        }
        
        item.keyEquivalent = key
        item.keyEquivalentModifierMask = modifiers
    }
    
    public func updateIconStyle(isMonochrome: Bool) {
        guard let button = statusItem?.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14.5, weight: .semibold)
        if let image = NSImage(systemSymbolName: "viewfinder.rectangular", accessibilityDescription: "SnipSnap")?.withSymbolConfiguration(config) {
            image.isTemplate = isMonochrome
            button.image = image
        }
    }
    
    // MARK: - Actions
    
    @objc private func actionOpenControl() {
        actionPreferences()
    }
    
    @objc private func actionScreenshot() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            CaptureOverlayWindowController.startCapture(mode: .normal)
        }
    }
    
    @objc private func actionPinClipboard() {
        PinWindowManager.shared.pinFromClipboard()
    }
    
    @objc private func actionSelectionTranslate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            CaptureOverlayWindowController.startCapture(mode: .translate)
        }
    }
    
    @objc private func actionQuickOCR() {
        actionSelectionTranslate()
    }
    
    @objc private func actionTogglePins() {
        PinWindowManager.shared.toggleAllPinsVisibility()
    }
    
    @objc private func actionUnlockAllPins() {
        PinWindowManager.shared.unlockAllPassThroughPins()
    }
    
    @objc private func actionCloseAllPins() {
        PinWindowManager.shared.closeAllPins()
    }
    
    @objc private func actionPreferences() {
        MainControlWindowController.show(tab: .general)
    }
    
    @objc private func actionQuit() {
        NSApp.terminate(nil)
    }
}
