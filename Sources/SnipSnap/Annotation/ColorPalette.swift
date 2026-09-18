import Cocoa

public struct ColorPalette {
    public static let presetColors: [NSColor] = [
        NSColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1.0), // Coral Red
        NSColor(red: 0.98, green: 0.55, blue: 0.00, alpha: 1.0), // Tangerine Orange
        NSColor(red: 1.00, green: 0.80, blue: 0.00, alpha: 1.0), // Sun Yellow
        NSColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1.0), // Mint Green
        NSColor(red: 0.00, green: 0.48, blue: 1.00, alpha: 1.0), // Sky Blue
        NSColor(red: 0.69, green: 0.32, blue: 0.87, alpha: 1.0), // Lavender Purple
        NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0), // Dark Charcoal
        NSColor(red: 1.00, green: 1.00, blue: 1.00, alpha: 1.0), // Pure White
    ]
    
    public static let strokeWidths: [CGFloat] = [2.0, 4.0, 8.0, 16.0]
    
    public static func hexString(from color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "#FF0000" }
        let r = Int(round(rgb.redComponent * 255.0))
        let g = Int(round(rgb.greenComponent * 255.0))
        let b = Int(round(rgb.blueComponent * 255.0))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    public static func color(fromHex hex: String) -> NSColor {
        var cString = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        if cString.count != 6 {
            return .systemRed
        }
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        return NSColor(
            red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgbValue & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgbValue & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }
}
