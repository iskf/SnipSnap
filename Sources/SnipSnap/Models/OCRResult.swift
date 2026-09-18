import Foundation
import CoreGraphics

public struct OCRLineItem: Identifiable {
    public var id = UUID()
    public var text: String
    public var confidence: Float
    public var boundingBox: CGRect // Image-coordinate rect
    public var normalizedBox: CGRect // Normalized 0..1 rect in Vision coords
    
    public init(id: UUID = UUID(), text: String, confidence: Float, boundingBox: CGRect, normalizedBox: CGRect = .zero) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.normalizedBox = normalizedBox
    }
}

public struct OCRResult {
    public var fullText: String
    public var lines: [OCRLineItem]
    public var translatedText: String?
    public var sourceLanguage: String?
    public var targetLanguage: String?
    
    public init(fullText: String = "", lines: [OCRLineItem] = [], translatedText: String? = nil, sourceLanguage: String? = nil, targetLanguage: String? = nil) {
        self.fullText = fullText
        self.lines = lines
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}
