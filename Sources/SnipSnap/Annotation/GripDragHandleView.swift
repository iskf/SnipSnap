import Cocoa

public class GripDragHandleView: NSView {
    public var onDrag: ((CGPoint) -> Void)?
    public var onDragBegan: (() -> Void)?
    public var onDragEnded: (() -> Void)?
    
    private var initialMouseLocation: CGPoint = .zero
    private var isDragging: Bool = false
    private var isHovered: Bool = false
    private var trackingArea: NSTrackingArea?
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 14, height: 26))
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 14).isActive = true
        heightAnchor.constraint(equalToConstant: 26).isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let options: NSTrackingArea.Options = [.activeAlways, .mouseEnteredAndExited, .inVisibleRect]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
    
    public override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        isHovered = true
        NSCursor.openHand.set()
        needsDisplay = true
    }
    
    public override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        isHovered = false
        needsDisplay = true
    }
    
    public override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        isDragging = true
        NSCursor.closedHand.set()
        onDragBegan?()
    }
    
    public override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let currentMouse = NSEvent.mouseLocation
        let delta = CGPoint(x: currentMouse.x - initialMouseLocation.x, y: currentMouse.y - initialMouseLocation.y)
        initialMouseLocation = currentMouse
        onDrag?(delta)
    }
    
    public override func mouseUp(with event: NSEvent) {
        isDragging = false
        NSCursor.openHand.set()
        onDragEnded?()
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        let dotColor = isHovered ? NSColor.white.withAlphaComponent(0.75) : NSColor.white.withAlphaComponent(0.35)
        ctx.setFillColor(dotColor.cgColor)
        
        // 2 columns, 3 rows of dots
        let dotRadius: CGFloat = 1.5
        let startX: CGFloat = 3.5
        let colSpacing: CGFloat = 5.0
        let startY: CGFloat = bounds.midY - 7.0
        let rowSpacing: CGFloat = 7.0
        
        for col in 0..<2 {
            let x = startX + CGFloat(col) * colSpacing
            for row in 0..<3 {
                let y = startY + CGFloat(row) * rowSpacing
                ctx.fillEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            }
        }
    }
}
