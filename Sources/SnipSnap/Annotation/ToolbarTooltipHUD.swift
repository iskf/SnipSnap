import Cocoa

public class ToolbarTooltipHUD: NSVisualEffectView {
    public static let shared = ToolbarTooltipHUD()
    
    private let titleLabel = NSTextField(labelWithString: "")
    private let keycapBadge = NSTextField(labelWithString: "")
    private let stack = NSStackView()
    
    private weak var currentTargetView: NSView?
    private var displayToken: Int = 0
    
    private init() {
        super.init(frame: NSRect(x: 0, y: 0, width: 100, height: 24))
        
        self.material = .hudWindow
        self.blendingMode = .withinWindow
        self.state = .active
        self.wantsLayer = true
        self.layer?.cornerRadius = 6
        self.layer?.masksToBounds = true
        self.layer?.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 0.94).cgColor
        self.layer?.borderColor = NSColor.white.withAlphaComponent(0.18).cgColor
        self.layer?.borderWidth = 0.5
        self.layer?.zPosition = 500
        
        setupViews()
        self.isHidden = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        // Transparent to all mouse clicks & hovers so it never blocks underlying views
        return nil
    }
    
    private func setupViews() {
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        titleLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        titleLabel.textColor = NSColor.white
        titleLabel.alignment = .center
        stack.addArrangedSubview(titleLabel)
        
        keycapBadge.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        keycapBadge.textColor = NSColor(calibratedWhite: 0.9, alpha: 1.0)
        keycapBadge.wantsLayer = true
        keycapBadge.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.15).cgColor
        keycapBadge.layer?.cornerRadius = 3
        keycapBadge.layer?.masksToBounds = true
        stack.addArrangedSubview(keycapBadge)
    }
    
    public func show(tip: String, keycap: String? = nil, above view: NSView, in superview: NSView) {
        if self.superview != superview {
            removeFromSuperview()
            superview.addSubview(self)
        }
        
        currentTargetView = view
        displayToken += 1
        
        titleLabel.stringValue = tip
        if let key = keycap, !key.isEmpty {
            keycapBadge.stringValue = " \(key) "
            keycapBadge.isHidden = false
        } else {
            keycapBadge.isHidden = true
        }
        
        stack.layoutSubtreeIfNeeded()
        let requiredSize = stack.fittingSize
        let finalWidth = max(requiredSize.width + 16, 50)
        let finalHeight: CGFloat = 24
        
        let viewFrameInSuper = view.convert(view.bounds, to: superview)
        let midX = viewFrameInSuper.midX
        
        // Intelligent vertical placement:
        // By default, place 8px above the view.
        // If it would exceed superview's top bound, place 8px below the view.
        var targetY = viewFrameInSuper.maxY + 8
        if targetY + finalHeight > superview.bounds.maxY - 6 {
            targetY = max(viewFrameInSuper.minY - finalHeight - 8, 6)
        }
        
        let originX = min(max(midX - finalWidth / 2, 8), superview.bounds.maxX - finalWidth - 8)
        self.frame = NSRect(x: originX, y: targetY, width: finalWidth, height: finalHeight)
        
        self.isHidden = false
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.08
            self.animator().alphaValue = 1.0
        }
    }
    
    public func hide(from view: NSView? = nil) {
        if let v = view, currentTargetView !== v {
            // Mouse left another button while a new button is already active; do not hide!
            return
        }
        currentTargetView = nil
        displayToken += 1
        let token = displayToken
        
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.08
            self.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            guard let self = self, self.displayToken == token else { return }
            self.isHidden = true
        })
    }
}
