import Foundation
import AppKit

public enum AnnotationToolType: String, CaseIterable, Identifiable, Sendable {
    case rectangle = "rectangle"
    case ellipse = "ellipse"
    case arrow = "arrow"
    case line = "line"
    case brush = "brush"
    case highlighter = "highlighter"
    case text = "text"
    case mosaic = "mosaic"
    case counter = "counter"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .rectangle: return "矩形 (R)"
        case .ellipse: return "椭圆 (O)"
        case .arrow: return "箭头 (A)"
        case .line: return "直线 (L)"
        case .brush: return "画笔 (P)"
        case .highlighter: return "荧光笔 (H)"
        case .text: return "文字 (T)"
        case .mosaic: return "马赛克 (M)"
        case .counter: return "序号印章 (N)"
        }
    }
    
    public var iconName: String {
        switch self {
        case .rectangle: return "rectangle"
        case .ellipse: return "oval"
        case .arrow: return "arrow.up.right"
        case .line: return "line.diagonal"
        case .brush: return "pencil.tip"
        case .highlighter: return "highlighter"
        case .text: return "textformat"
        case .mosaic: return "checkerboard.rectangle"
        case .counter: return "number.circle"
        }
    }
}

public enum TextStyleMode: String, CaseIterable, Sendable {
    case plain = "plain"       // 纯色文字
    case outline = "outline"   // 高反差描边字
}

public typealias TextBackgroundStyle = TextStyleMode

public enum MosaicType: String, CaseIterable, Sendable {
    case pixel = "pixel"
    case blur = "blur"
}

public enum CounterStyle: String, CaseIterable, Sendable {
    case filled = "filled"
    case outline = "outline"
}

public struct AnnotationElement: Identifiable, Cloneable, Sendable {
    public var id: UUID = UUID()
    public var type: AnnotationToolType
    
    // Selection state for vector manipulation
    public var isSelected: Bool = false
    
    // Geometry
    public var startPoint: CGPoint = .zero
    public var endPoint: CGPoint = .zero
    public var points: [CGPoint] = [] // For brush / highlighter / polygon
    
    // Styling
    public var strokeColor: NSColor = .systemRed
    public var fillColor: NSColor? = nil
    public var strokeWidth: CGFloat = 3.0
    public var isDashed: Bool = false
    public var isFilled: Bool = false
    
    // Text specific
    public var text: String = ""
    public var fontSize: CGFloat = 16.0
    public var fontName: String = "HelveticaNeue-Bold"
    public var textRect: CGRect = .zero
    public var textStyleMode: TextStyleMode = .plain
    public var textBackgroundStyle: TextStyleMode {
        get { textStyleMode }
        set { textStyleMode = newValue }
    }
    
    // Step counter specific
    public var counterNumber: Int = 1
    public var counterStyle: CounterStyle = .filled
    
    // Mosaic specific
    public var mosaicType: MosaicType = .pixel
    public var mosaicBlockSize: CGFloat = 14.0
    
    public init(type: AnnotationToolType) {
        self.type = type
    }
    
    public mutating func offset(by delta: CGPoint) {
        startPoint = CGPoint(x: startPoint.x + delta.x, y: startPoint.y + delta.y)
        endPoint = CGPoint(x: endPoint.x + delta.x, y: endPoint.y + delta.y)
        textRect = textRect.offsetBy(dx: delta.x, dy: delta.y)
        points = points.map { CGPoint(x: $0.x + delta.x, y: $0.y + delta.y) }
    }
    
    public func contains(point: CGPoint) -> Bool {
        let b = bounds().insetBy(dx: -strokeWidth - 4, dy: -strokeWidth - 4)
        return b.contains(point)
    }
    
    public func bounds() -> CGRect {
        switch type {
        case .rectangle, .ellipse, .mosaic:
            let minX = min(startPoint.x, endPoint.x)
            let minY = min(startPoint.y, endPoint.y)
            let width = abs(endPoint.x - startPoint.x)
            let height = abs(endPoint.y - startPoint.y)
            return CGRect(x: minX, y: minY, width: max(width, 1), height: max(height, 1))
        case .arrow, .line:
            let minX = min(startPoint.x, endPoint.x) - strokeWidth
            let minY = min(startPoint.y, endPoint.y) - strokeWidth
            let width = abs(endPoint.x - startPoint.x) + strokeWidth * 2
            let height = abs(endPoint.y - startPoint.y) + strokeWidth * 2
            return CGRect(x: minX, y: minY, width: max(width, 1), height: max(height, 1))
        case .brush, .highlighter:
            guard !points.isEmpty else { return .zero }
            var minX = points[0].x, maxX = points[0].x
            var minY = points[0].y, maxY = points[0].y
            for pt in points {
                minX = min(minX, pt.x)
                maxX = max(maxX, pt.x)
                minY = min(minY, pt.y)
                maxY = max(maxY, pt.y)
            }
            return CGRect(x: minX - strokeWidth, y: minY - strokeWidth,
                          width: (maxX - minX) + strokeWidth * 2,
                          height: (maxY - minY) + strokeWidth * 2)
        case .text:
            let base = textRect.isEmpty ? CGRect(origin: startPoint, size: CGSize(width: 40, height: fontSize + 10)) : textRect
            return base.insetBy(dx: -6, dy: -6)
        case .counter:
            let radius: CGFloat = 14.0
            return CGRect(x: startPoint.x - radius, y: startPoint.y - radius, width: radius * 2, height: radius * 2)
        }
    }
}

public protocol Cloneable {
    func clone() -> Self
}

extension AnnotationElement {
    public func clone() -> AnnotationElement {
        var copy = self
        copy.id = UUID()
        return copy
    }
}
