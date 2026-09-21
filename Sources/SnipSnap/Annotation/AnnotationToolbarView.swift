import Cocoa

public protocol AnnotationToolbarDelegate: AnyObject {
    func toolbarDidSelectTool(_ tool: AnnotationToolType?)
    func toolbarDidChangeColor(_ color: NSColor)
    func toolbarDidChangeStrokeWidth(_ width: CGFloat)
    func toolbarDidChangeFontSize(_ size: CGFloat)
    func toolbarDidChangeTextStyle(_ style: TextStyleMode)
    func toolbarDidChangeTextBackground(_ style: TextBackgroundStyle)
    func toolbarDidChangeMosaicBlockSize(_ size: CGFloat)
    func toolbarDidChangeCounterStyle(_ style: CounterStyle)
    func toolbarDidResetCounter()
    func toolbarDidClickUndo()
    func toolbarDidClickRedo()
    func toolbarDidClickOCR()
    func toolbarDidClickTranslate()
    func toolbarDidClickRecordGIF()
    func toolbarDidClickScrollCapture()
    func toolbarDidClickPin()
    func toolbarDidClickSave()
    func toolbarDidClickCopy()
    func toolbarDidClickClose()
    func toolbarDidDrag(delta: CGPoint)
}

public extension AnnotationToolbarDelegate {
    func toolbarDidSelectTool(_ tool: AnnotationToolType?) {}
    func toolbarDidChangeColor(_ color: NSColor) {}
    func toolbarDidChangeStrokeWidth(_ width: CGFloat) {}
    func toolbarDidChangeFontSize(_ size: CGFloat) {}
    func toolbarDidChangeTextStyle(_ style: TextStyleMode) {}
    func toolbarDidChangeTextBackground(_ style: TextBackgroundStyle) {}
    func toolbarDidChangeMosaicBlockSize(_ size: CGFloat) {}
    func toolbarDidChangeCounterStyle(_ style: CounterStyle) {}
    func toolbarDidResetCounter() {}
    func toolbarDidClickUndo() {}
    func toolbarDidClickRedo() {}
    func toolbarDidClickOCR() {}
    func toolbarDidClickTranslate() {}
    func toolbarDidClickRecordGIF() {}
    func toolbarDidClickScrollCapture() {}
    func toolbarDidClickPin() {}
    func toolbarDidClickSave() {}
    func toolbarDidClickCopy() {}
    func toolbarDidClickClose() {}
    func toolbarDidDrag(delta: CGPoint) {}
}

public class AnnotationToolbarView: NSView, SecondaryPaletteDelegate {
    public weak var delegate: AnnotationToolbarDelegate?
    
    public private(set) var selectedTool: AnnotationToolType? = nil
    public var isFlippedAbove: Bool = false {
        didSet {
            if oldValue != isFlippedAbove {
                updateSubBubblePosition()
            }
        }
    }
    
    // Components
    private let gripHandle = GripDragHandleView()
    private var toolButtons: [AnnotationToolType: ToolbarIconButton] = [:]
    
    // Independent Floating Sub-bubble
    public lazy var secondaryBubble = SecondaryPaletteBubbleView(delegate: self)
    
    // Layout
    private let mainRowStack = NSStackView()
    
    public static let standardWidth: CGFloat = 482.0
    public static let standardHeight: CGFloat = 38.0
    
    public init(delegate: AnnotationToolbarDelegate?) {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.standardWidth, height: Self.standardHeight))
        self.delegate = delegate
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 10
        self.layer?.masksToBounds = false
        self.layer?.backgroundColor = NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 0.96).cgColor
        
        // Deep soft shadow
        self.layer?.shadowColor = NSColor.black.cgColor
        self.layer?.shadowOpacity = 0.50
        self.layer?.shadowOffset = CGSize(width: 0, height: -3)
        self.layer?.shadowRadius = 12
        
        // Crisp 0.8px subtle border
        self.layer?.borderColor = NSColor.white.withAlphaComponent(0.20).cgColor
        self.layer?.borderWidth = 0.8
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    private func setupViews() {
        mainRowStack.orientation = .horizontal
        mainRowStack.alignment = .centerY
        mainRowStack.spacing = 2.5
        mainRowStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(mainRowStack)
        
        NSLayoutConstraint.activate([
            mainRowStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            mainRowStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            mainRowStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // Left drag handle
        gripHandle.onDrag = { [weak self] delta in
            self?.delegate?.toolbarDidDrag(delta: delta)
        }
        mainRowStack.addArrangedSubview(gripHandle)
        mainRowStack.addArrangedSubview(makeDivider(height: 14))
        
        // Group 1: 标注区 (Drawing tools with keycap badges)
        addToolButton(.rectangle, icon: "square", tipKey: "toolbar.tool.rectangle", keycap: "R")
        addToolButton(.ellipse, icon: "circle", tipKey: "toolbar.tool.ellipse", keycap: "O")
        addToolButton(.arrow, icon: "arrow.up.right", tipKey: "toolbar.tool.arrow", keycap: "A")
        addToolButton(.line, icon: "line.diagonal", tipKey: "toolbar.tool.line", keycap: "L")
        addToolButton(.brush, icon: "pencil", tipKey: "toolbar.tool.brush", keycap: "P")
        addToolButton(.highlighter, icon: "highlighter", tipKey: "toolbar.tool.highlighter", keycap: "H")
        addToolButton(.text, icon: "textformat", tipKey: "toolbar.tool.text", keycap: "T")
        addToolButton(.mosaic, icon: "checkerboard.rectangle", tipKey: "toolbar.tool.mosaic", keycap: "M")
        addToolButton(.counter, icon: "1.circle", tipKey: "toolbar.tool.counter", keycap: "N")
        
        // 分割线 ｜
        mainRowStack.addArrangedSubview(makeDivider(height: 18))
        
        // Group 2: 撤销区 (Undo / Redo)
        addActionButton(icon: "arrow.uturn.backward", tipKey: "toolbar.action.undo", keycap: "⌘Z", action: #selector(btnUndoClicked))
        addActionButton(icon: "arrow.uturn.forward", tipKey: "toolbar.action.redo", keycap: "⇧⌘Z", action: #selector(btnRedoClicked))
        
        // 分割线 ｜
        mainRowStack.addArrangedSubview(makeDivider(height: 18))
        
        // Group 3: 操作区 (取消, 录制动图, 保存, 贴屏, 完成并复制)
        addActionButton(icon: "xmark", tipKey: "toolbar.action.cancel", keycap: "Esc", action: #selector(btnCloseClicked))
        addActionButton(icon: "record.circle.fill", tipKey: "toolbar.action.record_gif", tint: NSColor(calibratedRed: 1.0, green: 0.28, blue: 0.28, alpha: 0.95), action: #selector(btnRecordGIFClicked))
        addActionButton(icon: "square.and.arrow.down", tipKey: "toolbar.action.save", keycap: "⌘S", action: #selector(btnSaveClicked))
        addActionButton(icon: "pin", tipKey: "toolbar.action.pin", keycap: "F2", action: #selector(btnPinClicked))
        addActionButton(icon: "checkmark", tipKey: "toolbar.action.copy", keycap: "Enter", isProminent: true, action: #selector(btnCopyClicked))
    }
    
    // MARK: - UI Helpers
    
    private func makeDivider(height: CGFloat = 16) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        
        let line = NSView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.35).cgColor
        line.layer?.cornerRadius = 0.5
        container.addSubview(line)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 8),
            container.heightAnchor.constraint(equalToConstant: 24),
            line.widthAnchor.constraint(equalToConstant: 1.0),
            line.heightAnchor.constraint(equalToConstant: height),
            line.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            line.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }
    
    private func addToolButton(_ tool: AnnotationToolType, icon: String, tipKey: String, keycap: String) {
        let btn = ToolbarIconButton(icon: icon, tipKey: tipKey, keycap: keycap, target: self, action: #selector(toolButtonClicked(_:)))
        toolButtons[tool] = btn
        mainRowStack.addArrangedSubview(btn)
    }
    
    private func addActionButton(icon: String, tipKey: String, keycap: String? = nil, isProminent: Bool = false, tint: NSColor = NSColor.white.withAlphaComponent(0.85), action: Selector) {
        let btn = ToolbarIconButton(icon: icon, tipKey: tipKey, keycap: keycap, tint: tint, target: self, action: action)
        btn.isProminentAction = isProminent
        mainRowStack.addArrangedSubview(btn)
    }
    
    // MARK: - Tool Selection & Sub-bubble Presentation
    
    public func selectTool(_ tool: AnnotationToolType?) {
        for (_, btn) in toolButtons {
            btn.isToolActive = false
        }
        
        selectedTool = tool
        
        guard let active = tool, let superview = self.superview else {
            secondaryBubble.hide()
            delegate?.toolbarDidSelectTool(nil)
            return
        }
        
        toolButtons[active]?.isToolActive = true
        secondaryBubble.show(for: active, underToolbar: self, isFlippedAbove: isFlippedAbove, in: superview)
        delegate?.toolbarDidSelectTool(active)
    }
    
    public func updateSubBubblePosition() {
        guard selectedTool != nil, let superview = self.superview else {
            return
        }
        secondaryBubble.updatePosition(underToolbar: self, isFlippedAbove: isFlippedAbove, in: superview)
    }
    
    // MARK: - Reflecting Vector Element Properties
    
    public func reflectElementProperties(_ elem: AnnotationElement?) {
        guard let elem = elem else {
            if selectedTool == nil {
                secondaryBubble.hide()
            }
            return
        }
        
        secondaryBubble.updateProperties(
            color: elem.strokeColor,
            width: elem.strokeWidth,
            fontSize: elem.fontSize,
            textStyle: elem.textStyleMode,
            mosaicSize: elem.mosaicBlockSize,
            counterStyle: elem.counterStyle
        )
        
        if let superview = self.superview {
            secondaryBubble.show(for: elem.type, underToolbar: self, isFlippedAbove: isFlippedAbove, in: superview)
        }
    }
    
    // MARK: - SecondaryPaletteDelegate Forwarding
    
    public func secondaryPaletteDidChangeColor(_ color: NSColor) {
        delegate?.toolbarDidChangeColor(color)
    }
    
    public func secondaryPaletteDidChangeStrokeWidth(_ width: CGFloat) {
        delegate?.toolbarDidChangeStrokeWidth(width)
    }
    
    public func secondaryPaletteDidChangeFontSize(_ size: CGFloat) {
        delegate?.toolbarDidChangeFontSize(size)
    }
    
    public func secondaryPaletteDidChangeTextStyle(_ style: TextStyleMode) {
        delegate?.toolbarDidChangeTextStyle(style)
        delegate?.toolbarDidChangeTextBackground(style)
    }
    
    public func secondaryPaletteDidChangeTextBackground(_ style: TextBackgroundStyle) {
        delegate?.toolbarDidChangeTextBackground(style)
    }
    
    public func secondaryPaletteDidChangeMosaicBlockSize(_ size: CGFloat) {
        delegate?.toolbarDidChangeMosaicBlockSize(size)
    }
    
    public func secondaryPaletteDidChangeCounterStyle(_ style: CounterStyle) {
        delegate?.toolbarDidChangeCounterStyle(style)
    }
    
    public func secondaryPaletteDidResetCounter() {
        delegate?.toolbarDidResetCounter()
    }
    
    // MARK: - Actions
    
    @objc private func toolButtonClicked(_ sender: ToolbarIconButton) {
        guard let (tool, _) = toolButtons.first(where: { $0.value == sender }) else { return }
        if selectedTool == tool {
            selectTool(nil)
        } else {
            selectTool(tool)
        }
    }
    
    @objc private func btnUndoClicked() { delegate?.toolbarDidClickUndo() }
    @objc private func btnRedoClicked() { delegate?.toolbarDidClickRedo() }
    @objc private func btnOCRClicked() { delegate?.toolbarDidClickOCR() }
    @objc private func btnTranslateClicked() { delegate?.toolbarDidClickTranslate() }
    @objc private func btnRecordGIFClicked() { delegate?.toolbarDidClickRecordGIF() }
    @objc private func btnScrollCaptureClicked() { delegate?.toolbarDidClickScrollCapture() }
    @objc private func btnPinClicked() { delegate?.toolbarDidClickPin() }
    @objc private func btnSaveClicked() { delegate?.toolbarDidClickSave() }
    @objc private func btnCloseClicked() { delegate?.toolbarDidClickClose() }
    @objc private func btnCopyClicked() { delegate?.toolbarDidClickCopy() }
}
