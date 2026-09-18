import Cocoa
import CoreImage

public protocol AnnotationCanvasDelegate: AnyObject {
    func canvasDidSelectElement(_ element: AnnotationElement?)
}

private class AnnotationInlineTextView: NSTextView {
    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onContentChanged: (() -> Void)?
    
    override func didChangeText() {
        super.didChangeText()
        bounds.origin = .zero
        onContentChanged?()
    }
    
    override func scroll(_ point: NSPoint) {
        super.scroll(.zero)
    }
    
    override func scrollRangeToVisible(_ range: NSRange) {
        bounds.origin = .zero
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onCancel?()
            return
        }
        if (event.keyCode == 36 || event.keyCode == 76) && (event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control)) {
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }
    
    override func scrollWheel(with event: NSEvent) {
        superview?.scrollWheel(with: event)
    }
}

public class AnnotationCanvasView: NSView {
    public weak var delegate: AnnotationCanvasDelegate?
    
    public var activeTool: AnnotationToolType? = nil {
        didSet {
            commitActiveTextEditor()
            if activeTool != nil {
                deselectAll()
            }
        }
    }
    public var currentColor: NSColor = .systemRed {
        didSet {
            updateSelectedElementProperty { $0.strokeColor = currentColor }
            if editingExistingElement != nil {
                editingExistingElement?.strokeColor = currentColor
            }
            activeTextView?.textColor = currentColor
            activeTextView?.insertionPointColor = currentColor.isDarkColor ? .white : currentColor
        }
    }
    public var currentStrokeWidth: CGFloat = 3.0 {
        didSet {
            updateSelectedElementProperty { $0.strokeWidth = currentStrokeWidth }
        }
    }
    public var currentFontSize: CGFloat = 18.0 {
        didSet {
            updateSelectedElementProperty { $0.fontSize = currentFontSize }
            if editingExistingElement != nil {
                editingExistingElement?.fontSize = currentFontSize
            }
            if let tv = activeTextView {
                tv.font = NSFont.boldSystemFont(ofSize: currentFontSize)
                adjustInlineTextViewSize(tv)
            }
        }
    }
    public var currentTextStyle: TextStyleMode = .plain {
        didSet {
            updateSelectedElementProperty { $0.textStyleMode = currentTextStyle }
            if editingExistingElement != nil {
                editingExistingElement?.textStyleMode = currentTextStyle
            }
        }
    }
    public var currentTextBackground: TextBackgroundStyle {
        get { currentTextStyle }
        set { currentTextStyle = newValue }
    }
    public var currentMosaicType: MosaicType = .pixel {
        didSet {
            updateSelectedElementProperty { $0.mosaicType = currentMosaicType }
        }
    }
    public var currentMosaicBlockSize: CGFloat = 14.0 {
        didSet {
            updateSelectedElementProperty { $0.mosaicBlockSize = currentMosaicBlockSize }
        }
    }
    public var currentCounterStyle: CounterStyle = .filled {
        didSet {
            updateSelectedElementProperty { $0.counterStyle = currentCounterStyle }
        }
    }
    
    public var baseCroppedImage: NSImage?
    
    public private(set) var elements: [AnnotationElement] = []
    private var undoStack: [[AnnotationElement]] = []
    private var redoStack: [[AnnotationElement]] = []
    
    private var currentElement: AnnotationElement?
    public private(set) var counterIndex: Int = 1
    
    // Object selection state (Vector Hybrid Mode)
    public private(set) var selectedElementIndex: Int? = nil
    private var dragStartMousePoint: CGPoint = .zero
    private var isMovingSelectedElement: Bool = false
    
    private var activeTextView: AnnotationInlineTextView?
    private var editingExistingElement: AnnotationElement?
    private var textAnchorLeft: CGFloat = 0
    private var textAnchorTop: CGFloat = 0
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override var acceptsFirstResponder: Bool { true }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        if activeTool != nil || activeTextView != nil {
            return super.hitTest(point)
        }
        
        // When no active tool, if point hits an existing vector element, allow selecting & moving it!
        let local = convert(point, from: superview)
        if elements.contains(where: { $0.contains(point: local) }) {
            return self
        }
        
        // Otherwise pass through to CaptureOverlayView for selection handles & overall moving
        return nil
    }
    
    // MARK: - Undo / Redo
    
    public func recordUndoState() {
        undoStack.append(elements)
        redoStack.removeAll()
    }
    
    public func undo() {
        commitActiveTextEditor()
        guard let lastState = undoStack.popLast() else { return }
        redoStack.append(elements)
        elements = lastState
        selectedElementIndex = nil
        needsDisplay = true
    }
    
    public func redo() {
        commitActiveTextEditor()
        guard let nextState = redoStack.popLast() else { return }
        undoStack.append(elements)
        elements = nextState
        selectedElementIndex = nil
        needsDisplay = true
    }
    
    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    
    public func resetCounter() {
        counterIndex = 1
    }
    
    public func clearAll() {
        commitActiveTextEditor()
        elements.removeAll()
        undoStack.removeAll()
        redoStack.removeAll()
        selectedElementIndex = nil
        currentElement = nil
        needsDisplay = true
    }
    
    // MARK: - Selection Management
    
    public func deselectAll() {
        if selectedElementIndex != nil {
            selectedElementIndex = nil
            for i in 0..<elements.count {
                elements[i].isSelected = false
            }
            delegate?.canvasDidSelectElement(nil)
            needsDisplay = true
        }
    }
    
    public func deleteSelectedElement() {
        guard let idx = selectedElementIndex, idx < elements.count else { return }
        recordUndoState()
        elements.remove(at: idx)
        selectedElementIndex = nil
        delegate?.canvasDidSelectElement(nil)
        needsDisplay = true
    }
    
    private func updateSelectedElementProperty(_ block: (inout AnnotationElement) -> Void) {
        guard let idx = selectedElementIndex, idx < elements.count else { return }
        recordUndoState()
        block(&elements[idx])
        if elements[idx].type == .text {
            let font = NSFont.boldSystemFont(ofSize: elements[idx].fontSize)
            let lines = elements[idx].text.components(separatedBy: "\n")
            let maxLineWidth = lines.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 60
            let lineHeight = font.ascender - font.descender + font.leading
            let contentHeight = lineHeight * CGFloat(max(lines.count, 1))
            let newW = maxLineWidth + 28
            let newH = contentHeight + 16
            var f = elements[idx].textRect
            let top = f.origin.y + f.size.height
            f.size = CGSize(width: newW, height: newH)
            f.origin.y = top - newH
            elements[idx].textRect = f
        }
        needsDisplay = true
    }
    
    // MARK: - Keyboard Handling (Delete / Backspace / Esc)
    
    public override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 { // Backspace or Delete
            if selectedElementIndex != nil {
                deleteSelectedElement()
                return
            }
        } else if event.keyCode == 53 { // Escape
            if selectedElementIndex != nil {
                deselectAll()
                return
            }
        }
        super.keyDown(with: event)
    }
    
    // MARK: - Mouse & Scroll Events for Drawing & Object Editing
    
    public override func scrollWheel(with event: NSEvent) {
        // 1. If inline text view is currently active, continuously scale its font size
        if activeTextView != nil {
            let delta = event.scrollingDeltaY
            if abs(delta) > 0.1 {
                let step: CGFloat = delta > 0 ? 1.0 : -1.0
                let newSize = min(max(currentFontSize + step, 10.0), 72.0)
                if newSize != currentFontSize {
                    currentFontSize = newSize
                }
            }
            return
        }
        
        // 2. If a text element is currently selected, continuously scale its font size
        if let idx = selectedElementIndex, idx < elements.count, elements[idx].type == .text {
            let delta = event.scrollingDeltaY
            if abs(delta) > 0.1 {
                let step: CGFloat = delta > 0 ? 1.0 : -1.0
                let newSize = min(max(elements[idx].fontSize + step, 10.0), 72.0)
                if newSize != elements[idx].fontSize {
                    currentFontSize = newSize
                }
            }
            return
        }
        
        super.scrollWheel(with: event)
    }
    
    public override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let localPoint = convert(event.locationInWindow, from: nil)
        dragStartMousePoint = localPoint
        
        // 1. If inline text editor is active and click is outside, commit it
        if let tv = activeTextView {
            if !tv.frame.contains(localPoint) {
                commitActiveTextEditor()
            } else {
                return
            }
        }
        
        // 2. Double-click re-editing: double click any existing text element to edit in place
        if event.clickCount == 2 {
            if let hitIndex = elements.lastIndex(where: { $0.type == .text && $0.contains(point: localPoint) }) {
                recordUndoState()
                let hitElem = elements.remove(at: hitIndex)
                selectedElementIndex = nil
                needsDisplay = true
                beginEditingText(elem: hitElem)
                return
            }
        }
        
        // Mode A: Tool is Active (Continuous Drawing Mode)
        if let tool = activeTool {
            deselectAll()
            
            if tool == .text {
                handleTextToolClick(at: localPoint)
                return
            }
            
            if tool == .counter {
                recordUndoState()
                var elem = AnnotationElement(type: .counter)
                elem.startPoint = localPoint
                elem.strokeColor = currentColor
                elem.counterNumber = counterIndex
                elem.counterStyle = currentCounterStyle
                counterIndex += 1
                elements.append(elem)
                needsDisplay = true
                return
            }
            
            recordUndoState()
            var elem = AnnotationElement(type: tool)
            elem.startPoint = localPoint
            elem.endPoint = localPoint
            elem.strokeColor = currentColor
            elem.strokeWidth = currentStrokeWidth
            elem.mosaicType = currentMosaicType
            elem.mosaicBlockSize = currentMosaicBlockSize
            if tool == .brush || tool == .highlighter {
                elem.points = [localPoint]
            }
            currentElement = elem
            needsDisplay = true
            return
        }
        
        // Mode B: Pointer / Select Mode (Vector Object Selection & Manipulation)
        if let hitIndex = elements.lastIndex(where: { $0.contains(point: localPoint) }) {
            recordUndoState()
            deselectAll()
            selectedElementIndex = hitIndex
            elements[hitIndex].isSelected = true
            isMovingSelectedElement = true
            NSCursor.closedHand.set()
            delegate?.canvasDidSelectElement(elements[hitIndex])
            needsDisplay = true
        } else {
            deselectAll()
        }
    }
    
    public override func mouseDragged(with event: NSEvent) {
        let localPoint = convert(event.locationInWindow, from: nil)
        let delta = CGPoint(x: localPoint.x - dragStartMousePoint.x, y: localPoint.y - dragStartMousePoint.y)
        dragStartMousePoint = localPoint
        
        // Mode A: Dragging to create new element
        if activeTool != nil, var elem = currentElement {
            elem.endPoint = localPoint
            if elem.type == .brush || elem.type == .highlighter {
                elem.points.append(localPoint)
            }
            currentElement = elem
            needsDisplay = true
            return
        }
        
        // Mode B: Dragging to move selected vector element
        if isMovingSelectedElement, let idx = selectedElementIndex, idx < elements.count {
            elements[idx].offset(by: delta)
            needsDisplay = true
            return
        }
        
        super.mouseDragged(with: event)
    }
    
    public override func mouseUp(with event: NSEvent) {
        if isMovingSelectedElement {
            isMovingSelectedElement = false
            NSCursor.openHand.set()
            needsDisplay = true
            return
        }
        
        guard activeTool != nil, let elem = currentElement else {
            super.mouseUp(with: event)
            return
        }
        
        // Continuous Drawing: Add element to vector list, keep tool active!
        elements.append(elem)
        currentElement = nil
        needsDisplay = true
    }
    
    // MARK: - Text Tool Handling & Inline Editing
    
    private func handleTextToolClick(at point: CGPoint) {
        commitActiveTextEditor()
        editingExistingElement = nil
        createInlineTextView(at: point, initialText: "", fontSize: currentFontSize, color: currentColor, style: currentTextStyle)
    }
    
    private func beginEditingText(elem: AnnotationElement) {
        commitActiveTextEditor()
        editingExistingElement = elem
        currentFontSize = elem.fontSize
        currentColor = elem.strokeColor
        currentTextStyle = elem.textStyleMode
        delegate?.canvasDidSelectElement(elem)
        createInlineTextView(at: elem.textRect.origin, initialText: elem.text, fontSize: elem.fontSize, color: elem.strokeColor, style: elem.textStyleMode, existingFrame: elem.textRect)
    }
    
    private func createInlineTextView(at origin: CGPoint, initialText: String, fontSize: CGFloat, color: NSColor, style: TextStyleMode, existingFrame: CGRect? = nil) {
        let initialWidth: CGFloat = 140
        let initialHeight: CGFloat = max(fontSize + 16, 36)
        
        if let ef = existingFrame, ef.width > 10, ef.height > 10 {
            textAnchorLeft = ef.origin.x
            textAnchorTop = ef.origin.y + ef.size.height
        } else {
            textAnchorLeft = origin.x
            textAnchorTop = origin.y + 10
        }
        
        let frame = NSRect(x: textAnchorLeft, y: textAnchorTop - initialHeight, width: initialWidth, height: initialHeight)
        
        let tv = AnnotationInlineTextView(frame: frame)
        let font = NSFont.boldSystemFont(ofSize: fontSize)
        tv.font = font
        tv.textColor = color
        tv.string = initialText
        tv.isRichText = false
        tv.allowsUndo = true
        tv.drawsBackground = true
        tv.backgroundColor = NSColor(calibratedWhite: 0.12, alpha: 0.85)
        tv.wantsLayer = true
        tv.layer?.cornerRadius = 6
        tv.layer?.borderWidth = 1.5
        tv.layer?.borderColor = NSColor(calibratedWhite: 0.7, alpha: 0.6).cgColor
        tv.textContainerInset = NSSize(width: 8, height: 6)
        tv.isVerticallyResizable = false
        tv.isHorizontallyResizable = false
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.heightTracksTextView = false
        tv.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.insertionPointColor = color.isDarkColor ? .white : color
        tv.focusRingType = .none
        
        tv.onCommit = { [weak self] in
            self?.commitActiveTextEditor()
        }
        tv.onCancel = { [weak self] in
            self?.cancelActiveTextEditor()
        }
        tv.onContentChanged = { [weak self, weak tv] in
            guard let tv = tv else { return }
            self?.adjustInlineTextViewSize(tv)
        }
        
        addSubview(tv)
        window?.makeFirstResponder(tv)
        if !initialText.isEmpty {
            tv.selectAll(nil)
        }
        activeTextView = tv
        adjustInlineTextViewSize(tv)
    }
    
    private func adjustInlineTextViewSize(_ tv: AnnotationInlineTextView) {
        let font = tv.font ?? NSFont.boldSystemFont(ofSize: currentFontSize)
        let text = tv.string.isEmpty ? " " : tv.string
        let lines = text.components(separatedBy: "\n")
        let maxLineWidth = lines.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 60
        let lineHeight = font.ascender - font.descender + font.leading
        let contentHeight = lineHeight * CGFloat(max(lines.count, 1))
        let newWidth = max(maxLineWidth + 28, 140)
        let newHeight = max(contentHeight + 16, 36)
        
        // Rock-solid anchor at (textAnchorLeft, textAnchorTop): never shifts left or jumps when typing!
        tv.frame = NSRect(x: textAnchorLeft, y: textAnchorTop - newHeight, width: newWidth, height: newHeight)
        tv.bounds.origin = .zero
    }
    
    public func commitActiveTextEditor() {
        guard let tv = activeTextView else { return }
        let text = tv.string.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            recordUndoState()
            var elem = editingExistingElement ?? AnnotationElement(type: .text)
            elem.type = .text
            elem.text = text
            elem.fontSize = tv.font?.pointSize ?? currentFontSize
            elem.strokeColor = tv.textColor ?? currentColor
            elem.textStyleMode = currentTextStyle
            
            let font = tv.font ?? NSFont.boldSystemFont(ofSize: elem.fontSize)
            let lines = text.components(separatedBy: "\n")
            let maxLineWidth = lines.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 60
            let lineHeight = font.ascender - font.descender + font.leading
            let contentHeight = lineHeight * CGFloat(max(lines.count, 1))
            
            let rectH = max(contentHeight + 16, 36)
            let rectW = max(maxLineWidth + 28, 140)
            elem.textRect = CGRect(x: textAnchorLeft, y: textAnchorTop - rectH, width: rectW, height: rectH)
            elem.startPoint = elem.textRect.origin
            elements.append(elem)
        }
        editingExistingElement = nil
        tv.removeFromSuperview()
        activeTextView = nil
        textAnchorLeft = 0
        textAnchorTop = 0
        needsDisplay = true
    }
    
    public func cancelActiveTextEditor() {
        guard let tv = activeTextView else { return }
        if let oldElem = editingExistingElement {
            elements.append(oldElem)
        }
        editingExistingElement = nil
        tv.removeFromSuperview()
        activeTextView = nil
        textAnchorLeft = 0
        textAnchorTop = 0
        needsDisplay = true
    }
    
    // MARK: - Drawing & Rendering
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        for elem in elements {
            drawElement(elem, in: context)
        }
        
        if let current = currentElement {
            drawElement(current, in: context)
        }
        
        // Draw selection adornment for selected vector object
        if let idx = selectedElementIndex, idx < elements.count {
            drawSelectionAdornment(for: elements[idx], in: context)
        }
    }
    
    private func drawSelectionAdornment(for elem: AnnotationElement, in ctx: CGContext) {
        ctx.saveGState()
        let b = elem.bounds().insetBy(dx: -4, dy: -4)
        
        // Dashed bounding box
        ctx.setStrokeColor(NSColor.systemTeal.cgColor)
        ctx.setLineWidth(1.5)
        ctx.setLineDash(phase: 0, lengths: [4, 4])
        ctx.stroke(b)
        
        // Corner handles
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.setStrokeColor(NSColor.systemTeal.cgColor)
        ctx.setLineWidth(1.0)
        ctx.setLineDash(phase: 0, lengths: [])
        
        let handleSize: CGFloat = 6.0
        let corners = [
            CGPoint(x: b.minX, y: b.minY),
            CGPoint(x: b.maxX, y: b.minY),
            CGPoint(x: b.maxX, y: b.maxY),
            CGPoint(x: b.minX, y: b.maxY)
        ]
        for pt in corners {
            let hr = CGRect(x: pt.x - handleSize/2, y: pt.y - handleSize/2, width: handleSize, height: handleSize)
            ctx.fill(hr)
            ctx.stroke(hr)
        }
        
        ctx.restoreGState()
    }
    
    private func drawElement(_ elem: AnnotationElement, in ctx: CGContext) {
        ctx.saveGState()
        
        switch elem.type {
        case .rectangle:
            let rect = elem.bounds()
            ctx.setStrokeColor(elem.strokeColor.cgColor)
            ctx.setLineWidth(elem.strokeWidth)
            let path = CGPath(roundedRect: rect, cornerWidth: 3, cornerHeight: 3, transform: nil)
            ctx.addPath(path)
            ctx.strokePath()
            
        case .ellipse:
            let rect = elem.bounds()
            ctx.setStrokeColor(elem.strokeColor.cgColor)
            ctx.setLineWidth(elem.strokeWidth)
            ctx.strokeEllipse(in: rect)
            
        case .line:
            ctx.setStrokeColor(elem.strokeColor.cgColor)
            ctx.setLineWidth(elem.strokeWidth)
            ctx.setLineCap(.round)
            ctx.move(to: elem.startPoint)
            ctx.addLine(to: elem.endPoint)
            ctx.strokePath()
            
        case .arrow:
            drawArrow(from: elem.startPoint, to: elem.endPoint, color: elem.strokeColor, width: elem.strokeWidth, in: ctx)
            
        case .brush:
            guard elem.points.count > 1 else { break }
            ctx.setStrokeColor(elem.strokeColor.cgColor)
            ctx.setLineWidth(elem.strokeWidth)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)
            ctx.move(to: elem.points[0])
            for pt in elem.points.dropFirst() {
                ctx.addLine(to: pt)
            }
            ctx.strokePath()
            
        case .highlighter:
            guard elem.points.count > 1 else { break }
            ctx.setStrokeColor(elem.strokeColor.withAlphaComponent(0.4).cgColor)
            ctx.setLineWidth(elem.strokeWidth * 3.5)
            ctx.setLineCap(.square)
            ctx.setLineJoin(.bevel)
            ctx.setBlendMode(.normal)
            ctx.move(to: elem.points[0])
            for pt in elem.points.dropFirst() {
                ctx.addLine(to: pt)
            }
            ctx.strokePath()
            
        case .text:
            let font = NSFont.boldSystemFont(ofSize: elem.fontSize)
            var drawRect = elem.textRect.insetBy(dx: 8, dy: 6)
            if drawRect.width <= 0 || drawRect.height <= 0 {
                let lines = elem.text.components(separatedBy: "\n")
                let maxLineWidth = lines.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 60
                let lineHeight = font.ascender - font.descender + font.leading
                let contentHeight = lineHeight * CGFloat(max(lines.count, 1))
                let baseRect = CGRect(origin: elem.startPoint, size: CGSize(width: maxLineWidth + 28, height: contentHeight + 16))
                drawRect = baseRect.insetBy(dx: 8, dy: 6)
            }
            
            let options: NSString.DrawingOptions = [.usesLineFragmentOrigin, .usesFontLeading]
            
            if elem.textStyleMode == .outline {
                let isDark = elem.strokeColor.isDarkColor
                let outlineColor = isDark ? NSColor.white : NSColor(calibratedWhite: 0.08, alpha: 0.95)
                let outlineStrokePercent: CGFloat = max(elem.fontSize * 0.45, 9.0)
                
                // Pass 1: High-contrast stroke outline
                let strokeAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .strokeColor: outlineColor,
                    .strokeWidth: outlineStrokePercent,
                    .foregroundColor: outlineColor
                ]
                (elem.text as NSString).draw(with: drawRect, options: options, attributes: strokeAttrs)
                
                // Pass 2: Filled core
                let fillAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: elem.strokeColor
                ]
                (elem.text as NSString).draw(with: drawRect, options: options, attributes: fillAttrs)
            } else {
                // Plain solid vector text
                let fillAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: elem.strokeColor
                ]
                (elem.text as NSString).draw(with: drawRect, options: options, attributes: fillAttrs)
            }
            
        case .counter:
            let center = elem.startPoint
            let radius: CGFloat = 13.0
            let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            
            if elem.counterStyle == .filled {
                // Circle fill
                ctx.setFillColor(elem.strokeColor.cgColor)
                ctx.fillEllipse(in: circleRect)
                
                // White border
                ctx.setStrokeColor(NSColor.white.cgColor)
                ctx.setLineWidth(1.5)
                ctx.strokeEllipse(in: circleRect)
                
                // White Number text
                let numStr = "\(elem.counterNumber)"
                let font = NSFont.boldSystemFont(ofSize: 13)
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.white
                ]
                let textSize = (numStr as NSString).size(withAttributes: textAttrs)
                let textPoint = CGPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2 + 1)
                (numStr as NSString).draw(at: textPoint, withAttributes: textAttrs)
            } else {
                // Outline style
                ctx.setFillColor(NSColor(calibratedWhite: 0.1, alpha: 0.6).cgColor)
                ctx.fillEllipse(in: circleRect)
                
                ctx.setStrokeColor(elem.strokeColor.cgColor)
                ctx.setLineWidth(2.0)
                ctx.strokeEllipse(in: circleRect)
                
                let numStr = "\(elem.counterNumber)"
                let font = NSFont.boldSystemFont(ofSize: 13)
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: elem.strokeColor
                ]
                let textSize = (numStr as NSString).size(withAttributes: textAttrs)
                let textPoint = CGPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2 + 1)
                (numStr as NSString).draw(at: textPoint, withAttributes: textAttrs)
            }
            
        case .mosaic:
            let rect = elem.bounds()
            drawMosaic(in: rect, type: elem.mosaicType, blockSize: elem.mosaicBlockSize, context: ctx)
        }
        
        ctx.restoreGState()
    }
    
    private func drawArrow(from start: CGPoint, to end: CGPoint, color: NSColor, width: CGFloat, in ctx: CGContext) {
        let length = hypot(end.x - start.x, end.y - start.y)
        guard length > 5 else { return }
        
        let arrowLength = min(max(width * 4.5, 14.0), length * 0.5)
        let arrowAngle: CGFloat = .pi / 6.0
        let angle = atan2(end.y - start.y, end.x - start.x)
        
        ctx.setStrokeColor(color.cgColor)
        ctx.setFillColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        
        // Draw line body
        ctx.move(to: start)
        ctx.addLine(to: end)
        ctx.strokePath()
        
        // Draw filled arrow head
        let p1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        ctx.move(to: end)
        ctx.addLine(to: p1)
        ctx.addLine(to: p2)
        ctx.closePath()
        ctx.fillPath()
    }
    
    private func drawMosaic(in rect: CGRect, type: MosaicType, blockSize: CGFloat, context: CGContext) {
        guard let baseImage = baseCroppedImage,
              let cgImage = baseImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            context.setFillColor(NSColor.gray.withAlphaComponent(0.7).cgColor)
            context.fill(rect)
            return
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        let filterName = (type == .pixel) ? "CIPixellate" : "CIGaussianBlur"
        let filter = CIFilter(name: filterName)
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        if type == .pixel {
            filter?.setValue(blockSize, forKey: kCIInputScaleKey)
        } else {
            filter?.setValue(blockSize * 0.6, forKey: kCIInputRadiusKey)
        }
        
        guard let outputCI = filter?.outputImage else { return }
        let ciContext = CIContext(options: nil)
        
        if let mosaicCG = ciContext.createCGImage(outputCI, from: outputCI.extent) {
            context.saveGState()
            context.clip(to: rect)
            context.draw(mosaicCG, in: self.bounds)
            context.restoreGState()
        }
    }
    
    // MARK: - Composite Output Generator
    
    public func renderComposite(baseImage: NSImage) -> NSImage {
        commitActiveTextEditor()
        let size = baseImage.size
        let resultImage = NSImage(size: size)
        
        resultImage.lockFocus()
        baseImage.draw(in: NSRect(origin: .zero, size: size))
        
        if let context = NSGraphicsContext.current?.cgContext {
            for elem in elements {
                drawElement(elem, in: context)
            }
        }
        resultImage.unlockFocus()
        
        return resultImage
    }
}

extension NSColor {
    public var isDarkColor: Bool {
        guard let rgb = self.usingColorSpace(.sRGB) else { return false }
        let luminance = 0.299 * rgb.redComponent + 0.587 * rgb.greenComponent + 0.114 * rgb.blueComponent
        return luminance < 0.45
    }
}

