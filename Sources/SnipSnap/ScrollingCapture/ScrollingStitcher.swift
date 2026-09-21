import Cocoa
import CoreGraphics
import Accelerate

/// Current scrolling movement direction
public enum ScrollDirection: Sendable {
    case down
    case up
    case idle
}

/// Result of stitching a new frame into the continuous canvas.
public enum StitchResult {
    case appended(shiftY: Int, totalHeight: Int, direction: ScrollDirection)
    case navigating(currentViewportY: CGFloat, totalHeight: Int, direction: ScrollDirection)
    case skippedIdentical
    case failed(reason: String)
}

/// High-performance computer-vision engine for stitching vertical scrolling frames.
/// Features:
/// 1. Bidirectional canvas expansion (up and down) with seamless watermark tracking.
/// 2. 1D Vertical displacement matching via row-signature cross correlation.
/// 3. Sticky header detection to prevent duplicate navigation bars.
/// 4. Zero duplicate slices when user navigates back and forth over captured territory.
public final class ScrollingStitcher: @unchecked Sendable {
    private let lock = NSLock()
    
    // Canvas state in continuous relative coordinates
    private var baseWidth: Int = 0
    private var minCanvasY: CGFloat = 0 // Topmost watermark (<= 0)
    private var maxCanvasY: CGFloat = 0 // Bottommost watermark (>= initialHeight)
    private var currentViewportY: CGFloat = 0 // Top of current viewport in canvas space
    private var viewportHeight: CGFloat = 0
    
    private var previousFrame: CGImage?
    private var previousRowSignatures: [UInt32] = []
    
    // Slices for high-fidelity rendering without reallocating giant bitmaps on every frame
    public struct ImageSlice {
        public let image: CGImage // Pre-cropped slice image (drastically reduces RAM usage)
        public let canvasY: CGFloat // position in continuous canvas space
        public let height: CGFloat
        public let width: CGFloat
    }
    private var slices: [ImageSlice] = []
    
    // Sticky header detection
    private var detectedStickyHeaderHeight: Int = 0
    
    // Thumbnail cache
    private var cachedThumbnail: NSImage?
    private var frameCount: Int = 0
    private var consecutiveMatchFailures: Int = 0
    
    /// Max height per individual image segment before adaptive splitting (e.g. 16,000px)
    public static let maxSegmentHeight: Int = 16000
    
    public init() {}
    
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        baseWidth = 0
        minCanvasY = 0
        maxCanvasY = 0
        currentViewportY = 0
        viewportHeight = 0
        previousFrame = CGImage?.none
        previousRowSignatures = []
        slices = []
        detectedStickyHeaderHeight = 0
        cachedThumbnail = nil
        frameCount = 0
        consecutiveMatchFailures = 0
    }
    
    // MARK: - Frame Processing
    
    /// Adds a newly captured frame to the stitched canvas (supports bidirectional expansion).
    public func processFrame(_ frame: CGImage) -> StitchResult {
        lock.lock()
        defer { lock.unlock() }
        
        let width = frame.width
        let height = frame.height
        guard width > 20, height > 20 else {
            return .failed(reason: "帧尺寸过小")
        }
        
        // First frame: initialize canvas
        if previousFrame == nil {
            baseWidth = width
            minCanvasY = 0
            maxCanvasY = CGFloat(height)
            currentViewportY = 0
            viewportHeight = CGFloat(height)
            previousFrame = frame
            previousRowSignatures = computeRowSignatures(for: frame)
            
            slices.append(ImageSlice(
                image: frame,
                canvasY: 0,
                height: CGFloat(height),
                width: CGFloat(width)
            ))
            frameCount = 1
            cachedThumbnail = nil
            consecutiveMatchFailures = 0
            return .appended(shiftY: height, totalHeight: height, direction: .down)
        }
        
        guard let prev = previousFrame else {
            return .failed(reason: "缺少前序帧")
        }
        
        let currentRowSignatures = computeRowSignatures(for: frame)
        
        // 1. Check if frame is identical to previous frame (user paused scrolling)
        if isIdentical(signaturesA: previousRowSignatures, signaturesB: currentRowSignatures) {
            return .skippedIdentical
        }
        
        // 2. Detect sticky header (rows at the top that remained unchanged while lower rows moved)
        let stickyTop = detectStickyHeader(prev: prev, current: frame)
        if stickyTop > detectedStickyHeaderHeight {
            detectedStickyHeaderHeight = stickyTop
        }
        
        // 3. Find vertical displacement (supports both downward and upward shifts)
        let minShift = 2
        let maxShift = max(minShift + 1, Int(Double(height) * 0.94))
        
        guard let match = findBestShift(
            prevSignatures: previousRowSignatures,
            currSignatures: currentRowSignatures,
            stickyHeader: detectedStickyHeaderHeight,
            minShift: minShift,
            maxShift: maxShift,
            totalHeight: height
        ) else {
            // Self-healing / Auto-recovery:
            // If matching fails twice in a row (e.g. fast swipe or low-feature gradient),
            // advance previousFrame to current frame so future frames can match against it.
            consecutiveMatchFailures += 1
            if consecutiveMatchFailures >= 2 {
                previousFrame = frame
                previousRowSignatures = currentRowSignatures
                consecutiveMatchFailures = 0
            }
            return .failed(reason: "未能可靠匹配滚屏位移")
        }
        
        consecutiveMatchFailures = 0
        let rawShiftY = match.shiftY
        guard rawShiftY != 0 else {
            return .skippedIdentical
        }
        
        // Pixel-level refinement: verify and correct the shift within ±2px
        let shiftY = refineShiftWithPixels(prev: prev, current: frame, candidateShift: rawShiftY)
        
        let totalH = Int(maxCanvasY - minCanvasY)
        
        // 4. Handle Downward Scroll (shiftY > 0, content moves up)
        if shiftY > 0 {
            currentViewportY += CGFloat(shiftY)
            let viewportBottom = currentViewportY + viewportHeight
            
            if viewportBottom > maxCanvasY {
                // Break through bottom watermark: append new slice
                let newContentHeight = viewportBottom - maxCanvasY
                let cropY = CGFloat(height) - newContentHeight
                let cropRect = CGRect(x: 0, y: cropY, width: CGFloat(width), height: newContentHeight)
                
                if let cropped = frame.cropping(to: cropRect) {
                    let slice = ImageSlice(
                        image: cropped,
                        canvasY: maxCanvasY,
                        height: newContentHeight,
                        width: CGFloat(width)
                    )
                    slices.append(slice)
                    maxCanvasY = viewportBottom
                    frameCount += 1
                    cachedThumbnail = nil
                }
                previousFrame = frame
                previousRowSignatures = currentRowSignatures
                let updatedTotal = Int(maxCanvasY - minCanvasY)
                return .appended(shiftY: Int(newContentHeight), totalHeight: updatedTotal, direction: .down)
            } else {
                // Navigating within already-captured range! No duplicate slice created
                previousFrame = frame
                previousRowSignatures = currentRowSignatures
                return .navigating(currentViewportY: currentViewportY, totalHeight: totalH, direction: .down)
            }
        }
        
        // 5. Handle Upward Scroll (shiftY < 0, content moves down)
        if shiftY < 0 {
            let upShift = CGFloat(-shiftY)
            currentViewportY -= upShift
            
            if currentViewportY < minCanvasY {
                // Break through top watermark: prepend new slice
                let newContentHeight = minCanvasY - currentViewportY
                let cropY: CGFloat = 0
                let cropRect = CGRect(x: 0, y: cropY, width: CGFloat(width), height: newContentHeight)
                
                if let cropped = frame.cropping(to: cropRect) {
                    let slice = ImageSlice(
                        image: cropped,
                        canvasY: currentViewportY,
                        height: newContentHeight,
                        width: CGFloat(width)
                    )
                    slices.append(slice)
                    minCanvasY = currentViewportY
                    frameCount += 1
                    cachedThumbnail = nil
                }
                previousFrame = frame
                previousRowSignatures = currentRowSignatures
                let updatedTotal = Int(maxCanvasY - minCanvasY)
                return .appended(shiftY: Int(newContentHeight), totalHeight: updatedTotal, direction: .up)
            } else {
                // Navigating within already-captured range! No duplicate slice created
                previousFrame = frame
                previousRowSignatures = currentRowSignatures
                return .navigating(currentViewportY: currentViewportY, totalHeight: totalH, direction: .up)
            }
        }
        
        return .skippedIdentical
    }
    
    // MARK: - Row Signatures & Bidirectional Matching
    
    /// Computes a 32-bit hash/signature for each row using sampled pixels across the row.
    private func computeRowSignatures(for image: CGImage) -> [UInt32] {
        let width = image.width
        let height = image.height
        
        let startX = Int(Double(width) * 0.1)
        let endX = Int(Double(width) * 0.9)
        let stepX = max(1, (endX - startX) / 16)
        var sampleCols: [Int] = []
        for x in stride(from: startX, to: endX, by: stepX) {
            sampleCols.append(x)
        }
        
        guard let data = image.dataProvider?.data,
              let ptr = CFDataGetBytePtr(data) else {
            return Array(repeating: 0, count: height)
        }
        
        let bytesPerRow = image.bytesPerRow
        let bytesPerPixel = max(4, image.bitsPerPixel / 8)
        
        var signatures = [UInt32](repeating: 0, count: height)
        for y in 0..<height {
            var hash: UInt32 = 2166136261
            let rowOffset = y * bytesPerRow
            for col in sampleCols {
                let pixelOffset = rowOffset + col * bytesPerPixel
                let r = UInt32(ptr[pixelOffset])
                let g = UInt32(ptr[pixelOffset + 1])
                let b = UInt32(ptr[pixelOffset + 2])
                let val = (r << 16) | (g << 8) | b
                hash = (hash ^ val) &* 16777619
            }
            signatures[y] = hash
        }
        return signatures
    }
    
    private func isIdentical(signaturesA: [UInt32], signaturesB: [UInt32]) -> Bool {
        guard signaturesA.count == signaturesB.count else { return false }
        var diffCount = 0
        let total = signaturesA.count
        for i in 0..<total {
            if signaturesA[i] != signaturesB[i] {
                diffCount += 1
                if diffCount > 5 { return false }
            }
        }
        return true
    }
    
    /// Searches for optimal shift Y in both downward (>0) and upward (<0) directions.
    /// Uses separate candidates per direction to prevent cross-contamination during direction changes.
    private func findBestShift(
        prevSignatures: [UInt32],
        currSignatures: [UInt32],
        stickyHeader: Int,
        minShift: Int,
        maxShift: Int,
        totalHeight: Int
    ) -> (shiftY: Int, confidence: Double)? {
        let effectiveHeight = min(prevSignatures.count, currSignatures.count, totalHeight)
        guard minShift <= maxShift else { return nil }
        let startRow = max(0, stickyHeader)
        let endRow = effectiveHeight
        guard startRow < endRow else { return nil }
        
        // Separate best candidates for each direction to prevent cross-contamination
        var bestDownShift = 0
        var bestDownRatio = 0.0
        var bestDownMatches = 0
        
        var bestUpShift = 0
        var bestUpRatio = 0.0
        var bestUpMatches = 0
        
        let minCheckedRows = 20
        
        // 1. Test Downward Shifts (shiftY > 0, page moved up)
        for shift in minShift...maxShift {
            let maxOverlap = effectiveHeight - shift
            guard startRow < maxOverlap else { continue }
            
            var matchCount = 0
            var checkedCount = 0
            
            for y in startRow..<maxOverlap {
                let prevY = y + shift
                if prevY < effectiveHeight {
                    checkedCount += 1
                    if prevSignatures[prevY] == currSignatures[y] {
                        matchCount += 1
                    }
                }
            }
            
            if checkedCount > minCheckedRows {
                let ratio = Double(matchCount) / Double(checkedCount)
                if ratio > 0.85 && ratio > bestDownRatio {
                    bestDownRatio = ratio
                    bestDownShift = shift
                    bestDownMatches = matchCount
                } else if ratio == bestDownRatio && matchCount > bestDownMatches {
                    bestDownShift = shift
                    bestDownMatches = matchCount
                }
            }
        }
        
        // 2. Test Upward Shifts (shiftY < 0, page moved down)
        for shift in minShift...maxShift {
            let maxOverlap = effectiveHeight - shift
            guard startRow < maxOverlap else { continue }
            
            var matchCount = 0
            var checkedCount = 0
            
            for y in startRow..<maxOverlap {
                let currY = y + shift
                if currY < effectiveHeight {
                    checkedCount += 1
                    if prevSignatures[y] == currSignatures[currY] {
                        matchCount += 1
                    }
                }
            }
            
            if checkedCount > minCheckedRows {
                let ratio = Double(matchCount) / Double(checkedCount)
                if ratio > 0.85 && ratio > bestUpRatio {
                    bestUpRatio = ratio
                    bestUpShift = -shift
                    bestUpMatches = matchCount
                } else if ratio == bestUpRatio && matchCount > bestUpMatches {
                    bestUpShift = -shift
                    bestUpMatches = matchCount
                }
            }
        }
        
        // 3. Choose the better direction based on ratio (not raw matchCount)
        var bestShift = 0
        var bestRatio = 0.0
        
        if bestDownRatio > bestUpRatio {
            bestShift = bestDownShift
            bestRatio = bestDownRatio
        } else if bestUpRatio > bestDownRatio {
            bestShift = bestUpShift
            bestRatio = bestUpRatio
        } else if bestDownRatio > 0 {
            // Equal ratio: prefer the direction with more matches
            if bestDownMatches >= bestUpMatches {
                bestShift = bestDownShift
                bestRatio = bestDownRatio
            } else {
                bestShift = bestUpShift
                bestRatio = bestUpRatio
            }
        }
        
        if bestShift != 0 {
            return (shiftY: bestShift, confidence: bestRatio)
        }
        return nil
    }
    
    /// Pixel-level verification: refines the shift by comparing actual pixel data across the full overlap region.
    /// Tests the candidate shift ±2px and returns the one with the lowest pixel error.
    /// Only overrides the candidate when a neighbor has significantly less error (>30% improvement).
    private func refineShiftWithPixels(prev: CGImage, current: CGImage, candidateShift: Int) -> Int {
        guard let dataPrev = prev.dataProvider?.data,
              let dataCurr = current.dataProvider?.data,
              let ptrPrev = CFDataGetBytePtr(dataPrev),
              let ptrCurr = CFDataGetBytePtr(dataCurr) else {
            return candidateShift
        }
        
        let width = min(prev.width, current.width)
        let height = min(prev.height, current.height)
        let bprPrev = prev.bytesPerRow
        let bprCurr = current.bytesPerRow
        let bpp = max(4, prev.bitsPerPixel / 8)
        let absShift = abs(candidateShift)
        
        // Sample columns for pixel comparison (uniformly across the content area)
        let sampleStep = max(1, width / 32)
        var sampleCols: [Int] = []
        for x in stride(from: width / 10, to: width * 9 / 10, by: sampleStep) {
            sampleCols.append(x)
        }
        guard !sampleCols.isEmpty else { return candidateShift }
        
        // Test candidate ±2 and compute total pixel error across the FULL overlap region
        let searchLo = max(absShift - 2, 1)
        let searchHi = min(absShift + 2, height - 2)
        guard searchLo <= searchHi else { return candidateShift }
        
        var candidateError: Int = -1
        var bestRefineShift = candidateShift
        var bestError: Int = Int.max
        
        for testAbs in searchLo...searchHi {
            var totalError = 0
            let overlapRows = height - testAbs
            guard overlapRows > 10 else { continue }
            
            // Sample every 4th row for speed while covering the full overlap
            let rowStep = max(1, overlapRows / 60)
            
            if candidateShift > 0 {
                // Downward: prev row (y + shift) should match curr row y
                for y in stride(from: 0, to: overlapRows, by: rowStep) {
                    let prevY = y + testAbs
                    guard prevY < height else { continue }
                    let rowOffPrev = prevY * bprPrev
                    let rowOffCurr = y * bprCurr
                    for col in sampleCols {
                        let pOff = col * bpp
                        totalError += abs(Int(ptrPrev[rowOffPrev + pOff]) - Int(ptrCurr[rowOffCurr + pOff]))
                        totalError += abs(Int(ptrPrev[rowOffPrev + pOff + 1]) - Int(ptrCurr[rowOffCurr + pOff + 1]))
                        totalError += abs(Int(ptrPrev[rowOffPrev + pOff + 2]) - Int(ptrCurr[rowOffCurr + pOff + 2]))
                    }
                }
            } else {
                // Upward: prev row y should match curr row (y + shift)
                for y in stride(from: 0, to: overlapRows, by: rowStep) {
                    let currY = y + testAbs
                    guard currY < height else { continue }
                    let rowOffPrev = y * bprPrev
                    let rowOffCurr = currY * bprCurr
                    for col in sampleCols {
                        let pOff = col * bpp
                        totalError += abs(Int(ptrPrev[rowOffPrev + pOff]) - Int(ptrCurr[rowOffCurr + pOff]))
                        totalError += abs(Int(ptrPrev[rowOffPrev + pOff + 1]) - Int(ptrCurr[rowOffCurr + pOff + 1]))
                        totalError += abs(Int(ptrPrev[rowOffPrev + pOff + 2]) - Int(ptrCurr[rowOffCurr + pOff + 2]))
                    }
                }
            }
            
            // Track candidate's own error
            if testAbs == absShift {
                candidateError = totalError
            }
            
            if totalError < bestError {
                bestError = totalError
                bestRefineShift = candidateShift > 0 ? testAbs : -testAbs
            }
        }
        
        // Only override if the best alternative is >30% better than the candidate
        if candidateError >= 0 && bestRefineShift != candidateShift {
            let improvement = Double(candidateError - bestError) / Double(max(1, candidateError))
            if improvement < 0.30 {
                return candidateShift // Not enough improvement, keep original
            }
        }
        
        return bestRefineShift
    }
    
    /// Detects fixed/sticky header elements by checking top rows that did not change between frames
    /// AND have non-uniform pixel variance (excluding solid white/blank background rows).
    private func detectStickyHeader(prev: CGImage, current: CGImage) -> Int {
        guard let dataPrev = prev.dataProvider?.data,
              let dataCurr = current.dataProvider?.data,
              let ptrPrev = CFDataGetBytePtr(dataPrev),
              let ptrCurr = CFDataGetBytePtr(dataCurr) else {
            return 0
        }
        
        let height = min(prev.height, current.height)
        let width = min(prev.width, current.width)
        let maxSearchHeight = min(height / 3, 160) // Check up to top 160px
        let bytesPerRow = min(prev.bytesPerRow, current.bytesPerRow)
        let bytesPerPixel = max(4, prev.bitsPerPixel / 8)
        
        var stickyRows = 0
        let sampleCols = [width / 8, width / 4, width / 2, width * 3 / 4, width * 7 / 8]
        
        for y in 0..<maxSearchHeight {
            var rowMatches = true
            let offset = y * bytesPerRow
            
            // Check if this row has actual feature variance across columns (not just flat background)
            var hasVariance = false
            let pOffset0 = offset + sampleCols[0] * bytesPerPixel
            let r0 = ptrPrev[pOffset0], g0 = ptrPrev[pOffset0 + 1], b0 = ptrPrev[pOffset0 + 2]
            
            for col in sampleCols {
                let pOffset = offset + col * bytesPerPixel
                let r1 = ptrPrev[pOffset], g1 = ptrPrev[pOffset + 1], b1 = ptrPrev[pOffset + 2]
                let r2 = ptrCurr[pOffset], g2 = ptrCurr[pOffset + 1], b2 = ptrCurr[pOffset + 2]
                if abs(Int(r1) - Int(r2)) > 5 || abs(Int(g1) - Int(g2)) > 5 || abs(Int(b1) - Int(b2)) > 5 {
                    rowMatches = false
                    break
                }
                if abs(Int(r1) - Int(r0)) > 15 || abs(Int(g1) - Int(g0)) > 15 || abs(Int(b1) - Int(b0)) > 15 {
                    hasVariance = true
                }
            }
            if rowMatches && hasVariance {
                stickyRows = y + 1
            } else if !rowMatches {
                break
            }
        }
        return stickyRows > 15 ? stickyRows : 0
    }
    
    // MARK: - Output Generation & Viewport Tracking
    
    public var currentTotalHeight: Int {
        lock.lock()
        defer { lock.unlock() }
        return Int(maxCanvasY - minCanvasY)
    }
    
    public var capturedFrameCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return frameCount
    }
    
    /// Normalized progress [0.0 ... 1.0] of current viewport position in full canvas
    public var viewportProgress: Double {
        lock.lock()
        defer { lock.unlock() }
        let total = maxCanvasY - minCanvasY
        guard total > 0 else { return 0.0 }
        return max(0.0, min(1.0, Double(currentViewportY - minCanvasY) / Double(total)))
    }
    
    /// Ratio [0.0 ... 1.0] of viewport height relative to total stitched height
    public var viewportRatio: Double {
        lock.lock()
        defer { lock.unlock() }
        let total = maxCanvasY - minCanvasY
        guard total > 0 else { return 1.0 }
        return max(0.05, min(1.0, Double(viewportHeight) / Double(total)))
    }
    
    /// Generates a scaled live thumbnail of the current stitched canvas for the mini-map HUD.
    public func generateThumbnail(targetWidth: CGFloat = 160) -> NSImage? {
        lock.lock()
        defer { lock.unlock() }
        
        let totalH = maxCanvasY - minCanvasY
        guard baseWidth > 0, totalH > 0, !slices.isEmpty else { return nil }
        
        let scale = targetWidth / CGFloat(baseWidth)
        let targetHeight = totalH * scale
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(targetWidth),
            height: Int(targetHeight),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        ctx.interpolationQuality = .medium
        
        // In CoreGraphics, (0,0) is bottom-left. Canvas Y is from top.
        // Slices are sorted top to bottom
        for slice in slices {
            let normY = slice.canvasY - minCanvasY
            let destX: CGFloat = 0
            let destY = targetHeight - (normY + slice.height) * scale
            let destW = targetWidth
            let destH = slice.height * scale
            
            ctx.draw(slice.image, in: CGRect(x: destX, y: destY, width: destW, height: destH))
        }
        
        guard let cgThumb = ctx.makeImage() else { return nil }
        return NSImage(cgImage: cgThumb, size: NSSize(width: targetWidth, height: targetHeight))
    }
    
    /// Generates final stitched images, automatically segmenting into multiple images
    /// if total height exceeds maxSegmentHeight (e.g. 16,000px).
    public func renderFinalImages() -> [NSImage] {
        lock.lock()
        defer { lock.unlock() }
        
        let totalH = Int(maxCanvasY - minCanvasY)
        guard baseWidth > 0, totalH > 0, !slices.isEmpty else { return [] }
        
        // Sort slices from top to bottom
        let sortedSlices = slices.sorted(by: { $0.canvasY < $1.canvasY })
        
        let maxHeight = ScrollingStitcher.maxSegmentHeight
        if totalH <= maxHeight {
            if let single = renderSegment(slices: sortedSlices, startY: 0, height: totalH) {
                return [single]
            }
            return []
        }
        
        // Multi-segment partition
        var segments: [NSImage] = []
        var currentSegmentSlices: [ImageSlice] = []
        var segStartY: CGFloat = 0
        var segEndY: CGFloat = 0
        
        for slice in sortedSlices {
            let normTop = slice.canvasY - minCanvasY
            let normBottom = normTop + slice.height
            
            if (normBottom - segStartY) > CGFloat(maxHeight) && !currentSegmentSlices.isEmpty {
                let segHeight = Int(segEndY - segStartY)
                if let img = renderSegment(slices: currentSegmentSlices, startY: segStartY, height: segHeight) {
                    segments.append(img)
                }
                currentSegmentSlices = []
                segStartY = normTop
            }
            currentSegmentSlices.append(slice)
            segEndY = normBottom
        }
        
        if !currentSegmentSlices.isEmpty {
            let segHeight = Int(segEndY - segStartY)
            if let img = renderSegment(slices: currentSegmentSlices, startY: segStartY, height: segHeight) {
                segments.append(img)
            }
        }
        
        return segments
    }
    
    /// Helper to render a specific slice range into an NSImage
    private func renderSegment(slices: [ImageSlice], startY: CGFloat, height: Int) -> NSImage? {
        guard height > 0, baseWidth > 0 else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: baseWidth,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        
        ctx.interpolationQuality = .high
        
        for slice in slices {
            let normY = slice.canvasY - minCanvasY
            let destX: CGFloat = 0
            let destY = CGFloat(height) - (normY - startY + slice.height)
            let destW = CGFloat(baseWidth)
            let destH = slice.height
            
            ctx.draw(slice.image, in: CGRect(x: destX, y: destY, width: destW, height: destH))
        }
        
        guard let finalCG = ctx.makeImage() else { return nil }
        return NSImage(cgImage: finalCG, size: NSSize(width: baseWidth, height: height))
    }
    
    /// Generates the full-resolution stitched image (compatible with single-image callers).
    public func renderFinalImage() -> NSImage? {
        return renderFinalImages().first
    }
}
