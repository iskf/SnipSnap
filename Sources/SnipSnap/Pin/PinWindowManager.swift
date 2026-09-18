import Cocoa

public struct PinItemMetadata: Codable {
    public var fileName: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var zoomScale: Double
    public var alphaValue: Double
    public var rotationAngle: Double
    public var isFlippedHorizontal: Bool
    public var isFlippedVertical: Bool
    public var isMousePassThrough: Bool
    
    public init(fileName: String, x: Double, y: Double, width: Double, height: Double, zoomScale: Double, alphaValue: Double, rotationAngle: Double, isFlippedHorizontal: Bool, isFlippedVertical: Bool, isMousePassThrough: Bool) {
        self.fileName = fileName
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.zoomScale = zoomScale
        self.alphaValue = alphaValue
        self.rotationAngle = rotationAngle
        self.isFlippedHorizontal = isFlippedHorizontal
        self.isFlippedVertical = isFlippedVertical
        self.isMousePassThrough = isMousePassThrough
    }
}

import Combine

public class PinWindowManager: ObservableObject {
    public static let shared = PinWindowManager()
    
    @Published public private(set) var pinWindows: [PinWindow] = []
    @Published public private(set) var arePinsHidden: Bool = false
    
    private let sessionDir: URL = {
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let dir = urls[0].appendingPathComponent("SnipSnap/PinsSession")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()
    
    private var globalFlagsMonitor: Any?
    private var localFlagsMonitor: Any?
    private var isRestoringPins: Bool = false
    
    private init() {}
    
    public func toggleAllPinsVisibility() {
        if arePinsHidden {
            for pin in pinWindows {
                pin.makeKeyAndOrderFront(nil)
            }
            arePinsHidden = false
        } else {
            for pin in pinWindows {
                pin.orderOut(nil)
            }
            arePinsHidden = true
        }
    }
    
    @discardableResult
    public func createPin(from image: NSImage, initialFrame: NSRect? = nil) -> PinWindow {
        let pin = PinWindow(image: image, initialFrame: initialFrame)
        pinWindows.append(pin)
        pin.orderFrontRegardless()
        pin.makeKeyAndOrderFront(nil)
        saveActivePinsAsync()
        return pin
    }
    
    public func removePin(_ pin: PinWindow) {
        pinWindows.removeAll { $0 == pin }
        updatePassThroughMonitoring()
        saveActivePinsAsync()
    }
    
    public func closeAllPins() {
        for pin in pinWindows {
            pin.orderOut(nil)
            pin.close()
        }
        pinWindows.removeAll()
        updatePassThroughMonitoring()
        saveActivePinsAsync()
    }
    
    // MARK: - Pass-Through Management & Option-Key Unlock
    
    public func unlockAllPassThroughPins() {
        for pin in pinWindows where pin.isMousePassThrough {
            pin.isMousePassThrough = false
        }
        updatePassThroughMonitoring()
        saveActivePinsAsync()
        NSSound(named: "Pop")?.play()
    }
    
    public func updatePassThroughMonitoring() {
        let hasPassThrough = pinWindows.contains { $0.isMousePassThrough }
        
        if hasPassThrough {
            if globalFlagsMonitor == nil {
                globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                    self?.handleFlagsChanged(event)
                }
            }
            if localFlagsMonitor == nil {
                localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
                    self?.handleFlagsChanged(event)
                    return event
                }
            }
        } else {
            if let g = globalFlagsMonitor {
                NSEvent.removeMonitor(g)
                globalFlagsMonitor = nil
            }
            if let l = localFlagsMonitor {
                NSEvent.removeMonitor(l)
                localFlagsMonitor = nil
            }
            for pin in pinWindows {
                pin.pinContentView.isOptionHeld = false
            }
        }
    }
    
    private func handleFlagsChanged(_ event: NSEvent) {
        let isOptionHeld = event.modifierFlags.contains(.option)
        for pin in pinWindows where pin.isMousePassThrough {
            pin.ignoresMouseEvents = !isOptionHeld
            pin.pinContentView.isOptionHeld = isOptionHeld
        }
    }
    
    // MARK: - Clipboard Pure Image Stream
    
    public func pinFromClipboard() {
        let pb = NSPasteboard.general
        
        // 1. Image directly on pasteboard
        if let image = NSImage(pasteboard: pb) {
            createPin(from: image)
            return
        }
        
        // 2. Image files in pasteboard (e.g. copied from Finder)
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
            for url in urls {
                if let image = NSImage(contentsOf: url) {
                    createPin(from: image)
                    return
                }
            }
        }
        
        NSSound.beep()
    }
    
    // MARK: - Pin Merge (Shift + Drag onto neighboring pin)
    
    public func mergePins(source: PinWindow, target: PinWindow, horizontal: Bool) {
        guard source != target else { return }
        
        let imgA = target.pinContentView.currentImage
        let imgB = source.pinContentView.currentImage
        
        let newWidth: CGFloat
        let newHeight: CGFloat
        
        if horizontal {
            newWidth = imgA.size.width + imgB.size.width
            newHeight = max(imgA.size.height, imgB.size.height)
        } else {
            newWidth = max(imgA.size.width, imgB.size.width)
            newHeight = imgA.size.height + imgB.size.height
        }
        
        let mergedImage = NSImage(size: CGSize(width: newWidth, height: newHeight))
        mergedImage.lockFocus()
        
        if horizontal {
            imgA.draw(in: NSRect(x: 0, y: 0, width: imgA.size.width, height: imgA.size.height))
            imgB.draw(in: NSRect(x: imgA.size.width, y: 0, width: imgB.size.width, height: imgB.size.height))
        } else {
            imgB.draw(in: NSRect(x: 0, y: 0, width: imgB.size.width, height: imgB.size.height))
            imgA.draw(in: NSRect(x: 0, y: imgB.size.height, width: imgA.size.width, height: imgA.size.height))
        }
        
        mergedImage.unlockFocus()
        
        // Update target window
        target.pinContentView.currentImage = mergedImage
        target.setFrame(NSRect(origin: target.frame.origin, size: mergedImage.size), display: true, animate: true)
        
        // Remove source window
        source.pinViewDidRequestClose()
        NSSound(named: "Tink")?.play()
    }
    
    // MARK: - Session Persistence & Restore
    
    public func saveActivePinsSync() {
        guard !isRestoringPins else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.sync { [weak self] in
                self?.saveActivePinsSync()
            }
            return
        }
        
        let dir = sessionDir
        
        if pinWindows.isEmpty {
            try? FileManager.default.removeItem(at: dir)
            return
        }
        
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        
        var metadatas: [PinItemMetadata] = []
        for (idx, pin) in pinWindows.enumerated() {
            let fileName = "pin_\(idx).png"
            let fileURL = dir.appendingPathComponent(fileName)
            
            let img = pin.pinContentView.currentImage
            if let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: fileURL)
            }
            
            let frame = pin.frame
            let content = pin.pinContentView!
            metadatas.append(PinItemMetadata(
                fileName: fileName,
                x: Double(frame.origin.x),
                y: Double(frame.origin.y),
                width: Double(frame.width),
                height: Double(frame.height),
                zoomScale: Double(content.zoomScale),
                alphaValue: Double(pin.alphaValue),
                rotationAngle: Double(content.rotationAngle),
                isFlippedHorizontal: content.isFlippedHorizontal,
                isFlippedVertical: content.isFlippedVertical,
                isMousePassThrough: pin.isMousePassThrough
            ))
        }
        
        let jsonURL = dir.appendingPathComponent("session.json")
        if let data = try? JSONEncoder().encode(metadatas) {
            try? data.write(to: jsonURL)
        }
    }
    
    public func saveActivePinsAsync() {
        guard !isRestoringPins else { return }
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.saveActivePinsAsync()
            }
            return
        }
        
        let dir = sessionDir
        if pinWindows.isEmpty {
            DispatchQueue.global(qos: .utility).async {
                try? FileManager.default.removeItem(at: dir)
            }
            return
        }
        
        struct PinSnapshot {
            let fileName: String
            let frame: NSRect
            let zoomScale: CGFloat
            let alphaValue: CGFloat
            let rotationAngle: CGFloat
            let isFlippedHorizontal: Bool
            let isFlippedVertical: Bool
            let isMousePassThrough: Bool
            let pngData: Data?
        }
        
        var snapshots: [PinSnapshot] = []
        for (idx, pin) in pinWindows.enumerated() {
            let img = pin.pinContentView.currentImage
            var pngData: Data? = nil
            if let tiff = img.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff) {
                pngData = rep.representation(using: .png, properties: [:])
            }
            let content = pin.pinContentView!
            snapshots.append(PinSnapshot(
                fileName: "pin_\(idx).png",
                frame: pin.frame,
                zoomScale: content.zoomScale,
                alphaValue: pin.alphaValue,
                rotationAngle: content.rotationAngle,
                isFlippedHorizontal: content.isFlippedHorizontal,
                isFlippedVertical: content.isFlippedVertical,
                isMousePassThrough: pin.isMousePassThrough,
                pngData: pngData
            ))
        }
        
        DispatchQueue.global(qos: .utility).async {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            
            var metadatas: [PinItemMetadata] = []
            for s in snapshots {
                if let data = s.pngData {
                    let fileURL = dir.appendingPathComponent(s.fileName)
                    try? data.write(to: fileURL)
                }
                metadatas.append(PinItemMetadata(
                    fileName: s.fileName,
                    x: Double(s.frame.origin.x),
                    y: Double(s.frame.origin.y),
                    width: Double(s.frame.width),
                    height: Double(s.frame.height),
                    zoomScale: Double(s.zoomScale),
                    alphaValue: Double(s.alphaValue),
                    rotationAngle: Double(s.rotationAngle),
                    isFlippedHorizontal: s.isFlippedHorizontal,
                    isFlippedVertical: s.isFlippedVertical,
                    isMousePassThrough: s.isMousePassThrough
                ))
            }
            
            let jsonURL = dir.appendingPathComponent("session.json")
            if let data = try? JSONEncoder().encode(metadatas) {
                try? data.write(to: jsonURL)
            }
        }
    }
    
    public func restoreSavedPins() {
        let jsonURL = sessionDir.appendingPathComponent("session.json")
        guard FileManager.default.fileExists(atPath: jsonURL.path),
              let data = try? Data(contentsOf: jsonURL),
              let metadatas = try? JSONDecoder().decode([PinItemMetadata].self, from: data),
              !metadatas.isEmpty else {
            return
        }
        
        isRestoringPins = true
        defer {
            isRestoringPins = false
        }
        
        for meta in metadatas {
            let fileURL = sessionDir.appendingPathComponent(meta.fileName)
            guard FileManager.default.fileExists(atPath: fileURL.path),
                  let image = NSImage(contentsOf: fileURL) else { continue }
            
            let initialFrame = NSRect(x: meta.x, y: meta.y, width: meta.width, height: meta.height)
            let pin = PinWindow(image: image, initialFrame: initialFrame)
            pin.pinContentView.zoomScale = CGFloat(meta.zoomScale)
            pin.pinContentView.rotationAngle = CGFloat(meta.rotationAngle)
            pin.pinContentView.isFlippedHorizontal = meta.isFlippedHorizontal
            pin.pinContentView.isFlippedVertical = meta.isFlippedVertical
            pin.alphaValue = CGFloat(meta.alphaValue)
            pin.isMousePassThrough = meta.isMousePassThrough
            
            pinWindows.append(pin)
            pin.orderFrontRegardless()
            pin.makeKeyAndOrderFront(nil)
        }
        
        updatePassThroughMonitoring()
    }
}
