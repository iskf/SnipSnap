import Cocoa
import ApplicationServices
import Carbon

public struct FocusedInputContext {
    public let text: String
    public let screenRect: NSRect
    public let focusedElement: AXUIElement?
    public let isEntireField: Bool
    
    public init(text: String, screenRect: NSRect, focusedElement: AXUIElement?, isEntireField: Bool = false) {
        self.text = text
        self.screenRect = screenRect
        self.focusedElement = focusedElement
        self.isEntireField = isEntireField
    }
}

public final class InputTranslateService: @unchecked Sendable {
    public static let shared = InputTranslateService()
    
    /// Tracks the last frontmost regular application before SnipSnap or its menu was clicked
    public private(set) var lastActiveApp: NSRunningApplication?
    
    public var currentOrLastActiveApp: NSRunningApplication? {
        let myPid = ProcessInfo.processInfo.processIdentifier
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != myPid {
            self.lastActiveApp = front
            return front
        }
        return lastActiveApp
    }
    
    private init() {
        setupActiveAppTracking()
    }
    
    private func setupActiveAppTracking() {
        let myPid = ProcessInfo.processInfo.processIdentifier
        
        // Initial setup
        if let front = NSWorkspace.shared.frontmostApplication,
           front.processIdentifier != myPid {
            self.lastActiveApp = front
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notif in
            if let app = notif.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                if app.processIdentifier != myPid {
                    self?.lastActiveApp = app
                }
            }
        }
    }
    
    // MARK: - Focused Input Detection
    
    public func captureFocusedInputContext() -> FocusedInputContext {
        let targetApp = currentOrLastActiveApp
            ?? NSWorkspace.shared.menuBarOwningApplication
            ?? NSWorkspace.shared.frontmostApplication
        
        // Step 1: Try macOS Accessibility API
        if AXIsProcessTrusted(), let app = targetApp {
            let appElem = AXUIElementCreateApplication(app.processIdentifier)
            // Enable enhanced accessibility on Chromium/Electron apps (Chrome, VSCode, Slack, etc.)
            _ = AXUIElementSetAttributeValue(appElem, "AXManualAccessibility" as CFString, kCFBooleanTrue)
            _ = AXUIElementSetAttributeValue(appElem, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
            
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(appElem, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
               let elem = focusedRef as! AXUIElement? {
                
                var text = ""
                var isEntireField = false
                
                // 1a. Check selected text (supports String & NSAttributedString)
                var selectedRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(elem, kAXSelectedTextAttribute as CFString, &selectedRef) == .success,
                   let selStr = extractString(from: selectedRef)?.trimmingCharacters(in: .whitespacesAndNewlines), !selStr.isEmpty {
                    text = selStr
                    isEntireField = false
                } else {
                    // 1b. Check full value of input element
                    var valueRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(elem, kAXValueAttribute as CFString, &valueRef) == .success,
                       let valStr = extractString(from: valueRef)?.trimmingCharacters(in: .whitespacesAndNewlines), !valStr.isEmpty {
                        text = valStr
                        isEntireField = true
                    }
                }
                
                // Extract bounds
                var screenRect = NSRect.zero
                var posRef: CFTypeRef?
                var sizeRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(elem, kAXPositionAttribute as CFString, &posRef) == .success,
                   AXUIElementCopyAttributeValue(elem, kAXSizeAttribute as CFString, &sizeRef) == .success,
                   let posVal = posRef, let sizeVal = sizeRef {
                    var point = CGPoint.zero
                    var size = CGSize.zero
                    AXValueGetValue(posVal as! AXValue, .cgPoint, &point)
                    AXValueGetValue(sizeVal as! AXValue, .cgSize, &size)
                    
                    if let mainScreen = NSScreen.screens.first {
                        let cocoaY = mainScreen.frame.height - point.y - size.height
                        screenRect = NSRect(x: point.x, y: cocoaY, width: size.width, height: size.height)
                    }
                }
                
                if screenRect.width <= 0 || screenRect.height <= 0 {
                    screenRect = defaultMouseRect()
                }
                
                if !text.isEmpty {
                    return FocusedInputContext(text: text, screenRect: screenRect, focusedElement: elem, isEntireField: isEntireField)
                } else {
                    // Focused element exists but has empty text
                    return FocusedInputContext(text: "", screenRect: screenRect, focusedElement: elem, isEntireField: true)
                }
            }
        }
        
        // Step 2: Try simulated Cmd+C (Captures highlighted selection across apps)
        if let selectedText = captureViaSimulatedCopy() {
            return FocusedInputContext(text: selectedText, screenRect: defaultMouseRect(), focusedElement: nil, isEntireField: false)
        }
        
        // Step 3: Try Cmd+A -> Cmd+C (Captures full content of current focused input box)
        if let inputFieldText = captureViaSimulatedSelectAll() {
            return FocusedInputContext(text: inputFieldText, screenRect: defaultMouseRect(), focusedElement: nil, isEntireField: true)
        }
        
        // Step 4: No active text in input field - return empty context (NEVER return stale clipboard data!)
        return FocusedInputContext(text: "", screenRect: defaultMouseRect(), focusedElement: nil, isEntireField: false)
    }
    
    private func extractString(from cfValue: CFTypeRef?) -> String? {
        guard let val = cfValue else { return nil }
        if let str = val as? String {
            return str
        }
        if let attrStr = val as? NSAttributedString {
            return attrStr.string
        }
        if let nsStr = val as? NSString {
            return nsStr as String
        }
        return nil
    }
    
    // MARK: - Key Dispatchers for Text Extraction
    
    /// Simulates Cmd+C and checks if NSPasteboard changeCount incremented.
    /// If changeCount did NOT increment, returns nil (does NOT use stale clipboard).
    private func captureViaSimulatedCopy() -> String? {
        let pb = NSPasteboard.general
        let initialCount = pb.changeCount
        
        simulateKeyCombo(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
        
        let deadline = ProcessInfo.processInfo.systemUptime + 0.15
        while ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
            if pb.changeCount != initialCount {
                if let str = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    return str
                }
            }
        }
        return nil
    }
    
    /// Simulates Cmd+A -> Cmd+C to read text from an unselected input box, then restores cursor position.
    private func captureViaSimulatedSelectAll() -> String? {
        let pb = NSPasteboard.general
        let initialCount = pb.changeCount
        
        // 1. Select All
        simulateKeyCombo(keyCode: CGKeyCode(kVK_ANSI_A), flags: .maskCommand)
        usleep(45000) // 45ms for target app to process Cmd+A
        
        // 2. Copy
        simulateKeyCombo(keyCode: CGKeyCode(kVK_ANSI_C), flags: .maskCommand)
        
        let deadline = ProcessInfo.processInfo.systemUptime + 0.15
        var capturedText: String? = nil
        while ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.02))
            if pb.changeCount != initialCount {
                if let str = pb.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty {
                    capturedText = str
                    break
                }
            }
        }
        
        // 3. Unselect and place cursor at the end by pressing Right Arrow
        simulateKeyCombo(keyCode: CGKeyCode(kVK_RightArrow), flags: [])
        
        if let text = capturedText {
            // Guard: If text is excessively large (e.g. > 2000 chars), the user probably had a whole webpage selected, not an input box
            if text.count < 2000 {
                return text
            }
        }
        return nil
    }
    
    private func defaultMouseRect() -> NSRect {
        let mouseLoc = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLoc) }) ?? NSScreen.main ?? NSScreen.screens.first!
        let vf = screen.visibleFrame
        
        if mouseLoc.y > vf.maxY - 50 {
            let x = min(max(mouseLoc.x - 240, vf.minX + 20), vf.maxX - 520)
            return NSRect(x: x, y: vf.maxY - 140, width: 490, height: 38)
        }
        return NSRect(x: min(max(mouseLoc.x - 240, vf.minX + 20), vf.maxX - 520), y: max(mouseLoc.y - 20, vf.minY + 20), width: 490, height: 38)
    }
    
    // MARK: - Text Replacement Injection
    
    @discardableResult
    public func replaceInputText(with newText: String, context: FocusedInputContext?) -> Bool {
        guard !newText.isEmpty else { return false }
        
        // 1. Activate target application so it regains keyboard focus
        if let targetApp = currentOrLastActiveApp {
            targetApp.activate(options: .activateIgnoringOtherApps)
        }
        usleep(60000) // 60ms for target window and input focus to stabilize
        
        // 2. Backup current clipboard content
        let pb = NSPasteboard.general
        let oldString = pb.string(forType: .string)
        
        // 3. Write replacement text to pasteboard
        pb.clearContents()
        pb.setString(newText, forType: .string)
        
        // 4. If replacing the entire input field (not a specific user sub-selection), select all first
        if context?.isEntireField == true {
            simulateKeyCombo(keyCode: CGKeyCode(kVK_ANSI_A), flags: .maskCommand)
            usleep(40000) // 40ms to let target app select all text
        }
        
        // 5. Paste the replacement text (Cmd+V)
        simulateKeyCombo(keyCode: CGKeyCode(kVK_ANSI_V), flags: .maskCommand)
        
        // 6. Restore previous clipboard content after paste has settled
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if let prev = oldString {
                let current = NSPasteboard.general.string(forType: .string)
                if current == newText {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(prev, forType: .string)
                }
            }
        }
        
        return true
    }
    
    // MARK: - Simulated Key Event Dispatcher
    
    private func simulateKeyCombo(keyCode: CGKeyCode, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        
        guard let keyDown = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false) else {
            return
        }
        
        keyDown.flags = flags
        keyUp.flags = flags
        
        keyDown.post(tap: .cghidEventTap)
        usleep(20000) // 20ms hold down duration so WindowServer and apps never miss the stroke
        keyUp.post(tap: .cghidEventTap)
    }
}
