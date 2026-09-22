import Foundation
import AppKit

public struct AppConfig: Codable, Equatable {
    public static let shared = AppConfig()
    
    // MARK: - 1. General (通用设置)
    public var language: String = "system" // "system", "zhHans", "en", "ja", "ko"
    public var launchAtLogin: Bool = false
    public var menuBarIconMonochrome: Bool = false
    public var playSoundEffect: Bool = true
    public var autoCopyAfterCapture: Bool = true
    public var autoSaveAfterCapture: Bool = false
    public var imageSaveFormat: String = "PNG" // "PNG", "JPEG"
    public var defaultSavePath: String = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? ""
    
    // MARK: - 2. Hotkeys (四大金刚全局快捷键 - F1-F4 纯单键体系)
    public var screenshotShortcut: String = "F1"
    public var pinShortcut: String = "F2"
    public var scrollCaptureShortcut: String = "F3"
    public var translateShortcut: String = "F4"
    public var togglePinsShortcut: String = "F5"
    public var inputTranslateShortcut: String = "⇧F4"
    
    // Compatibility alias for legacy code referencing ocrShortcut
    public var ocrShortcut: String {
        get { translateShortcut }
        set { translateShortcut = newValue }
    }
    
    // MARK: - 3. Capture & Annotation (截图与标注)
    public var showLoupe: Bool = true
    public var loupeColorFormat: String = "HEX" // "HEX", "RGB", "HSL"
    public var defaultStrokeColorHex: String = "#FF3B30"
    public var defaultStrokeWidth: CGFloat = 3.0
    public var autoPinAfterCapture: Bool = false
    
    // MARK: - 4. Pinning (贴图设置)
    public var pinWindowBorder: Bool = true
    public var pinWindowShadow: Bool = true
    public var pinWindowRoundedCorners: Bool = true
    public var pinInitialAlpha: Double = 1.0
    public var doubleClickPinAction: String = "zoom" // "zoom", "close", "annotate"
    
    // MARK: - 5. OCR & Translation (OCR与翻译)
    public var ocrLanguages: [String] = ["zh-Hans", "en-US", "ja-JP", "ko-KR"]
    public var targetTranslateLanguage: String = "zh-Hans"
    public var inputTranslateTargetLanguage: String = "en"
    public var smartBiDirectionalSwap: Bool = true
    public var recentTargetLanguages: [String] = ["en", "zh-Hans", "ja"]
    public var autoCopyOCRText: Bool = false
    public var translationProvider: String = "apple" // "apple", "deepl", "ai"
    public var deeplAuthKey: String = ""
    public var deeplIsFreeAPI: Bool = true
    
    // AI Translation (大模型翻译)
    public var aiProviderPreset: String = "deepseek" // "deepseek", "openai", "claude", "ollama", "custom"
    public var aiBaseURL: String = "https://api.deepseek.com"
    public var aiApiKey: String = ""
    public var aiModelName: String = "deepseek-chat"
    public var aiTemperature: Double = 0.3
    public var aiSystemPrompt: String = "You are a professional, accurate, and context-aware translator. Translate the given text faithfully and naturally into the target language. Retain original markdown, LaTeX, and inline code formatting (e.g. `code`). Only return the translated text without any explanation or commentary."
    
    // MARK: - 6. GIF Recording (动图录制设置)
    public var gifFrameRate: Int = 15 // 10, 15, 20, 30
    public var gifMaxDuration: Int = 30 // 15, 30, 60
    public var gifDownsample: Bool = true
    public var gifCaptureCursor: Bool = true
    public var gifAutoCopy: Bool = true
    public var gifAutoSave: Bool = false
    public var gifPlaySound: Bool = true
    
    public init() {}
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.language = (try? container.decodeIfPresent(String.self, forKey: .language)) ?? "system"
        self.launchAtLogin = (try? container.decodeIfPresent(Bool.self, forKey: .launchAtLogin)) ?? false
        self.menuBarIconMonochrome = (try? container.decodeIfPresent(Bool.self, forKey: .menuBarIconMonochrome)) ?? false
        self.playSoundEffect = (try? container.decodeIfPresent(Bool.self, forKey: .playSoundEffect)) ?? true
        self.autoCopyAfterCapture = (try? container.decodeIfPresent(Bool.self, forKey: .autoCopyAfterCapture)) ?? true
        self.autoSaveAfterCapture = (try? container.decodeIfPresent(Bool.self, forKey: .autoSaveAfterCapture)) ?? false
        self.imageSaveFormat = (try? container.decodeIfPresent(String.self, forKey: .imageSaveFormat)) ?? "PNG"
        self.defaultSavePath = (try? container.decodeIfPresent(String.self, forKey: .defaultSavePath)) ?? (FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first?.path ?? "")
        self.screenshotShortcut = (try? container.decodeIfPresent(String.self, forKey: .screenshotShortcut)) ?? "F1"
        self.pinShortcut = (try? container.decodeIfPresent(String.self, forKey: .pinShortcut)) ?? "F2"
        self.scrollCaptureShortcut = (try? container.decodeIfPresent(String.self, forKey: .scrollCaptureShortcut)) ?? "F3"
        self.translateShortcut = (try? container.decodeIfPresent(String.self, forKey: .translateShortcut)) ?? "F4"
        self.togglePinsShortcut = (try? container.decodeIfPresent(String.self, forKey: .togglePinsShortcut)) ?? "F5"
        self.inputTranslateShortcut = (try? container.decodeIfPresent(String.self, forKey: .inputTranslateShortcut)) ?? "⇧F4"
        
        // Migration: Ensure new F1-F4 standard layout
        if self.scrollCaptureShortcut.isEmpty || (self.translateShortcut == "F2" && self.pinShortcut == "F3") {
            self.pinShortcut = "F2"
            self.scrollCaptureShortcut = "F3"
            self.translateShortcut = "F4"
        }
        
        self.showLoupe = (try? container.decodeIfPresent(Bool.self, forKey: .showLoupe)) ?? true
        self.loupeColorFormat = (try? container.decodeIfPresent(String.self, forKey: .loupeColorFormat)) ?? "HEX"
        self.defaultStrokeColorHex = (try? container.decodeIfPresent(String.self, forKey: .defaultStrokeColorHex)) ?? "#FF3B30"
        self.defaultStrokeWidth = (try? container.decodeIfPresent(CGFloat.self, forKey: .defaultStrokeWidth)) ?? 3.0
        self.autoPinAfterCapture = (try? container.decodeIfPresent(Bool.self, forKey: .autoPinAfterCapture)) ?? false
        self.pinWindowBorder = (try? container.decodeIfPresent(Bool.self, forKey: .pinWindowBorder)) ?? true
        self.pinWindowShadow = (try? container.decodeIfPresent(Bool.self, forKey: .pinWindowShadow)) ?? true
        self.pinWindowRoundedCorners = (try? container.decodeIfPresent(Bool.self, forKey: .pinWindowRoundedCorners)) ?? true
        self.pinInitialAlpha = (try? container.decodeIfPresent(Double.self, forKey: .pinInitialAlpha)) ?? 1.0
        self.doubleClickPinAction = (try? container.decodeIfPresent(String.self, forKey: .doubleClickPinAction)) ?? "zoom"
        self.ocrLanguages = (try? container.decodeIfPresent([String].self, forKey: .ocrLanguages)) ?? ["zh-Hans", "en-US", "ja-JP", "ko-KR"]
        self.targetTranslateLanguage = (try? container.decodeIfPresent(String.self, forKey: .targetTranslateLanguage)) ?? "zh-Hans"
        self.inputTranslateTargetLanguage = (try? container.decodeIfPresent(String.self, forKey: .inputTranslateTargetLanguage)) ?? "en"
        self.smartBiDirectionalSwap = (try? container.decodeIfPresent(Bool.self, forKey: .smartBiDirectionalSwap)) ?? true
        self.recentTargetLanguages = (try? container.decodeIfPresent([String].self, forKey: .recentTargetLanguages)) ?? ["en", "zh-Hans", "ja"]
        self.autoCopyOCRText = (try? container.decodeIfPresent(Bool.self, forKey: .autoCopyOCRText)) ?? false
        let prov = (try? container.decodeIfPresent(String.self, forKey: .translationProvider)) ?? "apple"
        self.translationProvider = (prov == "builtin") ? "apple" : prov
        self.deeplAuthKey = (try? container.decodeIfPresent(String.self, forKey: .deeplAuthKey)) ?? ""
        self.deeplIsFreeAPI = (try? container.decodeIfPresent(Bool.self, forKey: .deeplIsFreeAPI)) ?? true
        self.aiProviderPreset = (try? container.decodeIfPresent(String.self, forKey: .aiProviderPreset)) ?? "deepseek"
        self.aiBaseURL = (try? container.decodeIfPresent(String.self, forKey: .aiBaseURL)) ?? "https://api.deepseek.com"
        self.aiApiKey = (try? container.decodeIfPresent(String.self, forKey: .aiApiKey)) ?? ""
        self.aiModelName = (try? container.decodeIfPresent(String.self, forKey: .aiModelName)) ?? "deepseek-chat"
        self.aiTemperature = (try? container.decodeIfPresent(Double.self, forKey: .aiTemperature)) ?? 0.3
        self.aiSystemPrompt = (try? container.decodeIfPresent(String.self, forKey: .aiSystemPrompt)) ?? "You are a professional, accurate, and context-aware translator. Translate the given text faithfully and naturally into the target language. Retain original markdown, LaTeX, and inline code formatting (e.g. `code`). Only return the translated text without any explanation or commentary."
        self.gifFrameRate = (try? container.decodeIfPresent(Int.self, forKey: .gifFrameRate)) ?? 15
        self.gifMaxDuration = (try? container.decodeIfPresent(Int.self, forKey: .gifMaxDuration)) ?? 30
        self.gifDownsample = (try? container.decodeIfPresent(Bool.self, forKey: .gifDownsample)) ?? true
        self.gifCaptureCursor = (try? container.decodeIfPresent(Bool.self, forKey: .gifCaptureCursor)) ?? true
        self.gifAutoCopy = (try? container.decodeIfPresent(Bool.self, forKey: .gifAutoCopy)) ?? true
        self.gifAutoSave = (try? container.decodeIfPresent(Bool.self, forKey: .gifAutoSave)) ?? false
        self.gifPlaySound = (try? container.decodeIfPresent(Bool.self, forKey: .gifPlaySound)) ?? true
    }
    
    // MARK: - Persistence
    
    public static let didChangeNotification = Notification.Name("SnipSnapAppConfigDidChange")
    
    public static func load() -> AppConfig {
        if let data = UserDefaults.standard.data(forKey: "SnipSnapAppConfig"),
           let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
            return config
        }
        return AppConfig()
    }
    
    public func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "SnipSnapAppConfig")
            NotificationCenter.default.post(name: AppConfig.didChangeNotification, object: self)
        }
    }
    
    public mutating func recordRecentTargetLanguage(_ lang: String) {
        var recents = recentTargetLanguages.filter { $0.lowercased() != lang.lowercased() }
        recents.insert(lang, at: 0)
        if recents.count > 4 {
            recents = Array(recents.prefix(4))
        }
        self.recentTargetLanguages = recents
        save()
    }
    
    public mutating func resetToDefaults() {
        self = AppConfig()
        save()
    }
    
    // MARK: - Conflict Detection
    
    public func checkConflict(for newKey: String, actionIdentifier: String) -> String? {
        let trimmed = newKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        let hotkeys: [(id: String, name: String, key: String)] = [
            ("screenshot", "屏幕截图", screenshotShortcut),
            ("pin", "剪贴板贴图", pinShortcut),
            ("scrollCapture", "长截图", scrollCaptureShortcut),
            ("translate", "选区翻译", translateShortcut),
            ("ocr", "选区翻译", translateShortcut),
            ("togglePins", "隐藏/显示所有贴图", togglePinsShortcut),
            ("inputTranslate", "输入框翻译与替换", inputTranslateShortcut)
        ]
        
        for item in hotkeys {
            if item.id != actionIdentifier && !(actionIdentifier == "ocr" && item.id == "translate") && item.key.caseInsensitiveCompare(trimmed) == .orderedSame {
                return item.name
            }
        }
        return nil
    }
}
