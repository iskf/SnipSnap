import Cocoa

public class CaptureContainerView: NSView {
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

public class CaptureWindow: NSWindow {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override var acceptsMouseMovedEvents: Bool {
        get { true }
        set {}
    }
}

public enum CaptureMode {
    case normal       // 普通截屏模式（带画笔工具栏）
    case translate    // 选区翻译模式（松手直出双栏翻译对照卡片）
}

public class CaptureOverlayWindowController: NSWindowController {
    public static var shared: CaptureOverlayWindowController?
    
    private var overlayView: CaptureOverlayView?
    private var localKeyMonitor: Any?
    
    public static func startCapture(mode: CaptureMode = .normal) {
        if let existing = shared {
            existing.closeCapture()
        }
        
        let mouseLoc = NSEvent.mouseLocation
        ScreenCaptureService.shared.captureFocusedScreen(at: mouseLoc) { captureData, detected in
            guard let captureData = captureData else {
                print("Failed to capture screen - permission check required")
                let alert = NSAlert()
                alert.messageText = "⚠️ 需要开启屏幕录制权限"
                alert.informativeText = "macOS 系统需要「屏幕与系统音频录制」权限以捕获当前屏幕上的窗口内容。\n\n请在「系统设置 - 隐私与安全性 - 屏幕与系统音频录制」中允许 SnipSnap，然后重新启动截屏。"
                alert.addButton(withTitle: "前往系统设置")
                alert.addButton(withTitle: "取消")
                if alert.runModal() == .alertFirstButtonReturn {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
                return
            }
            
            let screenFrame = captureData.screenFrame
            let window = CaptureWindow(
                contentRect: screenFrame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            window.level = .popUpMenu // Above all normal windows, Dock, and menubar, but allows full KeyWindow focus
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.hidesOnDeactivate = false
            window.acceptsMouseMovedEvents = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.setFrame(screenFrame, display: true)
            
            // Background frozen image view using CaptureContainerView (acceptsFirstMouse = true)
            let containerView = CaptureContainerView(frame: NSRect(origin: .zero, size: screenFrame.size))
            let imgView = NSImageView(frame: containerView.bounds)
            imgView.image = captureData.image
            imgView.imageScaling = .scaleAxesIndependently
            imgView.unregisterDraggedTypes()
            containerView.addSubview(imgView)
            
            let overlay = CaptureOverlayView(frame: containerView.bounds)
            overlay.captureMode = mode
            overlay.fullScreenImage = captureData.image
            overlay.fullBounds = screenFrame
            overlay.detectedWindows = detected
            containerView.addSubview(overlay)
            
            window.contentView = containerView
            
            let controller = CaptureOverlayWindowController(window: window)
            controller.overlayView = overlay
            shared = controller
            
            overlay.onClose = {
                controller.closeCapture()
            }
            
            controller.showWindow(nil)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            window.makeFirstResponder(overlay)
            
            controller.setupKeyMonitoring()
        }
    }
    
    private func setupKeyMonitoring() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, let overlay = self.overlayView else { return event }
            if overlay.isSavePanelActive {
                return event
            }
            if event.keyCode == 53 { // Escape
                overlay.handleEscapeKey()
                return nil
            } else if event.keyCode == 36 { // Enter
                overlay.toolbarDidClickCopy()
                return nil
            } else if event.keyCode == 99 { // F3
                overlay.toolbarDidClickPin()
                return nil
            } else if event.modifierFlags.contains(.command) && (event.keyCode == 1 || event.charactersIgnoringModifiers == "s") { // Cmd+S
                overlay.toolbarDidClickSave()
                return nil
            }
            return event
        }
    }
    
    public func closeCapture() {
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        window?.orderOut(nil)
        window?.close()
        CaptureOverlayWindowController.shared = nil
    }
    
    public func pinCurrentSelection() {
        overlayView?.toolbarDidClickPin()
    }
    
    public func translateCurrentSelection() {
        overlayView?.toolbarDidClickTranslate()
    }
}
