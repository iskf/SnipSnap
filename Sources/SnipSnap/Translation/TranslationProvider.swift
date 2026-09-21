import Foundation

public protocol CancellableTask: Sendable {
    func cancel()
}

extension URLSessionTask: CancellableTask {}

public struct AnyCancellableTask: CancellableTask {
    private let _cancel: @Sendable () -> Void
    
    public init(_ cancel: @escaping @Sendable () -> Void) {
        self._cancel = cancel
    }
    
    public func cancel() {
        _cancel()
    }
}

public struct TranslationOptions: Sendable {
    public var isStreaming: Bool
    public var onStreamChunk: (@Sendable (String) -> Void)?
    public var systemPrompt: String?
    public var temperature: Double?
    
    public init(
        isStreaming: Bool = false,
        onStreamChunk: (@Sendable (String) -> Void)? = nil,
        systemPrompt: String? = nil,
        temperature: Double? = nil
    ) {
        self.isStreaming = isStreaming
        self.onStreamChunk = onStreamChunk
        self.systemPrompt = systemPrompt
        self.temperature = temperature
    }
}

public protocol TranslationProvider: Sendable {
    var identifier: String { get }
    var displayName: String { get }
    
    func translate(
        text: String,
        from sourceLang: String,
        to targetLang: String,
        options: TranslationOptions,
        completion: @escaping @Sendable (Result<TranslationResponse, Error>) -> Void
    ) -> CancellableTask?
}
