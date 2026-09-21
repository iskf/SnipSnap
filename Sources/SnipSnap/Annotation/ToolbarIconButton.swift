import Cocoa

public class ToolbarIconButton: NSButton {
    public var tipKey: String? = nil
    private var _tipText: String = ""
    public var tipText: String {
        get {
            if let key = tipKey {
                return L10n(key)
            }
            return _tipText
        }
        set {
            _tipText = newValue
        }
    }
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
    
    public var isProminentAction: Bool = false {
        didSet {
            if isProminentAction {
                layer?.cornerRadius = 6
            }
            updateActiveAppearance()
        }
    }
    
    private var trackingArea: NSTrackingArea?
    private var isHovered: Bool = false
    
    public init(icon: String, tip: String = "", tipKey: String? = nil, keycap: String? = nil, tint: NSColor = NSColor.white.withAlphaComponent(0.85), target: AnyObject?, action: Selector) {
        self.tipKey = tipKey
        self._tipText = tip
        self.keycapText = keycap
        self.customTint = tint
        
        super.init(frame: .zero)
        
        self.target = target
        self.action = action
        
        self.bezelStyle = .regularSquare
        self.isBordered = false
        self.imagePosition = .imageOnly
        
        self.image = Self.createNormalizedIcon(named: icon, pointSize: 12.0)
        self.imageScaling = .scaleNone
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
    
    /// Normalizes and centers any SF Symbol into an optically balanced square bounding box
    public static func createNormalizedIcon(named name: String, targetBox: CGFloat = 14.0, pointSize: CGFloat = 12.0) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else {
            return nil
        }
        let w = base.size.width
        let h = base.size.height
        guard w > 0, h > 0 else { return base }
        
        let maxDim = max(w, h)
        // Keep proportional scale fitting neatly into targetBox
        let scale = min(targetBox / maxDim, 1.15)
        let fittedW = round(w * scale)
        let fittedH = round(h * scale)
        
        let normalized = NSImage(size: NSSize(width: targetBox, height: targetBox), flipped: false) { _ in
            let drawRect = NSRect(
                x: (targetBox - fittedW) / 2.0,
                y: (targetBox - fittedH) / 2.0,
                width: fittedW,
                height: fittedH
            )
            base.draw(in: drawRect)
            return true
        }
        normalized.isTemplate = true
        return normalized
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
            
            if self.isProminentAction {
                self.layer?.backgroundColor = isEntering
                    ? NSColor(calibratedRed: 0.16, green: 0.74, blue: 0.46, alpha: 1.0).cgColor
                    : NSColor(calibratedRed: 0.14, green: 0.65, blue: 0.40, alpha: 0.88).cgColor
                self.layer?.shadowOpacity = isEntering ? 0.7 : 0.3
            } else if !self.isToolActive {
                let hoverColor = isEntering ? NSColor.white.withAlphaComponent(0.12).cgColor : NSColor.clear.cgColor
                self.layer?.backgroundColor = hoverColor
            }
        }
        self.contentTintColor = isEntering || isToolActive || isProminentAction ? .white : customTint
    }
    
    private func animatePress(isDown: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            let scale: CGFloat = isDown ? 0.95 : (isHovered ? 1.06 : 1.0)
            self.layer?.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        }
    }
    
    private func updateActiveAppearance() {
        if isProminentAction {
            contentTintColor = .white
            layer?.backgroundColor = isHovered
                ? NSColor(calibratedRed: 0.16, green: 0.74, blue: 0.46, alpha: 1.0).cgColor
                : NSColor(calibratedRed: 0.14, green: 0.65, blue: 0.40, alpha: 0.88).cgColor
            layer?.borderColor = NSColor.white.withAlphaComponent(isHovered ? 0.40 : 0.20).cgColor
            layer?.borderWidth = 0.6
            layer?.shadowColor = NSColor(calibratedRed: 0.14, green: 0.65, blue: 0.40, alpha: 0.6).cgColor
            layer?.shadowOpacity = isHovered ? 0.7 : 0.3
            layer?.shadowRadius = isHovered ? 4 : 2
            layer?.shadowOffset = CGSize(width: 0, height: 1)
        } else if isToolActive {
            contentTintColor = .white
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.85).cgColor
            layer?.borderColor = nil
            layer?.borderWidth = 0
            layer?.shadowColor = NSColor.systemBlue.cgColor
            layer?.shadowOpacity = 0.6
            layer?.shadowRadius = 5
            layer?.shadowOffset = CGSize(width: 0, height: 0)
        } else {
            contentTintColor = isHovered ? .white : customTint
            layer?.backgroundColor = isHovered ? NSColor.white.withAlphaComponent(0.12).cgColor : NSColor.clear.cgColor
            layer?.borderColor = nil
            layer?.borderWidth = 0
            layer?.shadowOpacity = 0.0
        }
    }
}
