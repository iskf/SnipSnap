import Cocoa
import SwiftUI
import NaturalLanguage
#if canImport(Translation)
import Translation
#endif

// MARK: - View Model

public class InPlaceTranslateViewModel: ObservableObject {
    public enum TranslationErrorType: Equatable {
        case none
        case noTextDetected
        case missingLanguagePack
        case networkOffline
        case sameLanguage
        case generic(String)
    }
    
    @Published public var errorType: TranslationErrorType = .none
    @Published public var isUsingOnlineFallbackDueToMissingPack: Bool = false
    @Published public var isUsingOnlineAutoDetection: Bool = false
    @Published public var sourceImage: NSImage? = nil
    @Published public var originalText: String = ""
    @Published public var translatedText: String = ""
    @Published public var sourceLang: String = "auto"
    @Published public var targetLang: String = "zh-Hans"
    @Published public var detectedSourceLang: String = "auto"
    @Published public var userSelectedTargetLang: Bool = false
    @Published public var isLoading: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var engineName: String = "Apple 原生翻译"
    @Published public var toastMessage: String? = nil
    @Published public var translationTrigger: Int = 0
    @Published public var isShowingOriginal: Bool = false
    @Published public var ocrLines: [OCRLineItem] = []
    
    public static func openSystemTranslationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.Localization-Settings.extension"),
           NSWorkspace.shared.open(url) {
            return
        }
        if let fallback = URL(string: "x-apple.systempreferences:com.apple.systempreferences.GeneralSettings") {
            NSWorkspace.shared.open(fallback)
        }
    }
    
    public var canvasSize: CGSize = .zero
    public var onClose: (() -> Void)?
    public var onCopyFinished: (() -> Void)?
    public var onRetryOCR: (() -> Void)?
    
    public static let supportedLanguages: [(code: String, name: String, shortName: String)] = [
        ("zh-Hans", "中文 (简体)", "中"),
        ("en", "英语 (English)", "英"),
        ("ja", "日语 (日本語)", "日"),
        ("ko", "韩语 (한국어)", "韩"),
        ("fr", "法语 (Français)", "法"),
        ("de", "德语 (Deutsch)", "德"),
        ("es", "西班牙语 (Español)", "西"),
        ("ru", "俄语 (Русский)", "俄")
    ]
    
    public var sourceLanguageShortName: String {
        if sourceLang == "auto" {
            if !detectedSourceLang.isEmpty && detectedSourceLang != "auto" {
                return shortName(for: detectedSourceLang)
            }
            return "自动"
        }
        return shortName(for: sourceLang)
    }
    
    public var sourceLanguageDisplayName: String {
        if sourceLang == "auto" {
            if !detectedSourceLang.isEmpty && detectedSourceLang != "auto" {
                return "自动 (\(shortName(for: detectedSourceLang)))"
            }
            return "自动"
        }
        let normalized = Self.normalizeLanguageCode(sourceLang)
        if let match = Self.supportedLanguages.first(where: { $0.code == normalized }) {
            return match.shortName + "文"
        }
        return shortName(for: sourceLang)
    }
    
    public var targetLanguageDisplayName: String {
        let normalized = Self.normalizeLanguageCode(targetLang)
        if let match = Self.supportedLanguages.first(where: { $0.code == normalized }) {
            return match.shortName + "文"
        }
        return shortName(for: targetLang)
    }
    
    public var targetLanguageShortName: String {
        return shortName(for: targetLang)
    }
    
    public func shortName(for code: String) -> String {
        let normalized = Self.normalizeLanguageCode(code)
        if normalized.hasPrefix("zh") { return "中" }
        if normalized.hasPrefix("en") { return "英" }
        if normalized.hasPrefix("ja") { return "日" }
        if normalized.hasPrefix("ko") { return "韩" }
        if normalized.hasPrefix("fr") { return "法" }
        if normalized.hasPrefix("de") { return "德" }
        if normalized.hasPrefix("es") { return "西" }
        if normalized.hasPrefix("ru") { return "俄" }
        return String(code.prefix(2)).uppercased()
    }
    
    public static func normalizeLanguageCode(_ code: String) -> String {
        switch code.lowercased() {
        case "zh-hans", "zh", "zh_cn", "zh-cn": return "zh-Hans"
        case "zh-hant", "zh_tw", "zh-tw": return "zh-Hant"
        case "en", "en-us", "en-gb": return "en"
        case "ja", "ja-jp": return "ja"
        case "ko", "ko-kr": return "ko"
        case "fr", "fr-fr": return "fr"
        case "de", "de-de": return "de"
        case "es", "es-es": return "es"
        case "ru", "ru-ru": return "ru"
        default: return code
        }
    }
    
    public static func detectDominantLanguage(for text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // 1. Check Chinese character presence first (common in screenshots)
        if TranslationService.shared.detectIsChinese(trimmed) {
            return "zh-Hans"
        }
        
        // 2. Check Japanese kana
        let hasKana = trimmed.unicodeScalars.contains { scalar in
            (0x3040...0x309F).contains(scalar.value) || (0x30A0...0x30FF).contains(scalar.value)
        }
        if hasKana {
            return "ja"
        }
        
        // 3. Check Korean Hangul
        let hasHangul = trimmed.unicodeScalars.contains { scalar in
            (0xAC00...0xD7AF).contains(scalar.value) || (0x1100...0x11FF).contains(scalar.value)
        }
        if hasHangul {
            return "ko"
        }
        
        // 4. Use Apple NaturalLanguage framework
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmed)
        if let dominant = recognizer.dominantLanguage {
            let code = dominant.rawValue
            switch code {
            case "zh-Hans", "zh-Hant", "zh": return "zh-Hans"
            case "en": return "en"
            case "ja": return "ja"
            case "ko": return "ko"
            case "fr": return "fr"
            case "de": return "de"
            case "es": return "es"
            case "ru": return "ru"
            default:
                let hypotheses = recognizer.languageHypotheses(withMaximum: 2)
                if let top = hypotheses.sorted(by: { $0.value > $1.value }).first, top.value >= 0.45 {
                    return normalizeLanguageCode(top.key.rawValue)
                }
            }
        }
        
        // 5. If pure latin letters/words, assume English
        let latinLetters = trimmed.filter { $0.isLetter && $0.isASCII }
        if Double(latinLetters.count) / Double(max(trimmed.count, 1)) >= 0.3 {
            return "en"
        }
        
        return nil
    }
    
    public var sampledStyle: SampledImageStyle {
        ImageColorSampler.sampleStyle(from: sourceImage, text: originalText)
    }
    
    public var formattedTranslatedText: String {
        var text = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        let origTrimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        if origTrimmed.hasPrefix("//") && !text.hasPrefix("//") {
            text = "// " + text
        } else if origTrimmed.hasPrefix("#") && !text.hasPrefix("#") {
            text = "# " + text
        }
        return text
    }
    
    public init(sourceImage: NSImage? = nil, originalText: String = "", sourceLang: String = "auto", targetLang: String? = nil, canvasSize: CGSize = .zero) {
        self.sourceImage = sourceImage
        self.originalText = originalText
        self.sourceLang = sourceLang
        self.canvasSize = canvasSize
        
        let config = AppConfig.load()
        self.engineName = (config.translationProvider == "deepl" && !config.deeplAuthKey.isEmpty) ? "DeepL 官方" : "Apple 原生翻译"
        
        let preferred = (targetLang != nil && !targetLang!.isEmpty) ? targetLang! : config.targetTranslateLanguage
        self.targetLang = Self.normalizeLanguageCode(preferred)
    }
    
    public func toggleShowingOriginal() {
        withAnimation(.easeInOut(duration: 0.16)) {
            isShowingOriginal.toggle()
        }
    }
    
    public func changeSourceLanguage(_ newLang: String) {
        let norm = (newLang == "auto") ? "auto" : Self.normalizeLanguageCode(newLang)
        guard self.sourceLang != norm else { return }
        self.sourceLang = norm
        self.isUsingOnlineAutoDetection = false
        self.errorMessage = nil
        self.translatedText = ""
        performTranslation()
    }
    
    public func changeTargetLanguage(_ newLang: String) {
        let norm = Self.normalizeLanguageCode(newLang)
        guard self.targetLang != norm else { return }
        self.targetLang = norm
        self.userSelectedTargetLang = true
        self.isUsingOnlineAutoDetection = false
        self.errorMessage = nil
        self.translatedText = ""
        performTranslation()
    }
    
    public func swapLanguages() {
        let currentTarget = Self.normalizeLanguageCode(self.targetLang)
        let resolvedSource: String
        if self.sourceLang == "auto" {
            resolvedSource = (!self.detectedSourceLang.isEmpty && self.detectedSourceLang != "auto") ? Self.normalizeLanguageCode(self.detectedSourceLang) : "zh-Hans"
        } else {
            resolvedSource = Self.normalizeLanguageCode(self.sourceLang)
        }
        
        self.sourceLang = currentTarget
        self.targetLang = resolvedSource
        self.detectedSourceLang = currentTarget
        self.userSelectedTargetLang = true
        self.isUsingOnlineAutoDetection = false
        self.errorType = .none
        self.errorMessage = nil
        self.translatedText = ""
        performTranslation()
    }
    
    public func retry() {
        self.errorType = .none
        self.errorMessage = nil
        self.isLoading = true
        if let onRetry = onRetryOCR {
            onRetry()
        } else {
            performTranslation()
        }
    }
    
    public func calculateTextBounds(for size: CGSize) -> (maskRect: CGRect, textRect: CGRect, fontSize: CGFloat)? {
        guard let img = sourceImage,
              let cgImage = img.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.width > 0, cgImage.height > 0 else {
            return nil
        }
        
        guard !ocrLines.isEmpty, errorMessage == nil, !originalText.isEmpty else {
            return nil
        }
        
        let scaleX = size.width / CGFloat(cgImage.width)
        let scaleY = size.height / CGFloat(cgImage.height)
        
        var unionRect = CGRect.null
        for line in ocrLines {
            let lr = CGRect(
                x: line.boundingBox.minX * scaleX,
                y: line.boundingBox.minY * scaleY,
                width: line.boundingBox.width * scaleX,
                height: line.boundingBox.height * scaleY
            )
            unionRect = unionRect.isNull ? lr : unionRect.union(lr)
        }
        
        guard !unionRect.isNull else {
            return nil
        }
        
        let lineCount = max(ocrLines.count, 1)
        let avgLineHeight = unionRect.height / CGFloat(lineCount)
        let fontSize = max(min(avgLineHeight * 0.72, 22), 11.5)
        
        let maskRect = CGRect(
            x: max(unionRect.minX - 4, 0),
            y: max(unionRect.minY - 2, 0),
            width: min(unionRect.width + 8, size.width),
            height: min(unionRect.height + 4, size.height)
        )
        
        return (maskRect, unionRect, fontSize)
    }
    
    public func startTranslation(with text: String) {
        let cleaned = TranslationService.cleanOCRTextForTranslation(text)
        self.originalText = cleaned
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.isLoading = false
            self.errorType = .noTextDetected
            self.errorMessage = "未检测到清晰文字"
            return
        }
        
        if let detected = Self.detectDominantLanguage(for: trimmed) {
            self.detectedSourceLang = detected
            self.isUsingOnlineAutoDetection = false
        } else {
            self.detectedSourceLang = "en"
            self.isUsingOnlineAutoDetection = true
        }
        
        let isChinese = (self.detectedSourceLang == "zh-Hans")
        
        if !userSelectedTargetLang {
            let config = AppConfig.load()
            let prefTarget = Self.normalizeLanguageCode(config.targetTranslateLanguage)
            
            if isChinese {
                // If source is Chinese and user preference is Chinese, translate to English
                if prefTarget.hasPrefix("zh") {
                    self.targetLang = "en"
                } else {
                    self.targetLang = prefTarget
                }
            } else {
                // If source is foreign and preference is English, translate to Chinese
                if prefTarget.hasPrefix("en") {
                    self.targetLang = "zh-Hans"
                } else {
                    self.targetLang = prefTarget.isEmpty ? "zh-Hans" : prefTarget
                }
            }
        }
        
        let sNorm = Self.normalizeLanguageCode(self.sourceLang == "auto" ? self.detectedSourceLang : self.sourceLang)
        let tNorm = Self.normalizeLanguageCode(self.targetLang)
        if !sNorm.isEmpty && !tNorm.isEmpty && sNorm == tNorm {
            self.isLoading = false
            self.errorType = .sameLanguage
            self.errorMessage = "源语言与目标语言相同"
            return
        }
        
        performTranslation()
    }
    
    public func performTranslation() {
        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let sNorm = Self.normalizeLanguageCode(self.sourceLang == "auto" ? self.detectedSourceLang : self.sourceLang)
        let tNorm = Self.normalizeLanguageCode(self.targetLang)
        if !sNorm.isEmpty && !tNorm.isEmpty && sNorm == tNorm {
            self.isLoading = false
            self.errorType = .sameLanguage
            self.errorMessage = "源语言与目标语言相同"
            return
        }
        
        self.isLoading = true
        self.errorType = .none
        self.errorMessage = nil
        
        let config = AppConfig.load()
        if config.translationProvider == "deepl" && !config.deeplAuthKey.isEmpty {
            self.engineName = "DeepL 官方"
            translateViaMultiChannel()
            return
        }
        
        // If low confidence and online auto-detection is triggered, directly use multi-channel online engine to avoid Apple's broken out-of-process popup
        if self.isUsingOnlineAutoDetection && self.sourceLang == "auto" {
            self.engineName = "智能在线"
            translateViaMultiChannel()
            return
        }
        
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            self.engineName = "Apple 原生翻译"
            self.translationTrigger += 1
            return
        }
        #endif
        
        self.engineName = "内置多通道"
        translateViaMultiChannel()
    }
    
    public func translateViaMultiChannel() {
        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        self.isLoading = true
        
        TranslationService.shared.translate(
            text: trimmed,
            from: sourceLang,
            to: targetLang
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                switch result {
                case .success(let response):
                    self.translatedText = response.translatedText
                    self.errorType = .none
                    self.errorMessage = nil
                    let config = AppConfig.load()
                    if config.translationProvider == "deepl" && !config.deeplAuthKey.isEmpty {
                        self.engineName = "DeepL 官方"
                    } else if self.isUsingOnlineFallbackDueToMissingPack {
                        self.engineName = "在线备用"
                    } else if self.isUsingOnlineAutoDetection {
                        self.engineName = "智能在线"
                    } else {
                        self.engineName = "Apple 原生翻译"
                    }
                case .failure(let error):
                    let desc = error.localizedDescription
                    if self.isUsingOnlineFallbackDueToMissingPack {
                        self.errorType = .missingLanguagePack
                        self.errorMessage = "离线语言包未下载且网络不可用"
                    } else if desc.contains("网络") || desc.contains("network") || desc.contains("Internet") || (error as NSError).code == -1009 {
                        self.errorType = .networkOffline
                        self.errorMessage = "网络连接不可用"
                    } else {
                        self.errorType = .generic(desc)
                        self.errorMessage = "翻译失败: \(desc)"
                    }
                }
            }
        }
    }
    
    public func copyTranslated() {
        let textToCopy = formattedTranslatedText.isEmpty ? translatedText : formattedTranslatedText
        guard !textToCopy.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(textToCopy, forType: .string)
        NSSound(named: "Tink")?.play()
        showToast("已复制译文")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.onCopyFinished?()
        }
    }
    
    public func copyOriginal() {
        guard !originalText.isEmpty else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(originalText, forType: .string)
        NSSound(named: "Tink")?.play()
        showToast("已复制原文")
    }
    
    private func showToast(_ msg: String) {
        self.toastMessage = msg
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            if self?.toastMessage == msg {
                self?.toastMessage = nil
            }
        }
    }
}

#if canImport(Translation)
@available(macOS 15.0, *)
private struct AppleNativeTranslationModifier: ViewModifier {
    @ObservedObject var viewModel: InPlaceTranslateViewModel
    @State private var config: TranslationSession.Configuration?
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                triggerTranslation()
            }
            .onChange(of: viewModel.translationTrigger) { _, _ in
                triggerTranslation()
            }
            .onChange(of: viewModel.targetLang) { _, _ in
                triggerTranslation()
            }
            .onChange(of: viewModel.sourceLang) { _, _ in
                triggerTranslation()
            }
            .translationTask(config) { session in
                do {
                    let response = try await session.translate(viewModel.originalText)
                    DispatchQueue.main.async {
                        viewModel.isLoading = false
                        viewModel.translatedText = TranslationService.postProcessTranslatedText(response.targetText)
                        viewModel.engineName = "Apple 原生翻译"
                    }
                } catch {
                    DispatchQueue.main.async {
                        viewModel.isUsingOnlineFallbackDueToMissingPack = true
                        viewModel.errorType = .none
                        viewModel.errorMessage = nil
                        viewModel.translateViaMultiChannel()
                    }
                }
            }
    }
    
    private func triggerTranslation() {
        guard !viewModel.originalText.isEmpty else { return }
        // Explicit concrete source language - NEVER pass nil to avoid Apple's broken out-of-process sheet!
        let effectiveSource = (viewModel.sourceLang == "auto") ? viewModel.detectedSourceLang : viewModel.sourceLang
        let sNorm = InPlaceTranslateViewModel.normalizeLanguageCode(effectiveSource.isEmpty ? "en" : effectiveSource)
        let tNorm = InPlaceTranslateViewModel.normalizeLanguageCode(viewModel.targetLang)
        
        let sCode = Locale.Language(identifier: sNorm)
        let tCode = Locale.Language(identifier: tNorm)
        config = TranslationSession.Configuration(source: sCode, target: tCode)
    }
}
#endif

// MARK: - Native Apple-Style Segmented Control for [ 原文 | 译文 ]
private struct OriginalTranslatedSegmentedPicker: View {
    @ObservedObject var viewModel: InPlaceTranslateViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            // 原文
            Button(action: {
                if !viewModel.isShowingOriginal {
                    viewModel.toggleShowingOriginal()
                }
            }) {
                Text("原文")
                    .font(.system(size: 10, weight: viewModel.isShowingOriginal ? .semibold : .regular))
                    .foregroundColor(viewModel.isShowingOriginal ? .white : Color.white.opacity(0.55))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.8)
                    .background(
                        viewModel.isShowingOriginal
                            ? RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.24))
                            : RoundedRectangle(cornerRadius: 6).fill(Color.clear)
                    )
            }
            .buttonStyle(.plain)
            
            // 译文
            Button(action: {
                if viewModel.isShowingOriginal {
                    viewModel.toggleShowingOriginal()
                }
            }) {
                Text("译文")
                    .font(.system(size: 10, weight: !viewModel.isShowingOriginal ? .semibold : .regular))
                    .foregroundColor(!viewModel.isShowingOriginal ? .white : Color.white.opacity(0.55))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.8)
                    .background(
                        !viewModel.isShowingOriginal
                            ? RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.24))
                            : RoundedRectangle(cornerRadius: 6).fill(Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(1.2)
        .background(Color.white.opacity(0.08))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
        )
        .animation(.easeInOut(duration: 0.14), value: viewModel.isShowingOriginal)
        .help("在原文与译文之间原地切换 (敲击空格键也可切换)")
    }
}

// MARK: - Native Apple-Style Language Pair [ 中 ⇄ 英 ▾ ]
private struct UnifiedLanguagePairPicker: View {
    @ObservedObject var viewModel: InPlaceTranslateViewModel
    @State private var isSwapHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 2) {
            // 1. Source language menu (Allows manual user selection!)
            Menu {
                Button(action: {
                    viewModel.changeSourceLanguage("auto")
                }) {
                    HStack {
                        let autoDesc = (viewModel.detectedSourceLang != "auto" && !viewModel.detectedSourceLang.isEmpty)
                            ? "自动检测 (\(viewModel.shortName(for: viewModel.detectedSourceLang)))"
                            : "自动检测"
                        Text(autoDesc)
                        if viewModel.sourceLang == "auto" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                
                Divider()
                
                ForEach(InPlaceTranslateViewModel.supportedLanguages, id: \.code) { lang in
                    Button(action: {
                        viewModel.changeSourceLanguage(lang.code)
                    }) {
                        HStack {
                            Text(lang.name)
                            if viewModel.sourceLang != "auto" && InPlaceTranslateViewModel.normalizeLanguageCode(viewModel.sourceLang) == lang.code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(viewModel.sourceLanguageDisplayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.8)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(5.5)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("点击修改原语言 (当前: \(viewModel.sourceLanguageDisplayName))")
            
            // 2. Swap button
            Button(action: {
                viewModel.swapLanguages()
            }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(isSwapHovered ? .white : Color.white.opacity(0.65))
                    .padding(.horizontal, 3.5)
                    .padding(.vertical, 2.8)
                    .background(isSwapHovered ? Color.white.opacity(0.15) : Color.clear)
                    .cornerRadius(4.5)
            }
            .buttonStyle(.plain)
            .onHover { isSwapHovered = $0 }
            .help("互换源语言与目标语言")
            
            // 3. Target language menu
            Menu {
                ForEach(InPlaceTranslateViewModel.supportedLanguages, id: \.code) { lang in
                    Button(action: {
                        viewModel.changeTargetLanguage(lang.code)
                    }) {
                        HStack {
                            Text(lang.name)
                            if InPlaceTranslateViewModel.normalizeLanguageCode(viewModel.targetLang) == lang.code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(viewModel.targetLanguageDisplayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.8)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(5.5)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("点击修改目标语言 (当前: \(viewModel.targetLanguageDisplayName))")
        }
        .padding(1.2)
        .background(Color.white.opacity(0.08))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.6)
        )
    }
}

// MARK: - SwiftUI In-Place Screen Translate Overlay View (Safari Style)

public struct InPlaceTranslateHUDView: View {
    @ObservedObject public var viewModel: InPlaceTranslateViewModel
    @State private var isBreathingGlow: Bool = false
    @State private var dragInitialOrigin: CGPoint? = nil
    
    public init(viewModel: InPlaceTranslateViewModel) {
        self.viewModel = viewModel
    }
    
    @ViewBuilder
    public var body: some View {
        let content = VStack(alignment: .leading, spacing: 6) {
            capsuleToolbar
            inPlaceSelectionCanvas
        }
        .padding(8)
        
        #if canImport(Translation)
        if #available(macOS 15.0, *) {
            content.modifier(AppleNativeTranslationModifier(viewModel: viewModel))
        } else {
            content
        }
        #else
        content
        #endif
    }
    
    // MARK: - Mini Floating Capsule Toolbar (Safari Style & Draggable)
    private var capsuleToolbar: some View {
        HStack(spacing: 7) {
            // 1. Apple Native Segmented Control [ 原文 | 译文 ]
            if viewModel.errorMessage == nil && (!viewModel.translatedText.isEmpty || viewModel.isLoading) {
                OriginalTranslatedSegmentedPicker(viewModel: viewModel)
            }
            
            // 2. Apple Native Unified Language Pair [ 中 ⇄ 英 ▾ ]
            UnifiedLanguagePairPicker(viewModel: viewModel)
            
            // Subtle Divider
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 0.8, height: 12)
            
            // 3. Status or Engine Badge (minimalist icon by default, expands on error/fallback/loading)
            switch viewModel.errorType {
            case .missingLanguagePack:
                Button(action: {
                    InPlaceTranslateViewModel.openSystemTranslationSettings()
                }) {
                    HStack(spacing: 3.5) {
                        Image(systemName: "shippingbox.fill")
                            .font(.system(size: 8.5))
                            .foregroundColor(.orange)
                        Text("离线包未下载")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.orange)
                        Text("去下载 ↗")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(Color.orange.opacity(0.40))
                            .cornerRadius(4)
                    }
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2.5)
                    .background(Color.orange.opacity(0.16))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .help("点击前往 macOS「语言与地区」系统设置下载翻译语言包")

            case .noTextDetected:
                HStack(spacing: 3.5) {
                    Image(systemName: "text.badge.xmark")
                        .font(.system(size: 8.5))
                        .foregroundColor(.yellow)
                    Text("未检测到文字")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.yellow)
                    
                    Button(action: {
                        viewModel.retry()
                    }) {
                        Text("重试")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.25))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("重新框选检测并翻译")
                }
                .padding(.horizontal, 5.5)
                .padding(.vertical, 2.5)
                .background(Color.yellow.opacity(0.16))
                .cornerRadius(6)

            case .sameLanguage:
                HStack(spacing: 3.5) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 8.5))
                        .foregroundColor(.cyan)
                    Text("源与目标相同")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.cyan)
                    
                    Button(action: {
                        viewModel.swapLanguages()
                    }) {
                        Text("互换")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(Color.cyan.opacity(0.40))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("互换源语言与目标语言")
                }
                .padding(.horizontal, 5.5)
                .padding(.vertical, 2.5)
                .background(Color.cyan.opacity(0.16))
                .cornerRadius(6)

            case .networkOffline:
                HStack(spacing: 3.5) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 8.5))
                        .foregroundColor(.red)
                    Text("网络连接不可用")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.red)
                    
                    Button(action: {
                        viewModel.retry()
                    }) {
                        Text("重试")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.25))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("检查网络并重试")
                }
                .padding(.horizontal, 5.5)
                .padding(.vertical, 2.5)
                .background(Color.red.opacity(0.16))
                .cornerRadius(6)

            case .generic(let desc):
                HStack(spacing: 3.5) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8.5))
                        .foregroundColor(.yellow)
                    Text(desc.count > 12 ? String(desc.prefix(10)) + "..." : desc)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.yellow)
                    
                    Button(action: {
                        viewModel.retry()
                    }) {
                        Text("重试")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 1.5)
                            .background(Color.white.opacity(0.25))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 5.5)
                .padding(.vertical, 2.5)
                .background(Color.yellow.opacity(0.16))
                .cornerRadius(6)

            case .none:
                if viewModel.isUsingOnlineFallbackDueToMissingPack {
                    // Non-blocking gentle clickable pill when degraded to online fallback
                    Button(action: {
                        InPlaceTranslateViewModel.openSystemTranslationSettings()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "globe")
                                .font(.system(size: 8.5))
                                .foregroundColor(.cyan)
                            Text("已转在线·缺离线包")
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(.cyan)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 7.5, weight: .bold))
                                .foregroundColor(Color.cyan.opacity(0.85))
                        }
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 2.5)
                        .background(Color.cyan.opacity(0.15))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .help("因 Apple 离线语言包未安装，当前已自动降级为在线翻译。点击可前往系统设置下载离线包。")
                } else if viewModel.isUsingOnlineAutoDetection {
                    // Gentle indicator pill when low-confidence source language triggered online auto-fallback
                    HStack(spacing: 3.5) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 8.5))
                            .foregroundColor(.cyan)
                        Text("智能在线补位")
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.cyan)
                    }
                    .padding(.horizontal, 5.5)
                    .padding(.vertical, 2.5)
                    .background(Color.cyan.opacity(0.15))
                    .cornerRadius(6)
                    .help("源语种特征不明显，已启用多通道智能在线识别与翻译")
                } else {
                    // Minimalist subtle engine indicator (icon only with tooltip to save horizontal space)
                    HStack(spacing: 3.5) {
                        if viewModel.isLoading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 10, height: 10)
                        } else {
                            Image(systemName: viewModel.engineName.contains("Apple") ? "applelogo" : "globe")
                                .font(.system(size: 9.5))
                                .foregroundColor(Color.white.opacity(0.60))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2.5)
                    .help("当前翻译引擎: \(viewModel.engineName)")
                }
            }
            
            if let toast = viewModel.toastMessage {
                HStack(spacing: 3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.black.opacity(0.75))
                .cornerRadius(5)
                .transition(.opacity)
            }
            
            Spacer(minLength: 4)
            
            // 4. Copy Translation (only if translation is available)
            if !viewModel.translatedText.isEmpty && viewModel.errorMessage == nil {
                Button(action: {
                    viewModel.copyTranslated()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                        Text("复制")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(Color.white.opacity(0.90))
                    .padding(.horizontal, 6.5)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.09))
                    .cornerRadius(6.5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6.5)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .help("复制译文到剪贴板")
            }
            
            // 5. Close Button
            Button(action: {
                viewModel.onClose?()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.75))
                    .padding(4)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("退出翻译 (Esc 或点击外部均可退出)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(
            ZStack {
                TranslateHUDVisualEffectView()
                Color(NSColor(calibratedWhite: 0.12, alpha: 0.88))
            }
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 2)
        .frame(height: 28)
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { gesture in
                    guard let win = NSApp.windows.first(where: { $0 is TranslateFloatingWindow && $0.isVisible }) else { return }
                    if dragInitialOrigin == nil {
                        dragInitialOrigin = win.frame.origin
                    }
                    if let origin = dragInitialOrigin {
                        win.setFrameOrigin(CGPoint(x: origin.x + gesture.translation.width, y: origin.y - gesture.translation.height))
                    }
                }
                .onEnded { _ in
                    dragInitialOrigin = nil
                }
        )
    }
    
    // MARK: - In-Place Selection Canvas (Pixel-Perfect Registration)
    private var inPlaceSelectionCanvas: some View {
        let style = viewModel.sampledStyle
        let canvasW = viewModel.canvasSize.width
        let canvasH = viewModel.canvasSize.height
        let boundsInfo = viewModel.calculateTextBounds(for: viewModel.canvasSize)
        
        return ZStack(alignment: .topLeading) {
            // Base Layer: Original cropped screenshot (Always fully visible!)
            if let img = viewModel.sourceImage {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: canvasW, height: canvasH)
            } else {
                Color.clear
                    .frame(width: canvasW, height: canvasH)
            }
            
            // Overlay Layer: When translation is active and valid text exists, replace text in-place
            if !viewModel.isShowingOriginal {
                if let info = boundsInfo, viewModel.errorMessage == nil {
                    let maskRect = info.maskRect
                    let textRect = info.textRect
                    let fontSize = info.fontSize
                    
                    // Step 1: Seamless background patch (erases the original text cleanly)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(style.backgroundColor)
                        .frame(width: maskRect.width, height: maskRect.height)
                        .offset(x: maskRect.minX, y: maskRect.minY)
                    
                    // Step 2: In-place translated text typography
                    ZStack(alignment: .topLeading) {
                        if viewModel.isLoading && viewModel.translatedText.isEmpty {
                            HStack(spacing: 4) {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 12, height: 12)
                                Text("正在翻译...")
                                    .font(.system(size: fontSize, weight: .regular))
                                    .foregroundColor(style.textColor.opacity(0.6))
                            }
                            .padding(2)
                        } else {
                            let displayText = viewModel.formattedTranslatedText.isEmpty ? viewModel.translatedText : viewModel.formattedTranslatedText
                            Text(displayText)
                                .font(style.isCodeSnippet ? .system(size: fontSize, weight: .medium, design: .monospaced) : .system(size: fontSize, weight: .regular, design: .default))
                                .foregroundColor(style.textColor)
                                .lineSpacing(max(fontSize * 0.28, 3))
                                .fixedSize(horizontal: false, vertical: false)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(width: textRect.width, height: textRect.height, alignment: .topLeading)
                    .offset(x: textRect.minX, y: textRect.minY)
                }
            }
            
            // Apple Intelligence Radiant Violet-Blue Glow Outline (or colored hint on error)
            if viewModel.errorType == .missingLanguagePack {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.orange.opacity(0.80), lineWidth: 1.5)
                    .shadow(color: Color.orange.opacity(0.35), radius: 5, x: 0, y: 0)
                    .allowsHitTesting(false)
            } else if viewModel.errorMessage != nil {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.yellow.opacity(0.75), lineWidth: 1.5)
                    .shadow(color: Color.yellow.opacity(0.35), radius: 5, x: 0, y: 0)
                    .allowsHitTesting(false)
            } else {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(red: 0.38, green: 0.58, blue: 1.0), // Luminous Blue
                                Color(red: 0.68, green: 0.38, blue: 0.98), // Apple Intelligence Violet
                                Color(red: 0.92, green: 0.42, blue: 0.78)  // Radiant Magenta Tint
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.8
                    )
                    // Layer 1: Near intense radiant bloom (radius: 6)
                    .shadow(
                        color: Color(red: 0.55, green: 0.35, blue: 1.0)
                            .opacity(viewModel.isLoading ? (isBreathingGlow ? 0.95 : 0.60) : 0.82),
                        radius: 6, x: 0, y: 0
                    )
                    // Layer 2: Soft ambient radiant glow (radius: 10)
                    .shadow(
                        color: Color(red: 0.35, green: 0.50, blue: 1.0)
                            .opacity(viewModel.isLoading ? (isBreathingGlow ? 0.80 : 0.45) : 0.60),
                        radius: 10, x: 0, y: 0
                    )
                    .allowsHitTesting(false)
            }
        }
        .frame(width: canvasW, height: canvasH)
        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
        .onAppear {
            if viewModel.isLoading {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    isBreathingGlow = true
                }
            }
        }
        .onChange(of: viewModel.isLoading) { loading in
            if loading {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    isBreathingGlow = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    isBreathingGlow = false
                }
            }
        }
    }
}

// MARK: - Translucent Blur Background
struct TranslateHUDVisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - AppKit Hosting View Wrapper

public class InPlaceTranslateHUDHostingView: NSHostingView<InPlaceTranslateHUDView> {
    public init(viewModel: InPlaceTranslateViewModel) {
        super.init(rootView: InPlaceTranslateHUDView(viewModel: viewModel))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public required init(rootView: InPlaceTranslateHUDView) {
        super.init(rootView: rootView)
    }
}
