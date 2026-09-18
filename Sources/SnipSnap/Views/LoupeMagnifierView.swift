import Cocoa

public enum ColorFormat: String, CaseIterable {
    case hex = "HEX"
    case rgb = "RGB"
    case hsl = "HSL"
}

public class LoupeMagnifierView: NSView {
    public var targetPoint: CGPoint = .zero {
        didSet { needsDisplay = true }
    }
    public var selectionSize: CGSize = .zero {
        didSet { needsDisplay = true }
    }
    public var sourceImage: NSImage?
    public var fullBounds: CGRect = .zero
    
    public var currentFormat: ColorFormat = .hex {
        didSet { needsDisplay = true }
    }
    
    public var customTipText: String? = nil {
        didSet { needsDisplay = true }
    }
    
    public private(set) var currentColor: NSColor = .black
    
    private let gridSize: Int = 11 // 11x11 pixel grid
    public var pixelDisplaySize: CGFloat = 10.0 {
        didSet {
            updateCardSize()
            needsDisplay = true
        }
    }
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: 146, height: 185))
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = false
        
        // Deep soft shadow matching toolbar
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.45
        layer?.shadowOffset = CGSize(width: 0, height: -3)
        layer?.shadowRadius = 8
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func updateCardSize() {
        let gridSpan = CGFloat(gridSize) * pixelDisplaySize
        let w = max(gridSpan + 36, 146)
        let h = gridSpan + 75
        self.frame.size = CGSize(width: w, height: h)
    }
    
    public override func hitTest(_ point: NSPoint) -> NSView? {
        return nil
    }
    
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return false
    }
    
    public func cycleColorFormat() {
        switch currentFormat {
        case .hex: currentFormat = .rgb
        case .rgb: currentFormat = .hsl
        case .hsl: currentFormat = .hex
        }
    }
    
    public var formattedColorString: String {
        guard let rgb = currentColor.usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(rgb.redComponent * 255.0))
        let g = Int(round(rgb.greenComponent * 255.0))
        let b = Int(round(rgb.blueComponent * 255.0))
        
        switch currentFormat {
        case .hex:
            return String(format: "#%02X%02X%02X", r, g, b)
        case .rgb:
            return "rgb(\(r), \(g), \(b))"
        case .hsl:
            var h: CGFloat = 0, s: CGFloat = 0, br: CGFloat = 0, a: CGFloat = 0
            rgb.getHue(&h, saturation: &s, brightness: &br, alpha: &a)
            return String(format: "hsl(%d, %d%%, %d%%)", Int(h * 360), Int(s * 100), Int(br * 100))
        }
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let bounds = self.bounds
        
        // Deep matte dark grey #1C1C1E (95% opacity) matching toolbar
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 0.95).setFill()
        bgPath.fill()
        
        // Crisp 0.8px subtle border
        NSColor.white.withAlphaComponent(0.20).setStroke()
        bgPath.lineWidth = 0.8
        bgPath.stroke()
        
        // 1. Draw zoomed pixel grid area at top
        let gridAreaRect = CGRect(
            x: (bounds.width - CGFloat(gridSize) * pixelDisplaySize) / 2,
            y: bounds.height - CGFloat(gridSize) * pixelDisplaySize - 12,
            width: CGFloat(gridSize) * pixelDisplaySize,
            height: CGFloat(gridSize) * pixelDisplaySize
        )
        
        var sampledCenterColor: NSColor = .black
        
        if let cgImage = sourceImage?.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let scaleX = CGFloat(cgImage.width) / max(fullBounds.width, 1.0)
            let scaleY = CGFloat(cgImage.height) / max(fullBounds.height, 1.0)
            
            // targetPoint is in CaptureOverlayView coords (0..fullBounds.width, 0..fullBounds.height)
            let imgX = max(0, min(Int(floor(targetPoint.x * scaleX)), cgImage.width - 1))
            let imgY = max(0, min(Int(floor((fullBounds.height - targetPoint.y) * scaleY)), cgImage.height - 1))
            
            let halfGrid = gridSize / 2
            let startX = imgX - halfGrid
            let startY = imgY - halfGrid
            
            // Create an 11x11 sRGB buffer to sample exact colors
            var raw = [UInt8](repeating: 0, count: gridSize * gridSize * 4)
            let cs = CGColorSpace(name: CGColorSpace.sRGB)!
            if let sampleCtx = CGContext(
                data: &raw,
                width: gridSize,
                height: gridSize,
                bitsPerComponent: 8,
                bytesPerRow: gridSize * 4,
                space: cs,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
                let requestedRect = CGRect(x: startX, y: startY, width: gridSize, height: gridSize)
                let validCropRect = requestedRect.intersection(imageBounds)
                
                if !validCropRect.isNull, validCropRect.width > 0, validCropRect.height > 0,
                   let cropped = cgImage.cropping(to: validCropRect) {
                    let destX = validCropRect.origin.x - requestedRect.origin.x
                    let destY = requestedRect.maxY - validCropRect.maxY
                    let destRect = CGRect(x: destX, y: destY, width: validCropRect.width, height: validCropRect.height)
                    sampleCtx.draw(cropped, in: destRect)
                }
                
                // Draw cells
                for row in 0..<gridSize {
                    for col in 0..<gridSize {
                        // Direct 1:1 buffer row mapping: row 0 in CGImage memory is the top row, mapped to the top cell on screen
                        let bufferRow = row
                        let offset = bufferRow * (gridSize * 4) + col * 4
                        let r = CGFloat(raw[offset]) / 255.0
                        let g = CGFloat(raw[offset + 1]) / 255.0
                        let b = CGFloat(raw[offset + 2]) / 255.0
                        let pixelColor = NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
                        
                        if row == halfGrid && col == halfGrid {
                            sampledCenterColor = pixelColor
                        }
                        
                        let cellRect = CGRect(
                            x: gridAreaRect.origin.x + CGFloat(col) * pixelDisplaySize,
                            y: gridAreaRect.origin.y + CGFloat(gridSize - 1 - row) * pixelDisplaySize,
                            width: pixelDisplaySize,
                            height: pixelDisplaySize
                        )
                        pixelColor.setFill()
                        context.fill(cellRect)
                    }
                }
            }
            
            self.currentColor = sampledCenterColor
            
            // Grid lines
            context.setStrokeColor(NSColor.black.withAlphaComponent(0.25).cgColor)
            context.setLineWidth(0.5)
            for i in 0...gridSize {
                let x = gridAreaRect.origin.x + CGFloat(i) * pixelDisplaySize
                context.move(to: CGPoint(x: x, y: gridAreaRect.origin.y))
                context.addLine(to: CGPoint(x: x, y: gridAreaRect.maxY))
                
                let y = gridAreaRect.origin.y + CGFloat(i) * pixelDisplaySize
                context.move(to: CGPoint(x: gridAreaRect.origin.x, y: y))
                context.addLine(to: CGPoint(x: gridAreaRect.maxX, y: y))
            }
            context.strokePath()
            
            // Center reticle
            let centerCell = CGRect(
                x: gridAreaRect.origin.x + CGFloat(halfGrid) * pixelDisplaySize,
                y: gridAreaRect.origin.y + CGFloat(halfGrid) * pixelDisplaySize,
                width: pixelDisplaySize,
                height: pixelDisplaySize
            )
            context.setStrokeColor(NSColor.systemRed.cgColor)
            context.setLineWidth(1.5)
            context.stroke(centerCell)
        }
        
        // 2. Info area (Color swatch, Formatted color, Shift tip, Dimensions)
        let colorSwatchRect = CGRect(x: 12, y: 40, width: 14, height: 14)
        currentColor.setFill()
        NSBezierPath(roundedRect: colorSwatchRect, xRadius: 3, yRadius: 3).fill()
        NSColor.white.withAlphaComponent(0.5).setStroke()
        NSBezierPath(roundedRect: colorSwatchRect, xRadius: 3, yRadius: 3).stroke()
        
        let colorStr = formattedColorString
        let font10 = NSFont.monospacedSystemFont(ofSize: 10, weight: .bold)
        let colorAttrs: [NSAttributedString.Key: Any] = [
            .font: font10,
            .foregroundColor: NSColor.white
        ]
        NSString(string: colorStr).draw(at: CGPoint(x: 30, y: 40), withAttributes: colorAttrs)
        
        // Tip row (Using standard integer point size 10)
        let tipFont = NSFont.systemFont(ofSize: 10, weight: .regular)
        let tipAttrs: [NSAttributedString.Key: Any] = [
            .font: tipFont,
            .foregroundColor: NSColor(calibratedWhite: 0.75, alpha: 1.0)
        ]
        let tipStr = customTipText ?? L10n("loupe.tip")
        NSString(string: tipStr).draw(at: CGPoint(x: 12, y: 24), withAttributes: tipAttrs)
        
        // Coordinates / Size
        let sizeString: String
        if selectionSize.width > 0 && selectionSize.height > 0 {
            sizeString = "\(Int(selectionSize.width)) × \(Int(selectionSize.height))"
        } else {
            let screenX = Int(targetPoint.x + fullBounds.origin.x)
            let screenY = Int(targetPoint.y + fullBounds.origin.y)
            sizeString = "(\(screenX), \(screenY))"
        }
        let sizeFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        let sizeAttrs: [NSAttributedString.Key: Any] = [
            .font: sizeFont,
            .foregroundColor: NSColor.systemTeal
        ]
        NSString(string: sizeString).draw(at: CGPoint(x: 12, y: 8), withAttributes: sizeAttrs)
    }
}
