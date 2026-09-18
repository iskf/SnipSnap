import Cocoa

public class ToolbarIconButton: NSButton {
    public var tipText: String = ""
    public var keycapText: String? = nil
    public var customTint: NSColor = NSColor.white.withAlphaComponent(0.85) {
        didSet {
            contentTintColor = isHovered || isToolActive ? .white : customTint
        }
    }
    
    public var isToolActive: Bool = false {
        didSet {
            updateActiveAppearance()
        }
    }
    
    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false
    
    public init(icon: String, tip: String, keycap: String? = nil, tint: NSColor = NSColor.white.withAlphaComponent(0.85), target: AnyObject?, action: Selector) {
        self.tipText = tip
        self.keycapText = keycap
        self.customTint = tint
        
        super.init(frame: .zero)
        
        self.target = target
        self.action = action
        
        self.bezelStyle = .regularSquare
        self.isBordered = false
        self.imagePosition = .imageOnly
        
        let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .medium)
        self.image = NSImage(systemSymbolName: icon, accessibilityDescription: tip)?.withSymbolConfiguration(config)
        self.contentTintColor = tint
        
        self.wantsLayer = true
        self.layer?.cornerRadius = 5
        self.layer?.masksToBounds = false
        
        // Ensure anchor point is centered for scale animations
        self.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.widthAnchor.constraint(equalToConstant: 24).isActive = true
        self.heightAnchor.constraint(equalToConstant: 24).isActive = true
        
        updateActiveAppearance()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        // Expand tracking area vertically by 7px (covering full 38px toolbar height)
        // and horizontally by 1.5px (covering inter-button gap)
        let trackingBounds = bounds.insetBy(dx: -1.5, dy: -7)
        let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .inVisibleRect]
        let area = NSTrackingArea(rect: trackingBounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        animateHover(isEntering: true)
        
        if let superview = window?.contentView ?? self.superview {
            ToolbarTooltipHUD.shared.show(tip: tipText, keycap: keycapText, above: self, in: superview)
        }
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        animateHover(isEntering: false)
        ToolbarTooltipHUD.shared.hide(from: self)
    }
    
    public override func mouseDown(with event: NSEvent) {
        ToolbarTooltipHUD.shared.hide(from: self)
        animatePress(isDown: true)
        super.mouseDown(with: event)
        animatePress(isDown: false)
    }
    
    private func animateHover(isEntering: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            let scale: CGFloat = isEntering ? 1.06 : 1.0
            self.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
            
            if !self.isToolActive {
                let hoverColor = isEntering ? NSColor.white.withAlphaComponent(0.12).cgColor : NSColor.clear.cgColor
                self.layer?.backgroundColor = hoverColor
            }
        }
        self.contentTintColor = isEntering || isToolActive ? .white : customTint
    }
    
    private func animatePress(isDown: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            let scale: CGFloat = isDown ? 0.95 : (isHovered ? 1.06 : 1.0)
            self.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }
    
    private func updateActiveAppearance() {
        if isToolActive {
            contentTintColor = .white
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.85).cgColor
            layer?.shadowColor = NSColor.systemBlue.cgColor
            layer?.shadowOpacity = 0.6
            layer?.shadowRadius = 5
            layer?.shadowOffset = CGSize(width: 0, height: 0)
        } else {
            contentTintColor = isHovered ? .white : customTint
            layer?.backgroundColor = isHovered ? NSColor.white.withAlphaComponent(0.12).cgColor : NSColor.clear.cgColor
            layer?.shadowOpacity = 0.0
        }
    }
}
