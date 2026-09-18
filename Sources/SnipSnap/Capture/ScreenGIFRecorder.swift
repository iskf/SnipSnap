import Cocoa
import CoreGraphics
import CoreMedia
import ImageIO
import ScreenCaptureKit
import UniformTypeIdentifiers
import VideoToolbox

public class ScreenGIFRecorder: NSObject, SCStreamOutput, @unchecked Sendable {
    public static let shared = ScreenGIFRecorder()
    
    private var stream: SCStream?
    private var frames: [CGImage] = []
    private var currentLatestFrame: CGImage?
    private var sampleTimer: DispatchSourceTimer?
    
    private let syncQueue = DispatchQueue(label: "com.snipsnap.gifrecorder.sync", qos: .userInteractive)
    private var isPrepared: Bool = false
    private var isRecording: Bool = false
    private var isPaused: Bool = false
    private var targetDisplayID: CGDirectDisplayID?
    private var cropRect: CGRect = .zero
    private var frameInterval: Double = 1.0 / 15.0 // 15 FPS default
    private var maxFrameCount: Int = 15 * 60 // Max frames
    
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    private override init() {
        super.init()
    }
    
    /// Pre-warms ScreenCaptureKit live capture during 3-2-1 countdown.
    /// This eliminates the 1-2s async startup latency when countdown reaches 0.
    public func prepareRecording(
        targetScreen: NSScreen,
        localSelectionRect: CGRect,
        excludingWindowNumbers: [Int] = []
    ) {
        cancelRecording()
        
        let appConfig = AppConfig.load()
        let fps = max(5, min(30, appConfig.gifFrameRate))
        self.frameInterval = 1.0 / Double(fps)
        let maxDuration = max(5, min(120, appConfig.gifMaxDuration))
        self.maxFrameCount = fps * maxDuration
        
        let screenNumber = (targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            ?? CGMainDisplayID()
        self.targetDisplayID = screenNumber
        
        // Convert AppKit coordinates (bottom-left) to ScreenCaptureKit display coordinates (top-left)
        let displayHeight = targetScreen.frame.height
        let xInDisplay = localSelectionRect.origin.x
        let yInDisplay = displayHeight - (localSelectionRect.origin.y + localSelectionRect.size.height)
        
        let width: Int
        let height: Int
        if appConfig.gifDownsample {
            // Retina 1x smart downsampling
            width = max(4, Int(round(localSelectionRect.width)) & ~1)
            height = max(4, Int(round(localSelectionRect.height)) & ~1)
        } else {
            // Native retina resolution
            let scale = targetScreen.backingScaleFactor
            width = max(4, Int(round(localSelectionRect.width * scale)) & ~1)
            height = max(4, Int(round(localSelectionRect.height * scale)) & ~1)
        }
        // SCStreamConfiguration.sourceRect MUST be in logical points
        self.cropRect = CGRect(x: max(0, xInDisplay), y: max(0, yInDisplay), width: localSelectionRect.width, height: localSelectionRect.height)
        
        syncQueue.sync {
            frames.removeAll(keepingCapacity: true)
            currentLatestFrame = nil
            isPrepared = true
            isRecording = false
            isPaused = false
        }
        
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first(where: { $0.displayID == screenNumber }) ?? content.displays.first else {
                    print("[ScreenGIFRecorder] No matching SCDisplay found for ID: \(screenNumber)")
                    return
                }
                
                let excludedSet = Set(excludingWindowNumbers.map { CGWindowID($0) })
                let excludedWindows = content.windows.filter { excludedSet.contains($0.windowID) }
                
                let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)
                let config = SCStreamConfiguration()
                config.sourceRect = self.cropRect
                config.width = width
                config.height = height
                config.scalesToFit = true // Scale sourceRect to target pixel width x height cleanly
                config.showsCursor = appConfig.gifCaptureCursor
                config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.queueDepth = 8 // Increase from default (3-5) for deep-copy headroom
                
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.snipsnap.gifrecorder.queue", qos: .userInteractive))
                try await stream.startCapture()
                
                self.stream = stream
                print("[ScreenGIFRecorder] Stream pre-warmed during countdown at \(width)x\(height), \(fps)fps")
            } catch {
                print("[ScreenGIFRecorder] Failed to pre-warm SCStream: \(error)")
                self.syncQueue.async {
                    self.isPrepared = false
                    self.isRecording = false
                }
            }
        }
    }
    
    /// Activates recording the instant 3-2-1 countdown finishes.
    /// Starts rock-solid constant frame rate (CFR) sampling.
    public func startActiveRecording() {
        syncQueue.sync {
            frames.removeAll(keepingCapacity: true)
            isRecording = true
            isPaused = false
            
            // Start high-precision CFR timer (e.g. 15 FPS = 66ms interval)
            sampleTimer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: syncQueue)
            let interval = self.frameInterval
            timer.schedule(deadline: .now() + 0.05, repeating: interval)
            timer.setEventHandler { [weak self] in
                guard let self = self, self.isRecording, !self.isPaused else { return }
                if let frame = self.currentLatestFrame {
                    self.frames.append(frame)
                    if self.frames.count >= self.maxFrameCount {
                        self.isRecording = false
                    }
                }
            }
            timer.resume()
            self.sampleTimer = timer
            print("[ScreenGIFRecorder] Active CFR recording started at interval \(interval)s!")
        }
    }
    
    /// Backward-compatible startRecording if called directly without pre-warming.
    public func startRecording(
        targetScreen: NSScreen,
        localSelectionRect: CGRect,
        excludingWindowNumbers: [Int] = [],
        onMaxTimeReached: (() -> Void)? = nil
    ) {
        prepareRecording(targetScreen: targetScreen, localSelectionRect: localSelectionRect, excludingWindowNumbers: excludingWindowNumbers)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.startActiveRecording()
        }
    }
    
    public func pauseRecording() {
        syncQueue.sync {
            guard isRecording, !isPaused else { return }
            isPaused = true
            print("[ScreenGIFRecorder] Recording paused.")
        }
    }
    
    public func resumeRecording() {
        syncQueue.sync {
            guard isRecording, isPaused else { return }
            isPaused = false
            print("[ScreenGIFRecorder] Recording resumed.")
        }
    }
    
    public func cancelRecording() {
        syncQueue.sync {
            isPrepared = false
            isRecording = false
            isPaused = false
            sampleTimer?.cancel()
            sampleTimer = nil
            frames.removeAll()
            currentLatestFrame = nil
        }
        let activeStream = self.stream
        self.stream = nil
        Task {
            if let s = activeStream {
                try? await s.stopCapture()
            }
            print("[ScreenGIFRecorder] Recording cancelled.")
        }
    }
    
    // MARK: - SCStreamOutput
    
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Fast hardware conversion to CGImage
        var cgImage: CGImage?
        if VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage) != noErr || cgImage == nil {
            let ciImg = CIImage(cvPixelBuffer: pixelBuffer)
            cgImage = ciContext.createCGImage(ciImg, from: ciImg.extent)
        }
        
        guard let frame = cgImage else { return }
        
        // CRITICAL: Deep-copy pixel data to detach from IOSurface / CVPixelBuffer pool.
        // Without this, held CGImage references starve SCStream's buffer pool and it
        // silently stops delivering new frames — causing scrolling/dynamic content to freeze.
        guard let copied = deepCopyCGImage(frame) else { return }
        
        syncQueue.sync {
            currentLatestFrame = copied
            // If timer has not captured first frame yet, prime it
            if isRecording && frames.isEmpty {
                frames.append(copied)
            }
        }
    }
    
    /// Creates an independent deep copy of a CGImage by redrawing into a new bitmap context.
    /// This detaches the image from any IOSurface or CVPixelBuffer backing store.
    private func deepCopyCGImage(_ image: CGImage) -> CGImage? {
        let w = image.width
        let h = image.height
        guard let ctx = CGContext(
            data: nil,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: 0, // Let the system choose optimal row alignment
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage()
    }
    
    /// Stops recording and encodes the accumulated frames into an optimized GIF.
    public func stopRecording(completion: @escaping @Sendable (Data?) -> Void) {
        // Allow a brief 100ms flush delay so any in-flight sample buffers from the user's final action arrive
        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            var collectedFrames: [CGImage] = []
            let interval = self.frameInterval
            
            self.syncQueue.sync {
                self.isRecording = false
                self.sampleTimer?.cancel()
                self.sampleTimer = nil
                
                // Add final hold frame so end action is held nicely
                if let last = self.currentLatestFrame {
                    let holdCount = max(1, Int(0.6 / interval))
                    for _ in 0..<holdCount {
                        self.frames.append(last)
                    }
                }
                
                collectedFrames = self.frames
                self.frames = []
            }
            
            let activeStream = self.stream
            self.stream = nil
            self.isPrepared = false
            
            Task {
                if let s = activeStream {
                    try? await s.stopCapture()
                }
                
                guard !collectedFrames.isEmpty else {
                    print("[ScreenGIFRecorder] No frames captured.")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }
                
                let totalDuration = Double(collectedFrames.count) * interval
                print("[ScreenGIFRecorder] Encoding \(collectedFrames.count) frames (CFR: \(String(format: "%.2f", totalDuration))s at \(String(format: "%.3f", interval))s/frame) to GIF in background...")
                
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let gifData = self?.encodeGIF(frames: collectedFrames, frameDelay: interval)
                    
                    if let data = gifData {
                        print("[ScreenGIFRecorder] GIF encoded successfully! Size: \(data.count) bytes")
                        self?.exportGIFToClipboard(gifData: data)
                    }
                    
                    DispatchQueue.main.async {
                        completion(gifData)
                    }
                }
            }
        }
    }
    
    // MARK: - GIF Encoding & Clipboard Export
    
    private func encodeGIF(frames: [CGImage], frameDelay: Double) -> Data? {
        guard !frames.isEmpty else { return nil }
        
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            return nil
        }
        
        let fileProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0 // Infinite loop
            ]
        ]
        CGImageDestinationSetProperties(destination, fileProperties as CFDictionary)
        
        let frameProperties: [CFString: Any] = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: frameDelay,
                kCGImagePropertyGIFUnclampedDelayTime: frameDelay
            ]
        ]
        
        for frame in frames {
            autoreleasepool {
                CGImageDestinationAddImage(destination, frame, frameProperties as CFDictionary)
            }
        }
        
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        return data as Data
    }
    
    private func exportGIFToClipboard(gifData: Data) {
        let appConfig = AppConfig.load()
        DispatchQueue.main.async {
            if appConfig.gifAutoCopy {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                
                // 1. Write GIF data directly as com.compuserve.gif
                pasteboard.setData(gifData, forType: NSPasteboard.PasteboardType("com.compuserve.gif"))
                
                // 2. Also save to temporary directory and write file URL
                let tempDir = FileManager.default.temporaryDirectory
                let fileName = "SnipSnap_\(Int(Date().timeIntervalSince1970)).gif"
                let fileURL = tempDir.appendingPathComponent(fileName)
                try? gifData.write(to: fileURL)
                pasteboard.writeObjects([fileURL as NSURL])
            }
            
            if appConfig.gifAutoSave {
                let saveDir = URL(fileURLWithPath: appConfig.defaultSavePath)
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let fileName = "SnipSnap_\(formatter.string(from: Date())).gif"
                let fileURL = saveDir.appendingPathComponent(fileName)
                try? gifData.write(to: fileURL)
                print("[ScreenGIFRecorder] Saved GIF to: \(fileURL.path)")
            }
            
            // 3. Play sound if enabled
            if appConfig.gifPlaySound {
                NSSound(named: "Tink")?.play()
            }
            print("[ScreenGIFRecorder] Processed GIF export (\(gifData.count) bytes).")
        }
    }
}
