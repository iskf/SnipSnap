import Cocoa
import SwiftUI

public class OCRResultWindowController: NSWindowController {
    public static var current: OCRResultWindowController?
    
    public static func show(with result: OCRResult, image: NSImage? = nil) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 480),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "SnipSnap - 文字识别与翻译"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        
        let hosting = NSHostingView(rootView: OCRResultContentView(result: result, sourceImage: image))
        window.contentView = hosting
        
        let controller = OCRResultWindowController(window: window)
        current = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct OCRResultContentView: View {
    @State var originalText: String
    @State var translatedText: String = ""
    @State var isTranslating: Bool = false
    @State var copiedTip: String? = nil
    var sourceImage: NSImage?
    
    init(result: OCRResult, sourceImage: NSImage?) {
        _originalText = State(initialValue: result.fullText)
        _translatedText = State(initialValue: result.translatedText ?? "")
        self.sourceImage = sourceImage
    }
    
    var body: some View {
        ZStack {
            VisualEffectBackground()
            
            VStack(spacing: 0) {
                // Header Bar
                HStack {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text("OCR 文字识别 & 智能翻译")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                    
                    if let tip = copiedTip {
                        Text(tip)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)
                
                Divider().opacity(0.3)
                
                // Content Areas (Split horizontal)
                GeometryReader { geo in
                    HStack(spacing: 12) {
                        // Left: Original Recognized Text
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("识别文本 (\(originalText.count) 字)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                Button(action: {
                                    copyToClipboard(originalText, label: "已复制识别文本")
                                }) {
                                    Label("复制", systemImage: "doc.on.doc")
                                        .font(.system(size: 11))
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            TextEditor(text: $originalText)
                                .font(.system(size: 13, design: .monospaced))
                                .padding(8)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .frame(width: (geo.size.width - 24) / 2)
                        
                        // Right: Translation Result
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("智能翻译")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                Spacer()
                                
                                if isTranslating {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Button(action: performTranslate) {
                                        Label("翻译", systemImage: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                }
                                
                                if !translatedText.isEmpty {
                                    Button(action: {
                                        copyToClipboard(translatedText, label: "已复制翻译内容")
                                    }) {
                                        Label("复制", systemImage: "doc.on.doc")
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            
                            if translatedText.isEmpty && !isTranslating {
                                VStack(spacing: 10) {
                                    Spacer()
                                    Image(systemName: "character.book.closed")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary.opacity(0.5))
                                    Text("点击右上角「翻译」进行即时中英多语种翻译")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
                                .cornerRadius(8)
                            } else {
                                TextEditor(text: $translatedText)
                                    .font(.system(size: 13))
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                    )
                            }
                        }
                        .frame(width: (geo.size.width - 24) / 2)
                    }
                    .padding(16)
                }
                
                Divider().opacity(0.3)
                
                // Bottom Action Bar
                HStack {
                    if let image = sourceImage {
                        Button(action: {
                            PinWindowManager.shared.createPin(from: image)
                            OCRResultWindowController.current?.close()
                        }) {
                            Label("将截图贴到屏幕 (F3)", systemImage: "pin.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    Button("全部复制") {
                        let combined = "【识别文本】\n\(originalText)\n\n【翻译文本】\n\(translatedText)"
                        copyToClipboard(combined, label: "已复制全部内容")
                    }
                    .buttonStyle(.bordered)
                    
                    Button("关闭 (Esc)") {
                        OCRResultWindowController.current?.close()
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.cancelAction)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            if translatedText.isEmpty && !originalText.isEmpty {
                performTranslate()
            }
        }
    }
    
    private func performTranslate() {
        guard !originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isTranslating = true
        TranslationService.shared.translate(text: originalText) { result in
            DispatchQueue.main.async {
                isTranslating = false
                switch result {
                case .success(let resp):
                    self.translatedText = resp.translatedText
                case .failure(let err):
                    self.translatedText = "翻译失败: \(err.localizedDescription)"
                }
            }
        }
    }
    
    private func copyToClipboard(_ text: String, label: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        withAnimation {
            copiedTip = label
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                copiedTip = nil
            }
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
