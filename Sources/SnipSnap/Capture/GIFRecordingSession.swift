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
    private var activeStartTime: Double = 0.0
    private var accumulatedPausedDuration: Double = 0.0
    private var pauseStartTime: Double = 0.0
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
        self.activeStartTime = 0.0
        self.accumulatedPausedDuration = 0.0
        self.pauseStartTime = 0.0
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
        bWin.sharingType = .none // CRITICAL: 100% invisible to ScreenCaptureKit & screen recordings!
        bWin.ignoresMouseEvents = true // CRITICAL: Complete mouse freedom!
        
        let bView = RecordingBorderView(frame: NSRect(origin: .zero, size: screenRect.size))
        bWin.contentView = bView
        bWin.orderFrontRegardless()
        self.borderWindow = bWin
        self.borderView = bView
        
        // 2. Create Floating Control Capsule Window (matches AnnotationToolbar positioning)
        let capsuleHeight: CGFloat = RecordingControlCapsuleView.standardHeight // 38px
        
        // Create view first to measure intrinsic width
        let cView = RecordingControlCapsuleView(frame: NSRect(x: 0, y: 0, width: 300, height: capsuleHeight))
        cView.onPauseToggled = { [weak self] in self?.togglePause() }
        cView.onFinishClicked = { [weak self] in self?.finishSession() }
        cView.onCancelClicked = { [weak self] in self?.cancelSession() }
        cView.updateState(.countdown(remaining: 3))
        cView.layoutSubtreeIfNeeded()
        
        // Auto-sizing: let the stack view determine the natural width
        let capsuleWidth = max(200, cView.fittingSize.width + 12)
        
        // Right-aligned to selection rect (matches annotation toolbar positioning)
        let capsuleX = round(min(max(screenRect.maxX - capsuleWidth, screen.frame.minX + 10),
                                  screen.frame.maxX - capsuleWidth - 10))
        
        // Below selection with 8px gap (consistent with annotation toolbar)
        var capsuleY = round(screenRect.minY - capsuleHeight - 8.0)
        
        // If too low, flip above the selection rect
        if capsuleY < (screen.frame.minY + 15) {
            capsuleY = round(screenRect.maxY + 8.0)
        }
        
        // If above screen top, clamp inside
        if capsuleY + capsuleHeight > screen.frame.maxY - 10 {
            capsuleY = round(screenRect.maxY - capsuleHeight - 8.0)
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
        cWin.hasShadow = true // Window-level shadow (CALayer shadow removed to fix rectangular artifact)
        cWin.level = .floating
        cWin.sharingType = .none // CRITICAL: 100% invisible to ScreenCaptureKit & screen recordings!
        
        cView.frame = NSRect(origin: .zero, size: cRect.size)
        cWin.contentView = cView
        cWin.orderFrontRegardless()
        self.controlWindow = cWin
        self.capsuleView = cView
        
        setupShortcuts()
        
        // 3. Pre-warm ScreenCaptureKit live capture during 3-2-1 countdown
        // Eliminates 1-2s async startup delay so t=0 is 100% captured
        let borderWinNum = bWin.windowNumber
        let controlWinNum = cWin.windowNumber
        ScreenGIFRecorder.shared.prepareRecording(
            targetScreen: screen,
            localSelectionRect: localRect,
            excludingWindowNumbers: [borderWinNum, controlWinNum]
        )
        
        // 4. Start 3-2-1 Countdown Timer (displayed in capsule toolbar)
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] t in
            guard let self = self else { return }
            self.countdownRemaining -= 1
            if self.countdownRemaining > 0 {
                self.capsuleView?.updateState(.countdown(remaining: self.countdownRemaining))
            } else {
                t.invalidate()
                self.countdownTimer = nil
                self.beginActiveRecording()
            }
        }
    }
    
    private func beginActiveRecording() {
        guard sessionScreen != nil else { return }
        
        // Instant active capture from pre-warmed stream (0ms startup latency!)
        ScreenGIFRecorder.shared.startActiveRecording()
        
        let maxDuration = AppConfig.load().gifMaxDuration
        activeStartTime = CACurrentMediaTime()
        accumulatedPausedDuration = 0.0
        pauseStartTime = 0.0
        elapsedSeconds = 0
        capsuleView?.updateState(.recording(elapsed: 0, maxDuration: maxDuration))
        
        // High-precision sub-second timer to avoid drift
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self = self, !self.isPaused, !self.isEncoding else { return }
            let activeNow = CACurrentMediaTime() - self.activeStartTime - self.accumulatedPausedDuration
            let currentSec = max(0, Int(activeNow))
            if currentSec != self.elapsedSeconds {
                self.elapsedSeconds = currentSec
                self.capsuleView?.updateState(.recording(elapsed: self.elapsedSeconds, maxDuration: maxDuration))
            }
            
            if currentSec >= maxDuration {
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
            pauseStartTime = CACurrentMediaTime()
            ScreenGIFRecorder.shared.pauseRecording()
            borderView?.isDashed = true
            capsuleView?.updateState(.paused(elapsed: elapsedSeconds, maxDuration: maxDuration))
        } else {
            let pauseDuration = CACurrentMediaTime() - pauseStartTime
            if pauseDuration > 0 {
                accumulatedPausedDuration += pauseDuration
            }
            pauseStartTime = 0.0
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
                    let bytes = data.count
                    let sizeStr: String
                    if bytes < 1024 * 1024 {
                        let kb = max(1, bytes / 1024)
                        sizeStr = "\(kb) KB"
                    } else {
                        let mb = Double(bytes) / (1024.0 * 1024.0)
                        sizeStr = String(format: "%.1f MB", mb)
                    }
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

// MARK: - 1. Red Border View (Glowing outline, dashed when paused)

class RecordingBorderView: NSView {
    var isDashed: Bool = false {
        didSet { needsDisplay = true }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        let borderRect = bounds.insetBy(dx: 1.5, dy: 1.5)
        
        // Glowing red border
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

class RecordingControlCapsuleView: NSView {
    var onPauseToggled: (() -> Void)?
    var onFinishClicked: (() -> Void)?
    var onCancelClicked: (() -> Void)?
    
    private var initialMouseLocation: NSPoint?
    
    // Grip handle: 2x3 dot pattern (matches GripDragHandleView)
    private let gripView = NSView()
    private var isGripHovered: Bool = false
    private var gripTrackingArea: NSTrackingArea?
    
    private let statusDot = NSView()
    private let timeLabel = NSTextField(labelWithString: "")
    private let divider1 = RecordingControlCapsuleView.makeToolbarDivider()
    private let pauseButton = NSButton()
    private let finishButton = NSButton()
    private let cancelButton = NSButton()
    private let spinner = NSProgressIndicator()
    
    // Consistent sizing with AnnotationToolbarView
    static let standardHeight: CGFloat = 38.0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        
        // Background + border are drawn in draw() to avoid rectangular layer artifact.
        // (layer?.backgroundColor leaks outside cornerRadius when masksToBounds = false)
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.cornerRadius = 10
        layer?.masksToBounds = false
        
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Drag to Move (grip area)
    
    override func mouseDown(with event: NSEvent) {
        initialMouseLocation = NSEvent.mouseLocation
        NSCursor.closedHand.set()
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let initial = initialMouseLocation, let window = self.window else { return }
        let current = NSEvent.mouseLocation
        let dx = current.x - initial.x
        let dy = current.y - initial.y
        var frame = window.frame
        frame.origin.x += dx
        frame.origin.y += dy
        window.setFrameOrigin(frame.origin)
        initialMouseLocation = current
    }
    
    override func mouseUp(with event: NSEvent) {
        initialMouseLocation = nil
        NSCursor.openHand.set()
    }
    
    // MARK: - Layout Setup
    
    private func setupViews() {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 2.5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        
        // 1. Grip Handle (2x3 dot pattern, same as GripDragHandleView)
        gripView.wantsLayer = true
        gripView.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(gripView)
        NSLayoutConstraint.activate([
            gripView.widthAnchor.constraint(equalToConstant: 14),
            gripView.heightAnchor.constraint(equalToConstant: 26)
        ])
        
        // Divider after grip
        stack.addArrangedSubview(Self.makeToolbarDivider())
        
        // 2. Status Dot
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 4.0
        statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
        statusDot.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(statusDot)
        NSLayoutConstraint.activate([
            statusDot.widthAnchor.constraint(equalToConstant: 8),
            statusDot.heightAnchor.constraint(equalToConstant: 8)
        ])
        
        // 3. Time / Status Label
        timeLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11.5, weight: .semibold)
        timeLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        timeLabel.alignment = .left
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(timeLabel)
        
        // 4. Divider before buttons
        stack.addArrangedSubview(divider1)
        
        // 5. Action Buttons (ToolbarIconButton-style: 24x24, cornerRadius 5)
        setupToolbarButton(pauseButton, icon: "pause.fill", action: #selector(btnPauseClicked))
        setupToolbarButton(finishButton, icon: "checkmark", tint: NSColor.systemGreen, action: #selector(btnFinishClicked))
        setupToolbarButton(cancelButton, icon: "xmark", action: #selector(btnCancelClicked))
        
        stack.addArrangedSubview(pauseButton)
        stack.addArrangedSubview(finishButton)
        stack.addArrangedSubview(cancelButton)
        
        // 6. Spinner (for encoding)
        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.isHidden = true
        addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            spinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }
    
    /// ToolbarIconButton-matching style: 24x24, cornerRadius 5, SF Symbol 12.5pt medium
    private func setupToolbarButton(_ btn: NSButton, icon: String, tint: NSColor = NSColor.white.withAlphaComponent(0.85), action: Selector) {
        btn.bezelStyle = .regularSquare
        btn.isBordered = false
        btn.imagePosition = .imageOnly
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 5
        btn.layer?.masksToBounds = false
        btn.layer?.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        
        let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .medium)
        btn.image = NSImage(systemSymbolName: icon, accessibilityDescription: nil)?.withSymbolConfiguration(config)
        btn.contentTintColor = tint
        btn.target = self
        btn.action = action
        btn.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            btn.widthAnchor.constraint(equalToConstant: 24),
            btn.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        // Add hover tracking
        let trackingArea = NSTrackingArea(rect: .zero, options: [.activeAlways, .mouseEnteredAndExited, .inVisibleRect], owner: btn, userInfo: nil)
        btn.addTrackingArea(trackingArea)
    }
    
    /// Thin vertical divider (matches AnnotationToolbarView style)
    private static func makeToolbarDivider() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.wantsLayer = true
        
        let line = NSView()
        line.translatesAutoresizingMaskIntoConstraints = false
        line.wantsLayer = true
        line.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.35).cgColor
        line.layer?.cornerRadius = 0.5
        container.addSubview(line)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 8),
            container.heightAnchor.constraint(equalToConstant: 24),
            line.widthAnchor.constraint(equalToConstant: 1.0),
            line.heightAnchor.constraint(equalToConstant: 14),
            line.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            line.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        return container
    }
    
    // MARK: - Draw Background + 2x3 Dot Grip
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Draw rounded background (avoids rectangular layer artifact)
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        NSColor(calibratedRed: 0.11, green: 0.11, blue: 0.12, alpha: 0.96).setFill()
        bgPath.fill()
        
        // 2. Draw subtle border
        let borderPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.4, dy: 0.4), xRadius: 10, yRadius: 10)
        borderPath.lineWidth = 0.8
        NSColor.white.withAlphaComponent(0.20).setStroke()
        borderPath.stroke()
        
        // 3. Draw 2x3 dot grip (convert gripView coords from stack view space to self)
        guard !gripView.isHidden else { return }
        let gripFrame = gripView.convert(gripView.bounds, to: self)
        let dotColor = NSColor.white.withAlphaComponent(0.35)
        ctx.setFillColor(dotColor.cgColor)
        
        let dotRadius: CGFloat = 1.5
        let startX = gripFrame.midX - 2.5  // Center 2 columns horizontally
        let colSpacing: CGFloat = 5.0
        let startY = gripFrame.midY - 7.0
        let rowSpacing: CGFloat = 7.0
        
        for col in 0..<2 {
            let x = startX + CGFloat(col) * colSpacing
            for row in 0..<3 {
                let y = startY + CGFloat(row) * rowSpacing
                ctx.fillEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
            }
        }
    }
    
    // MARK: - State Updates
    
    func updateState(_ state: RecordingCapsuleState) {
        switch state {
        case .countdown(let remaining):
            gripView.isHidden = false
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = NSColor.systemOrange.cgColor
            timeLabel.stringValue = "准备录制 \(remaining)s"
            divider1.isHidden = false
            pauseButton.isHidden = true
            finishButton.isHidden = false
            cancelButton.isHidden = false
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            
        case .recording(let elapsed, let maxDuration):
            gripView.isHidden = false
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = NSColor.systemRed.cgColor
            let sec = elapsed % 60
            let min = elapsed / 60
            let maxSec = maxDuration % 60
            let maxMin = maxDuration / 60
            timeLabel.stringValue = String(format: "%02d:%02d / %02d:%02d", min, sec, maxMin, maxSec)
            divider1.isHidden = false
            pauseButton.isHidden = false
            let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .medium)
            pauseButton.image = NSImage(systemSymbolName: "pause.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            pauseButton.contentTintColor = NSColor.white.withAlphaComponent(0.85)
            pauseButton.layer?.backgroundColor = NSColor.clear.cgColor
            finishButton.isHidden = false
            cancelButton.isHidden = false
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            
        case .paused(let elapsed, let maxDuration):
            gripView.isHidden = false
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = NSColor.systemYellow.cgColor
            let sec = elapsed % 60
            let min = elapsed / 60
            let maxSec = maxDuration % 60
            let maxMin = maxDuration / 60
            timeLabel.stringValue = String(format: "%02d:%02d / %02d:%02d [已暂停]", min, sec, maxMin, maxSec)
            divider1.isHidden = false
            pauseButton.isHidden = false
            let config = NSImage.SymbolConfiguration(pointSize: 12.5, weight: .medium)
            pauseButton.image = NSImage(systemSymbolName: "play.fill", accessibilityDescription: nil)?.withSymbolConfiguration(config)
            pauseButton.contentTintColor = .systemYellow
            pauseButton.layer?.backgroundColor = NSColor.systemYellow.withAlphaComponent(0.20).cgColor
            finishButton.isHidden = false
            cancelButton.isHidden = false
            
        case .encoding:
            gripView.isHidden = true
            statusDot.isHidden = true
            spinner.isHidden = false
            spinner.startAnimation(nil)
            timeLabel.stringValue = "正在压制 GIF 动图..."
            divider1.isHidden = true
            pauseButton.isHidden = true
            finishButton.isHidden = true
            cancelButton.isHidden = true
            
        case .completed(let sizeString):
            gripView.isHidden = true
            spinner.isHidden = true
            spinner.stopAnimation(nil)
            statusDot.isHidden = false
            statusDot.layer?.backgroundColor = NSColor.systemGreen.cgColor
            timeLabel.stringValue = "✓ 已复制到剪贴板 (\(sizeString))"
            divider1.isHidden = true
            pauseButton.isHidden = true
            finishButton.isHidden = true
            cancelButton.isHidden = true
        }
        
        // Auto-resize window to fit new content
        resizeWindowToFit()
    }
    
    /// Recalculates the fitting size and resizes the hosting window.
    /// Keeps the right edge anchored so only the left side moves.
    private func resizeWindowToFit() {
        layoutSubtreeIfNeeded()
        
        guard let window = self.window else { return }
        
        let newWidth = max(200, fittingSize.width + 12)
        let currentFrame = window.frame
        
        // Anchor right edge: move origin.x left as width grows
        let newX = currentFrame.maxX - newWidth
        let newFrame = NSRect(x: newX, y: currentFrame.origin.y, width: newWidth, height: currentFrame.height)
        
        // Smooth animated resize
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }
        
        // Resize the content view to match
        self.frame = NSRect(origin: .zero, size: NSSize(width: newWidth, height: currentFrame.height))
        needsDisplay = true
    }
    
    @objc private func btnPauseClicked() { onPauseToggled?() }
    @objc private func btnFinishClicked() { onFinishClicked?() }
    @objc private func btnCancelClicked() { onCancelClicked?() }
}
