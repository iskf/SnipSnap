import Cocoa
import SwiftUI

public struct SampledImageStyle {
    public let backgroundColor: Color
    public let textColor: Color
    public let isCodeSnippet: Bool
    public let isDarkBackground: Bool
}

public class ImageColorSampler {
    public static func sampleStyle(from image: NSImage?, text: String) -> SampledImageStyle {
        guard let image = image,
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return fallbackStyle(text: text)
        }
        
        let width = cgImage.width
        let height = cgImage.height
        guard width > 0 && height > 0 else {
            return fallbackStyle(text: text)
        }
        
        // Sample corner and edge points: (2,2), (width-3, 2), (2, height-3), (width-3, height-3), (width/2, 2)
        let samplePoints = [
            CGPoint(x: 2, y: 2),
            CGPoint(x: max(width - 3, 0), y: 2),
            CGPoint(x: 2, y: max(height - 3, 0)),
            CGPoint(x: max(width - 3, 0), y: max(height - 3, 0)),
            CGPoint(x: width / 2, y: 2),
            CGPoint(x: width / 2, y: max(height - 3, 0))
        ]
        
        var totalR: CGFloat = 0
        var totalG: CGFloat = 0
        var totalB: CGFloat = 0
        var validCount: CGFloat = 0
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var pixelData = [UInt8](repeating: 0, count: 4)
        
        for pt in samplePoints {
            if let context = CGContext(
                data: &pixelData,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                context.draw(cgImage, in: CGRect(x: -pt.x, y: -pt.y, width: CGFloat(width), height: CGFloat(height)))
                let r = CGFloat(pixelData[0]) / 255.0
                let g = CGFloat(pixelData[1]) / 255.0
                let b = CGFloat(pixelData[2]) / 255.0
                totalR += r
                totalG += g
                totalB += b
                validCount += 1
            }
        }
        
        let avgR = validCount > 0 ? (totalR / validCount) : 0.14
        let avgG = validCount > 0 ? (totalG / validCount) : 0.15
        let avgB = validCount > 0 ? (totalB / validCount) : 0.17
        
        // Perceived luminance (ITU-R BT.709)
        let luminance = 0.2126 * avgR + 0.7152 * avgG + 0.0722 * avgB
        let isDark = luminance < 0.55
        
        let bg = Color(red: avgR, green: avgG, blue: avgB)
        
        // Detect if text is a code snippet or comment
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let isComment = trimmed.hasPrefix("//") || trimmed.hasPrefix("/*") || trimmed.hasPrefix("#")
        let hasCodeKeywords = ["func ", "let ", "var ", "const ", "import ", "def ", "class ", "return "].contains { trimmed.contains($0) }
        let isCode = isComment || hasCodeKeywords
        
        // Choose text color
        let textColor: Color
        if isComment {
            // High quality syntax comment color (IDE style green)
            textColor = isDark ? Color(red: 0.45, green: 0.72, blue: 0.48) : Color(red: 0.15, green: 0.48, blue: 0.18)
        } else if isDark {
            textColor = Color(red: 0.94, green: 0.95, blue: 0.96)
        } else {
            textColor = Color(red: 0.12, green: 0.13, blue: 0.15)
        }
        
        return SampledImageStyle(
            backgroundColor: bg,
            textColor: textColor,
            isCodeSnippet: isCode,
            isDarkBackground: isDark
        )
    }
    
    private static func fallbackStyle(text: String) -> SampledImageStyle {
        let isComment = text.trimmingCharacters(in: .whitespaces).hasPrefix("//")
        return SampledImageStyle(
            backgroundColor: Color(red: 0.13, green: 0.14, blue: 0.16),
            textColor: isComment ? Color(red: 0.45, green: 0.72, blue: 0.48) : Color.white.opacity(0.92),
            isCodeSnippet: isComment,
            isDarkBackground: true
        )
    }
}
