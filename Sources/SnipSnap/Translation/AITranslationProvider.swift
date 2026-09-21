import Foundation

public final class AITranslationProvider: NSObject, TranslationProvider, @unchecked Sendable {
    public let identifier: String = "ai"
    public var displayName: String { "AI 大模型" }
    
    public override init() {
        super.init()
    }
    
    // MARK: - Endpoint Resolver
    
    public static func resolveEndpoint(from baseURL: String) -> URL? {
        var trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasSuffix("/") {
            trimmed = String(trimmed.dropLast())
        }
        guard !trimmed.isEmpty else { return nil }
        
        if trimmed.hasSuffix("/chat/completions") {
            return URL(string: trimmed)
        }
        return URL(string: "\(trimmed)/chat/completions")
    }
    
    // MARK: - Language Label Resolver
    
    private func languageDisplayName(_ code: String) -> String {
        switch code.lowercased() {
        case "zh-hans", "zh", "zh_cn", "zh-cn": return "Simplified Chinese (简体中文)"
        case "zh-hant", "zh_tw", "zh-tw": return "Traditional Chinese (繁體中文)"
        case "en", "en-us", "en-gb": return "English"
        case "ja", "ja-jp": return "Japanese (日本語)"
        case "ko", "ko-kr": return "Korean (한국어)"
        case "fr": return "French (Français)"
        case "de": return "German (Deutsch)"
        case "es": return "Spanish (Español)"
        case "ru": return "Russian (Русский)"
        case "it": return "Italian (Italiano)"
        case "pt": return "Portuguese (Português)"
        default: return code
        }
    }
    
    // MARK: - Core Translation
    
    public func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        options: TranslationOptions,
        completion: @escaping @Sendable (Result<TranslationResponse, Error>) -> Void
    ) -> CancellableTask? {
        let config = AppConfig.load()
        guard let url = Self.resolveEndpoint(from: config.aiBaseURL) else {
            completion(.failure(NSError(domain: "AITranslation", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的 API 基础地址 (Base URL)"])))
            return nil
        }
        
        let trimmedKey = config.aiApiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        // Note: Ollama or local endpoints might not require an API key, so only require key if not localhost
        let isLocalhost = url.host == "localhost" || url.host == "127.0.0.1"
        if !isLocalhost && trimmedKey.isEmpty {
            completion(.failure(NSError(domain: "AITranslation", code: -2, userInfo: [NSLocalizedDescriptionKey: "API Key 不能为空，请在偏好设置中配置"])))
            return nil
        }
        
        let targetLabel = languageDisplayName(targetLang)
        let sourceLabel = (sourceLang == "auto") ? "detected language" : languageDisplayName(sourceLang)
        
        let userPrompt = "Translate the following text faithfully into \(targetLabel) (source language: \(sourceLabel)):\n\n\(text)"
        let systemPrompt = options.systemPrompt ?? config.aiSystemPrompt
        let temperature = options.temperature ?? config.aiTemperature
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !trimmedKey.isEmpty {
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 30.0
        
        let payload: [String: Any] = [
            "model": config.aiModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "deepseek-chat" : config.aiModelName,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": temperature,
            "stream": options.isStreaming
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(NSError(domain: "AITranslation", code: -3, userInfo: [NSLocalizedDescriptionKey: "构建请求 JSON 失败"])))
            return nil
        }
        request.httpBody = httpBody
        
        if options.isStreaming {
            let sessionDelegate = AIStreamDelegate(
                onChunk: { chunk in
                    DispatchQueue.main.async {
                        options.onStreamChunk?(chunk)
                    }
                },
                onComplete: { result in
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let fullText):
                            let cleaned = TranslationService.postProcessTranslatedText(fullText)
                            completion(.success(TranslationResponse(
                                translatedText: cleaned,
                                sourceLanguage: sourceLang,
                                targetLanguage: targetLang
                            )))
                        case .failure(let err):
                            completion(.failure(err))
                        }
                    }
                }
            )
            
            let session = URLSession(configuration: .default, delegate: sessionDelegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            sessionDelegate.task = task
            task.resume()
            
            return AnyCancellableTask {
                task.cancel()
                session.invalidateAndCancel()
            }
        } else {
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }
                
                if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
                    let errMsg = Self.parseHttpError(code: httpResp.statusCode, data: data)
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "AITranslation", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                    }
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let message = first["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "AITranslation", code: -4, userInfo: [NSLocalizedDescriptionKey: "解析 AI 响应数据格式失败"])))
                    }
                    return
                }
                
                let cleaned = TranslationService.postProcessTranslatedText(content)
                DispatchQueue.main.async {
                    completion(.success(TranslationResponse(
                        translatedText: cleaned,
                        sourceLanguage: sourceLang,
                        targetLanguage: targetLang
                    )))
                }
            }
            task.resume()
            return task
        }
    }
    
    // MARK: - Connection Testing
    
    public func testConnection(
        baseURL: String,
        apiKey: String,
        model: String,
        completion: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        guard let url = Self.resolveEndpoint(from: baseURL) else {
            completion(.failure(NSError(domain: "AITranslation", code: -1, userInfo: [NSLocalizedDescriptionKey: "无效的基础地址 URL"])))
            return
        }
        
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let isLocalhost = url.host == "localhost" || url.host == "127.0.0.1"
        if !isLocalhost && trimmedKey.isEmpty {
            completion(.failure(NSError(domain: "AITranslation", code: -2, userInfo: [NSLocalizedDescriptionKey: "API Key 不能为空"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !trimmedKey.isEmpty {
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        request.timeoutInterval = 10.0
        
        let payload: [String: Any] = [
            "model": model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "deepseek-chat" : model,
            "messages": [
                ["role": "system", "content": "You are a translator. Translate the text to Chinese. Return only the translation."],
                ["role": "user", "content": "Hello"]
            ],
            "temperature": 0.1,
            "stream": false
        ]
        
        guard let httpBody = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(.failure(NSError(domain: "AITranslation", code: -3, userInfo: [NSLocalizedDescriptionKey: "构建测试请求失败"])))
            return
        }
        request.httpBody = httpBody
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            let elapsedMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)
            
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            if let httpResp = response as? HTTPURLResponse, httpResp.statusCode != 200 {
                let errMsg = Self.parseHttpError(code: httpResp.statusCode, data: data)
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "AITranslation", code: httpResp.statusCode, userInfo: [NSLocalizedDescriptionKey: errMsg])))
                }
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "AITranslation", code: -4, userInfo: [NSLocalizedDescriptionKey: "API 响应解析失败"])))
                }
                return
            }
            
            let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                completion(.success("连接成功！(\(elapsedMs)ms) 测试响应：「\(trimmedContent)」"))
            }
        }.resume()
    }
    
    // MARK: - Error Helper
    
    private static func parseHttpError(code: Int, data: Data?) -> String {
        var detail = ""
        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let errObj = json["error"] as? [String: Any], let msg = errObj["message"] as? String {
                detail = msg
            } else if let msg = json["message"] as? String {
                detail = msg
            }
        }
        
        switch code {
        case 401:
            return "认证失败 (HTTP 401)：API Key 无效或过期。\(detail.isEmpty ? "" : "[\(detail)]")"
        case 403:
            return "访问受限 (HTTP 403)：无权访问该模型或账户欠费。\(detail.isEmpty ? "" : "[\(detail)]")"
        case 404:
            return "接口未找到 (HTTP 404)：请检查 Base URL 或 Model 名称是否正确。\(detail.isEmpty ? "" : "[\(detail)]")"
        case 429:
            return "请求限频 (HTTP 429)：并发过高或免费额度已耗尽。\(detail.isEmpty ? "" : "[\(detail)]")"
        case 500...599:
            return "服务商服务器异常 (HTTP \(code))：\(detail.isEmpty ? "请稍后重试" : detail)"
        default:
            return "请求失败 (HTTP \(code))：\(detail.isEmpty ? "请检查网络或参数" : detail)"
        }
    }
}

// MARK: - Server-Sent Events (SSE) Stream Delegate

private final class AIStreamDelegate: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private let onChunk: @Sendable (String) -> Void
    private let onComplete: @Sendable (Result<String, Error>) -> Void
    
    weak var task: URLSessionDataTask?
    private var buffer = ""
    private var accumulatedText = ""
    private var isFinished = false
    private let lock = NSLock()
    
    init(
        onChunk: @escaping @Sendable (String) -> Void,
        onComplete: @escaping @Sendable (Result<String, Error>) -> Void
    ) {
        self.onChunk = onChunk
        self.onComplete = onComplete
        super.init()
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished, let text = String(data: data, encoding: .utf8) else { return }
        
        buffer += text
        
        let lines = buffer.components(separatedBy: "\n")
        // Keep the last incomplete line in buffer
        if let lastLine = lines.last {
            buffer = lastLine
        }
        
        for line in lines.dropLast() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            if trimmed.hasPrefix("data:") {
                let jsonString = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
                if jsonString == "[DONE]" {
                    isFinished = true
                    onComplete(.success(accumulatedText))
                    return
                }
                
                guard let jsonData = jsonString.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first else {
                    continue
                }
                
                // Delta can be in choices[0]["delta"]["content"]
                var deltaText: String? = nil
                if let delta = first["delta"] as? [String: Any], let content = delta["content"] as? String {
                    deltaText = content
                } else if let text = first["text"] as? String {
                    deltaText = text
                }
                
                if let deltaText = deltaText, !deltaText.isEmpty {
                    accumulatedText += deltaText
                    onChunk(deltaText)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        lock.lock()
        defer { lock.unlock() }
        guard !isFinished else { return }
        isFinished = true
        
        if let error = error {
            if (error as NSError).code == NSURLErrorCancelled {
                // If cancelled by user, complete with what we have if non-empty, otherwise failure
                if !accumulatedText.isEmpty {
                    onComplete(.success(accumulatedText))
                } else {
                    onComplete(.failure(error))
                }
            } else {
                onComplete(.failure(error))
            }
        } else {
            onComplete(.success(accumulatedText))
        }
    }
}
