import Cocoa

public class CaptureOverlayView: NSView, AnnotationToolbarDelegate, AnnotationCanvasDelegate {
    public var fullScreenImage: NSImage?
    public var fullBounds: CGRect = .zero
    public var detectedWindows: [DetectedWindowInfo] = []
    
    // Crosshair & cursor state
    private var currentMousePoint: CGPoint = .zero
    public let magnifierView = LoupeMagnifierView()
    
    // Selection state
    private var selectionRect: CGRect = .zero {
        didSet {
            updateSelectionViews()
            repositionToolbar()
            repositionOCRHub()
            needsDisplay = true
        }
    }
    
    // Interaction states
    private var isSelectingNew: Bool = false
    private var isMovingSelection: Bool = false
    private var activeResizingHandle: Int? = nil // 0..7
    private var isDraggingSelection: Bool {
        return isSelectingNew || isMovingSelection || activeResizingHandle != nil
    }
    private var startDragPoint: CGPoint = .zero
    private var initialSelection: CGRect = .zero
    
    // Subviews
    private var toolbarView: AnnotationToolbarView?
    private var canvasView = AnnotationCanvasView()
    private var isUserCustomPositioned: Bool = false
    public private(set) var isSavePanelActive: Bool = false
    
    // In-place OCR state
    private var isOCROverlayActive: Bool = false
    private var ocrResult: OCRResult? = nil
    private var ocrFloatingHubView: NSVisualEffectView?
    private var translateHUDView: InPlaceTranslateHUDHostingView?
    
    public var captureMode: CaptureMode = .normal {
        didSet {
            if captureMode == .translate {
                magnifierView.customTipText = L10n("capture.translate_tip")
            } else {
                magnifierView.customTipText = nil
            }
        }
    }
    
    public var onClose: (() -> Void)?
    
    // Custom diagonal resize cursors
    private static let cursorNWSE: NSCursor = makeDiagonalCursor(isNWSE: true)
    private static let cursorNESW: NSCursor = makeDiagonalCursor(isNWSE: false)
    
    private static func makeDiagonalCursor(isNWSE: Bool) -> NSCursor {
        let size = NSSize(width: 17, height: 17)
        let img = NSImage(size: size)
        img.lockFocus()
        if let ctx = NSGraphicsContext.current?.cgContext {
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(3.0)
            ctx.setLineCap(.round)
            
            let p1 = isNWSE ? CGPoint(x: 2, y: 15) : CGPoint(x: 15, y: 15)
            let p2 = isNWSE ? CGPoint(x: 15, y: 2) : CGPoint(x: 2, y: 2)
            
            ctx.move(to: p1)
            ctx.addLine(to: p2)
            ctx.strokePath()
            
            ctx.setStrokeColor(NSColor.white.cgColor)
            ctx.setLineWidth(1.5)
            ctx.move(to: p1)
            ctx.addLine(to: p2)
            ctx.strokePath()
        }
        img.unlockFocus()
        return NSCursor(image: img, hotSpot: NSPoint(x: 8, y: 8))
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        
        canvasView.delegate = self
        addSubview(canvasView)
        canvasView.isHidden = true
        
        let tb = AnnotationToolbarView(delegate: self)
        addSubview(tb)
        tb.isHidden = true
        self.toolbarView = tb
        
        addSubview(magnifierView)
        magnifierView.layer?.zPosition = 50
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private var trackingArea: NSTrackingArea?
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override var acceptsFirstResponder: Bool { true }
    
    // MARK: - Keyboard Handling & Shortcuts
    
    public override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 8: // 'C' key -> Copy Color value
            if selectionRect.isEmpty {
                let colorStr = magnifierView.formattedColorString
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(colorStr, forType: .string)
                NSSound(named: "Tink")?.play()
                onClose?()
            }
            
        case 15: // 'R' key -> Rectangle
            toolbarView?.selectTool(.rectangle)
        case 31: // 'O' key -> Ellipse
            toolbarView?.selectTool(.ellipse)
        case 0:  // 'A' key -> Arrow
            toolbarView?.selectTool(.arrow)
        case 37: // 'L' key -> Line
            toolbarView?.selectTool(.line)
        case 35: // 'P' key -> Pencil/Brush
            toolbarView?.selectTool(.brush)
        case 4:  // 'H' key -> Highlighter
            toolbarView?.selectTool(.highlighter)
        case 17: // 'T' key -> Text
            toolbarView?.selectTool(.text)
        case 46: // 'M' key -> Toggle Magnifier before selection, or Mosaic after selection
            if selectionRect.isEmpty {
                magnifierView.isHidden.toggle()
                needsDisplay = true
            } else {
                toolbarView?.selectTool(.mosaic)
            }
        case 45: // 'N' key -> Counter
            toolbarView?.selectTool(.counter)
            
        case 123: // Left Arrow -> Nudge 1 pixel left
            nudgeMousePoint(dx: -1, dy: 0)
        case 124: // Right Arrow -> Nudge 1 pixel right
            nudgeMousePoint(dx: 1, dy: 0)
        case 125: // Down Arrow -> Nudge 1 pixel down
            nudgeMousePoint(dx: 0, dy: -1)
        case 126: // Up Arrow -> Nudge 1 pixel up
            nudgeMousePoint(dx: 0, dy: 1)
            
        case 6: // 'Z' key -> Undo / Redo
            if event.modifierFlags.contains(.command) {
                if event.modifierFlags.contains(.shift) {
                    canvasView.redo()
                } else {
                    canvasView.undo()
                }
            }
            
        case 1: // 'S' key -> Save
            if event.modifierFlags.contains(.command) {
                toolbarDidClickSave()
            }
            
        case 56, 60: // Left / Right Shift -> Cycle Color format
            magnifierView.cycleColorFormat()
            needsDisplay = true
            
        case 99, 49: // F3 or Space -> Pin
            toolbarDidClickPin()
            
        case 53: // Escape -> Cascaded dismissal
            handleEscapeKey()
            
        case 36: // Enter -> Complete capture and copy
            toolbarDidClickCopy()
            
        default:
            super.keyDown(with: event)
        }
    }
    
    public func handleEscapeKey() {
        if captureMode == .translate {
            dismissTranslateHUD()
            onClose?()
            return
        }
        if translateHUDView != nil {
            dismissTranslateHUD()
        } else if isOCROverlayActive {
            dismissOCROverlay()
        } else if toolbarView?.selectedTool != nil {
            toolbarView?.selectTool(nil)
        } else {
            handleCascadedDismiss()
        }
    }
    
    private func nudgeMousePoint(dx: CGFloat, dy: CGFloat) {
        currentMousePoint.x = min(max(currentMousePoint.x + dx, 0), bounds.width)
        currentMousePoint.y = min(max(currentMousePoint.y + dy, 0), bounds.height)
        if selectionRect.isEmpty {
            magnifierView.targetPoint = currentMousePoint
            positionMagnifierSmartQuadrant(at: currentMousePoint)
        }
        needsDisplay = true
    }
    
    public override func scrollWheel(with event: NSEvent) {
        if selectionRect.isEmpty && !magnifierView.isHidden {
            let delta = event.deltaY
            if delta > 0 {
                magnifierView.pixelDisplaySize = min(magnifierView.pixelDisplaySize + 1.0, 16.0)
            } else if delta < 0 {
                magnifierView.pixelDisplaySize = max(magnifierView.pixelDisplaySize - 1.0, 6.0)
            }
            positionMagnifierSmartQuadrant(at: currentMousePoint)
            needsDisplay = true
            return
        }
        super.scrollWheel(with: event)
    }
    
    public override func flagsChanged(with event: NSEvent) {
        if event.modifierFlags.contains(.shift) {
            magnifierView.cycleColorFormat()
            needsDisplay = true
        }
        super.flagsChanged(with: event)
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        if captureMode == .translate {
            dismissTranslateHUD()
            onClose?()
            return
        }
        if translateHUDView != nil {
            dismissTranslateHUD()
            return
        }
        if isOCROverlayActive {
            dismissOCROverlay()
            return
        }
        handleCascadedDismiss()
    }
    
    private func handleCascadedDismiss() {
        // Layer 1: If an annotation tool is active, cancel it first
        if canvasView.activeTool != nil {
            toolbarView?.selectTool(nil)
            needsDisplay = true
            return
        }
        
        // Layer 2: If a selection is active, clear it and return to hover state
        if !selectionRect.isEmpty {
            selectionRect = .zero
            toolbarView?.isHidden = true
            toolbarView?.secondaryBubble.hide()
            canvasView.isHidden = true
            magnifierView.isHidden = false
            isUserCustomPositioned = false
            ToolbarTooltipHUD.shared.hide()
            dismissOCROverlay()
            dismissTranslateHUD()
            needsDisplay = true
            return
        }
        
        // Layer 3: Entirely close and unfreeze screen
        toolbarView?.secondaryBubble.hide()
        ToolbarTooltipHUD.shared.hide()
        onClose?()
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        if let hub = ocrFloatingHubView, !hub.isHidden, hub.frame.contains(point) {
            return hub.hitTest(point)
        }
        if let tb = toolbarView, !tb.secondaryBubble.isHidden, tb.secondaryBubble.frame.contains(point) {
            return tb.secondaryBubble.hitTest(point)
        }
        if let tb = toolbarView, !tb.isHidden, tb.frame.contains(point) {
            return tb.hitTest(point)
        }
        if !selectionRect.isEmpty && canvasView.frame.contains(point) && canvasView.activeTool != nil {
            return canvasView.hitTest(point)
        }
        return self
    }
    
    // MARK: - Mouse Movement & Layered Cursors
    
    public override func mouseMoved(with event: NSEvent) {
        let rawPoint = convert(event.locationInWindow, from: nil)
        let clampedX = max(0, min(bounds.width, rawPoint.x))
        let clampedY = max(0, min(bounds.height, rawPoint.y))
        let point = CGPoint(x: round(clampedX), y: round(clampedY))
        currentMousePoint = point
        
        if isSavePanelActive {
            NSCursor.arrow.set()
            return
        }
        
        // If hovering over hub, bubble, or toolbarView, show arrow cursor
        if let hub = ocrFloatingHubView, !hub.isHidden, hub.frame.contains(point) {
            NSCursor.arrow.set()
            needsDisplay = true
            return
        }
        if let tb = toolbarView, !tb.secondaryBubble.isHidden, tb.secondaryBubble.frame.contains(point) {
            NSCursor.arrow.set()
            needsDisplay = true
            return
        }
        if let tb = toolbarView, !tb.isHidden, tb.frame.contains(point) {
            NSCursor.arrow.set()
            return
        }
        
        if selectionRect.isEmpty {
            magnifierView.isHidden = false
            magnifierView.targetPoint = point
            positionMagnifierSmartQuadrant(at: point)
            NSCursor.crosshair.set()
        } else {
            if let handle = hitTestHandle(at: point) {
                cursorForHandle(handle).set()
            } else if selectionRect.contains(point) {
                if isOCROverlayActive {
                    NSCursor.iBeam.set()
                } else if canvasView.activeTool != nil {
                    NSCursor.crosshair.set()
                } else {
                    NSCursor.openHand.set()
                }
            } else {
                NSCursor.crosshair.set()
            }
        }
        
        needsDisplay = true
    }
    
    private func positionMagnifierSmartQuadrant(at point: CGPoint) {
        let magSize = magnifierView.frame.size
        let offset: CGFloat = 20.0
        
        var x = point.x + offset
        var y = point.y - magSize.height - offset
        
        if x + magSize.width > bounds.maxX - 10 {
            x = point.x - magSize.width - offset
        }
        if y < bounds.minY + 10 {
            y = point.y + offset
        }
        
        magnifierView.frame = NSRect(origin: CGPoint(x: x, y: y), size: magSize)
        magnifierView.fullBounds = fullBounds
        magnifierView.sourceImage = fullScreenImage
    }
    
    // MARK: - Handle Geometry & Hit Testing
    
    private func handlePoints(for rect: CGRect) -> [CGPoint] {
        return [
            CGPoint(x: rect.minX, y: rect.maxY), // 0: Top-Left
            CGPoint(x: rect.midX, y: rect.maxY), // 1: Top-Center
            CGPoint(x: rect.maxX, y: rect.maxY), // 2: Top-Right
            CGPoint(x: rect.maxX, y: rect.midY), // 3: Right-Center
            CGPoint(x: rect.maxX, y: rect.minY), // 4: Bottom-Right
            CGPoint(x: rect.midX, y: rect.minY), // 5: Bottom-Center
            CGPoint(x: rect.minX, y: rect.minY), // 6: Bottom-Left
            CGPoint(x: rect.minX, y: rect.midY)  // 7: Left-Center
        ]
    }
    
    private func hitTestHandle(at pt: CGPoint) -> Int? {
        guard !selectionRect.isEmpty else { return nil }
        let points = handlePoints(for: selectionRect)
        let tolerance: CGFloat = 10.0
        for (i, p) in points.enumerated() {
            if abs(pt.x - p.x) <= tolerance && abs(pt.y - p.y) <= tolerance {
                return i
            }
        }
        return nil
    }
    
    private func cursorForHandle(_ index: Int) -> NSCursor {
        switch index {
        case 0, 4: return Self.cursorNWSE
        case 2, 6: return Self.cursorNESW
        case 1, 5: return NSCursor.resizeUpDown
        case 3, 7: return NSCursor.resizeLeftRight
        default: return NSCursor.arrow
        }
    }
    
    // MARK: - Mouse Dragging & Actions
    
    public override func mouseDown(with event: NSEvent) {
        if isSavePanelActive { return }
        window?.makeFirstResponder(self)
        let rawPoint = convert(event.locationInWindow, from: nil)
        let clampedX = max(0, min(bounds.width, rawPoint.x))
        let clampedY = max(0, min(bounds.height, rawPoint.y))
        let point = CGPoint(x: round(clampedX), y: round(clampedY))
        currentMousePoint = point
        startDragPoint = point
        initialSelection = selectionRect
        
        // Check double click inside selection -> Copy and Done!
        if event.clickCount == 2 {
            if !selectionRect.isEmpty && selectionRect.contains(point) && canvasView.activeTool == nil {
                toolbarDidClickCopy()
                return
            }
        }
        
        // If clicked Translate HUD, OCR Hub, secondaryBubble, or toolbarView, ignore overlay dragging
        if let hud = translateHUDView, !hud.isHidden, hud.frame.contains(point) {
            return
        }
        if let hub = ocrFloatingHubView, !hub.isHidden, hub.frame.contains(point) {
            return
        }
        if let tb = toolbarView, !tb.secondaryBubble.isHidden, tb.secondaryBubble.frame.contains(point) {
            return
        }
        if let tb = toolbarView, !tb.isHidden, tb.frame.contains(point) {
            return
        }
        
        // If OCR overlay active, check if clicked an individual recognized line
        if isOCROverlayActive, let ocr = ocrResult {
            for item in ocr.lines {
                let box = item.normalizedBox
                let wordRect = CGRect(
                    x: selectionRect.minX + box.origin.x * selectionRect.width,
                    y: selectionRect.minY + box.origin.y * selectionRect.height,
                    width: box.size.width * selectionRect.width,
                    height: box.size.height * selectionRect.height
                )
                if wordRect.contains(point) {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(item.text, forType: .string)
                    NSSound(named: "Tink")?.play()
                    return
                }
            }
        }
        
        // If an annotation tool is active and clicked inside, canvas will handle drawing
        if !selectionRect.isEmpty && canvasView.frame.contains(point) && canvasView.activeTool != nil {
            return
        }
        
        // Check if clicked a resize handle
        if let handle = hitTestHandle(at: point) {
            activeResizingHandle = handle
            return
        }
        
        // Check if clicked inside selection to move it
        if !selectionRect.isEmpty && selectionRect.contains(point) && canvasView.activeTool == nil {
            isMovingSelection = true
            NSCursor.closedHand.set()
            return
        }
        
        // Fluid Re-selection: clicked outside existing selection and outside toolbar
        selectionRect = .zero
        toolbarView?.isHidden = true
        canvasView.isHidden = true
        magnifierView.isHidden = false
        dismissOCROverlay()
        dismissTranslateHUD()
        isUserCustomPositioned = false
        ToolbarTooltipHUD.shared.hide()
        isSelectingNew = true
        selectionRect = CGRect(origin: point, size: .zero)
    }
    
    public override func mouseDragged(with event: NSEvent) {
        if isSavePanelActive { return }
        let rawPoint = convert(event.locationInWindow, from: nil)
        let clampedX = max(0, min(bounds.width, rawPoint.x))
        let clampedY = max(0, min(bounds.height, rawPoint.y))
        let point = CGPoint(x: round(clampedX), y: round(clampedY))
        currentMousePoint = point
        
        // Handle 1: Resizing via Handle
        if let handle = activeResizingHandle {
            resizeSelection(handle: handle, currentPoint: point)
            repositionToolbar()
            return
        }
        
        // Handle 2: Moving existing selection (Strict integer offset)
        if isMovingSelection {
            let dx = round(point.x - startDragPoint.x)
            let dy = round(point.y - startDragPoint.y)
            let moved = initialSelection.offsetBy(dx: dx, dy: dy)
            selectionRect = CGRect(
                x: round(moved.origin.x),
                y: round(moved.origin.y),
                width: round(moved.size.width),
                height: round(moved.size.height)
            ).intersection(bounds)
            repositionToolbar()
            return
        }
        
        // Handle 3: Dragging new selection (Strict integer coordinates)
        if isSelectingNew {
            let minX = round(min(startDragPoint.x, point.x))
            let minY = round(min(startDragPoint.y, point.y))
            let width = round(abs(point.x - startDragPoint.x))
            let height = round(abs(point.y - startDragPoint.y))
            
            selectionRect = CGRect(x: minX, y: minY, width: width, height: height).intersection(bounds)
            magnifierView.targetPoint = point
            magnifierView.selectionSize = selectionRect.size
            positionMagnifierSmartQuadrant(at: point)
        }
    }
    
    private func resizeSelection(handle: Int, currentPoint: CGPoint) {
        let clampedX = max(0, min(bounds.width, currentPoint.x))
        let clampedY = max(0, min(bounds.height, currentPoint.y))
        let pt = CGPoint(x: round(clampedX), y: round(clampedY))
        var rect = initialSelection
        switch handle {
        case 0: // Top-Left
            rect.origin.x = min(pt.x, initialSelection.maxX - 10)
            rect.size.width = initialSelection.maxX - rect.origin.x
            rect.size.height = max(pt.y - initialSelection.minY, 10)
        case 1: // Top-Center
            rect.size.height = max(pt.y - initialSelection.minY, 10)
        case 2: // Top-Right
            rect.size.width = max(pt.x - initialSelection.minX, 10)
            rect.size.height = max(pt.y - initialSelection.minY, 10)
        case 3: // Right-Center
            rect.size.width = max(pt.x - initialSelection.minX, 10)
        case 4: // Bottom-Right
            rect.size.width = max(pt.x - initialSelection.minX, 10)
            rect.origin.y = min(pt.y, initialSelection.maxY - 10)
            rect.size.height = initialSelection.maxY - rect.origin.y
        case 5: // Bottom-Center
            rect.origin.y = min(pt.y, initialSelection.maxY - 10)
            rect.size.height = initialSelection.maxY - rect.origin.y
        case 6: // Bottom-Left
            rect.origin.x = min(pt.x, initialSelection.maxX - 10)
            rect.size.width = initialSelection.maxX - rect.origin.x
            rect.origin.y = min(pt.y, initialSelection.maxY - 10)
            rect.size.height = initialSelection.maxY - rect.origin.y
        case 7: // Left-Center
            rect.origin.x = min(pt.x, initialSelection.maxX - 10)
            rect.size.width = initialSelection.maxX - rect.origin.x
        default:
            break
        }
        
        let roundedRect = CGRect(
            x: round(rect.origin.x),
            y: round(rect.origin.y),
            width: round(rect.size.width),
            height: round(rect.size.height)
        )
        selectionRect = roundedRect.intersection(bounds)
    }
    
    public override func mouseUp(with event: NSEvent) {
        if isSavePanelActive { return }
        let rawPoint = convert(event.locationInWindow, from: nil)
        let point = CGPoint(x: round(rawPoint.x), y: round(rawPoint.y))
        
        if activeResizingHandle != nil {
            activeResizingHandle = nil
            finalizeSelection()
            return
        }
        
        if isMovingSelection {
            isMovingSelection = false
            NSCursor.openHand.set()
            finalizeSelection()
            return
        }
        
        if isSelectingNew {
            isSelectingNew = false
            magnifierView.isHidden = true
            
            // 8px Threshold: If displacement < 8px, treat as single click to snap window!
            let displacement = hypot(point.x - startDragPoint.x, point.y - startDragPoint.y)
            if displacement < 8.0 {
                if let win = detectedWindows.first(where: { $0.frame.contains(point) }) {
                    let snapped = CGRect(
                        x: round(win.frame.origin.x),
                        y: round(win.frame.origin.y),
                        width: round(win.frame.width),
                        height: round(win.frame.height)
                    )
                    selectionRect = snapped.intersection(bounds)
                }
            }
            
            if selectionRect.width >= 10 && selectionRect.height >= 10 {
                finalizeSelection()
            } else {
                selectionRect = .zero
                toolbarView?.isHidden = true
                canvasView.isHidden = true
            }
            needsDisplay = true
        }
    }
    
    private func finalizeSelection() {
        guard !selectionRect.isEmpty else { return }
        
        if captureMode == .translate {
            // Dedicated selection translation mode:
            // 1. Calculate global screen coordinates of selectionRect
            let screenRect = NSRect(
                x: fullBounds.origin.x + selectionRect.origin.x,
                y: fullBounds.origin.y + selectionRect.origin.y,
                width: selectionRect.width,
                height: selectionRect.height
            )
            
            // 2. Crop selected image
            if let fullImage = fullScreenImage,
               let cropped = ScreenCaptureService.shared.crop(image: fullImage, to: selectionRect, fullBounds: fullBounds) {
                // 3. Show independent floating translate window
                TranslateFloatingWindowController.show(image: cropped, nearScreenRect: screenRect)
            }
            
            // 4. Immediately close capture overlay and UNFREEZE screen!
            self.onClose?()
            return
        }
        
        if captureMode == .scroll {
            // Dedicated scrolling capture mode:
            let screenRect = NSRect(
                x: fullBounds.origin.x + selectionRect.origin.x,
                y: fullBounds.origin.y + selectionRect.origin.y,
                width: selectionRect.width,
                height: selectionRect.height
            )
            guard let screen = window?.screen ?? NSScreen.main else { return }
            NSCursor.arrow.set()
            self.onClose?()
            DispatchQueue.main.async {
                ScrollingCaptureSession.shared.startSession(screen: screen, screenRect: screenRect)
            }
            return
        }
        
        // 1. Immediately position and show the toolbar upon drag completion
        repositionToolbar()
        toolbarView?.layer?.zPosition = 100
        toolbarView?.isHidden = false
        
        // 2. Crop background for annotation canvas
        if let fullImage = fullScreenImage,
           let cropped = ScreenCaptureService.shared.crop(image: fullImage, to: selectionRect, fullBounds: fullBounds) {
            canvasView.frame = selectionRect
            canvasView.baseCroppedImage = cropped
            canvasView.isHidden = false
        }
        
        needsDisplay = true
    }
    
    private func repositionToolbar() {
        repositionTranslateHUD()
        guard let tb = toolbarView, !selectionRect.isEmpty else { return }
        let tbWidth: CGFloat = AnnotationToolbarView.standardWidth
        let tbHeight: CGFloat = AnnotationToolbarView.standardHeight
        
        if isUserCustomPositioned {
            let x = min(max(tb.frame.origin.x, 10), bounds.maxX - tbWidth - 10)
            let y = min(max(tb.frame.origin.y, 10), bounds.maxY - tbHeight - 10)
            tb.frame = NSRect(x: x, y: y, width: tbWidth, height: tbHeight)
            tb.updateSubBubblePosition()
            return
        }
        
        // 1. Smart horizontal positioning: right-aligned for normal/large selections, centered for small selections
        let targetX: CGFloat
        if selectionRect.width >= tbWidth {
            targetX = selectionRect.maxX - tbWidth
        } else {
            targetX = selectionRect.midX - tbWidth / 2.0
        }
        let tbX = min(max(targetX, 10), bounds.maxX - tbWidth - 10)
        
        // 2. Vertical positioning: check total space needed below for primary (38) + secondary (32) + gaps (14)
        let totalNeededBelow: CGFloat = tbHeight + SecondaryPaletteBubbleView.standardHeight + 14.0
        var isFlippedAbove = false
        var tbY = selectionRect.minY - tbHeight - 8
        
        // If space below is insufficient for both toolbar and secondary bubble, flip to above the selection!
        if selectionRect.minY - totalNeededBelow < 15 {
            tbY = selectionRect.maxY + 8
            isFlippedAbove = true
        }
        
        // If above screen top, place inside selection
        if tbY + tbHeight > bounds.maxY - 10 {
            tbY = selectionRect.maxY - tbHeight - 8
            isFlippedAbove = false
        }
        
        tb.isFlippedAbove = isFlippedAbove
        tb.frame = NSRect(x: tbX, y: tbY, width: tbWidth, height: tbHeight)
        tb.updateSubBubblePosition()
    }
    
    private func updateSelectionViews() {
        if !selectionRect.isEmpty {
            canvasView.frame = selectionRect
        }
    }
    
    // MARK: - Full-Screen Crosshair & Overlay Drawing
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Subtle dim backdrop
        context.setFillColor(NSColor.black.withAlphaComponent(0.40).cgColor)
        context.fill(bounds)
        
        // 2. Clear out selection area
        if !selectionRect.isEmpty {
            context.saveGState()
            context.setBlendMode(.clear)
            context.fill(selectionRect)
            context.restoreGState()
            
            // 1. Apple Intelligence Violet-Blue Radiant Optical Glow Border:
            context.saveGState()
            // Outer radiant optical glow (radius 8.0, Apple Intelligence luminous violet-blue)
            context.setShadow(
                offset: .zero,
                blur: 8.0,
                color: NSColor(red: 0.55, green: 0.35, blue: 1.0, alpha: 0.85).cgColor
            )
            context.setStrokeColor(NSColor(red: 0.45, green: 0.55, blue: 1.0, alpha: 0.95).cgColor)
            context.setLineWidth(1.8)
            context.stroke(selectionRect.insetBy(dx: -0.5, dy: -0.5))
            
            // Inner crisp core line (radiant light blue)
            context.setShadow(offset: .zero, blur: 0, color: nil)
            context.setStrokeColor(NSColor(red: 0.75, green: 0.88, blue: 1.0, alpha: 0.95).cgColor)
            context.setLineWidth(1.0)
            context.stroke(selectionRect.insetBy(dx: -0.5, dy: -0.5))
            context.restoreGState()
            
            // 8 resize handles (macOS native circular/pill dots)
            drawHandles(for: selectionRect, in: context)
            
            // Dynamic dimension HUD: Frosted glass capsule with subtle border
            let sizeStr = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
            let hudFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold)
            let hudAttrs: [NSAttributedString.Key: Any] = [
                .font: hudFont,
                .foregroundColor: NSColor.white
            ]
            let hudSize = (sizeStr as NSString).size(withAttributes: hudAttrs)
            let hudRect = CGRect(x: selectionRect.minX, y: selectionRect.maxY + 5, width: hudSize.width + 14, height: hudSize.height + 7)
            
            // Frosted dark pill background
            context.setFillColor(NSColor(calibratedWhite: 0.12, alpha: 0.88).cgColor)
            let bgPath = NSBezierPath(roundedRect: hudRect, xRadius: 6, yRadius: 6)
            bgPath.fill()
            
            // Subtle border around HUD
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
            context.setLineWidth(0.8)
            let strokePath = NSBezierPath(roundedRect: hudRect, xRadius: 6, yRadius: 6)
            strokePath.stroke()
            
            (sizeStr as NSString).draw(at: CGPoint(x: hudRect.minX + 7, y: hudRect.minY + 3.5), withAttributes: hudAttrs)
            
            // In-place OCR word bounding boxes
            if isOCROverlayActive, let ocr = ocrResult {
                context.saveGState()
                for item in ocr.lines {
                    let box = item.normalizedBox
                    let wordRect = CGRect(
                        x: selectionRect.minX + box.origin.x * selectionRect.width,
                        y: selectionRect.minY + box.origin.y * selectionRect.height,
                        width: box.size.width * selectionRect.width,
                        height: box.size.height * selectionRect.height
                    )
                    
                    // Translucent highlight
                    context.setFillColor(NSColor(red: 0.45, green: 0.35, blue: 1.0, alpha: 0.22).cgColor)
                    let p = CGPath(roundedRect: wordRect, cornerWidth: 3, cornerHeight: 3, transform: nil)
                    context.addPath(p)
                    context.fillPath()
                    
                    // Subtle stroke
                    context.setStrokeColor(NSColor(red: 0.60, green: 0.45, blue: 1.0, alpha: 0.85).cgColor)
                    context.setLineWidth(1.0)
                    context.addPath(p)
                    context.strokePath()
                }
                context.restoreGState()
            }
        }
        
        // 3. Full-screen Infinite Crosshair Lines with Dual-tone High Contrast
        if selectionRect.isEmpty || isSelectingNew {
            drawInfiniteCrosshair(at: currentMousePoint, in: context)
        }
    }
    
    private func drawInfiniteCrosshair(at pt: CGPoint, in ctx: CGContext) {
        ctx.saveGState()
        
        let scale = window?.backingScaleFactor ?? 2.0
        let halfPixel = 0.5 / scale
        let x = (floor(pt.x * scale) / scale) + halfPixel
        let y = (floor(pt.y * scale) / scale) + halfPixel
        
        // Delicate Hairline (0.5pt / 1 physical pixel on Retina) with soft 75% opacity
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.75).cgColor)
        ctx.setLineWidth(1.0 / scale)
        ctx.move(to: CGPoint(x: bounds.minX, y: y))
        ctx.addLine(to: CGPoint(x: bounds.maxX, y: y))
        ctx.move(to: CGPoint(x: x, y: bounds.minY))
        ctx.addLine(to: CGPoint(x: x, y: bounds.maxY))
        ctx.strokePath()
        
        ctx.restoreGState()
    }
    
    private func drawHandles(for rect: CGRect, in ctx: CGContext) {
        let handleSize: CGFloat = 8.0
        let points = handlePoints(for: rect)
        
        ctx.saveGState()
        for pt in points {
            let handleRect = CGRect(x: pt.x - handleSize/2, y: pt.y - handleSize/2, width: handleSize, height: handleSize)
            
            // Drop shadow with slight purple-blue tint
            ctx.setFillColor(NSColor(red: 0.2, green: 0.1, blue: 0.4, alpha: 0.4).cgColor)
            let shadowPath = CGPath(roundedRect: handleRect.offsetBy(dx: 0, dy: -1), cornerWidth: 4, cornerHeight: 4, transform: nil)
            ctx.addPath(shadowPath)
            ctx.fillPath()
            
            // Solid white fill with pill/circular corners
            ctx.setFillColor(NSColor.white.cgColor)
            let path = CGPath(roundedRect: handleRect, cornerWidth: 4, cornerHeight: 4, transform: nil)
            ctx.addPath(path)
            ctx.fillPath()
            
            // Apple Intelligence Violet-Blue border
            ctx.setStrokeColor(NSColor(red: 0.55, green: 0.35, blue: 1.0, alpha: 0.95).cgColor)
            ctx.setLineWidth(1.5)
            ctx.addPath(path)
            ctx.strokePath()
        }
        ctx.restoreGState()
    }
    
    // MARK: - In-place OCR Floating Action Hub
    
    private func showInPlaceOCR(ocr: OCRResult) {
        self.ocrResult = ocr
        self.isOCROverlayActive = true
        
        if ocrFloatingHubView == nil {
            let hub = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 320, height: 36))
            hub.material = .hudWindow
            hub.blendingMode = .withinWindow
            hub.state = .active
            hub.wantsLayer = true
            hub.layer?.cornerRadius = 8
            hub.layer?.masksToBounds = true
            hub.layer?.backgroundColor = NSColor(calibratedWhite: 0.15, alpha: 0.95).cgColor
            hub.layer?.borderColor = NSColor.systemTeal.withAlphaComponent(0.5).cgColor
            hub.layer?.borderWidth = 1.0
            
            let stack = NSStackView()
            stack.orientation = .horizontal
            stack.alignment = .centerY
            stack.spacing = 6
            stack.translatesAutoresizingMaskIntoConstraints = false
            hub.addSubview(stack)
            
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: hub.leadingAnchor, constant: 8),
                stack.trailingAnchor.constraint(equalTo: hub.trailingAnchor, constant: -8),
                stack.centerYAnchor.constraint(equalTo: hub.centerYAnchor)
            ])
            
            let btnCopy = NSButton(title: "📋 " + L10n("ocr.copy_all"), target: self, action: #selector(btnOCRCopyAllClicked))
            btnCopy.bezelStyle = .inline
            btnCopy.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
            stack.addArrangedSubview(btnCopy)
            
            let btnTrans = NSButton(title: "🌐 " + L10n("ocr.translate"), target: self, action: #selector(btnOCRTranslateClicked))
            btnTrans.bezelStyle = .inline
            btnTrans.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            stack.addArrangedSubview(btnTrans)
            
            let btnClose = NSButton(title: "✕", target: self, action: #selector(dismissOCROverlay))
            btnClose.bezelStyle = .inline
            btnClose.font = NSFont.systemFont(ofSize: 11, weight: .bold)
            stack.addArrangedSubview(btnClose)
            
            addSubview(hub)
            self.ocrFloatingHubView = hub
        }
        
        repositionOCRHub()
        ocrFloatingHubView?.isHidden = false
        needsDisplay = true
    }
    
    private func repositionOCRHub() {
        guard let hub = ocrFloatingHubView, !selectionRect.isEmpty else { return }
        let hubW: CGFloat = 320.0
        let hubH: CGFloat = 36.0
        let x = min(max(selectionRect.maxX - hubW, 20), bounds.maxX - hubW - 20)
        let y = min(selectionRect.maxY + 6, bounds.maxY - hubH - 10)
        hub.frame = NSRect(x: x, y: y, width: hubW, height: hubH)
    }
    
    @objc private func dismissOCROverlay() {
        isOCROverlayActive = false
        ocrResult = nil
        ocrFloatingHubView?.removeFromSuperview()
        ocrFloatingHubView = nil
        needsDisplay = true
    }
    
    @objc private func btnOCRCopyAllClicked() {
        guard let text = ocrResult?.fullText, !text.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        NSSound(named: "Tink")?.play()
    }
    
    @objc private func btnOCRTranslateClicked() {
        if let text = ocrResult?.fullText, !text.isEmpty {
            showInPlaceTranslate(initialText: text)
        } else if let finalImage = getRenderedImage() {
            showInPlaceTranslate(sourceImage: finalImage)
        }
    }
    
    // MARK: - In-place Dual-Column Translation HUD
    
    private func showInPlaceTranslate(sourceImage: NSImage? = nil, initialText: String? = nil) {
        dismissTranslateHUD()
        
        let vm = InPlaceTranslateViewModel()
        vm.onClose = { [weak self] in
            self?.dismissTranslateHUD()
            if self?.captureMode == .translate {
                self?.onClose?()
            }
        }
        vm.onCopyFinished = { [weak self] in
            self?.dismissTranslateHUD()
            self?.onClose?()
        }
        
        let hud = InPlaceTranslateHUDHostingView(viewModel: vm)
        self.translateHUDView = hud
        addSubview(hud)
        repositionTranslateHUD()
        
        if let text = initialText, !text.isEmpty {
            vm.startTranslation(with: text)
        } else if let image = sourceImage ?? getRenderedImage() {
            vm.isLoading = true
            VisionOCRService.shared.recognizeText(from: image) { [weak vm] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let ocr):
                        vm?.startTranslation(with: ocr.fullText)
                    case .failure(let err):
                        vm?.isLoading = false
                        vm?.errorMessage = "\(L10n("ocr.recognize_fail")): \(err.localizedDescription)"
                    }
                }
            }
        }
    }
    
    private func repositionTranslateHUD() {
        guard let hud = translateHUDView, !selectionRect.isEmpty else { return }
        let hudW: CGFloat = 520.0
        let hudH: CGFloat = 260.0
        
        var x = selectionRect.midX - (hudW / 2.0)
        x = min(max(x, 16), bounds.maxX - hudW - 16)
        
        var y: CGFloat
        if selectionRect.minY >= hudH + 20 {
            y = selectionRect.minY - hudH - 12
        } else if bounds.maxY - selectionRect.maxY >= hudH + 20 {
            y = selectionRect.maxY + 12
        } else {
            y = min(max(selectionRect.midY - (hudH / 2.0), 16), bounds.maxY - hudH - 16)
        }
        
        hud.frame = NSRect(x: x, y: y, width: hudW, height: hudH)
    }
    
    private func dismissTranslateHUD() {
        translateHUDView?.removeFromSuperview()
        translateHUDView = nil
        needsDisplay = true
    }
    
    // MARK: - AnnotationCanvasDelegate Actions
    
    public func canvasDidSelectElement(_ element: AnnotationElement?) {
        toolbarView?.reflectElementProperties(element)
    }
    
    // MARK: - AnnotationToolbarDelegate Actions
    
    public func toolbarDidSelectTool(_ tool: AnnotationToolType?) {
        canvasView.activeTool = tool
    }
    
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
    
    public func toolbarDidClickOCR() {
        guard let finalImage = getRenderedImage() else { return }
        VisionOCRService.shared.recognizeText(from: finalImage) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let ocr):
                self.showInPlaceOCR(ocr: ocr)
            case .failure(let err):
                let empty = OCRResult(fullText: "\(L10n("ocr.recognize_fail")): \(err.localizedDescription)")
                self.showInPlaceOCR(ocr: empty)
            }
        }
    }
    
    public func toolbarDidClickTranslate() {
        if selectionRect.isEmpty || selectionRect.width < 10 || selectionRect.height < 10 {
            if let win = detectedWindows.first(where: { $0.frame.contains(currentMousePoint) }) {
                selectionRect = win.frame.intersection(bounds)
            } else {
                selectionRect = bounds
            }
        }
        guard let finalImage = getRenderedImage() else { return }
        showInPlaceTranslate(sourceImage: finalImage)
    }
    
    // MARK: - GIF Recording Controls
    
    public func toolbarDidClickRecordGIF() {
        if selectionRect.isEmpty || selectionRect.width < 10 || selectionRect.height < 10 {
            if let win = detectedWindows.first(where: { $0.frame.contains(currentMousePoint) }) {
                selectionRect = win.frame.intersection(bounds)
            } else {
                selectionRect = bounds
            }
        }
        guard let screen = window?.screen ?? NSScreen.main else { return }
        
        let screenRect = NSRect(
            x: fullBounds.origin.x + selectionRect.origin.x,
            y: fullBounds.origin.y + selectionRect.origin.y,
            width: selectionRect.width,
            height: selectionRect.height
        )
        
        // Immediately dismiss overlay window to release full-screen dimming and focus
        ToolbarTooltipHUD.shared.hide()
        onClose?()
        
        // Launch CleanShot-style dual-window recording session
        DispatchQueue.main.async {
            GIFRecordingSession.shared.startSession(screen: screen, screenRect: screenRect)
        }
    }
    
    // MARK: - Scrolling Capture Controls
    
    public func toolbarDidClickScrollCapture() {
        if selectionRect.isEmpty || selectionRect.width < 10 || selectionRect.height < 10 {
            if let win = detectedWindows.first(where: { $0.frame.contains(currentMousePoint) }) {
                selectionRect = win.frame.intersection(bounds)
            } else {
                selectionRect = bounds
            }
        }
        guard let screen = window?.screen ?? NSScreen.main else { return }
        
        let screenRect = NSRect(
            x: fullBounds.origin.x + selectionRect.origin.x,
            y: fullBounds.origin.y + selectionRect.origin.y,
            width: selectionRect.width,
            height: selectionRect.height
        )
        
        // Dismiss overlay
        NSCursor.arrow.set()
        ToolbarTooltipHUD.shared.hide()
        onClose?()
        
        // Launch scrolling capture session
        DispatchQueue.main.async {
            ScrollingCaptureSession.shared.startSession(screen: screen, screenRect: screenRect)
        }
    }
    
    public func toolbarDidClickPin() {
        if selectionRect.isEmpty || selectionRect.width < 10 || selectionRect.height < 10 {
            if let win = detectedWindows.first(where: { $0.frame.contains(currentMousePoint) }) {
                selectionRect = win.frame.intersection(bounds)
            } else {
                selectionRect = bounds
            }
        }
        guard let finalImage = getRenderedImage() else { return }
        HistoryManager.shared.recordCapture(finalImage)
        let screenRect = NSRect(
            x: fullBounds.origin.x + selectionRect.origin.x,
            y: fullBounds.origin.y + selectionRect.origin.y,
            width: selectionRect.width,
            height: selectionRect.height
        )
        let pin = PinWindowManager.shared.createPin(from: finalImage, initialFrame: screenRect)
        onClose?()
        DispatchQueue.main.async {
            pin.orderFrontRegardless()
            pin.makeKeyAndOrderFront(nil)
        }
    }
    
    public func toolbarDidClickSave() {
        guard let finalImage = getRenderedImage() else { return }
        HistoryManager.shared.recordCapture(finalImage)
        
        isSavePanelActive = true
        let config = AppConfig.load()
        
        let savePanel = NSSavePanel()
        let isJpeg = config.imageSaveFormat.uppercased() == "JPEG"
        savePanel.allowedContentTypes = isJpeg ? [.jpeg, .png] : [.png, .jpeg]
        
        let ext = isJpeg ? "jpg" : "png"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd-HHmmss"
        savePanel.nameFieldStringValue = "SnipSnap_\(df.string(from: Date())).\(ext)"
        
        if !config.defaultSavePath.isEmpty {
            let dirURL = URL(fileURLWithPath: config.defaultSavePath)
            if FileManager.default.fileExists(atPath: dirURL.path) {
                savePanel.directoryURL = dirURL
            }
        }
        
        // Elevate save panel above the full-screen overlay window (.popUpMenu = 101)
        savePanel.level = NSWindow.Level(Int(CGWindowLevelForKey(.popUpMenuWindow)) + 1)
        NSApp.activate(ignoringOtherApps: true)
        
        savePanel.begin { [weak self] response in
            guard let self = self else { return }
            self.isSavePanelActive = false
            
            if response == .OK, let url = savePanel.url {
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
                if config.playSoundEffect {
                    NSSound(named: "Tink")?.play()
                }
                self.onClose?()
            } else {
                // User cancelled: keep selection and annotations, restore key window focus
                self.window?.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    public func toolbarDidClickCopy() {
        guard let finalImage = getRenderedImage() else { return }
        HistoryManager.shared.recordCapture(finalImage)
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
        
        // Multi-channel pasteboard: TIFF for native Mac apps, PNG for Web/Electron/WeChat, fileURL for Finder
        pb.declareTypes([.tiff, .png, .fileURL], owner: nil)
        if let tiff = finalImage.tiffRepresentation {
            pb.setData(tiff, forType: .tiff)
        }
        if let png = pngData {
            pb.setData(png, forType: .png)
        }
        (fileURL as NSURL).write(to: pb)
        
        let config = AppConfig.load()
        autoSaveImageIfNeeded(finalImage, config: config)
        
        if config.playSoundEffect {
            NSSound(named: "Tink")?.play()
        }
        onClose?()
    }
    
    private func autoSaveImageIfNeeded(_ image: NSImage, config: AppConfig) {
        guard config.autoSaveAfterCapture else { return }
        
        let saveDir: URL
        if !config.defaultSavePath.isEmpty && FileManager.default.fileExists(atPath: config.defaultSavePath) {
            saveDir = URL(fileURLWithPath: config.defaultSavePath)
        } else if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            saveDir = desktop
        } else {
            return
        }
        
        let isJpeg = config.imageSaveFormat.uppercased() == "JPEG"
        let ext = isJpeg ? "jpg" : "png"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let baseName = "SnipSnap_\(df.string(from: Date()))"
        var fileURL = saveDir.appendingPathComponent("\(baseName).\(ext)")
        
        var counter = 1
        while FileManager.default.fileExists(atPath: fileURL.path) {
            fileURL = saveDir.appendingPathComponent("\(baseName)_\(counter).\(ext)")
            counter += 1
        }
        
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return }
        
        let data = isJpeg
            ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
            : rep.representation(using: .png, properties: [:])
            
        if let data = data {
            try? data.write(to: fileURL)
        }
    }
    
    public func toolbarDidClickClose() {
        ToolbarTooltipHUD.shared.hide()
        handleCascadedDismiss()
    }
    
    public func toolbarDidDrag(delta: CGPoint) {
        guard let tb = toolbarView else { return }
        isUserCustomPositioned = true
        var newOrigin = tb.frame.origin
        newOrigin.x += delta.x
        newOrigin.y += delta.y
        newOrigin.x = min(max(newOrigin.x, 10), bounds.maxX - tb.frame.width - 10)
        newOrigin.y = min(max(newOrigin.y, 10), bounds.maxY - tb.frame.height - 10)
        tb.frame.origin = newOrigin
        tb.updateSubBubblePosition()
    }
    
    private func getRenderedImage() -> NSImage? {
        guard let fullImage = fullScreenImage,
              let cropped = ScreenCaptureService.shared.crop(image: fullImage, to: selectionRect, fullBounds: fullBounds) else {
            return nil
        }
        // Direct zero-loss return when no annotations added, avoiding NSImage.lockFocus() resampling
        if canvasView.elements.isEmpty {
            return cropped
        }
        return canvasView.renderComposite(baseImage: cropped)
    }
}
