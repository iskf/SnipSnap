import Cocoa
import SwiftUI

// MARK: - View Model

public final class InputTranslateViewModel: ObservableObject, @unchecked Sendable {
    @Published public var originalText: String = ""
    @Published public var translatedText: String = ""
    @Published public var sourceLang: String = "auto"
    @Published public var targetLang: String = "en"
    @Published public var detectedSourceLang: String = "auto"
    @Published public var selectedProvider: String = "apple"
    @Published public var isLoading: Bool = false
    @Published public var isStreaming: Bool = false
    @Published public var isShowingOriginal: Bool = false
    @Published public var errorMessage: String? = nil
    @Published public var toastMessage: String? = nil
    
    public var activeTask: CancellableTask? = nil
    public var context: FocusedInputContext? = nil
    public var onDismiss: (() -> Void)?
    
    public init(text: String, context: FocusedInputContext?) {
        self.originalText = text
        self.context = context
        
        let config = AppConfig.load()
        self.selectedProvider = config.translationProvider
        self.targetLang = InPlaceTranslateViewModel.normalizeLanguageCode(config.inputTranslateTargetLanguage)
        
        if !text.isEmpty {
            setupInitialLanguages(text: text, config: config)
        }
    }
    
    private func setupInitialLanguages(text: String, config: AppConfig) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let detected = InPlaceTranslateViewModel.detectDominantLanguage(for: trimmed) ?? "zh-Hans"
        self.detectedSourceLang = detected
        
        if config.smartBiDirectionalSwap {
            let isTargetMatched = InPlaceTranslateViewModel.normalizeLanguageCode(detected) == InPlaceTranslateViewModel.normalizeLanguageCode(config.inputTranslateTargetLanguage)
            if isTargetMatched {
                // If input text is already in the target language (e.g. English), auto-swap back to native (e.g. Chinese)
                self.sourceLang = config.inputTranslateTargetLanguage
                self.targetLang = config.targetTranslateLanguage.hasPrefix("zh") ? "zh-Hans" : "zh-Hans"
            } else {
                self.sourceLang = "auto"
                self.targetLang = config.inputTranslateTargetLanguage
            }
        } else {
            self.sourceLang = "auto"
            self.targetLang = config.inputTranslateTargetLanguage
        }
    }
    
    public var availableEngines: [AvailableEngineItem] {
        var items: [AvailableEngineItem] = [
            AvailableEngineItem(id: "apple", displayName: L10n("translate.engine.apple"), shortName: "Apple", iconName: "applelogo")
        ]
        let config = AppConfig.load()
        if let url = AITranslationProvider.resolveEndpoint(from: config.aiBaseURL) {
            let isLocalhost = url.host == "localhost" || url.host == "127.0.0.1"
            let hasKey = !config.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if isLocalhost || hasKey {
                let preset = config.aiProviderPreset
                let name = preset == "deepseek" ? "DeepSeek" : (preset == "openai" ? "OpenAI" : (preset == "ollama" ? "Ollama" : "AI"))
                items.append(AvailableEngineItem(id: "ai", displayName: "\(name) \(L10n("translate.engine.ai"))", shortName: name, iconName: "sparkles"))
            }
        }
        if !config.deeplAuthKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            items.append(AvailableEngineItem(id: "deepl", displayName: L10n("translate.engine.deepl"), shortName: "DeepL", iconName: "globe"))
        }
        return items
    }
    
    public var currentEngineItem: AvailableEngineItem {
        if let found = availableEngines.first(where: { $0.id == selectedProvider }) {
            return found
        }
        return AvailableEngineItem(id: selectedProvider, displayName: selectedProvider.capitalized, shortName: selectedProvider.capitalized, iconName: "globe")
    }
    
    public var sourceLanguageDisplayName: String {
        if sourceLang == "auto" {
            if !detectedSourceLang.isEmpty && detectedSourceLang != "auto" {
                return "\(L10n("translate.auto")) (\(shortName(for: detectedSourceLang)))"
            }
            return L10n("translate.auto")
        }
        return shortName(for: sourceLang)
    }
    
    public var targetLanguageDisplayName: String {
        return shortName(for: targetLang)
    }
    
    public func shortName(for code: String) -> String {
        let norm = InPlaceTranslateViewModel.normalizeLanguageCode(code)
        if let found = InPlaceTranslateViewModel.supportedLanguages.first(where: { $0.code == norm }) {
            return L10n(found.shortKey)
        }
        return String(code.prefix(2)).uppercased()
    }
    
    public func languageName(for code: String) -> String {
        let norm = InPlaceTranslateViewModel.normalizeLanguageCode(code)
        if let found = InPlaceTranslateViewModel.supportedLanguages.first(where: { $0.code == norm }) {
            return L10n(found.nameKey)
        }
        return code
    }
    
    public func startTranslation() {
        let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }
        
        if detectedSourceLang == "auto" {
            setupInitialLanguages(text: trimmed, config: AppConfig.load())
        }
        
        cancelCurrentTask()
        self.isLoading = true
        self.errorMessage = nil
        self.translatedText = ""
        self.isShowingOriginal = false
        
        let effSource = (sourceLang == "auto") ? detectedSourceLang : sourceLang
        
        if selectedProvider == "ai" {
            self.isStreaming = true
            self.activeTask = TranslationService.shared.translateStream(
                text: trimmed,
                from: effSource,
                to: targetLang,
                provider: "ai",
                onChunk: { [weak self] chunk in
                    guard let self = self else { return }
                    if self.isLoading {
                        self.isLoading = false
                        self.translatedText = ""
                    }
                    self.translatedText += chunk
                },
                completion: { [weak self] result in
                    guard let self = self else { return }
                    self.isLoading = false
                    self.isStreaming = false
                    self.activeTask = nil
                    switch result {
                    case .success(let resp):
                        self.translatedText = resp.translatedText
                    case .failure(let err):
                        if (err as NSError).code != NSURLErrorCancelled {
                            self.errorMessage = err.localizedDescription
                        }
                    }
                }
            )
        } else {
            self.isStreaming = false
            TranslationService.shared.translate(
                text: trimmed,
                from: effSource,
                to: targetLang,
                provider: selectedProvider
            ) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.isLoading = false
                    switch result {
                    case .success(let resp):
                        self.translatedText = resp.translatedText
                    case .failure(let err):
                        self.errorMessage = err.localizedDescription
                    }
                }
            }
        }
    }
    
    public func cancelCurrentTask() {
        activeTask?.cancel()
        activeTask = nil
        isLoading = false
        isStreaming = false
    }
    
    public func toggleShowingOriginal() {
        guard !originalText.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.14)) {
            isShowingOriginal.toggle()
        }
    }
    
    public func copyCurrentText() {
        let textToCopy = isShowingOriginal ? originalText : (translatedText.isEmpty ? originalText : translatedText)
        let trimmed = textToCopy.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(trimmed, forType: .string)
        
        withAnimation {
            self.toastMessage = L10n("translate.copied")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            withAnimation {
                self?.toastMessage = nil
            }
        }
    }
    
    public func confirmReplacement() {
        cancelCurrentTask()
        let textToInject = translatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !textToInject.isEmpty else {
            onDismiss?()
            return
        }
        let savedContext = context
        onDismiss?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            InputTranslateService.shared.replaceInputText(with: textToInject, context: savedContext)
        }
    }
    
    public func cancel() {
        cancelCurrentTask()
        onDismiss?()
    }
    
    public func cycleNextEngine() {
        let engines = availableEngines
        guard engines.count > 1 else { return }
        if let idx = engines.firstIndex(where: { $0.id == selectedProvider }) {
            let next = engines[(idx + 1) % engines.count]
            changeEngine(next.id)
        } else if let first = engines.first {
            changeEngine(first.id)
        }
    }
    
    public func changeEngine(_ newProvider: String) {
        guard selectedProvider != newProvider else { return }
        selectedProvider = newProvider
        startTranslation()
    }
    
    public func changeSourceLanguage(_ newLang: String) {
        guard sourceLang != newLang else { return }
        sourceLang = newLang
        startTranslation()
    }
    
    public func changeTargetLanguage(_ newLang: String) {
        let norm = InPlaceTranslateViewModel.normalizeLanguageCode(newLang)
        guard targetLang != norm else { return }
        targetLang = norm
        
        var config = AppConfig.load()
        config.recordRecentTargetLanguage(norm)
        
        startTranslation()
    }
    
    public func swapLanguages() {
        let oldTarget = targetLang
        let oldSource = (sourceLang == "auto") ? detectedSourceLang : sourceLang
        self.sourceLang = oldTarget
        self.targetLang = oldSource
        self.detectedSourceLang = oldTarget
        startTranslation()
    }
}

// MARK: - SwiftUI View: Layout Aligned with Selection Translate HUD

public struct InputTranslateCapsuleView: View {
    @ObservedObject public var viewModel: InputTranslateViewModel
    @State private var isSwapHovered: Bool = false
    @FocusState private var isInputFocused: Bool
    
    public init(viewModel: InputTranslateViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 1. Top Floating Capsule Toolbar (Matching Selection Translate HUD)
            capsuleToolbar
            
            // 2. Bottom Text Preview / Input Card
            inputTranslateContentCard
        }
        .padding(8)
    }
    
    // MARK: - Top Capsule Toolbar
    
    private var capsuleToolbar: some View {
        HStack(spacing: 7) {
            // 1. [ 原文 | 译文 ] Segmented Control
            if !viewModel.originalText.isEmpty {
                originalTranslatedPicker
            }
            
            // 2. [ 源语言 ⇄ 目标语言 ▾ ] Unified Language Pair Picker
            unifiedLanguagePairPicker
            
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.18))
                .frame(width: 0.8, height: 12)
            
            // 3. Engine Switcher Menu [  Apple ▾ / ✨ DeepSeek ▾ ]
            engineSwitcherMenu
            
            // Toast Pill (e.g. 已复制)
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
                .background(Color.black.opacity(0.85))
                .cornerRadius(5)
                .transition(.opacity)
            }
            
            Spacer(minLength: 4)
            
            // 4. [ ↵ 替换 ] (Replaces the Copy Button in Selection Translate HUD)
            Button(action: {
                viewModel.confirmReplacement()
            }) {
                HStack(spacing: 3.5) {
                    Image(systemName: "return")
                        .font(.system(size: 9, weight: .bold))
                    Text(L10n("input_translate.replace"))
                        .font(.system(size: 10.5, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3.2)
                .background(Color(red: 0.16, green: 0.65, blue: 0.40))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.25), lineWidth: 0.6)
                )
            }
            .buttonStyle(.plain)
            .help(L10n("input_translate.replace_help"))
            .disabled(viewModel.translatedText.isEmpty && viewModel.errorMessage != nil)
            
            // 5. Close Button [ ✕ ]
            Button(action: {
                viewModel.cancel()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
                    .padding(4.5)
                    .background(Color.white.opacity(0.16))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(L10n("input_translate.cancel_help"))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            ZStack {
                Color(NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.13, alpha: 0.98))
                LinearGradient(
                    colors: [Color.white.opacity(0.10), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.24), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.40), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - [ 原文 | 译文 ] Segmented Picker
    
    private var originalTranslatedPicker: some View {
        HStack(spacing: 0) {
            // 原文
            Button(action: {
                if !viewModel.isShowingOriginal {
                    viewModel.toggleShowingOriginal()
                }
            }) {
                Text(L10n("translate.tab.original"))
                    .font(.system(size: 10.5, weight: viewModel.isShowingOriginal ? .bold : .medium))
                    .foregroundColor(viewModel.isShowingOriginal ? .white : Color.white.opacity(0.72))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.8)
                    .background(
                        viewModel.isShowingOriginal
                            ? RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.26))
                            : RoundedRectangle(cornerRadius: 5).fill(Color.clear)
                    )
            }
            .buttonStyle(.plain)
            
            // 译文
            Button(action: {
                if viewModel.isShowingOriginal {
                    viewModel.toggleShowingOriginal()
                }
            }) {
                Text(L10n("translate.tab.translated"))
                    .font(.system(size: 10.5, weight: !viewModel.isShowingOriginal ? .bold : .medium))
                    .foregroundColor(!viewModel.isShowingOriginal ? .white : Color.white.opacity(0.72))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2.8)
                    .background(
                        !viewModel.isShowingOriginal
                            ? RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.26))
                            : RoundedRectangle(cornerRadius: 5).fill(Color.clear)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(1.5)
        .background(Color.black.opacity(0.35))
        .cornerRadius(6.5)
        .overlay(
            RoundedRectangle(cornerRadius: 6.5)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
        )
        .animation(.easeInOut(duration: 0.14), value: viewModel.isShowingOriginal)
        .help(L10n("translate.switch_help"))
    }
    
    // MARK: - Unified Language Pair Picker [ 中 ⇄ 英 ▾ ]
    
    private var unifiedLanguagePairPicker: some View {
        HStack(spacing: 2.5) {
            // Source Language Menu
            Menu {
                Button(action: { viewModel.changeSourceLanguage("auto") }) {
                    HStack {
                        let autoDesc = (viewModel.detectedSourceLang != "auto" && !viewModel.detectedSourceLang.isEmpty)
                            ? "\(L10n("translate.auto_detect")) (\(viewModel.shortName(for: viewModel.detectedSourceLang)))"
                            : L10n("translate.auto_detect")
                        Text(autoDesc)
                        if viewModel.sourceLang == "auto" {
                            Image(systemName: "checkmark")
                        }
                    }
                }
                Divider()
                ForEach(InPlaceTranslateViewModel.supportedLanguages, id: \.code) { lang in
                    Button(action: { viewModel.changeSourceLanguage(lang.code) }) {
                        HStack {
                            Text(viewModel.languageName(for: lang.code))
                            if viewModel.sourceLang != "auto" && InPlaceTranslateViewModel.normalizeLanguageCode(viewModel.sourceLang) == lang.code {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(viewModel.sourceLanguageDisplayName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.8)
                    .background(Color.white.opacity(0.16))
                    .cornerRadius(5)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("\(L10n("translate.change_source")) (\(viewModel.sourceLanguageDisplayName))")
            
            // Swap Button
            Button(action: { viewModel.swapLanguages() }) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundColor(isSwapHovered ? .white : Color.white.opacity(0.85))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2.8)
                    .background(isSwapHovered ? Color.white.opacity(0.20) : Color.clear)
                    .cornerRadius(4.5)
            }
            .buttonStyle(.plain)
            .onHover { isSwapHovered = $0 }
            .help(L10n("translate.swap_help"))
            
            // Target Language Menu
            Menu {
                let recents = AppConfig.load().recentTargetLanguages
                if !recents.isEmpty {
                    Section(L10n("translate.recent_languages")) {
                        ForEach(recents, id: \.self) { code in
                            Button(action: { viewModel.changeTargetLanguage(code) }) {
                                HStack {
                                    Text(viewModel.languageName(for: code))
                                    if InPlaceTranslateViewModel.normalizeLanguageCode(viewModel.targetLang) == InPlaceTranslateViewModel.normalizeLanguageCode(code) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    Divider()
                }
                Section(L10n("translate.all_languages")) {
                    ForEach(InPlaceTranslateViewModel.supportedLanguages, id: \.code) { lang in
                        Button(action: { viewModel.changeTargetLanguage(lang.code) }) {
                            HStack {
                                Text(L10n(lang.nameKey))
                                if InPlaceTranslateViewModel.normalizeLanguageCode(viewModel.targetLang) == lang.code {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                Text(viewModel.targetLanguageDisplayName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.8)
                    .background(Color.white.opacity(0.16))
                    .cornerRadius(5)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("\(L10n("translate.change_target")) (\(viewModel.targetLanguageDisplayName))")
        }
        .padding(1.5)
        .background(Color.black.opacity(0.35))
        .cornerRadius(6.5)
        .overlay(
            RoundedRectangle(cornerRadius: 6.5)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.6)
        )
    }
    
    // MARK: - Engine Switcher Menu [  Apple ▾ / ✨ DeepSeek ▾ ]
    
    private var engineSwitcherMenu: some View {
        Menu {
            ForEach(viewModel.availableEngines) { engine in
                Button(action: { viewModel.changeEngine(engine.id) }) {
                    HStack {
                        Text(engine.displayName)
                        if viewModel.selectedProvider == engine.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Button(action: { PreferencesWindowController.show() }) {
                HStack {
                    Text(L10n("translate.engine.configure_more"))
                    Image(systemName: "gearshape")
                }
            }
        } label: {
            HStack(spacing: 3.5) {
                if viewModel.isLoading || viewModel.isStreaming {
                    ProgressView()
                        .scaleEffect(0.45)
                        .frame(width: 9, height: 9)
                } else {
                    Image(systemName: viewModel.currentEngineItem.iconName)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(viewModel.selectedProvider == "ai" ? Color(red: 0.78, green: 0.58, blue: 1.0) : (viewModel.selectedProvider == "deepl" ? Color(red: 0.40, green: 0.78, blue: 1.0) : .white))
                }
                
                Text(viewModel.currentEngineItem.shortName)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.85))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2.8)
            .background(Color.white.opacity(0.16))
            .cornerRadius(5.5)
            .overlay(
                RoundedRectangle(cornerRadius: 5.5)
                    .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("\(L10n("translate.current_engine")): \(viewModel.currentEngineItem.displayName)\n\(L10n("translate.engine.switch_help"))")
    }
    
    // MARK: - Bottom Content Card (Matching Selection HUD Foundation)
    
    private var inputTranslateContentCard: some View {
        ZStack(alignment: .topLeading) {
            // Dark Frosted Foundation
            RoundedRectangle(cornerRadius: 9)
                .fill(Color(NSColor(calibratedRed: 0.12, green: 0.12, blue: 0.14, alpha: 0.96)))
            
            VStack(alignment: .leading, spacing: 6) {
                if viewModel.originalText.isEmpty {
                    // Empty state: professional input and interactive guidance
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 7) {
                            Image(systemName: "text.cursor")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(red: 0.38, green: 0.65, blue: 1.0))
                            
                            TextField(L10n("input_translate.placeholder"), text: $viewModel.originalText, onCommit: {
                                viewModel.startTranslation()
                            })
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundColor(.white)
                            .focused($isInputFocused)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 10)
                        
                        Divider()
                            .opacity(0.18)
                            .padding(.horizontal, 8)
                        
                        HStack(spacing: 5) {
                            Image(systemName: "lightbulb.fill")
                                .font(.system(size: 9.5))
                                .foregroundColor(.yellow.opacity(0.85))
                            Text(L10n("input_translate.guide_hint"))
                                .font(.system(size: 11))
                                .foregroundColor(Color.white.opacity(0.60))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            HStack(spacing: 4) {
                                keyBadge("Return", label: L10n("input_translate.action_translate"))
                                keyBadge("Esc", label: L10n("input_translate.action_cancel"))
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isInputFocused = true
                        }
                    }
                } else if viewModel.isLoading && viewModel.translatedText.isEmpty {
                    // Loading state
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 14, height: 14)
                        Text(L10n("input_translate.translating"))
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                    .padding(10)
                } else if let err = viewModel.errorMessage {
                    // Error state with retry
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.system(size: 11))
                        Text(err)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.yellow)
                        Spacer()
                        Button(action: { viewModel.startTranslation() }) {
                            Text(L10n("translate.retry"))
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(10)
                } else {
                    // Normal text display
                    VStack(alignment: .leading, spacing: 4) {
                        let textToShow = viewModel.isShowingOriginal ? viewModel.originalText : viewModel.translatedText
                        ScrollView(.vertical, showsIndicators: true) {
                            Text(textToShow.isEmpty ? "..." : textToShow)
                                .font(.system(size: 12.5, weight: .regular))
                                .foregroundColor(.white)
                                .lineSpacing(4)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 10)
                                .padding(.top, 10)
                                .padding(.bottom, 4)
                        }
                        .frame(maxHeight: 180)
                        
                        Divider()
                            .opacity(0.18)
                            .padding(.horizontal, 8)
                        
                        HStack {
                            Text(L10n("input_translate.footer_hint"))
                                .font(.system(size: 10.5))
                                .foregroundColor(Color.white.opacity(0.50))
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                    }
                }
            }
        }
        .overlay(
            // Apple Intelligence Radiant Violet-Blue Glow Outline
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color(red: 0.38, green: 0.58, blue: 1.0).opacity(0.6),
                            Color(red: 0.68, green: 0.38, blue: 0.98).opacity(0.6),
                            Color(red: 0.92, green: 0.42, blue: 0.78).opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.45), radius: 8, x: 0, y: 3)
    }
    
    private func keyBadge(_ key: String, label: String) -> some View {
        HStack(spacing: 2.5) {
            Text(key)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.85))
                .padding(.horizontal, 4.5)
                .padding(.vertical, 1.5)
                .background(Color.white.opacity(0.18))
                .cornerRadius(3.5)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Color.white.opacity(0.55))
        }
    }
}

// MARK: - Floating Window & Controller

public final class InputTranslateCapsuleWindow: NSWindow {
    public var onEnterPressed: (() -> Void)?
    public var onEscPressed: (() -> Void)?
    public var onSpacePressed: (() -> Void)?
    public var onTabPressed: (() -> Void)?
    public var onCopyPressed: (() -> Void)?
    
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.isMovableByWindowBackground = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isReleasedWhenClosed = false
    }
    
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    
    public override func keyDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "c" {
            onCopyPressed?()
            return
        }
        if event.keyCode == 36 { // Enter
            onEnterPressed?()
            return
        }
        if event.keyCode == 53 { // Esc
            onEscPressed?()
            return
        }
        if event.keyCode == 49 { // Spacebar
            onSpacePressed?()
            return
        }
        if event.keyCode == 48 { // Tab
            onTabPressed?()
            return
        }
        super.keyDown(with: event)
    }
}

public final class InputTranslateWindowController: NSWindowController {
    public static var current: InputTranslateWindowController?
    
    public let viewModel: InputTranslateViewModel
    private var globalClickMonitor: Any?
    private var localKeyMonitor: Any?
    private var appearTime: TimeInterval = 0
    
    public init(window: InputTranslateCapsuleWindow, viewModel: InputTranslateViewModel) {
        self.viewModel = viewModel
        super.init(window: window)
        
        window.onEnterPressed = { [weak self] in
            guard let self = self else { return }
            if !self.viewModel.translatedText.isEmpty {
                self.viewModel.confirmReplacement()
            } else {
                self.viewModel.startTranslation()
            }
        }
        window.onEscPressed = { [weak self] in self?.viewModel.cancel() }
        window.onSpacePressed = { [weak self] in self?.viewModel.toggleShowingOriginal() }
        window.onTabPressed = { [weak self] in self?.viewModel.cycleNextEngine() }
        window.onCopyPressed = { [weak self] in self?.viewModel.copyCurrentText() }
        
        setupMonitors()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupMonitors() {
        appearTime = ProcessInfo.processInfo.systemUptime
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self, let win = self.window else { return }
                let now = ProcessInfo.processInfo.systemUptime
                // Ignore clicks during the first 450ms so that the opening mouse click doesn't instantly dismiss
                if now - self.appearTime < 0.45 { return }
                if win.attachedSheet != nil || !(win.childWindows?.isEmpty ?? true) { return }
                let mouseLocation = NSEvent.mouseLocation
                if win.frame.insetBy(dx: -12, dy: -12).contains(mouseLocation) { return }
                self.closeWindow()
            }
        }
        
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers?.lowercased() == "c" {
                self.viewModel.copyCurrentText()
                return nil
            }
            if event.keyCode == 36 { // Enter
                if !self.viewModel.translatedText.isEmpty {
                    self.viewModel.confirmReplacement()
                } else {
                    self.viewModel.startTranslation()
                }
                return nil
            }
            if event.keyCode == 53 { // Esc
                self.viewModel.cancel()
                return nil
            }
            if event.keyCode == 49 { // Space
                // If originalText is empty, let space be typed
                if !self.viewModel.originalText.isEmpty {
                    self.viewModel.toggleShowingOriginal()
                    return nil
                }
            }
            if event.keyCode == 48 { // Tab
                self.viewModel.cycleNextEngine()
                return nil
            }
            return event
        }
    }
    
    public static func show(with context: FocusedInputContext) {
        closeCurrent()
        
        let trimmedText = context.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let vm = InputTranslateViewModel(text: trimmedText, context: context)
        
        let windowW: CGFloat = 500.0
        let windowH: CGFloat = 135.0
        
        let targetScreen = NSScreen.screens.first(where: { $0.frame.intersects(context.screenRect) }) ?? NSScreen.main ?? NSScreen.screens.first!
        let vf = targetScreen.visibleFrame
        
        // Position window right above the focused input field, or below if near top
        var originX = context.screenRect.minX
        var originY = context.screenRect.maxY + 8.0
        
        if originY + windowH > vf.maxY {
            originY = max(context.screenRect.minY - windowH - 8.0, vf.minY + 8.0)
        }
        if originX + windowW > vf.maxX {
            originX = vf.maxX - windowW - 12.0
        }
        originX = max(originX, vf.minX + 12.0)
        
        let targetFrame = NSRect(x: originX, y: originY, width: windowW, height: windowH)
        let window = InputTranslateCapsuleWindow(contentRect: targetFrame)
        
        let controller = InputTranslateWindowController(window: window, viewModel: vm)
        current = controller
        
        vm.onDismiss = { [weak controller] in
            controller?.closeWindow()
        }
        
        let hosting = NSHostingView(rootView: InputTranslateCapsuleView(viewModel: vm))
        hosting.frame = NSRect(origin: .zero, size: targetFrame.size)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        window.contentView = hosting
        
        window.setFrame(targetFrame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        if !trimmedText.isEmpty {
            vm.startTranslation()
        }
    }
    
    public static func closeCurrent() {
        if let existing = current {
            existing.closeWindow()
            current = nil
        }
    }
    
    public func closeWindow() {
        if let monitor = globalClickMonitor {
            NSEvent.removeMonitor(monitor)
            globalClickMonitor = nil
        }
        if let monitor = localKeyMonitor {
            NSEvent.removeMonitor(monitor)
            localKeyMonitor = nil
        }
        window?.orderOut(nil)
        window?.close()
        if InputTranslateWindowController.current === self {
            InputTranslateWindowController.current = nil
        }
    }
}
