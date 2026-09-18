import Cocoa
import CoreGraphics

public class GIFRecordingSession: NSObject, @unchecked Sendable {
    public static let shared = GIFRecordingSession()
    
    private var borderWindow: NSWindow?
    private var controlWindow: NSWindow?
    private var borderView: RecordingBorderView?
    private var capsuleView: RecordingControlCapsuleView?
    
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    
    private var sessionScreen: NSScreen?
    private var sessionRect: CGRect = .zero // Screen coordinates
    private var localRect: CGRect = .zero   // Screen-local AppKit coordinates
    
    private var countdownTimer: Timer?
    private var countdownRemaining: Int = 3
    
    private var recordingTimer: Timer?
    private var elapsedSeconds: Int = 0
    private var isPaused: Bool = false
    private var isEncoding: Bool = false
    
    private override init() {
        super.init()
    }
    
    public func startSession(screen: NSScreen, screenRect: CGRect) {
        // Close any ongoing session first
        cleanup()
        
        self.sessionScreen = screen
        self.sessionRect = screenRect
        
        // Convert screen coordinates to screen-relative local coordinates
        let localOriginX = screenRect.origin.x - screen.frame.origin.x
        let localOriginY = screenRect.origin.y - screen.frame.origin.y
        self.localRect = CGRect(x: localOriginX, y: localOriginY, width: screenRect.width, height: screenRect.height)
        
        self.countdownRemaining = 3
        self.elapsedSeconds = 0
        self.isPaused = false
        self.isEncoding = false
        
        // 1. Create Border Window (ignoresMouseEvents = true so underlying apps are 100% interactive)
        let bWin = NSWindow(
            contentRect: screenRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        bWin.isOpaque = false
        bWin.backgroundColor = .clear
        bWin.hasShadow = false
        bWin.level = .floating
        bWin.ignoresMouseEvents = true // CRITICAL: Complete mouse freedom!
        
        let bView = RecordingBorderView(frame: NSRect(origin: .zero, size: screenRect.size))
        bView.countdownNumber = 3
        bWin.contentView = bView
        bWin.orderFrontRegardless()
        self.borderWindow = bWin
        self.borderView = bView
        
        // 2. Create Floating Control Capsule Window
        let capsuleWidth: CGFloat = 268.0
        let capsuleHeight: CGFloat = 38.0
        let capsuleX = round(screenRect.midX - capsuleWidth / 2.0)
        var capsuleY = round(screenRect.minY - capsuleHeight - 12.0)
        
        // If too low, place above the recording rect
        if capsuleY < (screen.frame.minY + 15) {
            capsuleY = round(screenRect.maxY + 12.0)
        }
        
        let cRect = NSRect(x: capsuleX, y: capsuleY, width: capsuleWidth, height: capsuleHeight)
        let cWin = NSWindow(
            contentRect: cRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        cWin.isOpaque = false
        cWin.backgroundColor = .clear
        cWin.hasShadow = true
        cWin.level = .floating
        
        let cView = RecordingControlCapsuleView(frame: NSRect(origin: .zero, size: cRect.size))
        cView.onPauseToggled = { [weak self] in self?.togglePause() }
        cView.onFinishClicked = { [weak self] in self?.finishSession() }
        cView.onCancelClicked = { [weak self] in self?.cancelSession() }
        cView.updateState(.countdown(remaining: 3))
        
        cWin.contentView = cView
        cWin.orderFrontRegardless()
        self.controlWindow = cWin
        self.capsuleView = cView
        
        setupShortcuts()
        
        // 3. Start 3-2-1 Countdown Timer
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { return }
            self.countdownRemaining -= 1
            if self.countdownRemaining > 0 {
                self.borderView?.countdownNumber = self.countdownRemaining
                self.capsuleView?.updateState(.countdown(remaining: self.countdownRemaining))
            } else {
                t.invalidate()
                self.countdownTimer = nil
                self.beginActiveRecording()
            }
        }
    }
    
    private func beginActiveRecording() {
        guard let screen = sessionScreen else { return }
        
        // Hide countdown number on border
        borderView?.countdownNumber = nil
        
        let borderWinNum = borderWindow?.windowNumber ?? 0
        let controlWinNum = controlWindow?.windowNumber ?? 0
        
        // Start ScreenCaptureKit live capture
        ScreenGIFRecorder.shared.startRecording(
            targetScreen: screen,
            localSelectionRect: localRect,
            excludingWindowNumbers: [borderWinNum, controlWinNum]
        )
        
        let maxDuration = AppConfig.load().gifMaxDuration
        capsuleView?.updateState(.recording(elapsed: 0, maxDuration: maxDuration))
        
        // Start live elapsed timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused, !self.isEncoding else { return }
            self.elapsedSeconds += 1
            self.capsuleView?.updateState(.recording(elapsed: self.elapsedSeconds, maxDuration: maxDuration))
            
            if self.elapsedSeconds >= maxDuration {
                self.finishSession()
            }
        }
    }
    
    // MARK: - Actions
    
    public func togglePause() {
        guard !isEncoding, countdownRemaining <= 0 else { return }
        isPaused.toggle()
        let maxDuration = AppConfig.load().gifMaxDuration
        if isPaused {
            ScreenGIFRecorder.shared.pauseRecording()
            borderView?.isDashed = true
            capsuleView?.updateState(.paused(elapsed: elapsedSeconds, maxDuration: maxDuration))
        } else {
            ScreenGIFRecorder.shared.resumeRecording()
            borderView?.isDashed = false
            capsuleView?.updateState(.recording(elapsed: elapsedSeconds, maxDuration: maxDuration))
        }
    }
    
    public func finishSession() {
        guard !isEncoding else { return }
        isEncoding = true
        
        countdownTimer?.invalidate()
        countdownTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // 1. Immediately dismiss the red border window so screen is clean
        borderWindow?.orderOut(nil)
        borderWindow = nil
        borderView = nil
        
        // 2. Morph control capsule to encoding state
        capsuleView?.updateState(.encoding)
        
        // 3. Stop recorder and compress GIF
        ScreenGIFRecorder.shared.stopRecording { [weak self] gifData in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let data = gifData {
                    let mb = Double(data.count) / (1024.0 * 1024.0)
                    let sizeStr = String(format: "%.1f MB", mb)
                    self.capsuleView?.updateState(.completed(sizeString: sizeStr))
                    
                    // Auto-fade out after 1.5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                        self?.fadeOutAndCleanup()
                    }
                } else {
                    self.cleanup()
                }
            }
        }
    }
    
    public func cancelSession() {
        ScreenGIFRecorder.shared.cancelRecording()
        cleanup()
    }
    
    // MARK: - Key Shortcuts
    
    private func setupShortcuts() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, !self.isEncoding else { return event }
            if event.keyCode == 36 { // Enter -> Finish
                self.finishSession()
                return nil
            } else if event.keyCode == 53 { // Esc -> Cancel
                self.cancelSession()
                return nil
            }
            return event
        }
        
        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, !self.isEncoding else { return }
            if event.keyCode == 36 { // Enter
                DispatchQueue.main.async { self.finishSession() }
            } else if event.keyCode == 53 { // Esc
                DispatchQueue.main.async { self.cancelSession() }
            }
        }
    }
    
    private func fadeOutAndCleanup() {
        guard let win = controlWindow else {
            cleanup()
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.35
            win.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.cleanup()
        })
    }
    
    private func cleanup() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        if let m = localKeyMonitor {
            NSEvent.removeMonitor(m)
            localKeyMonitor = nil
        }
        if let m = globalKeyMonitor {
            NSEvent.removeMonitor(m)
            globalKeyMonitor = nil
        }
        
        borderWindow?.orderOut(nil)
        borderWindow = nil
        borderView = nil
        
        controlWindow?.orderOut(nil)
        controlWindow = nil
        capsuleView = nil
        
        sessionScreen = nil
    }
}

// MARK: - 1. Red Border View (With Optional 3-2-1 Countdown Overlay)

class RecordingBorderView: NSView {
    var countdownNumber: Int? = nil {
        didSet { needsDisplay = true }
    }
    var isDashed: Bool = false {
        didSet { needsDisplay = true }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let borderRect = bounds.insetBy(dx: 1.5, dy: 1.5)
        
        // 1. Glowing red border
        context.saveGState()
        context.setShadow(offset: .zero, blur: 6.0, color: NSColor.systemRed.withAlphaComponent(0.85).cgColor)
        context.setStrokeColor(NSColor.systemRed.cgColor)
        context.setLineWidth(2.5)
        if isDashed {
            let dashes: [CGFloat] = [6.0, 4.0]
            context.setLineDash(phase: 0, lengths: dashes)
        }
        context.stroke(borderRect)
        context.restoreGState()
        
        // 2. Countdown 3-2-1 centered disc
        if let num = countdownNumber, num > 0 {
            let discSize: CGFloat = 80.0
            let discRect = NSRect(
                x: round(bounds.midX - discSize / 2.0),
                y: round(bounds.midY - discSize / 2.0),
                width: discSize,
                height: discSize
            )
            
            context.saveGState()
            context.setFillColor(NSColor(calibratedWhite: 0.1, alpha: 0.85).cgColor)
            let path = NSBezierPath(ovalIn: discRect)
            path.fill()
            
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(1.5)
            let strokePath = NSBezierPath(ovalIn: discRect)
            strokePath.stroke()
            
            let numStr = "\(num)"
            let font = NSFont.systemFont(ofSize: 44, weight: .bold)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: NSColor.white
            ]
            let size = (numStr as NSString).size(withAttributes: attrs)
            let textPoint = NSPoint(
                x: discRect.midX - size.width / 2.0,
                y: discRect.midY - size.height / 2.0 + 1.0
            )
            (numStr as NSString).draw(at: textPoint, withAttributes: attrs)
            context.restoreGState()
        }
    }
}

// MARK: - 2. Floating Control Capsule View

enum RecordingCapsuleState {
    case countdown(remaining: Int)
    case recording(elapsed: Int, maxDuration: Int)
    case paused(elapsed: Int, maxDuration: Int)
    case encoding
    case completed(sizeString: String)
}

class RecordingControlCapsuleView: NSVisualEffectView {
    var onPauseToggled: (() -> Void)?
    var onFinishClicked: (() -> Void)?
    var onCancelClicked: (() -> Void)?
    
    private let statusDot = NSView()
    private let timeLabel = NSTextField(labelWithString: "")
    private let divider = NSView()
    private let pauseButton = NSButton()
    private let finishButton = NSButton()
    private let cancelButton = NSButton()
    private let spinner = NSProgressIndicator()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 19
        layer?.masksToBounds = true
        layer?.borderColor = NSColor.white.withAlphaComponent(0.20).cgColor
        layer?.borderWidth = 0.8
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        // Red Pulsing Status Dot
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4.5
        statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        addSubview(statusDot)
        
        // Time / Status Label
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12.5, weight: .bold)
        timeLabel.textColor = .white
        timeLabel.alignment = .left
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(timeLabel)
        
        // Divider
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false
        addSubview(divider)
        
        // Pause Button
        setupButton(pauseButton, icon: "pause.fill", action: #selector(btnPauseClicked))
        pauseButton.toolTip = "暂停/继续"
        
        // Finish Button
        setupButton(finishButton, icon: "checkmark.circle.fill", tint: NSColor.systemGreen, action: #selector(btnFinishClicked))
        finishButton.toolTip = "完成并复制 (Enter)"
        
        // Cancel Button
        setupButton(cancelButton, icon: "xmark.circle.fill", tint: NSColor.white.withAlphaComponent(0.7), action: #selector(btnCancelClicked))
        cancelButton.toolTip = "取消录制 (Esc)"
        
        // Spinner (for encoding)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        addSubview(spinner)
        
        NSLayoutConstraint.activate([
            statusDot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            statusDot.centerYAnchor.constraint(equalTo: centerYAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 9),
            statusDot.heightAnchor.constraint(equalToConstant: 9),
            
            timeLabel.leadingAnchor.constraint(equalTo: statusDot.trailingAnchor, constant: 8),
            timeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            
            divider.leadingAnchor.constraint(equalTo: timeLabel.trailingAnchor, constant: 10),
            divider.centerYAnchor.constraint(equalTo: centerYAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 16),
            
            pauseButton.leadingAnchor.constraint(equalTo: divider.trailingAnchor, constant: 8),
            pauseButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            pauseButton.widthAnchor.constraint(equalToConstant: 24),
            pauseButton.heightAnchor.constraint(equalToConstant: 24),
            
            finishButton.leadingAnchor.constraint(equalTo: pauseButton.trailingAnchor, constant: 6),
            finishButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            finishButton.widthAnchor.constraint(equalToConstant: 24),
            finishButton.heightAnchor.constraint(equalToConstant: 24),
            
            cancelButton.leadingAnchor.constraint(equalTo: finishButton.trailingAnchor, constant: 6),
            cancelButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            cancelButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            cancelButton.widthAnchor.constraint(equalToConstant: 24),
            cancelButton.heightAnchor.constraint(equalToConstant: 24),
            
            spinner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    private func setupButton(_ btn: NSButton, icon: String, tint: NSColor = .white, action: Selector) {
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.imagePosition = .imageOnly
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        btn.contentTintColor = tint
        btn.target = self
        btn.action = action
        btn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(btn)
    }
    
    func updateState(_ state: RecordingCapsuleState) {
        switch state {
        case .countdown(let remaining):
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            timeLabel.stringValue = "准备录制 \(remaining)s"
            divider.isHidden = false
            pauseButton.isHidden = true
            finishButton.isHidden = false
            cancelButton.isHidden = false
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            
        case .recording(let elapsed, let maxDuration):
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
            let sec = elapsed % 60
            let min = elapsed / 60
            let maxSec = maxDuration % 60
            let maxMin = maxDuration / 60
            timeLabel.stringValue = String(format: "%02d:%02d / %02d:%02d", min, sec, maxMin, maxSec)
            divider.isHidden = false
            pauseButton.isHidden = false
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            pauseButton.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            finishButton.isHidden = false
            cancelButton.isHidden = false
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            
        case .paused(let elapsed, let maxDuration):
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = NSColor.systemYellow.cgColor
            let sec = elapsed % 60
            let min = elapsed / 60
            let maxSec = maxDuration % 60
            let maxMin = maxDuration / 60
            timeLabel.stringValue = String(format: "%02d:%02d / %02d:%02d [已暂停]", min, sec, maxMin, maxSec)
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            pauseButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            
        case .encoding:
            statusDot.isHidden = true
            spinner.isHidden = false
            spinner.startAnimation(nil)
            timeLabel.stringValue = "正在压制 GIF 动图..."
            divider.isHidden = true
            pauseButton.isHidden = true
            finishButton.isHidden = true
            cancelButton.isHidden = true
            
        case .completed(let sizeString):
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            timeLabel.stringValue = "✓ 已写入剪贴板 (\(sizeString))"
            divider.isHidden = true
            pauseButton.isHidden = true
            finishButton.isHidden = true
            cancelButton.isHidden = true
        }
    }
    
    @objc private func btnPauseClicked() { onPauseToggled?() }
    @objc private func btnFinishClicked() { onFinishClicked?() }
    @objc private func btnCancelClicked() { onCancelClicked?() }
}
