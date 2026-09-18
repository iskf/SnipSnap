import Cocoa
import CoreGraphics

public class AppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Run purely as menu bar accessory app without appearing in Dock
        NSApp.setActivationPolicy(.accessory)
        
        // Set application icon explicitly (SwiftPM bundles may not auto-bind Info.plist icon)
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let iconImage = NSImage(contentsOfFile: iconPath) {
            NSApp.applicationIconImage = iconImage
        }
        
        // Request Screen Capture permission if needed
        if #available(macOS 10.15, *) {
            if !CGPreflightScreenCaptureAccess() {
                CGRequestScreenCaptureAccess()
            }
        }
        
        // Setup Menu Bar Item
        MenuBarController.shared.setupMenuBar()
        
        // Register Global Hotkeys
        setupGlobalHotkeys()
        
        // Restore persistent pinned windows from previous session
        PinWindowManager.shared.restoreSavedPins()
        
        // Preload Preferences window hierarchy in background for zero-latency opening
        MainControlWindowController.preload()
        
        // Show visible main control center window on launch
        DispatchQueue.main.async {
            if CommandLine.arguments.contains("--hotkeys") {
                MainControlWindowController.show(tab: .hotkeys)
            } else if CommandLine.arguments.contains("--capture") {
                CaptureOverlayWindowController.startCapture(mode: .normal)
            } else if CommandLine.arguments.contains("--pinning") {
                MainControlWindowController.show(tab: .pinning)
            } else if CommandLine.arguments.contains("--ocr") {
                MainControlWindowController.show(tab: .ocr)
            } else if let pinIdx = CommandLine.arguments.firstIndex(of: "--pin-file"), pinIdx + 1 < CommandLine.arguments.count {
                let path = CommandLine.arguments[pinIdx + 1]
                if let img = NSImage(contentsOfFile: path) {
                    _ = PinWindowManager.shared.createPin(from: img)
                }
            } else if CommandLine.arguments.contains("--test-translate-japanese") {
                let img = NSImage(size: NSSize(width: 380, height: 120))
                img.lockFocus()
                NSColor.white.setFill()
                NSRect(x: 0, y: 0, width: 380, height: 120).fill()
                let str = "Google 検索は次の言語でもご利用いただけます: English"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.black
                ]
                str.draw(in: NSRect(x: 16, y: 40, width: 350, height: 40), withAttributes: attrs)
                img.unlockFocus()
                TranslateFloatingWindowController.show(image: img, nearScreenRect: NSRect(x: 500, y: 400, width: 380, height: 120))
            } else if CommandLine.arguments.contains("--test-translate-ambiguous") {
                let img = NSImage(size: NSSize(width: 340, height: 180))
                img.lockFocus()
                NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0).setFill()
                NSRect(x: 0, y: 0, width: 340, height: 180).fill()
                let str = "status_code: 404 & error_code: 0x800"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 15),
                    .foregroundColor: NSColor.white
                ]
                str.draw(in: NSRect(x: 20, y: 40, width: 300, height: 100), withAttributes: attrs)
                img.unlockFocus()
                TranslateFloatingWindowController.show(image: img, nearScreenRect: NSRect(x: 500, y: 400, width: 340, height: 180))
            } else if CommandLine.arguments.contains("--test-translate-empty") {
                let img = NSImage(size: NSSize(width: 340, height: 180))
                img.lockFocus()
                NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0).setFill()
                NSRect(x: 0, y: 0, width: 340, height: 180).fill()
                img.unlockFocus()
                TranslateFloatingWindowController.show(image: img, nearScreenRect: NSRect(x: 500, y: 400, width: 340, height: 180))
            } else if CommandLine.arguments.contains("--test-translate") {
                let img = NSImage(size: NSSize(width: 340, height: 180))
                img.lockFocus()
                NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.18, alpha: 1.0).setFill()
                NSRect(x: 0, y: 0, width: 340, height: 180).fill()
                let str = "Design aesthetics and typography. Fast and responsive macOS native translation."
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 15),
                    .foregroundColor: NSColor.white
                ]
                str.draw(in: NSRect(x: 20, y: 40, width: 300, height: 100), withAttributes: attrs)
                img.unlockFocus()
                TranslateFloatingWindowController.show(image: img, nearScreenRect: NSRect(x: 500, y: 400, width: 340, height: 180))
            } else {
                MainControlWindowController.show(tab: .general)
            }
        }
        
        print("SnipSnap launched successfully!")
    }
    
    public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            MainControlWindowController.show()
        }
        return true
    }
    
    public func applicationDidBecomeActive(_ notification: Notification) {
        GlobalHotkeyManager.shared.checkAndReactivateEventTap()
    }
    
    private func setupGlobalHotkeys() {
        let hotkeys = GlobalHotkeyManager.shared
        
        hotkeys.onScreenshot = {
            DispatchQueue.main.async {
                CaptureOverlayWindowController.startCapture(mode: .normal)
            }
        }
        
        hotkeys.onSelectionTranslate = {
            DispatchQueue.main.async {
                if let overlayController = CaptureOverlayWindowController.shared {
                    overlayController.translateCurrentSelection()
                } else {
                    CaptureOverlayWindowController.startCapture(mode: .translate)
                }
            }
        }
        
        hotkeys.onQuickOCR = {
            DispatchQueue.main.async {
                if let overlayController = CaptureOverlayWindowController.shared {
                    overlayController.translateCurrentSelection()
                } else {
                    CaptureOverlayWindowController.startCapture(mode: .translate)
                }
            }
        }
        
        hotkeys.onPinClipboard = {
            DispatchQueue.main.async {
                if let overlayController = CaptureOverlayWindowController.shared {
                    overlayController.pinCurrentSelection()
                } else {
                    PinWindowManager.shared.pinFromClipboard()
                }
            }
        }
        
        hotkeys.onToggleAllPins = {
            DispatchQueue.main.async {
                PinWindowManager.shared.toggleAllPinsVisibility()
            }
        }
        
        hotkeys.registerDefaultHotkeys()
    }
    
    public func applicationWillTerminate(_ notification: Notification) {
        GlobalHotkeyManager.shared.unregisterAll()
        PinWindowManager.shared.saveActivePinsSync()
    }
}
