import Cocoa
import CoreGraphics
import ScreenCaptureKit

public struct DetectedWindowInfo: Sendable {
    public var windowID: CGWindowID
    public var frame: CGRect
    public var title: String?
    public var appName: String?
}

public struct CapturedScreenData: @unchecked Sendable {
    public var image: NSImage
    public var screenFrame: CGRect
    public var targetScreen: NSScreen
    
    public init(image: NSImage, screenFrame: CGRect, targetScreen: NSScreen) {
        self.image = image
        self.screenFrame = screenFrame
        self.targetScreen = targetScreen
    }
}

public class ScreenCaptureService {
    public static let shared = ScreenCaptureService()
    
    private init() {}
    
    /// Captures the screen currently focused by the mouse pointer.
    /// This avoids macOS multi-display window isolation restrictions and guarantees 100% native resolution on any monitor.
    public func captureFocusedScreen(
        at point: CGPoint? = nil,
        completion: @escaping @MainActor @Sendable (CapturedScreenData?, [DetectedWindowInfo]) -> Void
    ) {
        let mousePoint = point ?? NSEvent.mouseLocation
        let screens = NSScreen.screens
        guard !screens.isEmpty else {
            Task { @MainActor in completion(nil, []) }
            return
        }
        
        // Find target screen containing mousePoint
        let targetScreen: NSScreen = screens.first(where: { NSMouseInRect(mousePoint, $0.frame, false) })
            ?? NSScreen.main
            ?? screens[0]
            
        let screenFrame = targetScreen.frame
        let targetDisplayID = (targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            ?? CGMainDisplayID()
            
        Task {
            // 1. Primary Engine: Modern ScreenCaptureKit (macOS 14.0+ / 15+ / Sequoia)
            if #available(macOS 14.0, *) {
                do {
                    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                    
                    let targetSCDisplay = content.displays.first(where: { $0.displayID == targetDisplayID })
                        ?? content.displays.first(where: {
                            $0.frame.intersects(screenFrame)
                        })
                        ?? content.displays.first
                        
                    guard let display = targetSCDisplay else {
                        throw NSError(domain: "ScreenCaptureService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No matching SCDisplay found"])
                    }
                    
                    let filter = SCContentFilter(display: display, excludingWindows: [])
                    let config = SCStreamConfiguration()
                    config.width = display.width
                    config.height = display.height
                    config.showsCursor = false
                    config.scalesToFit = false
                    
                    let cgImg = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    let nsImage = NSImage(cgImage: cgImg, size: screenFrame.size)
                    
                    // Windows detection for smart snapping, strictly mapped to targetScreen local coordinates
                    let primaryScreenHeight = screens.first(where: { $0.frame.origin == .zero })?.frame.height ?? screenFrame.height
                    let quartzScreenX = screenFrame.origin.x
                    let quartzScreenY = primaryScreenHeight - (screenFrame.origin.y + screenFrame.height)
                    
                    var detectedAcc: [DetectedWindowInfo] = []
                    for w in content.windows {
                        guard w.windowLayer == 0, w.frame.width > 50, w.frame.height > 50 else { continue }
                        
                        let relX = w.frame.origin.x - quartzScreenX
                        let relY = w.frame.origin.y - quartzScreenY
                        let localX = relX
                        let localY = screenFrame.height - (relY + w.frame.height)
                        
                        let localFrame = CGRect(
                            x: round(localX),
                            y: round(localY),
                            width: round(w.frame.width),
                            height: round(w.frame.height)
                        )
                        
                        let screenBounds = CGRect(origin: .zero, size: screenFrame.size)
                        let intersection = localFrame.intersection(screenBounds)
                        if !intersection.isNull && intersection.width >= 40 && intersection.height >= 40 {
                            detectedAcc.append(DetectedWindowInfo(
                                windowID: w.windowID,
                                frame: localFrame,
                                title: w.title,
                                appName: w.owningApplication?.applicationName
                            ))
                        }
                    }
                    
                    let result = CapturedScreenData(image: nsImage, screenFrame: screenFrame, targetScreen: targetScreen)
                    let finalDetected = detectedAcc
                    await MainActor.run {
                        completion(result, finalDetected)
                    }
                    return
                } catch {
                    print("ScreenCaptureKit error on display \(targetDisplayID): \(error), falling back to Quartz...")
                }
            }
            
            // 2. Fallback Engine: Legacy Quartz Window Server for target screen
            let fallbackResult = self.legacyCaptureScreen(screen: targetScreen, displayID: targetDisplayID)
            let fallbackDetected = self.legacyDetectWindows(targetScreen: targetScreen)
            await MainActor.run {
                completion(fallbackResult, fallbackDetected)
            }
        }
    }
    
    /// Compatibility wrapper for existing callers
    public func captureAllScreens(completion: @escaping @MainActor @Sendable ((image: NSImage, unionBounds: CGRect)?, [DetectedWindowInfo]) -> Void) {
        captureFocusedScreen { captured, detected in
            if let captured = captured {
                completion((captured.image, captured.screenFrame), detected)
            } else {
                completion(nil, detected)
            }
        }
    }
    
    private func legacyCaptureScreen(screen: NSScreen, displayID: CGDirectDisplayID) -> CapturedScreenData? {
        if let cgImage = CGDisplayCreateImage(displayID) {
            let nsImage = NSImage(cgImage: cgImage, size: screen.frame.size)
            return CapturedScreenData(image: nsImage, screenFrame: screen.frame, targetScreen: screen)
        }
        
        guard let cgImage = CGWindowListCreateImage(
            screen.frame,
            .optionOnScreenOnly,
            kCGNullWindowID,
            [.bestResolution]
        ) else {
            return nil
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: screen.frame.size)
        return CapturedScreenData(image: nsImage, screenFrame: screen.frame, targetScreen: screen)
    }
    
    private func legacyDetectWindows(targetScreen: NSScreen) -> [DetectedWindowInfo] {
        var results: [DetectedWindowInfo] = []
        let screenFrame = targetScreen.frame
        guard screenFrame.width > 0, screenFrame.height > 0 else { return results }
        
        guard let windowListInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return results
        }
        
        let primaryScreenHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height ?? screenFrame.height
        let quartzScreenX = screenFrame.origin.x
        let quartzScreenY = primaryScreenHeight - (screenFrame.origin.y + screenFrame.height)
        
        for item in windowListInfo {
            guard let layer = item[kCGWindowLayer as String] as? Int, layer == 0 else { continue }
            guard let boundsDict = item[kCGWindowBounds as String] as? [String: CGFloat] else { continue }
            guard let x = boundsDict["X"], let y = boundsDict["Y"],
                  let w = boundsDict["Width"], let h = boundsDict["Height"],
                  w > 50, h > 50 else { continue }
            
            let windowID = item[kCGWindowNumber as String] as? CGWindowID ?? 0
            let title = item[kCGWindowName as String] as? String
            let appName = item[kCGWindowOwnerName as String] as? String
            
            let relX = x - quartzScreenX
            let relY = y - quartzScreenY
            let localX = relX
            let localY = screenFrame.height - (relY + h)
            
            let localFrame = CGRect(
                x: round(localX),
                y: round(localY),
                width: round(w),
                height: round(h)
            )
            
            let screenBounds = CGRect(origin: .zero, size: screenFrame.size)
            let intersection = localFrame.intersection(screenBounds)
            if !intersection.isNull && intersection.width >= 40 && intersection.height >= 40 {
                results.append(DetectedWindowInfo(
                    windowID: windowID,
                    frame: localFrame,
                    title: title,
                    appName: appName
                ))
            }
        }
        
        return results
    }
    
    public func crop(image: NSImage, to rect: CGRect, fullBounds: CGRect) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        guard fullBounds.width > 0, fullBounds.height > 0, rect.width > 0, rect.height > 0 else { return nil }
        
        let scaleX = CGFloat(cgImage.width) / fullBounds.width
        let scaleY = CGFloat(cgImage.height) / fullBounds.height
        
        // rect is in CaptureOverlayView coordinates (origin 0,0 at bottom-left of full union bounds)
        // CGImage has (0, 0) at the top-left, while NSView has (0, 0) at bottom-left
        // Strictly snap to whole integer pixels to avoid CoreGraphics fractional integral expansion
        let cropX = round(rect.origin.x * scaleX)
        let cropY = round((fullBounds.height - (rect.origin.y + rect.height)) * scaleY)
        let cropW = round(rect.width * scaleX)
        let cropH = round(rect.height * scaleY)
        
        let imgWidth = CGFloat(cgImage.width)
        let imgHeight = CGFloat(cgImage.height)
        
        // Clamp to prevent out-of-bounds crop returning nil
        let clampedX = max(0, min(cropX, imgWidth - 1))
        let clampedY = max(0, min(cropY, imgHeight - 1))
        let clampedW = max(1, min(cropW, imgWidth - clampedX))
        let clampedH = max(1, min(cropH, imgHeight - clampedY))
        
        let cropRect = CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)
        guard let croppedCG = cgImage.cropping(to: cropRect) else { return nil }
        
        let exactSize = CGSize(width: clampedW / scaleX, height: clampedH / scaleY)
        return NSImage(cgImage: croppedCG, size: exactSize)
    }
}
