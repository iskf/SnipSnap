import Foundation
#if canImport(Translation)
import Translation
#endif

public struct TranslationResponse: Sendable {
    public let translatedText: String
    public let sourceLanguage: String
    public let targetLanguage: String
    
    public init(translatedText: String, sourceLanguage: String, targetLanguage: String) {
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public class TranslationService: @unchecked Sendable {
    public static let shared = TranslationService()
    public let aiProvider = AITranslationProvider()
    
    private var lastGoogleFailure: Date?
    private let googleCooldownSeconds: TimeInterval = 300.0 // 5 minutes circuit breaker
    
    private init() {}
    
    // MARK: - OCR Text Normalization & Space Handling
    
    /// Smartly cleans OCR text for translation:
    /// - Merges English wrapped lines with a single space when continuing mid-sentence
    /// - Merges Chinese wrapped lines WITHOUT spaces (preventing awkward gaps between Chinese characters)
    /// - Normalizes consecutive spaces while preserving deliberate paragraph breaks
    public static func cleanOCRTextForTranslation(_ raw: String) -> String {
        let lines = raw.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        guard lines.count > 1 else { return raw }
        
        var joined: [String] = []
        for line in lines {
            if let last = joined.last {
                let lastChar = last.last ?? " "
                let isTerminator = [".", "!", "?", ";", "。", "！", "？", "；", ":", "："].contains(String(lastChar))
                let firstChar = line.first ?? " "
                
                let lastIsChinese = (0x4E00...0x9FFF).contains(lastChar.unicodeScalars.first?.value ?? 0)
                let firstIsChinese = (0x4E00...0x9FFF).contains(firstChar.unicodeScalars.first?.value ?? 0)
                
                if !isTerminator {
                    if lastIsChinese && firstIsChinese {
                        // In Chinese, soft line-breaks merge without inserting spaces
                        joined[joined.count - 1] = last + line
                        continue
                    } else if firstChar.isLetter && firstChar.isLowercase {
                        // In English, soft line-breaks merge with a clean single space
                        joined[joined.count - 1] = last + " " + line
                        continue
                    }
                }
            }
            joined.append(line)
        }
        return joined.joined(separator: "\n")
    }
    
    // MARK: - Post-processing & Output Typography Cleaner
    
    /// Cleans and formats translated output:
    /// 1. Strips stray URL encodings (%20, % 20, %0A, % 0A) from translation servers
    /// 2. Decodes HTML entities (&quot;, &#39;, &amp;, etc.)
    /// 3. Removes accidental spaces between Chinese characters ("立 即 定 位" -> "立即定位")
    /// 4. Cleans spaces before English punctuation ("hello , world ." -> "hello, world.")
    /// 5. Standardizes code comment spacing ("//1." -> "// 1.")
    /// 6. Collapses redundant consecutive spaces
    public static func postProcessTranslatedText(_ text: String) -> String {
        var s = text
        
        // 1. Clean URL percent remnants
        let urlRemnants = [
            ("% 20", " "), ("%20", " "),
            ("% 0A", "\n"), ("%0A", "\n"),
            ("% 0D", "\n"), ("%0D", "\n"),
            ("%2520", " "), ("%250A", "\n")
        ]
        for (token, rep) in urlRemnants {
            s = s.replacingOccurrences(of: token, with: rep)
        }
        
        // 2. Decode HTML entities
        let entities = [
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&amp;", "&"),
            ("&nbsp;", " ")
        ]
        for (entity, rep) in entities {
            s = s.replacingOccurrences(of: entity, with: rep)
        }
        
        // 3. Remove accidental spaces between Chinese characters
        let cjkSpacePattern = "([\\u4e00-\\u9fa5])\\s+([\\u4e00-\\u9fa5])"
        if let regex = try? NSRegularExpression(pattern: cjkSpacePattern, options: []) {
            var matchFound = true
            while matchFound {
                let range = NSRange(location: 0, length: s.utf16.count)
                if regex.firstMatch(in: s, options: [], range: range) != nil {
                    s = regex.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: "$1$2")
                } else {
                    matchFound = false
                }
            }
        }
        
        // 4. Clean spaces before English punctuation
        let punctPattern = "\\s+([,.:;?!])"
        if let regex = try? NSRegularExpression(pattern: punctPattern, options: []) {
            s = regex.stringByReplacingMatches(in: s, options: [], range: NSRange(location: 0, length: s.utf16.count), withTemplate: "$1")
        }
        
        // 5. Code comments "//" spacing
        if s.hasPrefix("//") && !s.hasPrefix("// ") && s.count > 2 {
            let index = s.index(s.startIndex, offsetBy: 2)
            s = "// " + s[index...]
        }
        
        // 6. Clean multiple consecutive spaces (preserves newlines)
        let multiSpace = "[ \\t]{2,}"
        if let regex = try? NSRegularExpression(pattern: multiSpace, options: []) {
            s = regex.stringByReplacingMatches(in: s, options: [], range: NSRange(location: 0, length: s.utf16.count), withTemplate: " ")
        }
        
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Public Main Translation Entry
    
    public func translate(
        text: String,
        from sourceLang: String = "auto",
        to targetLang: String? = nil,
        completion: @escaping @Sendable (Result<TranslationResponse, Error>) -> Void
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success(TranslationResponse(translatedText: "", sourceLanguage: "auto", targetLanguage: "zh")))
            return
        }
        
        let config = AppConfig.load()
        let isSourceChinese = detectIsChinese(trimmed)
        
        // Smart automatic language pairing
        let resolvedSource = sourceLang
        let resolvedTarget: String
        if let explicitTarget = targetLang, !explicitTarget.isEmpty, explicitTarget != "auto" {
            resolvedTarget = explicitTarget
        } else {
            resolvedTarget = isSourceChinese ? "en" : "zh-Hans"
        }
        
        if config.translationProvider == "ai" {
            _ = aiProvider.translate(
                text: trimmed,
                from: resolvedSource,
                to: resolvedTarget,
                options: TranslationOptions(isStreaming: false),
                completion: completion
            )
        } else if config.translationProvider == "deepl" && !config.deeplAuthKey.isEmpty {
            translateViaDeepL(text: trimmed, authKey: config.deeplAuthKey, isFree: config.deeplIsFreeAPI, from: resolvedSource, to: resolvedTarget) { [weak self] result in
                switch result {
                case .success(let resp):
                    completion(.success(resp))
                case .failure:
                    // Fallback to Apple official translation seamlessly
                    self?.translateViaApple(text: trimmed, isSourceChinese: isSourceChinese, from: resolvedSource, to: resolvedTarget, completion: completion)
                }
            }
        } else {
            translateViaApple(text: trimmed, isSourceChinese: isSourceChinese, from: resolvedSource, to: resolvedTarget, completion: completion)
        }
    }
    
    // MARK: - Streaming Translation Entry
    
    @discardableResult
    public func translateStream(
        text: String,
        from sourceLang: String = "auto",
        to targetLang: String? = nil,
        onChunk: @escaping @Sendable (String) -> Void,
        completion: @escaping @Sendable (Result<TranslationResponse, Error>) -> Void
    ) -> CancellableTask? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(.success(TranslationResponse(translatedText: "", sourceLanguage: "auto", targetLanguage: "zh")))
            return nil
        }
        
        let config = AppConfig.load()
        let isSourceChinese = detectIsChinese(trimmed)
        let resolvedSource = sourceLang
        let resolvedTarget: String
        if let explicitTarget = targetLang, !explicitTarget.isEmpty, explicitTarget != "auto" {
            resolvedTarget = explicitTarget
        } else {
            resolvedTarget = isSourceChinese ? "en" : "zh-Hans"
        }
        
        if config.translationProvider == "ai" {
            let options = TranslationOptions(isStreaming: true, onStreamChunk: onChunk)
            return aiProvider.translate(
                text: trimmed,
                from: resolvedSource,
                to: resolvedTarget,
                options: options,
                completion: completion
            )
        } else {
            translate(text: trimmed, from: sourceLang, to: targetLang) { result in
                if case .success(let resp) = result {
                    onChunk(resp.translatedText)
                }
                completion(result)
            }
            return nil
        }
    }
    
    // MARK: - Engine 1: Builtin Multi-Channel with Fast Circuit Breaker
    
    private func translateViaBuiltin(
        text: String,
        isSourceChinese: Bool,
        from sourceLang: String,
        to targetLang: String,
        completion: @escaping (Result<TranslationResponse, Error>) -> Void
    ) {
        // Check Circuit Breaker for Google endpoint
        if let lastFail = lastGoogleFailure, Date().timeIntervalSince(lastFail) < googleCooldownSeconds {
            // Google has recently failed (e.g. 429 rate limit or IP block), fast-track to Neural MyMemory
            translateViaMyMemoryFallback(text: text, isSourceChinese: isSourceChinese, from: sourceLang, to: targetLang, completion: completion)
            return
        }
        
        let gTarget = normalizeLanguageForGoogle(targetLang)
        let gSource = (sourceLang == "auto") ? "auto" : normalizeLanguageForGoogle(sourceLang)
        
        var components = URLComponents(string: "https://translate.googleapis.com/translate_a/single")
        components?.queryItems = [
            URLQueryItem(name: "client", value: "gtx"),
            URLQueryItem(name: "sl", value: gSource),
            URLQueryItem(name: "tl", value: gTarget),
            URLQueryItem(name: "dt", value: "t"),
            URLQueryItem(name: "q", value: text)
        ]
        
        guard let url = components?.url else {
            translateViaMyMemoryFallback(text: text, isSourceChinese: isSourceChinese, from: sourceLang, to: targetLang, completion: completion)
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0 // Tight timeout to avoid UI stalls
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
               let segments = json.first as? [Any] {
                
                var fullTranslated = ""
                for seg in segments {
                    if let item = seg as? [Any], let part = item.first as? String {
                        fullTranslated += part
                    }
                }
                
                if !fullTranslated.isEmpty {
                    let cleaned = Self.postProcessTranslatedText(fullTranslated)
                    DispatchQueue.main.async {
                        completion(.success(TranslationResponse(
                            translatedText: cleaned,
                            sourceLanguage: isSourceChinese ? "zh" : "en",
                            targetLanguage: targetLang
                        )))
                    }
                    return
                }
            }
            
            // Mark Google failure to activate circuit breaker
            self?.lastGoogleFailure = Date()
            
            // Fallback immediately to MyMemory Neural Translation
            self?.translateViaMyMemoryFallback(text: text, isSourceChinese: isSourceChinese, from: sourceLang, to: targetLang, completion: completion)
        }.resume()
    }
    
    private func translateViaMyMemoryFallback(
        text: String,
        isSourceChinese: Bool,
        from sourceLang: String,
        to targetLang: String,
        completion: @escaping (Result<TranslationResponse, Error>) -> Void
    ) {
        let sourceTag: String
        let targetTag: String
        if sourceLang == "auto" {
            sourceTag = isSourceChinese ? "zh-CN" : "en"
            targetTag = isSourceChinese ? "en" : "zh-CN"
        } else {
            sourceTag = normalizeLanguageForMyMemory(sourceLang)
            targetTag = normalizeLanguageForMyMemory(targetLang)
        }
        
        let langPair = "\(sourceTag)|\(targetTag)"
        
        var components = URLComponents(string: "https://api.mymemory.translated.net/get")
        components?.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "langpair", value: langPair),
            URLQueryItem(name: "de", value: "snipsnap_macos@app.internal")
        ]
        
        guard let url = components?.url else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "SnipSnapTranslation", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法构建翻译请求 URL"])))
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 7.0
        request.setValue("SnipSnap/1.0 (Macintosh; Intel Mac OS X)", forHTTPHeaderField: "User-Agent")
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let responseData = json["responseData"] as? [String: Any],
                  let translated = responseData["translatedText"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "SnipSnapTranslation", code: -2, userInfo: [NSLocalizedDescriptionKey: "翻译接口返回解析失败"])))
                }
                return
            }
            
            let cleaned = Self.postProcessTranslatedText(translated)
            
            DispatchQueue.main.async {
                completion(.success(TranslationResponse(
                    translatedText: cleaned,
                    sourceLanguage: isSourceChinese ? "zh" : "en",
                    targetLanguage: targetLang
                )))
            }
        }.resume()
    }
    
    // MARK: - Engine 2: DeepL Official API
    
    private func translateViaDeepL(
        text: String,
        authKey: String,
        isFree: Bool,
        from sourceLang: String,
        to targetLang: String,
        completion: @escaping (Result<TranslationResponse, Error>) -> Void
    ) {
        let trimmedKey = authKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            completion(.failure(NSError(domain: "DeepL", code: -1, userInfo: [NSLocalizedDescriptionKey: "DeepL Auth Key 不能为空"])))
            return
        }
        
        // DeepL Free keys always end with ':fx'. Auto-detect to avoid 403 endpoint mismatch.
        let effectiveIsFree = trimmedKey.hasSuffix(":fx") ? true : isFree
        let host = effectiveIsFree ? "api-free.deepl.com" : "api.deepl.com"
        guard let url = URL(string: "https://\(host)/v2/translate") else {
            completion(.failure(NSError(domain: "DeepL", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效 DeepL API 基础地址"])))
            return
        }
        
        let deepLTarget = normalizeTargetLanguageForDeepL(targetLang)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10.0
        request.setValue("DeepL-Auth-Key \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        var bodyComponents = URLComponents()
        var queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "target_lang", value: deepLTarget)
        ]
        if sourceLang != "auto" && !sourceLang.isEmpty {
            let deepLSource = normalizeSourceLanguageForDeepL(sourceLang)
            queryItems.append(URLQueryItem(name: "source_lang", value: deepLSource))
        }
        bodyComponents.queryItems = queryItems
        request.httpBody = bodyComponents.percentEncodedQuery?.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            // Check HTTP status code and extract clear diagnostic message from DeepL response
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                var serverMessage = ""
                if let data = data {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let msg = json["message"] as? String {
                        serverMessage = msg
                    } else if let rawString = String(data: data, encoding: .utf8), !rawString.isEmpty {
                        serverMessage = rawString
                    }
                }
                
                let failureReason: String
                switch httpResponse.statusCode {
                case 403:
                    if trimmedKey.hasSuffix(":fx") && !effectiveIsFree {
                        failureReason = "认证失败 (HTTP 403)：此 Key 属于 DeepL Free 免费版，请开启「免费版 API 终端」开关。"
                    } else if !trimmedKey.hasSuffix(":fx") && effectiveIsFree {
                        failureReason = "认证失败 (HTTP 403)：此 Key 属于 DeepL Pro 版，请关闭「免费版 API 终端」开关。"
                    } else {
                        failureReason = "认证失败 (HTTP 403)：API Key 无效或未授权。\(serverMessage.isEmpty ? "" : "[\(serverMessage)]")"
                    }
                case 456:
                    failureReason = "额度超限 (HTTP 456)：您的 DeepL 账号翻译字符用量已耗尽。"
                case 400:
                    failureReason = "请求参数错误 (HTTP 400)：\(serverMessage.isEmpty ? "请检查语言代码设置" : serverMessage)"
                case 429:
                    failureReason = "请求过于频繁 (HTTP 429)：并发过多，请稍后再试。"
                case 500...599:
                    failureReason = "DeepL 服务器错误 (HTTP \(httpResponse.statusCode))：\(serverMessage)"
                default:
                    failureReason = "DeepL 返回异常 (HTTP \(httpResponse.statusCode))：\(serverMessage)"
                }
                
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "DeepL", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: failureReason])))
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let translations = json["translations"] as? [[String: Any]],
                  let first = translations.first,
                  let translatedText = first["text"] as? String else {
                let rawBody = data != nil ? (String(data: data!, encoding: .utf8) ?? "") : ""
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "DeepL", code: -2, userInfo: [NSLocalizedDescriptionKey: "DeepL 返回数据格式错误: \(rawBody.prefix(80))"])))
                }
                return
            }
            
            let detected = first["detected_source_language"] as? String ?? sourceLang
            let cleaned = Self.postProcessTranslatedText(translatedText)
            
            DispatchQueue.main.async {
                completion(.success(TranslationResponse(
                    translatedText: cleaned,
                    sourceLanguage: detected,
                    targetLanguage: targetLang
                )))
            }
        }.resume()
    }
    
    // MARK: - DeepL Connection Test
    
    public func testDeepLConnection(
        authKey: String,
        isFree: Bool,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let trimmedKey = authKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            completion(.failure(NSError(domain: "DeepL", code: -1, userInfo: [NSLocalizedDescriptionKey: "Auth Key 不能为空"])))
            return
        }
        
        let effectiveIsFree = trimmedKey.hasSuffix(":fx") ? true : isFree
        translateViaDeepL(text: "Hello", authKey: trimmedKey, isFree: effectiveIsFree, from: "en", to: "zh-Hans") { result in
            switch result {
            case .success(let resp):
                let endpointInfo = effectiveIsFree ? "免费版终端" : "Pro 终端"
                completion(.success("连接成功！[\(endpointInfo)] 测试响应：「\(resp.translatedText)」"))
            case .failure(let err):
                completion(.failure(err))
            }
        }
    }
    
    // MARK: - AI Connection Test
    
    public func testAIConnection(
        baseURL: String,
        apiKey: String,
        model: String,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        aiProvider.testConnection(baseURL: baseURL, apiKey: apiKey, model: model, completion: completion)
    }
    
    // MARK: - Language Helpers
    
    public func detectIsChinese(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value)
        }
    }
    
    private func normalizeLanguageForGoogle(_ lang: String) -> String {
        switch lang.lowercased() {
        case "zh-hans", "zh", "zh_cn", "zh-cn": return "zh-CN"
        case "zh-hant", "zh_tw", "zh-tw": return "zh-TW"
        case "en", "en-us", "en-gb": return "en"
        case "ja", "ja-jp": return "ja"
        case "ko", "ko-kr": return "ko"
        case "fr": return "fr"
        case "de": return "de"
        case "es": return "es"
        case "ru": return "ru"
        default: return lang
        }
    }
    
    private func normalizeLanguageForMyMemory(_ lang: String) -> String {
        switch lang.lowercased() {
        case "zh-hans", "zh", "zh_cn", "zh-cn": return "zh-CN"
        case "zh-hant", "zh_tw", "zh-tw": return "zh-TW"
        case "en", "en-us", "en-gb": return "en"
        case "ja", "ja-jp": return "ja"
        case "ko", "ko-kr": return "ko"
        case "fr": return "fr"
        case "de": return "de"
        case "es": return "es"
        case "ru": return "ru"
        default: return lang
        }
    }
    
    /// DeepL API source_lang specification:
    /// English must be "EN" (regional codes like EN-US/EN-GB cause HTTP 400).
    /// Portuguese must be "PT".
    private func normalizeSourceLanguageForDeepL(_ lang: String) -> String {
        switch lang.lowercased() {
        case "zh-hans", "zh", "zh-cn", "zh_cn": return "ZH"
        case "zh-hant", "zh-tw", "zh_tw": return "ZH"
        case "en", "en-us", "en-gb": return "EN"
        case "ja", "ja-jp": return "JA"
        case "ko", "ko-kr": return "KO"
        case "de": return "DE"
        case "fr": return "FR"
        case "es": return "ES"
        case "ru": return "RU"
        case "pt", "pt-pt", "pt-br": return "PT"
        case "it": return "IT"
        case "nl": return "NL"
        case "pl": return "PL"
        default:
            let prefix = String(lang.prefix(2)).uppercased()
            return prefix.isEmpty ? lang.uppercased() : prefix
        }
    }
    
    /// DeepL API target_lang specification:
    /// Supports regional codes like EN-US, EN-GB, PT-BR, PT-PT, ZH-HANS, ZH-HANT, etc.
    private func normalizeTargetLanguageForDeepL(_ lang: String) -> String {
        switch lang.lowercased() {
        case "zh-hans", "zh", "zh-cn", "zh_cn": return "ZH"
        case "zh-hant", "zh-tw", "zh_tw": return "ZH-HANT"
        case "en", "en-us": return "EN-US"
        case "en-gb": return "EN-GB"
        case "ja", "ja-jp": return "JA"
        case "ko", "ko-kr": return "KO"
        case "de": return "DE"
        case "fr": return "FR"
        case "es": return "ES"
        case "ru": return "RU"
        case "pt", "pt-br": return "PT-BR"
        case "pt-pt": return "PT-PT"
        case "it": return "IT"
        case "nl": return "NL"
        case "pl": return "PL"
        default:
            return lang.uppercased()
        }
    }
    
    // MARK: - Engine: Apple Official Native Translation (macOS 15+)
    
    private func translateViaApple(
        text: String,
        isSourceChinese: Bool,
        from sourceLang: String,
        to targetLang: String,
        completion: @escaping (Result<TranslationResponse, Error>) -> Void
    ) {
        #if canImport(Translation)
        if #available(macOS 26.0, *) {
            let sCode = (sourceLang == "auto") ? (isSourceChinese ? "zh-Hans" : "en") : normalizeLanguageForApple(sourceLang)
            let tCode = normalizeLanguageForApple(targetLang)
            
            Task {
                do {
                    let session = TranslationSession(
                        installedSource: Locale.Language(identifier: sCode),
                        target: Locale.Language(identifier: tCode)
                    )
                    let response = try await session.translate(text)
                    let cleaned = TranslationService.postProcessTranslatedText(response.targetText)
                    DispatchQueue.main.async {
                        completion(.success(TranslationResponse(
                            translatedText: cleaned,
                            sourceLanguage: sCode,
                            targetLanguage: tCode
                        )))
                    }
                } catch {
                    // Fallback to builtin multi-channel if offline model isn't installed or error occurs
                    DispatchQueue.main.async { [weak self] in
                        self?.translateViaBuiltin(text: text, isSourceChinese: isSourceChinese, from: sourceLang, to: targetLang, completion: completion)
                    }
                }
            }
            return
        }
        #endif
        
        // Fallback for older macOS versions without Translation framework
        translateViaBuiltin(text: text, isSourceChinese: isSourceChinese, from: sourceLang, to: targetLang, completion: completion)
    }
    
    private func normalizeLanguageForApple(_ lang: String) -> String {
        switch lang.lowercased() {
        case "zh", "zh-hans", "zh_cn", "zh-cn": return "zh-Hans"
        case "zh-hant", "zh_tw", "zh-tw": return "zh-Hant"
        case "en", "en-us", "en-gb": return "en"
        case "ja", "ja-jp": return "ja"
        case "ko", "ko-kr": return "ko"
        case "fr", "fr-fr": return "fr"
        case "de", "de-de": return "de"
        case "es", "es-es": return "es"
        case "ru", "ru-ru": return "ru"
        case "it": return "it"
        case "pt": return "pt"
        default: return lang
        }
    }
}
