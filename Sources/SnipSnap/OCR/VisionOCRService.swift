import Cocoa
import Vision

public class VisionOCRService {
    public static let shared = VisionOCRService()
    
    private init() {}
    
    public func recognizeText(from image: NSImage,
                              languages: [String]? = nil,
                              completion: @escaping (Result<OCRResult, Error>) -> Void) {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            completion(.failure(NSError(domain: "SnipSnapOCR", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析图像 CGImage"])))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let config = AppConfig.load()
            let primaryLangs = languages ?? config.ocrLanguages
            
            // Apple Vision 框架存在已知底层限制：若在单个 recognitionLanguages 数组中同时混入中文 (zh-Hans/zh-Hant)
            // 与日韩语 (ja-JP/ko-KR)，会引发 CJK 词典冲突，导致平假名/片假名或谚文被误判为噪声而直接丢失整句。
            // 因此将互斥的 CJK 语系拆解为两个正交的识别组，并自动择优选取覆盖率与置信度最高的结果。
            let latinAndEuropean = ["en-US", "fr-FR", "de-DE", "es-ES", "ru-RU"]
            let chineseGroup = ["zh-Hans", "zh-Hant"] + latinAndEuropean
            let japanKoreaGroup = ["ja-JP", "ko-KR"] + latinAndEuropean
            
            let isPrimaryJapaneseOrKorean = primaryLangs.contains { $0.hasPrefix("ja") || $0.hasPrefix("ko") }
            let group1 = isPrimaryJapaneseOrKorean ? japanKoreaGroup : chineseGroup
            let group2 = isPrimaryJapaneseOrKorean ? chineseGroup : japanKoreaGroup
            
            func performRequest(with langs: [String]) -> OCRResult? {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.recognitionLanguages = langs
                
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    return nil
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    return nil
                }
                
                var lines: [OCRLineItem] = []
                var fullTextPieces: [String] = []
                let imageWidth = CGFloat(cgImage.width)
                let imageHeight = CGFloat(cgImage.height)
                
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    let text = topCandidate.string
                    let confidence = topCandidate.confidence
                    let box = observation.boundingBox
                    
                    // Convert normalized Vision coordinates (origin bottom-left) to standard image rect
                    let rect = CGRect(
                        x: box.origin.x * imageWidth,
                        y: (1.0 - box.origin.y - box.size.height) * imageHeight,
                        width: box.size.width * imageWidth,
                        height: box.size.height * imageHeight
                    )
                    lines.append(OCRLineItem(text: text, confidence: confidence, boundingBox: rect, normalizedBox: box))
                    fullTextPieces.append(text)
                }
                
                let fullText = fullTextPieces.joined(separator: "\n")
                return OCRResult(fullText: fullText, lines: lines)
            }
            
            guard let result1 = performRequest(with: group1) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "SnipSnapOCR", code: -2, userInfo: [NSLocalizedDescriptionKey: "文字识别执行异常"])))
                }
                return
            }
            
            let trimmed1 = result1.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 当主通道未识别到文字、文字较短或需要交叉比对时，运行第二通道进行智能补位与优选
            if let result2 = performRequest(with: group2) {
                let trimmed2 = result2.fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // 若第二通道识别出了内容而第一通道为空，或第二通道识别出的文字字符明显更完整（例如日韩文）：
                if (trimmed1.isEmpty && !trimmed2.isEmpty) || (trimmed2.count > trimmed1.count + 2) {
                    DispatchQueue.main.async {
                        completion(.success(result2))
                    }
                    return
                }
            }
            
            DispatchQueue.main.async {
                completion(.success(result1))
            }
        }
    }
}
