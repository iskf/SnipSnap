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
    private let syncQueue = DispatchQueue(label: "com.snipsnap.gifrecorder.sync")
    private var isRecording: Bool = false
    private var isPaused: Bool = false
    private var targetDisplayID: CGDirectDisplayID?
    private var cropRect: CGRect = .zero
    private var lastFrameTimestamp: Double = 0.0
    private var frameInterval: Double = 1.0 / 15.0 // 15 FPS
    private var maxFrameCount: Int = 15 * 30 // 30 seconds max
    
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    private override init() {
        super.init()
    }
    
    /// Starts recording a selected region on screen.
    /// - Parameters:
    ///   - targetScreen: The NSScreen where selection was made
    ///   - localSelectionRect: Selection in AppKit coordinates (origin at bottom-left)
    ///   - excludingWindowNumbers: Window IDs to exclude (e.g. border and control capsule windows)
    ///   - onMaxTimeReached: Called if max duration is reached
    public func startRecording(
        targetScreen: NSScreen,
        localSelectionRect: CGRect,
        excludingWindowNumbers: [Int] = [],
        onMaxTimeReached: (() -> Void)? = nil
    ) {
        guard !isRecording else { return }
        
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
        self.cropRect = CGRect(x: max(0, xInDisplay), y: max(0, yInDisplay), width: CGFloat(width), height: CGFloat(height))
        
        syncQueue.sync {
            frames.removeAll(keepingCapacity: true)
            isRecording = true
            isPaused = false
            lastFrameTimestamp = 0.0
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
                config.scalesToFit = false
                config.showsCursor = appConfig.gifCaptureCursor
                config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps))
                config.pixelFormat = kCVPixelFormatType_32BGRA
                
                let stream = SCStream(filter: filter, configuration: config, delegate: nil)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue(label: "com.snipsnap.gifrecorder.queue", qos: .userInteractive))
                try await stream.startCapture()
                
                self.stream = stream
                print("[ScreenGIFRecorder] Recording started at \(width)x\(height), \(fps)fps (max \(maxDuration)s)")
            } catch {
                print("[ScreenGIFRecorder] Failed to start SCStream: \(error)")
                self.syncQueue.async {
                    self.isRecording = false
                    self.isPaused = false
                }
            }
        }
    }
    
    public func pauseRecording() {
        syncQueue.sync {
            isPaused = true
            print("[ScreenGIFRecorder] Recording paused.")
        }
    }
    
    public func resumeRecording() {
        syncQueue.sync {
            isPaused = false
            lastFrameTimestamp = 0.0
            print("[ScreenGIFRecorder] Recording resumed.")
        }
    }
    
    public func cancelRecording() {
        syncQueue.sync {
            isRecording = false
            isPaused = false
            frames.removeAll()
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
        
        let now = CACurrentMediaTime()
        var shouldCapture = false
        syncQueue.sync {
            if isRecording && !isPaused {
                if lastFrameTimestamp == 0 || (now - lastFrameTimestamp) >= (frameInterval * 0.85) {
                    lastFrameTimestamp = now
                    shouldCapture = true
                }
            }
        }
        guard shouldCapture else { return }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Fast hardware conversion to CGImage
        var cgImage: CGImage?
        if VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage) != noErr || cgImage == nil {
            let ciImg = CIImage(cvPixelBuffer: pixelBuffer)
            cgImage = ciContext.createCGImage(ciImg, from: ciImg.extent)
        }
        
        if let frame = cgImage {
            syncQueue.sync {
                if isRecording {
                    frames.append(frame)
                    if frames.count >= maxFrameCount {
                        isRecording = false
                    }
                }
            }
        }
    }
    
    /// Stops recording and encodes the accumulated frames into an optimized GIF.
    /// Delivers the result on completion block and writes directly to system clipboard.
    public func stopRecording(completion: @escaping @Sendable (Data?) -> Void) {
        var collectedFrames: [CGImage] = []
        syncQueue.sync {
            isRecording = false
            collectedFrames = self.frames
            self.frames = []
        }
        
        let activeStream = self.stream
        self.stream = nil
        
        Task {
            if let s = activeStream {
                try? await s.stopCapture()
            }
            
            guard !collectedFrames.isEmpty else {
                print("[ScreenGIFRecorder] No frames captured.")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            print("[ScreenGIFRecorder] Encoding \(collectedFrames.count) frames to GIF in background...")
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let gifData = self?.encodeGIF(frames: collectedFrames, frameDelay: 0.066)
                
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
