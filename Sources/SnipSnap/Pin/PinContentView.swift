import Cocoa

public protocol PinContentViewDelegate: AnyObject {
    func pinViewDidRequestClose()
    func pinViewDidRequestOCR()
    func pinViewDidRequestTranslate()
    func pinViewDidRequestSave()
    func pinViewDidRequestCopy()
    func pinViewDidToggleMousePassThrough()
    func pinViewDidToggleShadow()
    func pinViewDidChangeAnnotationMode(isAnnotating: Bool)
    func pinViewDidMove()
    func pinViewDidDragToolbar(delta: CGPoint)
}

public class PinContentView: NSView, AnnotationToolbarDelegate, AnnotationCanvasDelegate, NSDraggingSource {
    public weak var delegate: PinContentViewDelegate?
    
    public var currentImage: NSImage {
        didSet {
            canvasView.baseCroppedImage = currentImage
            needsDisplay = true
        }
    }
    
    // Transform states
    public var zoomScale: CGFloat = 1.0 {
        didSet {
            updateFrameForScale()
        }
    }
    public var rotationAngle: CGFloat = 0.0 { // In degrees: 0, 90, 180, 270
        didSet {
            if oldValue != rotationAngle {
                updateFrameForScale()
                needsDisplay = true
            }
        }
    }
    public var isFlippedHorizontal: Bool = false
    public var isFlippedVertical: Bool = false
    public var isAnnotating: Bool = false {
        didSet {
            canvasView.isHidden = !isAnnotating
            if isAnnotating {
                canvasView.delegate = self
                toolbarView?.selectTool(.brush)
            } else {
                toolbarView?.selectTool(nil)
                canvasView.commitActiveTextEditor()
            }
            needsDisplay = true
            delegate?.pinViewDidChangeAnnotationMode(isAnnotating: isAnnotating)
        }
    }
    
    // Subviews
    private var canvasView = AnnotationCanvasView()
    public private(set) var toolbarView: AnnotationToolbarView?
    private var isThumbnail: Bool = false
    private var savedBeforeThumbnailFrame: NSRect?
    
    // Pass-through Option unlock state
    public var isOptionHeld: Bool = false {
        didSet {
            if oldValue != isOptionHeld {
                needsDisplay = true
            }
        }
    }
    
    // Dragging
    private var initialWindowLocation: CGPoint = .zero
    private var isDraggingWindow: Bool = false
    
    // Apple Intelligence Glow Shadow & Layout Margin
    public static let margin: CGFloat = 12.0
    public var contentRect: NSRect { bounds.insetBy(dx: PinContentView.margin, dy: PinContentView.margin) }
    public var contentScreenRect: NSRect {
        guard let win = window else { return frame }
        let winRect = convert(contentRect, to: nil)
        return win.convertToScreen(winRect)
    }
    private var isBorderEnabled: Bool = AppConfig.load().pinWindowBorder
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        // Transparent shadow margin passes mouse events directly to underlying windows
        guard contentRect.contains(point) else {
            return nil
        }
        return super.hitTest(point)
    }
    
    public init(image: NSImage, delegate: PinContentViewDelegate?) {
        self.currentImage = image
        self.delegate = delegate
        let totalSize = CGSize(width: image.size.width + PinContentView.margin * 2, height: image.size.height + PinContentView.margin * 2)
        super.init(frame: NSRect(origin: .zero, size: totalSize))
        
        wantsLayer = true
        layer?.cornerRadius = 0
        layer?.masksToBounds = false
        layer?.borderWidth = 0
        layer?.borderColor = nil
        
        canvasView.frame = contentRect
        canvasView.baseCroppedImage = image
        canvasView.delegate = self
        canvasView.isHidden = true
        addSubview(canvasView)
        
        let tb = AnnotationToolbarView(delegate: self)
        tb.isHidden = true
        self.toolbarView = tb
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(configDidChange),
            name: AppConfig.didChangeNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func configDidChange() {
        let newBorder = AppConfig.load().pinWindowBorder
        if isBorderEnabled != newBorder {
            isBorderEnabled = newBorder
            needsDisplay = true
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - 1:1 Resolution Reset
    
    public func resetToOriginalResolution() {
        zoomScale = 1.0
        rotationAngle = 0.0
        isFlippedHorizontal = false
        isFlippedVertical = false
        window?.alphaValue = 1.0
        updateFrameForScale(anchoredAt: nil)
        needsDisplay = true
    }
    
    // MARK: - Cursor-Anchored Zooming and Resizing
    
    public func updateFrameForScale(anchoredAt mouseScreenPos: CGPoint? = nil) {
        guard let win = window else { return }
        let oldFrame = win.frame
        let normalizedAngle = ((Int(round(rotationAngle)) % 360) + 360) % 360
        let isRotatedOrthogonally = (normalizedAngle == 90 || normalizedAngle == 270)
        let baseW = isRotatedOrthogonally ? currentImage.size.height : currentImage.size.width
        let baseH = isRotatedOrthogonally ? currentImage.size.width : currentImage.size.height
        let targetImgW = max(round(baseW * zoomScale), 50)
        let targetImgH = max(round(baseH * zoomScale), 50)
        let newWidth = targetImgW + PinContentView.margin * 2
        let newHeight = targetImgH + PinContentView.margin * 2
        
        var newOrigin = oldFrame.origin
        if let anchor = mouseScreenPos, oldFrame.width > 0, oldFrame.height > 0 {
            // Anchor-ratio based zoom (Figma/Photoshop style): keep pixel under cursor stationary
            let u = (anchor.x - oldFrame.origin.x) / oldFrame.width
            let v = (anchor.y - oldFrame.origin.y) / oldFrame.height
            newOrigin.x = round(anchor.x - u * newWidth)
            newOrigin.y = round(anchor.y - v * newHeight)
        } else {
            // Center-anchored zoom or rotation
            newOrigin.x = round(oldFrame.midX - newWidth / 2)
            newOrigin.y = round(oldFrame.midY - newHeight / 2)
        }
        
        // Screen boundary clamping: keep entire window (including shadow margin) within visible screen
        let centerPoint = CGPoint(x: oldFrame.midX, y: oldFrame.midY)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(centerPoint, $0.frame, false) }) ?? win.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            if newWidth <= vf.width {
                newOrigin.x = min(max(newOrigin.x, vf.minX + 4), vf.maxX - newWidth - 4)
            } else {
                newOrigin.x = vf.minX
            }
            if newHeight <= vf.height {
                newOrigin.y = min(max(newOrigin.y, vf.minY + 4), vf.maxY - newHeight - 4)
            } else {
                newOrigin.y = vf.minY
            }
        }
        
        win.setFrame(NSRect(origin: newOrigin, size: CGSize(width: newWidth, height: newHeight)), display: true, animate: false)
        self.frame = NSRect(origin: .zero, size: CGSize(width: newWidth, height: newHeight))
        canvasView.frame = self.contentRect
        delegate?.pinViewDidMove()
        PinWindowManager.shared.saveActivePinsAsync()
    }
    
    private func repositionToolbar() {
        delegate?.pinViewDidMove()
    }
    
    // MARK: - Mouse & Scroll Events
    
    public override func scrollWheel(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            let delta = event.deltaY * 0.05
            if let win = window {
                let newAlpha = min(max(win.alphaValue + delta, 0.15), 1.0)
                win.alphaValue = newAlpha
                PinWindowManager.shared.saveActivePinsAsync()
            }
        } else {
            let delta = event.deltaY
            let mouseLoc = NSEvent.mouseLocation
            if delta > 0 {
                zoomScale = min(zoomScale * 1.08, 8.0)
            } else if delta < 0 {
                zoomScale = max(zoomScale * 0.92, 0.15)
            }
            updateFrameForScale(anchoredAt: mouseLoc)
        }
    }
    
    public override func magnify(with event: NSEvent) {
        let factor = 1.0 + event.magnification
        zoomScale = min(max(zoomScale * factor, 0.15), 8.0)
        updateFrameForScale(anchoredAt: NSEvent.mouseLocation)
    }
    
    public override func mouseDown(with event: NSEvent) {
        if isAnnotating {
            return
        }
        
        // If pin is in pass-through mode and Option is held, clicking instantly unlocks it
        if let win = window as? PinWindow, win.isMousePassThrough {
            win.isMousePassThrough = false
            isOptionHeld = false
            NSSound(named: "Pop")?.play()
            needsDisplay = true
            return
        }
        
        // Double-click instantly dismisses pin (Snipaste classic gesture)
        if event.clickCount == 2 {
            delegate?.pinViewDidRequestClose()
            return
        }
        
        // Check for Command-Drag to initiate External Drag-and-Drop (to Slack/Finder/WeChat)
        if event.modifierFlags.contains(.command) {
            startExternalDragSession(with: event)
            return
        }
        
        if let win = window {
            initialWindowLocation = event.locationInWindow
            isDraggingWindow = true
            win.orderFront(nil)
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard isDraggingWindow, let win = window else {
            super.mouseDragged(with: event)
            return
        }
        
        let currentLocation = NSEvent.mouseLocation
        var proposedOrigin = CGPoint(
            x: round(currentLocation.x - initialWindowLocation.x),
            y: round(currentLocation.y - initialWindowLocation.y)
        )
        
        let winSize = win.frame.size
        let snapDist: CGFloat = 12.0
        
        // 1. Screen edge magnetic snapping
        if let screen = win.screen ?? NSScreen.main {
            let vf = screen.visibleFrame
            if abs(proposedOrigin.x - vf.minX) <= snapDist {
                proposedOrigin.x = vf.minX
            } else if abs((proposedOrigin.x + winSize.width) - vf.maxX) <= snapDist {
                proposedOrigin.x = vf.maxX - winSize.width
            }
            if abs(proposedOrigin.y - vf.minY) <= snapDist {
                proposedOrigin.y = vf.minY
            } else if abs((proposedOrigin.y + winSize.height) - vf.maxY) <= snapDist {
                proposedOrigin.y = vf.maxY - winSize.height
            }
        }
        
        // 2. Adjacent pins magnetic snapping
        let allPins = PinWindowManager.shared.pinWindows
        for otherPin in allPins where otherPin != win {
            let other = otherPin.frame
            
            // X-axis alignment
            if abs(proposedOrigin.x - other.maxX) <= snapDist {
                proposedOrigin.x = other.maxX
            } else if abs((proposedOrigin.x + winSize.width) - other.minX) <= snapDist {
                proposedOrigin.x = other.minX - winSize.width
            } else if abs(proposedOrigin.x - other.minX) <= snapDist {
                proposedOrigin.x = other.minX
            } else if abs((proposedOrigin.x + winSize.width) - other.maxX) <= snapDist {
                proposedOrigin.x = other.maxX - winSize.width
            }
            
            // Y-axis alignment
            if abs(proposedOrigin.y - other.maxY) <= snapDist {
                proposedOrigin.y = other.maxY
            } else if abs((proposedOrigin.y + winSize.height) - other.minY) <= snapDist {
                proposedOrigin.y = other.minY - winSize.height
            } else if abs(proposedOrigin.y - other.minY) <= snapDist {
                proposedOrigin.y = other.minY
            } else if abs((proposedOrigin.y + winSize.height) - other.maxY) <= snapDist {
                proposedOrigin.y = other.maxY - winSize.height
            }
        }
        
        win.setFrameOrigin(proposedOrigin)
    }
    
    public override func mouseUp(with event: NSEvent) {
        if isDraggingWindow {
            isDraggingWindow = false
            PinWindowManager.shared.saveActivePinsAsync()
            
            // Check for Shift + Drag Pin Merge
            if event.modifierFlags.contains(.shift), let thisWin = self.window as? PinWindow {
                checkForPinMerge(sourcePin: thisWin)
            }
        }
    }
    
    private func checkForPinMerge(sourcePin: PinWindow) {
        let allPins = PinWindowManager.shared.pinWindows
        for otherPin in allPins where otherPin != sourcePin {
            let intersection = sourcePin.frame.intersection(otherPin.frame)
            let isNear = sourcePin.frame.insetBy(dx: -30, dy: -30).intersects(otherPin.frame)
            
            if isNear || !intersection.isNull {
                let horizontal = abs(sourcePin.frame.midX - otherPin.frame.midX) > abs(sourcePin.frame.midY - otherPin.frame.midY)
                PinWindowManager.shared.mergePins(source: sourcePin, target: otherPin, horizontal: horizontal)
                break
            }
        }
    }
    
    // MARK: - NSDraggingSource (Drag & Drop Out into WeChat / Slack / Finder)
    
    private func startExternalDragSession(with event: NSEvent) {
        guard let tiff = currentImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempUrl = tempDir.appendingPathComponent("SnipSnap_\(Int(Date().timeIntervalSince1970)).png")
        try? pngData.write(to: tempUrl)
        
        let item = NSDraggingItem(pasteboardWriter: tempUrl as NSURL)
        let dragRect = NSRect(origin: event.locationInWindow, size: CGSize(width: 80, height: 80))
        item.setDraggingFrame(dragRect, contents: currentImage)
        
        beginDraggingSession(with: [item], event: event, source: self)
    }
    
    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        if event.clickCount == 2 {
            delegate?.pinViewDidRequestClose()
            return
        }
        showContextMenu(for: event)
    }
    
    private func toggleThumbnail() {
        guard let win = window else { return }
        if isThumbnail {
            if let prev = savedBeforeThumbnailFrame {
                win.setFrame(prev, display: true, animate: true)
            }
            isThumbnail = false
        } else {
            savedBeforeThumbnailFrame = win.frame
            let thumbSize = CGSize(width: 80, height: 80 * (currentImage.size.height / max(currentImage.size.width, 1)))
            let thumbFrame = NSRect(origin: win.frame.origin, size: thumbSize)
            win.setFrame(thumbFrame, display: true, animate: true)
            isThumbnail = true
        }
    }
    
    // MARK: - Context Menu
    
    private func showContextMenu(for event: NSEvent) {
        let menu = NSMenu(title: "PinMenu")
        
        // --- 分组 1: 核心智能 ---
        let translateItem = NSMenuItem(title: "翻译", action: #selector(menuActionTranslate), keyEquivalent: "")
        translateItem.target = self
        menu.addItem(translateItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 分组 2: 编辑与变换 ---
        let annotateItem = NSMenuItem(
            title: isAnnotating ? "退出标注模式" : "标注贴图",
            action: #selector(menuActionToggleAnnotation),
            keyEquivalent: ""
        )
        annotateItem.target = self
        menu.addItem(annotateItem)
        
        // 子菜单: 图像变换
        let transformMenu = NSMenu(title: "图像变换")
        
        let rotateCWItem = NSMenuItem(title: "顺时针旋转 90°", action: #selector(menuActionRotate), keyEquivalent: "r")
        rotateCWItem.target = self
        transformMenu.addItem(rotateCWItem)
        
        let rotateCCWItem = NSMenuItem(title: "逆时针旋转 90°", action: #selector(menuActionRotateCCW), keyEquivalent: "r")
        rotateCCWItem.keyEquivalentModifierMask = [.shift]
        rotateCCWItem.target = self
        transformMenu.addItem(rotateCCWItem)
        
        let flipHItem = NSMenuItem(title: "水平翻转", action: #selector(menuActionFlipH), keyEquivalent: "h")
        flipHItem.target = self
        transformMenu.addItem(flipHItem)
        
        let flipVItem = NSMenuItem(title: "垂直翻转", action: #selector(menuActionFlipV), keyEquivalent: "v")
        flipVItem.target = self
        transformMenu.addItem(flipVItem)
        
        transformMenu.addItem(NSMenuItem.separator())
        
        let resetItem = NSMenuItem(title: "恢复 1:1 原始比例", action: #selector(menuActionResetResolution), keyEquivalent: "0")
        resetItem.target = self
        transformMenu.addItem(resetItem)
        
        let thumbItem = NSMenuItem(
            title: isThumbnail ? "展开为原图" : "折叠为缩略图",
            action: #selector(menuActionToggleThumbnail),
            keyEquivalent: "t"
        )
        thumbItem.target = self
        transformMenu.addItem(thumbItem)
        
        let transformSubmenuItem = NSMenuItem(title: "图像变换", action: nil, keyEquivalent: "")
        transformSubmenuItem.submenu = transformMenu
        menu.addItem(transformSubmenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 分组 3: 窗口与交互 ---
        // 子菜单: 窗口透明度
        let opacityMenu = NSMenu(title: "窗口透明度")
        let currentAlpha = window?.alphaValue ?? 1.0
        let opacityLevels: [(Double, String)] = [
            (1.0, "100% (不透明)"),
            (0.8, "80%"),
            (0.6, "60%"),
            (0.4, "40%"),
            (0.2, "20%")
        ]
        for (val, title) in opacityLevels {
            let item = NSMenuItem(title: title, action: #selector(menuActionSetOpacity(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = val
            if abs(currentAlpha - val) < 0.08 {
                item.state = .on
            }
            opacityMenu.addItem(item)
        }
        let opacitySubmenuItem = NSMenuItem(title: "窗口透明度", action: nil, keyEquivalent: "")
        opacitySubmenuItem.submenu = opacityMenu
        menu.addItem(opacitySubmenuItem)
        
        let passThroughItem = NSMenuItem(title: "鼠标穿透", action: #selector(menuActionTogglePassThrough), keyEquivalent: "l")
        passThroughItem.keyEquivalentModifierMask = .command
        passThroughItem.target = self
        if let win = window as? PinWindow, win.isMousePassThrough {
            passThroughItem.state = .on
        }
        menu.addItem(passThroughItem)
        
        let shadowItem = NSMenuItem(title: "切换悬浮阴影", action: #selector(menuActionToggleShadow), keyEquivalent: "")
        shadowItem.target = self
        if isBorderEnabled || (window as? PinWindow)?.hasShadow == true {
            shadowItem.state = .on
        }
        menu.addItem(shadowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // --- 分组 4: 导出与关闭 ---
        let copyItem = NSMenuItem(title: "复制图片", action: #selector(menuActionCopy), keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = .command
        copyItem.target = self
        menu.addItem(copyItem)
        
        let saveItem = NSMenuItem(title: "存储图片为...", action: #selector(menuActionSave), keyEquivalent: "s")
        saveItem.keyEquivalentModifierMask = .command
        saveItem.target = self
        menu.addItem(saveItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let closeItem = NSMenuItem(title: "关闭贴图", action: #selector(menuActionClose), keyEquivalent: "\u{1b}")
        closeItem.target = self
        menu.addItem(closeItem)
        
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    
    @objc private func menuActionSetOpacity(_ sender: NSMenuItem) {
        guard let alpha = sender.representedObject as? Double, let win = window else { return }
        win.alphaValue = alpha
        PinWindowManager.shared.saveActivePinsAsync()
    }
    
    @objc private func menuActionToggleThumbnail() {
        toggleThumbnail()
    }
    
    @objc private func menuActionOCR() { delegate?.pinViewDidRequestOCR() }
    @objc private func menuActionTranslate() { delegate?.pinViewDidRequestTranslate() }
    @objc private func menuActionResetResolution() { resetToOriginalResolution() }
    @objc private func menuActionToggleAnnotation() {
        isAnnotating.toggle()
    }
    @objc public func menuActionRotate() {
        rotationAngle = (rotationAngle + 90).truncatingRemainder(dividingBy: 360)
        needsDisplay = true
        PinWindowManager.shared.saveActivePinsAsync()
    }
    @objc public func menuActionRotateCCW() {
        rotationAngle = (rotationAngle - 90 + 360).truncatingRemainder(dividingBy: 360)
        needsDisplay = true
        PinWindowManager.shared.saveActivePinsAsync()
    }
    @objc public func menuActionFlipH() {
        isFlippedHorizontal.toggle()
        needsDisplay = true
        PinWindowManager.shared.saveActivePinsAsync()
    }
    @objc public func menuActionFlipV() {
        isFlippedVertical.toggle()
        needsDisplay = true
        PinWindowManager.shared.saveActivePinsAsync()
    }
    @objc private func menuActionTogglePassThrough() { delegate?.pinViewDidToggleMousePassThrough() }
    @objc private func menuActionToggleShadow() {
        isBorderEnabled.toggle()
        needsDisplay = true
        delegate?.pinViewDidToggleShadow()
    }
    @objc private func menuActionCopy() { delegate?.pinViewDidRequestCopy() }
    @objc private func menuActionSave() { delegate?.pinViewDidRequestSave() }
    @objc private func menuActionClose() { delegate?.pinViewDidRequestClose() }
    
    // MARK: - Drawing
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let targetRect = contentRect
        
        // 1. Draw Apple Intelligence Glow Shadow if enabled (unrotated relative to window content box)
        if isBorderEnabled {
            drawAppleIntelligenceGlowShadow(in: context, for: targetRect)
        }
        
        // 2. Draw Screenshot Image transformed around center
        context.saveGState()
        
        let midX = targetRect.midX
        let midY = targetRect.midY
        
        context.translateBy(x: midX, y: midY)
        if rotationAngle != 0 {
            context.rotate(by: -rotationAngle * .pi / 180.0)
        }
        if isFlippedHorizontal {
            context.scaleBy(x: -1, y: 1)
        }
        if isFlippedVertical {
            context.scaleBy(x: 1, y: -1)
        }
        
        let imgDrawW = round(currentImage.size.width * zoomScale)
        let imgDrawH = round(currentImage.size.height * zoomScale)
        let drawRect = NSRect(x: -imgDrawW / 2.0, y: -imgDrawH / 2.0, width: imgDrawW, height: imgDrawH)
        currentImage.draw(in: drawRect)
        
        context.restoreGState()
        
        // 3. Draw Option-Unlock Indicator when in pass-through mode
        if isOptionHeld, (window as? PinWindow)?.isMousePassThrough == true {
            drawUnlockIndicator(in: targetRect)
        }
    }
    
    private func drawAppleIntelligenceGlowShadow(in context: CGContext, for rect: NSRect) {
        guard rect.width > 2 && rect.height > 2 else { return }
        
        context.saveGState()
        
        // Layer 1: Ambient Outer Halo (blur 10.0, soft Apple Intelligence violet #8B5CF6)
        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: 10.0,
            color: NSColor(red: 0.55, green: 0.35, blue: 0.98, alpha: 0.45).cgColor
        )
        NSColor.black.setFill()
        context.fill(rect)
        context.restoreGState()
        
        // Layer 2: Radiant Inner Bloom (blur 4.5, vibrant brand indigo #6366F1)
        context.saveGState()
        context.setShadow(
            offset: .zero,
            blur: 4.5,
            color: NSColor(red: 0.39, green: 0.40, blue: 0.95, alpha: 0.60).cgColor
        )
        NSColor.black.setFill()
        context.fill(rect)
        context.restoreGState()
        
        context.restoreGState()
    }
    
    private func drawUnlockIndicator(in rect: NSRect) {
        let bannerW: CGFloat = min(rect.width - 24, 180)
        let bannerH: CGFloat = 30
        let bannerRect = NSRect(
            x: round((rect.width - bannerW) / 2) + rect.minX,
            y: round((rect.height - bannerH) / 2) + rect.minY,
            width: bannerW,
            height: bannerH
        )
        
        let path = NSBezierPath(roundedRect: bannerRect, xRadius: 8, yRadius: 8)
        NSColor(calibratedWhite: 0.1, alpha: 0.85).setFill()
        path.fill()
        
        NSColor.white.withAlphaComponent(0.4).setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        let text = "🔓 点击解锁贴图"
        let font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attrs)
        let textPoint = CGPoint(
            x: round(bannerRect.midX - textSize.width / 2),
            y: round(bannerRect.midY - textSize.height / 2)
        )
        (text as NSString).draw(at: textPoint, withAttributes: attrs)
    }
    
    // MARK: - Annotation Helpers & Compositing
    
    public func renderedImageWithAnnotations() -> NSImage {
        if canvasView.elements.isEmpty {
            return currentImage
        }
        return canvasView.renderComposite(baseImage: currentImage)
    }
    
    public func commitAnnotationsToCurrentImage() {
        if !canvasView.elements.isEmpty {
            let finalImage = canvasView.renderComposite(baseImage: currentImage)
            self.currentImage = finalImage
            canvasView.baseCroppedImage = finalImage
            canvasView.clearAll()
            PinWindowManager.shared.saveActivePinsAsync()
        }
    }
    
    // MARK: - AnnotationCanvasDelegate
    
    public func canvasDidSelectElement(_ element: AnnotationElement?) {
        toolbarView?.reflectElementProperties(element)
    }
    
    // MARK: - AnnotationToolbarDelegate
    
    public func toolbarDidSelectTool(_ tool: AnnotationToolType?) { canvasView.activeTool = tool }
    public func toolbarDidChangeColor(_ color: NSColor) { canvasView.currentColor = color }
    public func toolbarDidChangeStrokeWidth(_ width: CGFloat) { canvasView.currentStrokeWidth = width }
    public func toolbarDidChangeFontSize(_ size: CGFloat) { canvasView.currentFontSize = size }
    public func toolbarDidChangeTextStyle(_ style: TextStyleMode) { canvasView.currentTextStyle = style }
    public func toolbarDidChangeTextBackground(_ style: TextBackgroundStyle) { canvasView.currentTextBackground = style }
    public func toolbarDidChangeMosaicBlockSize(_ size: CGFloat) { canvasView.currentMosaicBlockSize = size }
    public func toolbarDidChangeCounterStyle(_ style: CounterStyle) { canvasView.currentCounterStyle = style }
    public func toolbarDidResetCounter() { canvasView.resetCounter() }
    public func toolbarDidClickUndo() { canvasView.undo() }
    public func toolbarDidClickRedo() { canvasView.redo() }
    public func toolbarDidClickOCR() { delegate?.pinViewDidRequestOCR() }
    public func toolbarDidClickTranslate() { delegate?.pinViewDidRequestTranslate() }
    public func toolbarDidClickPin() { isAnnotating = false }
    public func toolbarDidClickSave() { delegate?.pinViewDidRequestSave() }
    public func toolbarDidClickCopy() {
        let finalImage = canvasView.elements.isEmpty ? currentImage : canvasView.renderComposite(baseImage: currentImage)
        let pb = NSPasteboard.general
        pb.clearContents()
        
        var pngData: Data? = nil
        if let tiff = finalImage.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff) {
            pngData = rep.representation(using: .png, properties: [:])
        }
        
        let tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let fileURL = tempDir.appendingPathComponent("SnipSnap_\(df.string(from: Date())).png")
        if let png = pngData {
            try? png.write(to: fileURL)
        }
        
        pb.declareTypes([.tiff, .png, .fileURL], owner: nil)
        if let tiff = finalImage.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        if let png = pngData {
            pb.setData(png, forType: .png)
        }
        (fileURL as NSURL).write(to: pb)
        
        NSSound(named: "Tink")?.play()
        
        // 合并标注到当前贴图
        if !canvasView.elements.isEmpty {
            self.currentImage = finalImage
            canvasView.baseCroppedImage = finalImage
            canvasView.clearAll()
            PinWindowManager.shared.saveActivePinsAsync()
        }
        
        isAnnotating = false
    }
    public func toolbarDidClickClose() {
        canvasView.clearAll()
        isAnnotating = false
    }
    public func toolbarDidDrag(delta: CGPoint) {
        delegate?.pinViewDidDragToolbar(delta: delta)
    }
}
