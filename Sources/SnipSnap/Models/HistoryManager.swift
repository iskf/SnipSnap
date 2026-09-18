import Cocoa
import Combine

public struct HistoryItem: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let width: Int
    public let height: Int
    public let imageFileName: String
    public let thumbnailFileName: String
    
    public init(id: UUID = UUID(), timestamp: Date = Date(), width: Int, height: Int, imageFileName: String, thumbnailFileName: String) {
        self.id = id
        self.timestamp = timestamp
        self.width = width
        self.height = height
        self.imageFileName = imageFileName
        self.thumbnailFileName = thumbnailFileName
    }
}

public class HistoryManager: ObservableObject {
    public static let shared = HistoryManager()
    
    public static let maxHistoryCount = 50
    
    @Published public private(set) var items: [HistoryItem] = []
    
    private let historyDir: URL
    private let imagesDir: URL
    private let thumbnailsDir: URL
    private let indexFileURL: URL
    private let ioQueue = DispatchQueue(label: "com.snipsnap.history.io", qos: .utility)
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.historyDir = appSupport.appendingPathComponent("SnipSnap/History")
        self.imagesDir = historyDir.appendingPathComponent("Images")
        self.thumbnailsDir = historyDir.appendingPathComponent("Thumbnails")
        self.indexFileURL = historyDir.appendingPathComponent("history.json")
        
        createDirectoriesIfNeeded()
        loadIndex()
    }
    
    private func createDirectoriesIfNeeded() {
        try? FileManager.default.createDirectory(at: historyDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
    }
    
    private func loadIndex() {
        guard FileManager.default.fileExists(atPath: indexFileURL.path),
              let data = try? Data(contentsOf: indexFileURL),
              let loaded = try? JSONDecoder().decode([HistoryItem].self, from: data) else {
            return
        }
        self.items = loaded
    }
    
    private func saveIndexSync() {
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: indexFileURL)
        }
    }
    
    // MARK: - Public API
    
    /// Records a captured screenshot into history
    public func recordCapture(_ image: NSImage) {
        let id = UUID()
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        let imageFileName = "\(id.uuidString).png"
        let thumbFileName = "\(id.uuidString)_thumb.jpg"
        
        let item = HistoryItem(
            id: id,
            timestamp: Date(),
            width: width,
            height: height,
            imageFileName: imageFileName,
            thumbnailFileName: thumbFileName
        )
        
        // Prepare image data for saving
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return }
        
        let fullPngData = rep.representation(using: .png, properties: [:])
        
        // Generate thumbnail (~320px max dimension)
        let thumbImage = createThumbnail(from: image, maxDimension: 320)
        let thumbData = thumbImage?.tiffRepresentation.flatMap {
            NSBitmapImageRep(data: $0)?.representation(using: .jpeg, properties: [.compressionFactor: 0.85])
        }
        
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            
            let fullURL = self.imagesDir.appendingPathComponent(imageFileName)
            let thumbURL = self.thumbnailsDir.appendingPathComponent(thumbFileName)
            
            if let fullPngData = fullPngData {
                try? fullPngData.write(to: fullURL)
            }
            if let thumbData = thumbData {
                try? thumbData.write(to: thumbURL)
            }
            
            DispatchQueue.main.async {
                self.items.insert(item, at: 0)
                self.trimHistoryIfNeeded()
                self.ioQueue.async {
                    self.saveIndexSync()
                }
            }
        }
    }
    
    private func trimHistoryIfNeeded() {
        while items.count > Self.maxHistoryCount {
            let removed = items.removeLast()
            deleteFiles(for: removed)
        }
    }
    
    private func deleteFiles(for item: HistoryItem) {
        let fullURL = imagesDir.appendingPathComponent(item.imageFileName)
        let thumbURL = thumbnailsDir.appendingPathComponent(item.thumbnailFileName)
        try? FileManager.default.removeItem(at: fullURL)
        try? FileManager.default.removeItem(at: thumbURL)
    }
    
    public func deleteItem(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: index)
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            self.deleteFiles(for: removed)
            self.saveIndexSync()
        }
    }
    
    public func clearAll() {
        let oldItems = items
        items.removeAll()
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            for item in oldItems {
                self.deleteFiles(for: item)
            }
            self.saveIndexSync()
        }
    }
    
    public func getImage(for item: HistoryItem) -> NSImage? {
        let fullURL = imagesDir.appendingPathComponent(item.imageFileName)
        return NSImage(contentsOf: fullURL)
    }
    
    public func getThumbnail(for item: HistoryItem) -> NSImage? {
        let thumbURL = thumbnailsDir.appendingPathComponent(item.thumbnailFileName)
        if FileManager.default.fileExists(atPath: thumbURL.path) {
            return NSImage(contentsOf: thumbURL)
        }
        return getImage(for: item)
    }
    
    private func createThumbnail(from image: NSImage, maxDimension: CGFloat) -> NSImage? {
        let originalSize = image.size
        guard originalSize.width > 0 && originalSize.height > 0 else { return nil }
        
        let ratio = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
        let newSize = (ratio < 1.0) ? CGSize(width: originalSize.width * ratio, height: originalSize.height * ratio) : originalSize
        
        let thumb = NSImage(size: newSize)
        thumb.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize), from: NSRect(origin: .zero, size: originalSize), operation: .copy, fraction: 1.0)
        thumb.unlockFocus()
        return thumb
    }
}
