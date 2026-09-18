import Cocoa

public protocol SecondaryPaletteDelegate: AnyObject {
    func secondaryPaletteDidChangeColor(_ color: NSColor)
    func secondaryPaletteDidChangeStrokeWidth(_ width: CGFloat)
    func secondaryPaletteDidChangeFontSize(_ size: CGFloat)
    func secondaryPaletteDidChangeTextStyle(_ style: TextStyleMode)
    func secondaryPaletteDidChangeTextBackground(_ style: TextBackgroundStyle)
    func secondaryPaletteDidChangeMosaicBlockSize(_ size: CGFloat)
    func secondaryPaletteDidChangeCounterStyle(_ style: CounterStyle)
    func secondaryPaletteDidResetCounter()
}

public extension SecondaryPaletteDelegate {
    func secondaryPaletteDidChangeTextStyle(_ style: TextStyleMode) {}
    func secondaryPaletteDidChangeTextBackground(_ style: TextBackgroundStyle) {}
}

// MARK: - Dedicated Button for Secondary Palette with First Mouse support
public class SecondaryPaletteButton: NSButton {
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - VisionOS-style Connected Segmented Capsule
public class CapsuleSegmentedControl: NSView {
    public var onSelectionChanged: ((Int) -> Void)?
    
    public private(set) var selectedIndex: Int = 0
    private let items: [String]
    private let itemWidths: [CGFloat]
    
    private let thumbView = NSView()
    private var itemLabels: [NSTextField] = []
    private var dividers: [NSBox] = []
    private var trackingAreasList: [NSTrackingArea] = []
    
    public init(items: [String], itemWidths: [CGFloat], defaultIndex: Int = 0) {
        self.items = items
        self.itemWidths = itemWidths
        self.selectedIndex = defaultIndex
        
        let totalW = itemWidths.reduce(0, +)
        super.init(frame: NSRect(x: 0, y: 0, width: totalW, height: 22))
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        guard super.hitTest(point) != nil else { return nil }
        return self
    }
    
    private func setupUI() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true
        layer?.backgroundColor = NSColor(calibratedWhite: 0.16, alpha: 0.70).cgColor
        layer?.borderColor = NSColor.white.withAlphaComponent(0.12).cgColor
        layer?.borderWidth = 0.5
        
        translatesAutoresizingMaskIntoConstraints = false
        let totalW = itemWidths.reduce(0, +)
        widthAnchor.constraint(equalToConstant: totalW).isActive = true
        heightAnchor.constraint(equalToConstant: 22).isActive = true
        
        // Thumb view (sliding glowing white capsule)
        thumbView.wantsLayer = true
        thumbView.layer?.cornerRadius = 5
        thumbView.layer?.backgroundColor = NSColor(white: 1.0, alpha: 0.22).cgColor
        thumbView.layer?.borderColor = NSColor.white.withAlphaComponent(0.20).cgColor
        thumbView.layer?.borderWidth = 0.5
        thumbView.layer?.shadowColor = NSColor.black.cgColor
        thumbView.layer?.shadowOpacity = 0.25
        thumbView.layer?.shadowOffset = CGSize(width: 0, height: -1)
        thumbView.layer?.shadowRadius = 2
        addSubview(thumbView)
        
        // Separators between items
        var currentX: CGFloat = 0
        for i in 0..<items.count {
            if i > 0 {
                let sep = NSBox(frame: NSRect(x: currentX - 0.5, y: 5, width: 1, height: 12))
                sep.boxType = .custom
                sep.borderWidth = 0
                sep.fillColor = NSColor.white.withAlphaComponent(0.12)
                addSubview(sep, positioned: .below, relativeTo: thumbView)
                dividers.append(sep)
            }
            currentX += itemWidths[i]
        }
        
        // Item Labels
        currentX = 0
        for (i, text) in items.enumerated() {
            let w = itemWidths[i]
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: 11, weight: .bold)
            label.alignment = .center
            label.textColor = (i == selectedIndex) ? .white : NSColor.white.withAlphaComponent(0.65)
            label.frame = NSRect(x: currentX, y: 1, width: w, height: 20)
            label.isEditable = false
            label.isSelectable = false
            label.isBezeled = false
            label.drawsBackground = false
            addSubview(label)
            itemLabels.append(label)
            currentX += w
        }
        
        thumbView.frame = frameForThumb(at: selectedIndex)
        updateDividerVisibility(animated: false)
    }
    
    private func frameForThumb(at index: Int) -> NSRect {
        guard index >= 0 && index < items.count else { return .zero }
        var startX: CGFloat = 0
        for i in 0..<index {
            startX += itemWidths[i]
        }
        let w = itemWidths[index]
        return NSRect(x: startX + 1.5, y: 1.5, width: w - 3, height: 19)
    }
    
    private func updateDividerVisibility(animated: Bool) {
        for (i, sep) in dividers.enumerated() {
            let isNearSelected = (i == selectedIndex - 1 || i == selectedIndex)
            if animated {
                sep.animator().alphaValue = isNearSelected ? 0.0 : 1.0
            } else {
                sep.alphaValue = isNearSelected ? 0.0 : 1.0
            }
        }
    }
    
    public func setSelectedIndex(_ index: Int, animated: Bool = true) {
        guard index >= 0 && index < items.count else { return }
        if selectedIndex == index && thumbView.frame.width > 0 {
            return
        }
        selectedIndex = index
        let targetFrame = frameForThumb(at: index)
        
        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.15
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                thumbView.animator().frame = targetFrame
            }
        } else {
            thumbView.frame = targetFrame
        }
        
        for (i, label) in itemLabels.enumerated() {
            let isSel = (i == index)
            if animated {
                label.animator().textColor = isSel ? .white : NSColor.white.withAlphaComponent(0.65)
            } else {
                label.textColor = isSel ? .white : NSColor.white.withAlphaComponent(0.65)
            }
        }
        
        updateDividerVisibility(animated: animated)
    }
    
    public override func mouseDown(with event: NSEvent) {
        handleMouseEvent(event)
    }
    
    public override func mouseDragged(with event: NSEvent) {
        handleMouseEvent(event)
    }
    
    private func handleMouseEvent(_ event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        var curX: CGFloat = 0
        var targetIndex: Int? = nil
        for (i, w) in itemWidths.enumerated() {
            if pt.x >= curX && pt.x < curX + w {
                targetIndex = i
                break
            }
            curX += w
        }
        if targetIndex == nil {
            if pt.x < 0 { targetIndex = 0 }
            else if pt.x >= curX { targetIndex = items.count - 1 }
        }
        if let idx = targetIndex {
            setSelectedIndex(idx, animated: true)
            onSelectionChanged?(idx)
        }
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        for a in trackingAreasList {
            removeTrackingArea(a)
        }
        trackingAreasList.removeAll()
        
        var curX: CGFloat = 0
        for (_, w) in itemWidths.enumerated() {
            let r = NSRect(x: curX, y: 0, width: w, height: 22)
            let a = NSTrackingArea(rect: r, options: [.mouseEnteredAndExited, .activeInActiveApp], owner: self, userInfo: nil)
            addTrackingArea(a)
            trackingAreasList.append(a)
            curX += w
        }
    }
    
    public override func mouseEntered(with event: NSEvent) {
        guard let area = event.trackingArea,
              let idx = trackingAreasList.firstIndex(of: area),
              idx < itemLabels.count,
              idx != selectedIndex else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            itemLabels[idx].animator().textColor = NSColor.white.withAlphaComponent(0.92)
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        guard let area = event.trackingArea,
              let idx = trackingAreasList.firstIndex(of: area),
              idx < itemLabels.count,
              idx != selectedIndex else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            itemLabels[idx].animator().textColor = NSColor.white.withAlphaComponent(0.65)
        }
    }
}

public class SecondaryPaletteBubbleView: NSView {
    public weak var delegate: SecondaryPaletteDelegate?
    
    public private(set) var selectedColor: NSColor = ColorPalette.presetColors[0]
    public private(set) var selectedWidth: CGFloat = 4.0
    public private(set) var selectedFontSize: CGFloat = 18.0
    public private(set) var selectedTextStyle: TextStyleMode = .plain
    public var selectedTextBackground: TextBackgroundStyle { selectedTextStyle }
    public private(set) var selectedMosaicBlockSize: CGFloat = 10.0
    public private(set) var selectedCounterStyle: CounterStyle = .filled
    
    private let contentStack = NSStackView()
    
    // Sub-palette containers
    private let shapeStack = NSStackView()
    private let textStack = NSStackView()
    private let mosaicStack = NSStackView()
    private let counterStack = NSStackView()
    
    // Tracking lists & controls
    private var shapeWidthButtons: [NSButton] = []
    private var shapeColorButtons: [NSButton] = []
    
    private var fontSizeSegmentControl: CapsuleSegmentedControl?
    private var textStyleSegmentControl: CapsuleSegmentedControl?
    private var textColorButtons: [NSButton] = []
    
    private var mosaicSegmentControl: CapsuleSegmentedControl?
    
    private var counterStyleSegmentControl: CapsuleSegmentedControl?
    private var counterColorButtons: [NSButton] = []
    
    public static let standardHeight: CGFloat = 32.0
    
    public init(delegate: SecondaryPaletteDelegate?) {
        self.delegate = delegate
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: Self.standardHeight))
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 10
        self.layer?.masksToBounds = false
        self.layer?.backgroundColor = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 0.96).cgColor
        self.layer?.borderColor = NSColor.white.withAlphaComponent(0.20).cgColor
        self.layer?.borderWidth = 0.8
        
        self.layer?.shadowColor = NSColor.black.cgColor
        self.layer?.shadowOpacity = 0.45
        self.layer?.shadowOffset = CGSize(width: 0, height: -3)
        self.layer?.shadowRadius = 8
        self.layer?.zPosition = 300
        
        setupViews()
        self.isHidden = true
        self.alphaValue = 0.0
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    private func setupViews() {
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 6
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)
        
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 10),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10)
        ])
        
        buildShapePalette()
        buildTextPalette()
        buildMosaicPalette()
        buildCounterPalette()
    }
    
    // MARK: - Sub-palettes
    
    private func buildShapePalette() {
        shapeStack.orientation = .horizontal
        shapeStack.alignment = .centerY
        shapeStack.spacing = 6
        
        let widths: [CGFloat] = [2.0, 4.0, 8.0, 12.0]
        for w in widths {
            let btn = makeWidthButton(width: w, action: #selector(shapeWidthClicked(_:)))
            shapeWidthButtons.append(btn)
            shapeStack.addArrangedSubview(btn)
        }
        shapeStack.addArrangedSubview(makeDivider())
        for col in ColorPalette.presetColors {
            let btn = makeColorButton(color: col, action: #selector(shapeColorClicked(_:)))
            shapeColorButtons.append(btn)
            shapeStack.addArrangedSubview(btn)
        }
    }
    
    private func buildTextPalette() {
        textStack.orientation = .horizontal
        textStack.alignment = .centerY
        textStack.spacing = 6
        
        let fontSizes = ["14", "18", "24", "32"]
        let defaultFontIdx = [14.0, 18.0, 24.0, 32.0].firstIndex(of: selectedFontSize) ?? 1
        let fontSeg = CapsuleSegmentedControl(items: fontSizes, itemWidths: [28, 28, 28, 28], defaultIndex: defaultFontIdx)
        fontSeg.onSelectionChanged = { [weak self] idx in
            let sizes: [CGFloat] = [14.0, 18.0, 24.0, 32.0]
            if idx < sizes.count {
                self?.selectedFontSize = sizes[idx]
                self?.delegate?.secondaryPaletteDidChangeFontSize(sizes[idx])
            }
        }
        fontSizeSegmentControl = fontSeg
        textStack.addArrangedSubview(fontSeg)
        
        textStack.addArrangedSubview(makeDivider())
        
        let styles = [L10n("palette.text.plain"), L10n("palette.text.outline")]
        let defaultStyleIdx = (selectedTextStyle == .plain) ? 0 : 1
        let styleSeg = CapsuleSegmentedControl(items: styles, itemWidths: [44, 44], defaultIndex: defaultStyleIdx)
        styleSeg.onSelectionChanged = { [weak self] idx in
            let style: TextStyleMode = (idx == 0) ? .plain : .outline
            self?.selectedTextStyle = style
            self?.delegate?.secondaryPaletteDidChangeTextStyle(style)
            self?.delegate?.secondaryPaletteDidChangeTextBackground(style)
        }
        textStyleSegmentControl = styleSeg
        textStack.addArrangedSubview(styleSeg)
        
        textStack.addArrangedSubview(makeDivider())
        
        textColorButtons.removeAll()
        for col in ColorPalette.presetColors {
            let btn = makeColorButton(color: col, action: #selector(textColorClicked(_:)))
            textColorButtons.append(btn)
            textStack.addArrangedSubview(btn)
        }
    }
    
    private func buildMosaicPalette() {
        mosaicStack.orientation = .horizontal
        mosaicStack.alignment = .centerY
        mosaicStack.spacing = 8
        
        let defaultIdx = (selectedMosaicBlockSize == 10.0) ? 0 : 1
        let mosaicSeg = CapsuleSegmentedControl(items: [L10n("palette.mosaic.fine"), L10n("palette.mosaic.coarse")], itemWidths: [64, 64], defaultIndex: defaultIdx)
        mosaicSeg.onSelectionChanged = { [weak self] idx in
            let size: CGFloat = (idx == 0) ? 10.0 : 20.0
            self?.selectedMosaicBlockSize = size
            self?.delegate?.secondaryPaletteDidChangeMosaicBlockSize(size)
        }
        mosaicSegmentControl = mosaicSeg
        mosaicStack.addArrangedSubview(mosaicSeg)
    }
    
    private func buildCounterPalette() {
        counterStack.orientation = .horizontal
        counterStack.alignment = .centerY
        counterStack.spacing = 6
        
        let resetBtn = makeCounterResetButton(action: #selector(counterResetClicked))
        counterStack.addArrangedSubview(resetBtn)
        counterStack.addArrangedSubview(makeDivider())
        
        let defaultIdx = (selectedCounterStyle == .filled) ? 0 : 1
        let styleSeg = CapsuleSegmentedControl(items: [L10n("palette.counter.filled"), L10n("palette.counter.outline")], itemWidths: [44, 44], defaultIndex: defaultIdx)
        styleSeg.onSelectionChanged = { [weak self] idx in
            let style: CounterStyle = (idx == 0) ? .filled : .outline
            self?.selectedCounterStyle = style
            self?.delegate?.secondaryPaletteDidChangeCounterStyle(style)
        }
        counterStyleSegmentControl = styleSeg
        counterStack.addArrangedSubview(styleSeg)
        counterStack.addArrangedSubview(makeDivider())
        
        counterColorButtons.removeAll()
        for col in ColorPalette.presetColors {
            let btn = makeColorButton(color: col, action: #selector(counterColorClicked(_:)))
            counterColorButtons.append(btn)
            counterStack.addArrangedSubview(btn)
        }
    }
    
    // MARK: - Presentation
    
    public func show(for tool: AnnotationToolType, underToolbar toolbar: NSView, isFlippedAbove: Bool, in superview: NSView) {
        if self.superview != superview {
            removeFromSuperview()
            superview.addSubview(self)
        }
        
        contentStack.subviews.forEach { $0.removeFromSuperview() }
        
        switch tool {
        case .rectangle, .ellipse, .arrow, .line, .brush, .highlighter:
            contentStack.addArrangedSubview(shapeStack)
            highlightShapeButtons()
        case .text:
            contentStack.addArrangedSubview(textStack)
            highlightTextButtons()
        case .mosaic:
            contentStack.addArrangedSubview(mosaicStack)
            highlightMosaicButtons()
        case .counter:
            contentStack.addArrangedSubview(counterStack)
            highlightCounterButtons()
        }
        
        contentStack.layoutSubtreeIfNeeded()
        let fittingW = contentStack.fittingSize.width + 20
        let finalWidth = max(fittingW, 140)
        
        let toolbarFrameInSuper = toolbar.convert(toolbar.bounds, to: superview)
        
        // 水平居中对齐主工具条（且不超出面板/屏幕边缘）
        let originX = min(max(toolbarFrameInSuper.midX - finalWidth / 2, 4), max(superview.bounds.maxX - finalWidth - 4, 4))
        
        // 垂直方位智能跟随：第一层在上方则紧贴第一层上方，否则下挂在第一层下方
        var originY: CGFloat
        if isFlippedAbove {
            originY = toolbarFrameInSuper.maxY + 6
            if originY + Self.standardHeight > superview.bounds.maxY - 2 && toolbarFrameInSuper.minY >= Self.standardHeight + 4 {
                originY = toolbarFrameInSuper.minY - Self.standardHeight - 4
            }
        } else {
            originY = toolbarFrameInSuper.minY - Self.standardHeight - 4
            if originY < 0 && (toolbarFrameInSuper.maxY + Self.standardHeight + 6 <= superview.bounds.maxY) {
                originY = toolbarFrameInSuper.maxY + 6
            }
            originY = max(min(originY, superview.bounds.maxY - Self.standardHeight), 2)
        }
        
        self.frame = NSRect(x: originX, y: originY, width: finalWidth, height: Self.standardHeight)
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            self.animator().alphaValue = 1.0
            self.isHidden = false
        }
    }
    
    public func updatePosition(underToolbar toolbar: NSView, isFlippedAbove: Bool, in superview: NSView) {
        guard !isHidden else { return }
        let toolbarFrameInSuper = toolbar.convert(toolbar.bounds, to: superview)
        
        // 水平居中对齐主工具条（且不超出面板/屏幕边缘）
        let originX = min(max(toolbarFrameInSuper.midX - bounds.width / 2, 4), max(superview.bounds.maxX - bounds.width - 4, 4))
        
        var originY: CGFloat
        if isFlippedAbove {
            originY = toolbarFrameInSuper.maxY + 6
            if originY + Self.standardHeight > superview.bounds.maxY - 2 && toolbarFrameInSuper.minY >= Self.standardHeight + 4 {
                originY = toolbarFrameInSuper.minY - Self.standardHeight - 4
            }
        } else {
            originY = toolbarFrameInSuper.minY - Self.standardHeight - 4
            if originY < 0 && (toolbarFrameInSuper.maxY + Self.standardHeight + 6 <= superview.bounds.maxY) {
                originY = toolbarFrameInSuper.maxY + 6
            }
            originY = max(min(originY, superview.bounds.maxY - Self.standardHeight), 2)
        }
        self.frame = NSRect(x: originX, y: originY, width: bounds.width, height: Self.standardHeight)
    }
    
    public func hide() {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            self.animator().alphaValue = 0.0
        }, completionHandler: {
            self.isHidden = true
            self.contentStack.subviews.forEach { $0.removeFromSuperview() }
        })
    }
    
    public func updateProperties(color: NSColor, width: CGFloat, fontSize: CGFloat, textStyle: TextStyleMode, mosaicSize: CGFloat, counterStyle: CounterStyle) {
        self.selectedColor = color
        self.selectedWidth = width
        self.selectedFontSize = fontSize
        self.selectedTextStyle = textStyle
        self.selectedMosaicBlockSize = mosaicSize
        self.selectedCounterStyle = counterStyle
        
        highlightShapeButtons()
        highlightTextButtons()
        highlightMosaicButtons()
        highlightCounterButtons()
    }
    
    // MARK: - State Highlighting
    
    private func highlightShapeButtons() {
        let widths: [CGFloat] = [2.0, 4.0, 8.0, 12.0]
        for (idx, btn) in shapeWidthButtons.enumerated() {
            let isSel = (widths[idx] == selectedWidth)
            btn.layer?.borderColor = isSel ? NSColor.white.cgColor : NSColor.white.withAlphaComponent(0.2).cgColor
            btn.layer?.borderWidth = isSel ? 2.0 : 0.5
            btn.layer?.backgroundColor = isSel ? NSColor.systemBlue.withAlphaComponent(0.4).cgColor : NSColor.clear.cgColor
        }
        for btn in shapeColorButtons {
            let isSel = (btn.layer?.backgroundColor == selectedColor.cgColor)
            btn.layer?.borderWidth = isSel ? 2.5 : 0.5
            btn.layer?.borderColor = isSel ? NSColor.white.cgColor : NSColor.white.withAlphaComponent(0.25).cgColor
            let scale: CGFloat = isSel ? 1.18 : 1.0
            btn.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }
    
    private func highlightTextButtons() {
        let sizes: [CGFloat] = [14.0, 18.0, 24.0, 32.0]
        if let idx = sizes.firstIndex(of: selectedFontSize) {
            fontSizeSegmentControl?.setSelectedIndex(idx, animated: true)
        }
        
        let styleIdx = (selectedTextStyle == .plain) ? 0 : 1
        textStyleSegmentControl?.setSelectedIndex(styleIdx, animated: true)
        
        for btn in textColorButtons {
            let isSel = (btn.layer?.backgroundColor == selectedColor.cgColor)
            btn.layer?.borderWidth = isSel ? 2.5 : 0.5
            btn.layer?.borderColor = isSel ? NSColor.white.cgColor : NSColor.white.withAlphaComponent(0.25).cgColor
            let scale: CGFloat = isSel ? 1.15 : 1.0
            btn.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }
    
    private func highlightMosaicButtons() {
        let idx = (selectedMosaicBlockSize == 10.0) ? 0 : 1
        mosaicSegmentControl?.setSelectedIndex(idx, animated: true)
    }
    
    private func highlightCounterButtons() {
        let selTag = (selectedCounterStyle == .filled) ? 0 : 1
        counterStyleSegmentControl?.setSelectedIndex(selTag, animated: true)
        for btn in counterColorButtons {
            let isSel = (btn.layer?.backgroundColor == selectedColor.cgColor)
            btn.layer?.borderWidth = isSel ? 2.5 : 0.5
            btn.layer?.borderColor = isSel ? NSColor.white.cgColor : NSColor.white.withAlphaComponent(0.25).cgColor
            let scale: CGFloat = isSel ? 1.15 : 1.0
            btn.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }
    
    // MARK: - UI Helpers
    
    private func makeDivider() -> NSView {
        let v = NSBox()
        v.boxType = .separator
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 14).isActive = true
        return v
    }
    
    private func makeWidthButton(width: CGFloat, action: Selector) -> NSButton {
        let btn = SecondaryPaletteButton(frame: .zero)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.title = ""
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 9
        btn.layer?.backgroundColor = NSColor.clear.cgColor
        btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.2).cgColor
        btn.layer?.borderWidth = 0.5
        
        let dot = CALayer()
        dot.backgroundColor = NSColor.white.cgColor
        let dotD = max(width, 3)
        dot.cornerRadius = dotD / 2
        dot.bounds = CGRect(x: 0, y: 0, width: dotD, height: dotD)
        dot.position = CGPoint(x: 9, y: 9)
        btn.layer?.addSublayer(dot)
        
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 18).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 18).isActive = true
        
        btn.target = self
        btn.action = action
        return btn
    }
    
    private func makeColorButton(color: NSColor, action: Selector) -> NSButton {
        let btn = SecondaryPaletteButton(frame: .zero)
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.title = ""
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 7.5
        btn.layer?.backgroundColor = color.cgColor
        btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
        btn.layer?.borderWidth = 0.5
        
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 15).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 15).isActive = true
        
        btn.target = self
        btn.action = action
        return btn
    }
    
    private func makeCounterResetButton(action: Selector) -> NSButton {
        let btn = SecondaryPaletteButton(frame: .zero)
        btn.target = self
        btn.action = action
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 5
        btn.layer?.backgroundColor = NSColor(calibratedWhite: 0.20, alpha: 0.8).cgColor
        btn.layer?.borderColor = NSColor.white.withAlphaComponent(0.15).cgColor
        btn.layer?.borderWidth = 0.5
        
        let config = NSImage.SymbolConfiguration(pointSize: 9.5, weight: .bold)
        if let icon = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: "重置")?.withSymbolConfiguration(config) {
            btn.image = icon
            btn.imagePosition = .imageLeading
            btn.contentTintColor = .white
        }
        
        let attrTitle = NSAttributedString(string: " 1", attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.systemFont(ofSize: 11, weight: .bold)
        ])
        btn.attributedTitle = attrTitle
        btn.toolTip = L10n("palette.counter.reset")
        
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.widthAnchor.constraint(equalToConstant: 40).isActive = true
        btn.heightAnchor.constraint(equalToConstant: 22).isActive = true
        return btn
    }
    
    // MARK: - Actions
    
    @objc private func shapeWidthClicked(_ sender: NSButton) {
        guard let idx = shapeWidthButtons.firstIndex(of: sender) else { return }
        let widths: [CGFloat] = [2.0, 4.0, 8.0, 12.0]
        selectedWidth = widths[idx]
        highlightShapeButtons()
        delegate?.secondaryPaletteDidChangeStrokeWidth(selectedWidth)
    }
    
    @objc private func shapeColorClicked(_ sender: NSButton) {
        guard let idx = shapeColorButtons.firstIndex(of: sender) else { return }
        selectedColor = ColorPalette.presetColors[idx]
        highlightShapeButtons()
        delegate?.secondaryPaletteDidChangeColor(selectedColor)
    }
    
    @objc private func textColorClicked(_ sender: NSButton) {
        guard let idx = textColorButtons.firstIndex(of: sender) else { return }
        selectedColor = ColorPalette.presetColors[idx]
        highlightTextButtons()
        delegate?.secondaryPaletteDidChangeColor(selectedColor)
    }
    
    @objc private func counterResetClicked() {
        delegate?.secondaryPaletteDidResetCounter()
    }
    
    @objc private func counterColorClicked(_ sender: NSButton) {
        guard let idx = counterColorButtons.firstIndex(of: sender) else { return }
        selectedColor = ColorPalette.presetColors[idx]
        highlightCounterButtons()
        delegate?.secondaryPaletteDidChangeColor(selectedColor)
    }
}
