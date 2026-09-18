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
    
    public static let standardWidth: CGFloat = 462.0
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
        addToolButton(.rectangle, icon: "rectangle", tip: "矩形", keycap: "R")
        addToolButton(.ellipse, icon: "oval", tip: "椭圆", keycap: "O")
        addToolButton(.arrow, icon: "arrow.up.right", tip: "箭头", keycap: "A")
        addToolButton(.line, icon: "line.diagonal", tip: "直线", keycap: "L")
        addToolButton(.brush, icon: "pencil", tip: "画笔", keycap: "P")
        addToolButton(.highlighter, icon: "highlighter", tip: "荧光笔", keycap: "H")
        addToolButton(.text, icon: "textformat", tip: "文字", keycap: "T")
        addToolButton(.mosaic, icon: "checkerboard.rectangle", tip: "马赛克", keycap: "M")
        addToolButton(.counter, icon: "1.circle", tip: "步骤序号", keycap: "N")
        
        // 分割线 ｜
        mainRowStack.addArrangedSubview(makeDivider(height: 18))
        
        // Group 2: 撤销区 (Undo / Redo)
        addActionButton(icon: "arrow.uturn.backward", tip: "撤销", keycap: "⌘Z", action: #selector(btnUndoClicked))
        addActionButton(icon: "arrow.uturn.forward", tip: "重做", keycap: "⇧⌘Z", action: #selector(btnRedoClicked))
        
        // 分割线 ｜
        mainRowStack.addArrangedSubview(makeDivider(height: 18))
        
        // Group 3: 操作区 (取消, 保存, 贴屏, 完成并复制)
        addActionButton(icon: "xmark", tip: "取消截图", keycap: "Esc", action: #selector(btnCloseClicked))
        addActionButton(icon: "square.and.arrow.down", tip: "保存图片", keycap: "⌘S", action: #selector(btnSaveClicked))
        addActionButton(icon: "pin", tip: "贴到屏幕", keycap: "F3", action: #selector(btnPinClicked))
        addActionButton(icon: "checkmark", tip: "完成并复制", keycap: "Enter", action: #selector(btnCopyClicked))
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
    
    private func addToolButton(_ tool: AnnotationToolType, icon: String, tip: String, keycap: String) {
        let btn = ToolbarIconButton(icon: icon, tip: tip, keycap: keycap, target: self, action: #selector(toolButtonClicked(_:)))
        toolButtons[tool] = btn
        mainRowStack.addArrangedSubview(btn)
    }
    
    private func addActionButton(icon: String, tip: String, keycap: String? = nil, action: Selector) {
        let btn = ToolbarIconButton(icon: icon, tip: tip, keycap: keycap, target: self, action: action)
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
    @objc private func btnPinClicked() { delegate?.toolbarDidClickPin() }
    @objc private func btnSaveClicked() { delegate?.toolbarDidClickSave() }
    @objc private func btnCloseClicked() { delegate?.toolbarDidClickClose() }
    @objc private func btnCopyClicked() { delegate?.toolbarDidClickCopy() }
}
