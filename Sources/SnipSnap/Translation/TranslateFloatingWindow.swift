import Cocoa
import SwiftUI

// MARK: - Custom In-Place Translate Window

public class TranslateFloatingWindow: NSWindow {
    public var onCloseRequested: (() -> Void)?
    public var onSpacePressed: (() -> Void)?
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onCloseRequested?()
            return
        }
        if event.keyCode == 49 { // Spacebar
            onSpacePressed?()
            return
        }
        super.keyDown(with: event)
    }
}

// MARK: - In-Place Translate Window Controller

public class TranslateFloatingWindowController: NSWindowController {
    public static var current: TranslateFloatingWindowController?
    
    public let viewModel: InPlaceTranslateViewModel
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?
    private var localKeyMonitor: Any?
    
    public init(window: TranslateFloatingWindow, viewModel: InPlaceTranslateViewModel) {
        self.viewModel = viewModel
        super.init(window: window)
        
        window.onCloseRequested = { [weak self] in
            self?.closeWindow()
        }
        window.onSpacePressed = { [weak self] in
            self?.viewModel.toggleShowingOriginal()
        }
        
        setupMonitors()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMonitors() {
        // Global monitor: click outside on other windows/desktop to dismiss
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let win = self.window else { return }
                // Do not dismiss if window has attached sheets or child windows
                if win.attachedSheet != nil || !(win.childWindows?.isEmpty ?? true) {
                    return
                }
                // Do not dismiss if click was inside or near the window frame
                let mouseLocation = NSEvent.mouseLocation
                if win.frame.insetBy(dx: -8, dy: -8).contains(mouseLocation) {
                    return
                }
                self.closeWindow()
            }
        }
        
        // Local monitor: Esc key or Spacebar
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Esc
                self?.closeWindow()
                return nil
            }
            if event.keyCode == 49 { // Spacebar
                self?.viewModel.toggleShowingOriginal()
                return nil
            }
            return event
        }
    }
    
    // MARK: - Main Presentation Entry (Safari-Style In-Place Screen Overlay)
    
    public static func show(image: NSImage, nearScreenRect: NSRect) {
        closeCurrent()
        
        let canvasW = max(nearScreenRect.width, 20.0)
        let canvasH = max(nearScreenRect.height, 20.0)
        let canvasSize = CGSize(width: canvasW, height: canvasH)
        
        let margin: CGFloat = 8.0
        let capsuleH: CGFloat = 34.0 // 28pt capsule + 6pt spacing
        let windowW = max(canvasW, 340.0) + margin * 2.0
        let windowH = canvasH + capsuleH + margin * 2.0
        
        // Target screen bounds
        let centerPoint = CGPoint(x: nearScreenRect.midX, y: nearScreenRect.midY)
        let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(centerPoint, $0.frame, false) })
            ?? NSScreen.screens.first(where: { $0.frame.intersects(nearScreenRect) })
            ?? NSScreen.main
            ?? NSScreen.screens.first!
        let vf = targetScreen.visibleFrame
        
        // Bottom-left origin alignment:
        // Inside window, canvas is at the bottom with margin padding (14pt).
        // Therefore, window origin Y = nearScreenRect.minY - margin places canvas EXACTLY at nearScreenRect.minY!
        var windowY = nearScreenRect.minY - margin
        
        // If near top menu bar and capsule toolbar would be cut off:
        if nearScreenRect.maxY + capsuleH + margin > vf.maxY {
            windowY = min(nearScreenRect.minY - capsuleH - margin, vf.maxY - windowH)
        }
        
        var windowX = nearScreenRect.minX - margin
        if windowX + windowW > vf.maxX {
            windowX = vf.maxX - windowW - 4.0
        }
        windowX = max(windowX, vf.minX + 4.0)
        
        let targetFrame = NSRect(x: windowX, y: windowY, width: windowW, height: windowH)
        
        let config = AppConfig.load()
        let vm = InPlaceTranslateViewModel(sourceImage: image, targetLang: config.targetTranslateLanguage, canvasSize: canvasSize)
        let window = TranslateFloatingWindow(contentRect: targetFrame)
        
        let controller = TranslateFloatingWindowController(window: window, viewModel: vm)
        current = controller
        
        vm.onClose = { [weak controller] in
            controller?.closeWindow()
        }
        vm.onCopyFinished = { [weak controller] in
            controller?.closeWindow()
        }
        vm.onRetryOCR = { [weak vm, weak image] in
            guard let vm = vm, let img = image else { return }
            vm.isLoading = true
            vm.errorMessage = nil
            VisionOCRService.shared.recognizeText(from: img) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let ocr):
                        vm.ocrLines = ocr.lines
                        vm.startTranslation(with: ocr.fullText)
                    case .failure(let err):
                        vm.isLoading = false
                        vm.errorMessage = "文字识别失败: \(err.localizedDescription)"
                    }
                }
            }
        }
        
        let hudView = InPlaceTranslateHUDView(viewModel: vm)
        let hosting = NSHostingView(rootView: hudView)
        hosting.frame = NSRect(origin: .zero, size: targetFrame.size)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        window.contentView = hosting
        
        window.setFrame(targetFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        
        // Start OCR recognition and translation pipeline
        vm.isLoading = true
        VisionOCRService.shared.recognizeText(from: image) { [weak vm] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let ocr):
                    vm?.ocrLines = ocr.lines
                    vm?.startTranslation(with: ocr.fullText)
                case .failure(let err):
                    vm?.isLoading = false
                    vm?.errorMessage = "文字识别失败: \(err.localizedDescription)"
                }
            }
        }
    }
    
    public static func closeCurrent() {
        if let existing = current {
            existing.closeWindow()
            current = nil
        }
    }
    
    public func closeWindow() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localClickMonitor {
            NSEvent.removeMonitor(monitor)
            localClickMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        window?.orderOut(nil)
        window?.close()
        if TranslateFloatingWindowController.current === self {
            TranslateFloatingWindowController.current = nil
        }
    }
}
