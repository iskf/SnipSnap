import Cocoa
import CoreGraphics
import SwiftUI

// MARK: - Custom HUD Window to allow full mouse and keyboard interaction
public class ScrollingCaptureHUDWindow: NSWindow {
    public override var canBecomeKey: Bool { true }
    public override var canBecomeMain: Bool { true }
    public override var acceptsMouseMovedEvents: Bool {
        get { true }
        set {}
    }
}

// MARK: - FirstMouseHostingView to ensure clicks on floating window controls fire immediately
public class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

public class ScrollingCaptureSession: NSObject, @unchecked Sendable {
    public static let shared = ScrollingCaptureSession()
    
    private var borderWindow: NSWindow?
    private var borderView: ScrollingCaptureBorderView?
    private var hudWindow: ScrollingCaptureHUDWindow?
    
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    
    private var sessionScreen: NSScreen?
    private var captureRect: CGRect = .zero // Quartz coordinates
    
    private let stitcher = ScrollingStitcher()
    private let viewModel = ScrollingCaptureViewModel()
    
    private var captureTimer: Timer?
    private var isCapturing: Bool = false
    private var isFinishing: Bool = false
    private var frameCounter: Int = 0
    private var hasDetectedTheme: Bool = false
    
    private override init() {
        super.init()
    }
    
    public func startSession(screen: NSScreen, screenRect: CGRect) {
        cleanup()
        
        self.sessionScreen = screen
        stitcher.reset()
        self.frameCounter = 0
        self.hasDetectedTheme = false
        self.isCapturing = true
        self.isFinishing = false
        
        // Convert screenRect (macOS bottom-left origin) to Quartz display coordinates (top-left origin)
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let quartzY = primaryScreenHeight - screenRect.maxY
        self.captureRect = CGRect(x: screenRect.minX, y: quartzY, width: screenRect.width, height: screenRect.height)
        
        // 1. Reset ViewModel
        viewModel.totalPixels = Int(screenRect.height)
        viewModel.frameCount = 0
        viewModel.segmentCount = 1
        viewModel.thumbnail = nil
        viewModel.isCompleted = false
        viewModel.statusMessage = "请手动滑动页面..."
        
        viewModel.onFinish = { [weak self] in self?.finishSession() }
        viewModel.onCancel = { [weak self] in self?.cancelSession() }
        
        // 2. Border Window (covers screen, ignoresMouseEvents = true so user has 100% mouse freedom to scroll & click!)
        let bWin = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        bWin.isOpaque = false
        bWin.backgroundColor = .clear
        bWin.hasShadow = false
        bWin.level = .floating
        bWin.sharingType = .none // Invisible to screen capture!
        bWin.ignoresMouseEvents = true // Complete mouse freedom
        
        let localRect = NSRect(
            x: screenRect.minX - screen.frame.minX,
            y: screenRect.minY - screen.frame.minY,
            width: screenRect.width,
            height: screenRect.height
        )
        let bView = ScrollingCaptureBorderView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            selectionRect: localRect,
            initialHeight: Int(screenRect.height)
        )
        bWin.contentView = bView
        bWin.orderFrontRegardless()
        self.borderWindow = bWin
        self.borderView = bView
        
        // 3. Floating HUD Window (compact 164px width, docked to the right of selection rect)
        let hudWidth: CGFloat = 164
        let hudHeight: CGFloat = 280
        
        var hudX = screenRect.maxX + 10
        if hudX + hudWidth > screen.frame.maxX - 10 {
            // Flip to left if screen right boundary is tight
            hudX = screenRect.minX - hudWidth - 10
        }
        if hudX < screen.frame.minX + 10 {
            hudX = min(screenRect.minX + 10, screen.frame.maxX - hudWidth - 10)
        }
        
        var hudY = screenRect.maxY - hudHeight
        if hudY < screen.frame.minY + 15 {
            hudY = screen.frame.minY + 15
        }
        if hudY + hudHeight > screen.frame.maxY - 15 {
            hudY = screen.frame.maxY - hudHeight - 15
        }
        
        let hudRect = NSRect(x: hudX, y: hudY, width: hudWidth, height: hudHeight)
        let hWin = ScrollingCaptureHUDWindow(
            contentRect: hudRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        hWin.isOpaque = false
        hWin.backgroundColor = .clear
        hWin.hasShadow = true
        hWin.level = .floating
        hWin.sharingType = .none // Invisible to screen capture!
        hWin.ignoresMouseEvents = false
        
        let hostingView = FirstMouseHostingView(rootView: ScrollingCaptureHUDView(viewModel: viewModel))
        hostingView.frame = NSRect(origin: .zero, size: hudRect.size)
        hWin.contentView = hostingView
        hWin.orderFrontRegardless()
        self.hudWindow = hWin
        
        setupShortcuts()
        
        // 4. Initial capture & Start continuous frame sampling loop (approx 16 FPS / 60ms)
        captureFrame()
        
        captureTimer = Timer.scheduledTimer(withTimeInterval: 0.065, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    
    private func tick() {
        guard isCapturing, !isFinishing else { return }
        captureFrame()
    }
    
    private func captureFrame() {
        guard isCapturing, !isFinishing else { return }
        
        // Scale captureRect by display scale factor for native resolution
        let scale = sessionScreen?.backingScaleFactor ?? 2.0
        let quartzRect = CGRect(
            x: captureRect.origin.x * scale,
            y: captureRect.origin.y * scale,
            width: captureRect.width * scale,
            height: captureRect.height * scale
        )
        
        guard let cgImage = CGWindowListCreateImage(
            quartzRect,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else { return }
        
        if !hasDetectedTheme || frameCounter % 15 == 0 {
            let isLight = detectIsLightBackground(image: cgImage)
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.isLightBackground = isLight
            }
            hasDetectedTheme = true
        }
        
        let result = stitcher.processFrame(cgImage)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch result {
            case .appended(_, let totalH, let direction):
                self.viewModel.totalPixels = totalH
                self.viewModel.frameCount = self.stitcher.capturedFrameCount
                self.viewModel.scrollDirection = direction
                self.viewModel.viewportProgress = self.stitcher.viewportProgress
                self.viewModel.viewportRatio = self.stitcher.viewportRatio
                self.borderView?.currentHeight = totalH
                
                self.frameCounter += 1
                if self.frameCounter % 3 == 0 {
                    self.viewModel.thumbnail = self.stitcher.generateThumbnail(targetWidth: 146)
                }
                
            case .navigating(_, _, let direction):
                self.viewModel.scrollDirection = direction
                self.viewModel.viewportProgress = self.stitcher.viewportProgress
                self.viewModel.viewportRatio = self.stitcher.viewportRatio
                
            case .skippedIdentical:
                self.viewModel.scrollDirection = .idle
                
            case .failed(let reason):
                self.viewModel.statusMessage = reason
            }
        }
    }
    
    public func finishSession() {
        guard !isFinishing else { return }
        isFinishing = true
        isCapturing = false
        
        captureTimer?.invalidate()
        captureTimer = nil
        
        // Hide border window immediately
        borderWindow?.orderOut(nil)
        borderWindow = nil
        borderView = nil
        
        viewModel.statusMessage = "正在生成高清长图..."
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let finalImages = self.stitcher.renderFinalImages()
            
            DispatchQueue.main.async {
                if !finalImages.isEmpty {
                    let config = AppConfig.load()
                    if config.autoSaveAfterCapture {
                        self.autoSaveImages(finalImages, config: config)
                    }
                    
                    // Copy to clipboard (all images written so multi-image pasting works in Finder/Chat apps)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.writeObjects(finalImages)
                    
                    // Update state to completed
                    self.viewModel.isCompleted = true
                    self.viewModel.segmentCount = finalImages.count
                    if finalImages.count > 1 {
                        self.viewModel.statusMessage = L10n("scroll.hud.copied_segments")
                    } else {
                        self.viewModel.statusMessage = L10n("scroll.hud.copied")
                    }
                    self.viewModel.thumbnail = finalImages.first
                    
                    if config.playSoundEffect {
                        NSSound(named: "Glass")?.play()
                    }
                    
                    // Smooth auto-dismiss HUD after 1.0 second (give time to read confirmation)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.fadeOutAndCleanup()
                    }
                } else {
                    self.cleanup()
                }
            }
        }
    }
    
    private func autoSaveImages(_ images: [NSImage], config: AppConfig) {
        let saveDir: URL
        if !config.defaultSavePath.isEmpty && FileManager.default.fileExists(atPath: config.defaultSavePath) {
            saveDir = URL(fileURLWithPath: config.defaultSavePath)
        } else if let desktop = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first {
            saveDir = desktop
        } else {
            return
        }
        
        let isJpeg = config.imageSaveFormat.uppercased() == "JPEG"
        let ext = isJpeg ? "jpg" : "png"
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd_HH.mm.ss"
        let timestamp = df.string(from: Date())
        
        for (index, image) in images.enumerated() {
            let suffix = images.count > 1 ? "_part\(index + 1)" : ""
            let baseName = "SnipSnap_\(timestamp)\(suffix)"
            var fileURL = saveDir.appendingPathComponent("\(baseName).\(ext)")
            
            var counter = 1
            while FileManager.default.fileExists(atPath: fileURL.path) {
                fileURL = saveDir.appendingPathComponent("\(baseName)_\(counter).\(ext)")
                counter += 1
            }
            
            guard let tiff = image.tiffRepresentation,
                  let rep = NSBitmapImageRep(data: tiff) else { continue }
            
            let data = isJpeg
                ? rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92])
                : rep.representation(using: .png, properties: [:])
            
            if let data = data {
                try? data.write(to: fileURL)
            }
        }
    }
    
    public func cancelSession() {
        cleanup()
    }
    
    private func setupShortcuts() {
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, !self.isFinishing else { return event }
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
            guard let self = self, !self.isFinishing else { return }
            if event.keyCode == 36 { // Enter -> Finish
                DispatchQueue.main.async { self.finishSession() }
            } else if event.keyCode == 53 { // Esc -> Cancel
                DispatchQueue.main.async { self.cancelSession() }
            }
        }
    }
    
    private func fadeOutAndCleanup() {
        guard let win = hudWindow else {
            cleanup()
            return
        }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            win.animator().alphaValue = 0.0
        }, completionHandler: { [weak self] in
            self?.cleanup()
        })
    }
    
    private func cleanup() {
        captureTimer?.invalidate()
        captureTimer = nil
        
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
        
        hudWindow?.orderOut(nil)
        hudWindow = nil
        
        sessionScreen = nil
        isCapturing = false
        isFinishing = false
    }
    
    /// Samples pixels from the current frame to determine if the background is light or dark
    private func detectIsLightBackground(image: CGImage) -> Bool {
        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else { return false }
        let width = image.width
        let height = image.height
        let bpr = image.bytesPerRow
        let bpp = max(4, image.bitsPerPixel / 8)
        
        var totalLum = 0.0
        var samples = 0
        let stepX = max(1, width / 12)
        let stepY = max(1, height / 12)
        
        for y in stride(from: 0, to: height, by: stepY) {
            let rowOff = y * bpr
            for x in stride(from: 0, to: width, by: stepX) {
                let off = rowOff + x * bpp
                let r = Double(ptr[off])
                let g = Double(ptr[off + 1])
                let b = Double(ptr[off + 2])
                let lum = 0.299 * r + 0.587 * g + 0.114 * b
                totalLum += lum
                samples += 1
            }
        }
        guard samples > 0 else { return false }
        let avgLum = (totalLum / Double(samples)) / 255.0
        return avgLum > 0.55
    }
}

// MARK: - Apple Intelligence Violet-Blue Border & Dynamic Dimension Pill View

class ScrollingCaptureBorderView: NSView {
    public var selectionRect: NSRect
    public var currentHeight: Int {
        didSet {
            if oldValue != currentHeight {
                needsDisplay = true
            }
        }
    }
    
    init(frame: NSRect, selectionRect: NSRect, initialHeight: Int) {
        self.selectionRect = selectionRect
        self.currentHeight = initialHeight
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext, !selectionRect.isEmpty else { return }
        
        // 1. Apple Intelligence Violet-Blue Radiant Optical Glow Border:
        context.saveGState()
        // Outer radiant optical glow (radius 8.0, Apple Intelligence luminous violet-blue)
        context.setShadow(
            offset: .zero,
            blur: 8.0,
            color: NSColor(red: 0.55, green: 0.35, blue: 1.0, alpha: 0.85).cgColor
        )
        context.setStrokeColor(NSColor(red: 0.45, green: 0.55, blue: 1.0, alpha: 0.95).cgColor)
        context.setLineWidth(1.8)
        context.stroke(selectionRect.insetBy(dx: -0.5, dy: -0.5))
        
        // Inner crisp core line (radiant light blue)
        context.setShadow(offset: .zero, blur: 0, color: nil)
        context.setStrokeColor(NSColor(red: 0.75, green: 0.88, blue: 1.0, alpha: 0.95).cgColor)
        context.setLineWidth(1.0)
        context.stroke(selectionRect.insetBy(dx: -0.5, dy: -0.5))
        context.restoreGState()
        
        // 2. Dynamic dimension HUD: Frosted glass capsule with subtle border
        // Displays: "width × currentHeight px" (e.g. "800 × 3,420 px")
        let formattedHeight = NumberFormatter.localizedString(from: NSNumber(value: currentHeight), number: .decimal)
        let sizeStr = "\(Int(selectionRect.width)) × \(formattedHeight) px"
        let hudFont = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .bold)
        let hudAttrs: [NSAttributedString.Key: Any] = [
            .font: hudFont,
            .foregroundColor: NSColor.white
        ]
        let hudSize = (sizeStr as NSString).size(withAttributes: hudAttrs)
        
        // Position HUD: placed 5px above top-left of selectionRect
        // If too close to screen top, flip inside selectionRect
        var hudY = selectionRect.maxY + 5
        if hudY + hudSize.height + 7 > bounds.maxY - 10 {
            hudY = selectionRect.maxY - (hudSize.height + 7) - 6
        }
        let hudRect = CGRect(
            x: selectionRect.minX,
            y: hudY,
            width: hudSize.width + 14,
            height: hudSize.height + 7
        )
        
        // Frosted dark pill background
        context.setFillColor(NSColor(calibratedWhite: 0.12, alpha: 0.88).cgColor)
        let bgPath = NSBezierPath(roundedRect: hudRect, xRadius: 6, yRadius: 6)
        bgPath.fill()
        
        // Subtle border around HUD
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.18).cgColor)
        context.setLineWidth(0.8)
        let strokePath = NSBezierPath(roundedRect: hudRect, xRadius: 6, yRadius: 6)
        strokePath.stroke()
        
        (sizeStr as NSString).draw(
            at: CGPoint(x: hudRect.minX + 7, y: hudRect.minY + 3.5),
            withAttributes: hudAttrs
        )
    }
}
