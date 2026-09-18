import Cocoa

public class PinWindow: NSPanel, PinContentViewDelegate {
    public var pinContentView: PinContentView!
    public var isMousePassThrough: Bool = false {
        didSet {
            ignoresMouseEvents = isMousePassThrough
            alphaValue = isMousePassThrough ? 0.75 : 1.0
            PinWindowManager.shared.updatePassThroughMonitoring()
            PinWindowManager.shared.saveActivePinsAsync()
        }
    }
    
    private var toolbarPanel: NSPanel?
    
    public init(image: NSImage, initialFrame: NSRect? = nil) {
        let margin = PinContentView.margin
        let size = image.size
        let windowSize = CGSize(width: size.width + margin * 2, height: size.height + margin * 2)
        let origin: CGPoint
        
        if let initF = initialFrame {
            origin = CGPoint(x: initF.origin.x - margin, y: initF.origin.y - margin)
        } else {
            let mouseLoc = NSEvent.mouseLocation
            let targetScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLoc, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens.first!
            let vf = targetScreen.visibleFrame
            origin = CGPoint(
                x: min(max(mouseLoc.x - windowSize.width / 2, vf.minX), vf.maxX - windowSize.width),
                y: min(max(mouseLoc.y - windowSize.height / 2, vf.minY), vf.maxY - windowSize.height)
            )
        }
        
        let frame = NSRect(origin: origin, size: windowSize)
        
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        let config = AppConfig.load()
        self.hasShadow = !config.pinWindowBorder && config.pinWindowShadow
        self.isMovableByWindowBackground = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: AppConfig.didChangeNotification,
            object: nil
        )
        
        self.pinContentView = PinContentView(image: image, delegate: self)
        self.contentView = pinContentView
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        if let panel = toolbarPanel {
            self.removeChildWindow(panel)
            panel.orderOut(nil)
            panel.close()
        }
    }
    
    @objc private func configDidChange() {
        let config = AppConfig.load()
        self.hasShadow = !config.pinWindowBorder && config.pinWindowShadow
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func keyDown(with event: NSEvent) {
        // Check Escape key: if annotating, exit annotation mode, otherwise close pin window
        if event.keyCode == 53 {
            if pinContentView.isAnnotating {
                pinContentView.isAnnotating = false
                return
            }
            pinViewDidRequestClose()
            return
        }
        
        let chars = event.charactersIgnoringModifiers?.lowercased()
        let isCmd = event.modifierFlags.contains(.command)
        
        if isCmd {
            switch chars {
            case "c":
                pinViewDidRequestCopy()
                return
            case "s":
                pinViewDidRequestSave()
                return
            case "l":
                pinViewDidToggleMousePassThrough()
                return
            default:
                break
            }
        } else {
            switch chars {
            case "r", "R":
                if event.modifierFlags.contains(.shift) {
                    pinContentView.menuActionRotateCCW()
                } else {
                    pinContentView.menuActionRotate()
                }
                return
            case "h":
                pinContentView.menuActionFlipH()
                return
            case "v":
                pinContentView.menuActionFlipV()
                return
            case "=", "+":
                pinContentView.zoomScale = min(pinContentView.zoomScale * 1.15, 8.0)
                return
            case "-":
                pinContentView.zoomScale = max(pinContentView.zoomScale * 0.85, 0.15)
                return
            default:
                break
            }
        }
        
        // Number keys 1~9 for opacity, 0 for 1:1 scale & 100% opacity
        if let char = chars?.first, char >= "1" && char <= "9", let digit = Int(String(char)) {
            self.alphaValue = CGFloat(digit) / 10.0
            PinWindowManager.shared.saveActivePinsAsync()
            return
        } else if chars == "0" {
            self.alphaValue = 1.0
            self.pinContentView.resetToOriginalResolution()
            PinWindowManager.shared.saveActivePinsAsync()
            return
        }
        
        super.keyDown(with: event)
    }
    
    // MARK: - PinContentViewDelegate
    
    public func pinViewDidRequestClose() {
        hideAnnotationToolbar()
        PinWindowManager.shared.removePin(self)
        self.orderOut(nil)
        self.close()
    }
    
    public func pinViewDidRequestOCR() {
        VisionOCRService.shared.recognizeText(from: pinContentView.currentImage) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let ocr):
                OCRResultWindowController.show(with: ocr, image: self.pinContentView.currentImage)
            case .failure(let err):
                let empty = OCRResult(fullText: "识别失败: \(err.localizedDescription)")
                OCRResultWindowController.show(with: empty, image: self.pinContentView.currentImage)
            }
        }
    }
    
    public func pinViewDidRequestTranslate() {
        TranslateFloatingWindowController.show(
            image: pinContentView.currentImage,
            nearScreenRect: pinContentView.contentScreenRect
        )
    }
    
    public func pinViewDidRequestSave() {
        let config = AppConfig.load()
        let savePanel = NSSavePanel()
        let isJpeg = config.imageSaveFormat.uppercased() == "JPEG"
        savePanel.allowedContentTypes = isJpeg ? [.jpeg, .png] : [.png, .jpeg]
        
        let ext = isJpeg ? "jpg" : "png"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmmss"
        savePanel.nameFieldStringValue = "Pin_\(df.string(from: Date())).\(ext)"
        
        if !config.defaultSavePath.isEmpty {
            let dirURL = URL(fileURLWithPath: config.defaultSavePath)
            if FileManager.default.fileExists(atPath: dirURL.path) {
                savePanel.directoryURL = dirURL
            }
        }
        
        savePanel.level = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)) + 1)
        NSApp.activate(ignoringOtherApps: true)
        
        let finalImage = self.pinContentView.renderedImageWithAnnotations()
        
        savePanel.begin { [weak self] response in
            guard let self = self, response == .OK, let url = savePanel.url else { return }
            let chosenExt = url.pathExtension.lowercased()
            let useJpeg = (chosenExt == "jpg" || chosenExt == "jpeg")
            if let tiff = finalImage.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff) {
                let data = useJpeg
                    ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
                    : rep.representation(using: .png, properties: [:])
                if let data = data {
                    try? data.write(to: url)
                }
            }
            
            // 合并标注到当前贴图并退出标注模式
            self.pinContentView.commitAnnotationsToCurrentImage()
            if self.pinContentView.isAnnotating {
                self.pinContentView.isAnnotating = false
            }
            
            if config.playSoundEffect {
                NSSound(named: "Tink")?.play()
            }
        }
    }
    
    public func pinViewDidRequestCopy() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([pinContentView.currentImage])
        NSSound(named: "Tink")?.play()
    }
    
    public func pinViewDidToggleMousePassThrough() {
        isMousePassThrough.toggle()
    }
    
    public func pinViewDidToggleShadow() {
        hasShadow.toggle()
    }
    
    public func pinViewDidChangeAnnotationMode(isAnnotating: Bool) {
        if isAnnotating {
            showAnnotationToolbar()
        } else {
            hideAnnotationToolbar()
        }
    }
    
    public func pinViewDidMove() {
        if pinContentView?.isAnnotating == true {
            updateToolbarPosition()
        }
    }
    
    public func pinViewDidDragToolbar(delta: CGPoint) {
        guard let panel = toolbarPanel else { return }
        panel.setFrameOrigin(CGPoint(x: panel.frame.origin.x + delta.x, y: panel.frame.origin.y + delta.y))
    }
    
    // MARK: - External Floating Annotation Toolbar
    
    public override func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {
        super.setFrame(frameRect, display: displayFlag, animate: animateFlag)
        if pinContentView?.isAnnotating == true {
            updateToolbarPosition()
        }
    }
    
    public override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        if pinContentView?.isAnnotating == true {
            updateToolbarPosition()
        }
    }
    
    private func showAnnotationToolbar() {
        if toolbarPanel == nil {
            let panelW = AnnotationToolbarView.standardWidth + 24
            let panelH: CGFloat = 84.0
            
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: panelW, height: panelH),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = NSWindow.Level(Int(CGWindowLevelForKey(.floatingWindow)) + 1)
            panel.becomesKeyOnlyIfNeeded = true
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            let container = NSView(frame: NSRect(x: 0, y: 0, width: panelW, height: panelH))
            container.wantsLayer = true
            
            if let tb = pinContentView.toolbarView {
                tb.removeFromSuperview()
                tb.isHidden = false
                container.addSubview(tb)
            }
            
            panel.contentView = container
            self.toolbarPanel = panel
        }
        
        updateToolbarPosition()
        if let panel = toolbarPanel {
            if panel.parent == nil {
                self.addChildWindow(panel, ordered: .above)
            }
            panel.orderFrontRegardless()
        }
    }
    
    private func hideAnnotationToolbar() {
        if let panel = toolbarPanel {
            self.removeChildWindow(panel)
            panel.orderOut(nil)
        }
    }
    
    public func updateToolbarPosition() {
        guard let panel = toolbarPanel, let tb = pinContentView.toolbarView else { return }
        let panelW = AnnotationToolbarView.standardWidth + 24
        let panelH: CGFloat = 84.0
        
        let screen = self.screen ?? NSScreen.main ?? NSScreen.screens.first!
        let vf = screen.visibleFrame
        
        let targetX = min(max(self.frame.midX - panelW / 2.0, vf.minX + 8), vf.maxX - panelW - 8)
        let spaceBelow = self.frame.minY - vf.minY
        
        let isAbove = spaceBelow < panelH + 8
        let targetY: CGFloat
        if isAbove {
            targetY = min(self.frame.maxY + 4, vf.maxY - panelH - 8)
            tb.isFlippedAbove = true
            tb.frame = NSRect(x: 12, y: 6, width: AnnotationToolbarView.standardWidth, height: AnnotationToolbarView.standardHeight)
        } else {
            targetY = max(self.frame.minY - panelH - 4, vf.minY + 8)
            tb.isFlippedAbove = false
            tb.frame = NSRect(x: 12, y: 40, width: AnnotationToolbarView.standardWidth, height: AnnotationToolbarView.standardHeight)
        }
        
        panel.setFrame(NSRect(x: targetX, y: targetY, width: panelW, height: panelH), display: true)
        tb.updateSubBubblePosition()
    }
}
