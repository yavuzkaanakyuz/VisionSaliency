//
//  SaliencyDetector.swift
//  VisionSaliency
//
//  Created by Yavuz Kaan Akyüz on 8/10/25.
//

import SwiftUI
import Vision
import UIKit
import Photos

@MainActor
class SaliencyDetector: ObservableObject {
    @Published var originalImage: UIImage?
    @Published var saliencyImage: UIImage?
    @Published var combinedImage: UIImage?
    @Published var apiReadyImage: UIImage?
    @Published var isProcessing = false
    @Published var analysisResults: [String] = []
    
    func processImage(_ image: UIImage) async {
        isProcessing = true
        originalImage = image
        saliencyImage = nil
        combinedImage = nil
        apiReadyImage = nil
        analysisResults = []
        
        guard let cgImage = image.cgImage else {
            isProcessing = false
            return
        }
        
        // Create saliency request
        let request = VNGenerateAttentionBasedSaliencyImageRequest()
        
        do {
            // Execute Vision request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try await handler.perform([request])
            
            // Process results
            if let results = request.results?.first {
                await processSaliencyResults(results, originalCGImage: cgImage)
            }
        } catch {
            print("Saliency detection error: \(error)")
            analysisResults.append("Error: \(error.localizedDescription)")
        }
        
        isProcessing = false
    }
    
    private func processSaliencyResults(_ observation: VNSaliencyImageObservation, originalCGImage: CGImage) async {
        // Create saliency image
        let saliencyPixelBuffer = observation.pixelBuffer
        saliencyImage = await createUIImage(from: saliencyPixelBuffer)
        
        // Create combined image
        combinedImage = await createCombinedImage(
            original: originalCGImage,
            saliency: saliencyPixelBuffer
        )
        
        // Add analysis results
        analysisResults.append("✓ Attention areas detected")
        analysisResults.append("📊 Saliency confidence: \(String(format: "%.2f", observation.confidence))")
        
        // Pick the best salient rectangle (prefer larger+confident)
        let topBox = observation.salientObjects?
            .max(by: { (a, b) -> Bool in
                let areaA = (a.boundingBox.width * a.boundingBox.height) * CGFloat(a.confidence)
                let areaB = (b.boundingBox.width * b.boundingBox.height) * CGFloat(b.confidence)
                return areaA < areaB
            })?.boundingBox
        if let topBox = topBox {
            analysisResults.append("📍 Main area (Vision box)")
        }

        // Produce API-optimized image
        let centroidPx = computeSaliencyCentroid(saliencyPixelBuffer: saliencyPixelBuffer)
        let roiFromBoxes = bestRectFromSalientObjects(
            salientObjects: observation.salientObjects ?? [],
            centroidPx: centroidPx,
            imageSize: CGSize(width: originalCGImage.width, height: originalCGImage.height)
        )
        let roiFromMap = tightBoundingRectFromSaliency(
            saliencyPixelBuffer: saliencyPixelBuffer,
            imageWidth: CGFloat(originalCGImage.width),
            imageHeight: CGFloat(originalCGImage.height),
            topPercent: 0.05
        )

        if let optimized = finalizeAPIImage(from: originalCGImage, roiRect: roiFromBoxes ?? roiFromMap) {
            apiReadyImage = optimized
            let w = Int(optimized.size.width)
            let h = Int(optimized.size.height)
            analysisResults.append("🗜️ API image: \(w)x\(h) px (cropped + resized)")
        }
        
        // Add processing time info
        analysisResults.append("⏱️ Processing completed successfully")
    }

    // MARK: - API image generation

    private func finalizeAPIImage(from original: CGImage, roiRect: CGRect?) -> UIImage? {
        let imageWidth = CGFloat(original.width)
        let imageHeight = CGFloat(original.height)
        guard var rect = roiRect, rect.width > 0, rect.height > 0 else { return nil }

        // Dynamic padding: kutu kenara yakınsa çok az; değilse biraz bağlam.
        let borderMin = min(rect.minX, rect.minY, imageWidth - rect.maxX, imageHeight - rect.maxY)
        let closeness = max(0, min(1, borderMin / max(imageWidth, imageHeight))) // 0 -> çok yakın, 1 -> ortada
        let paddingRatio = 0.02 + 0.08 * closeness
        let padding = max(rect.width, rect.height) * paddingRatio
        rect = rect.insetBy(dx: -padding, dy: -padding)
        rect = rect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))

        // CGImage space flip on Y
        let cropRect = CGRect(
            x: rect.origin.x,
            y: imageHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )

        guard let croppedCG = original.cropping(to: cropRect) else { return nil }

        // Dynamic hedef çözünürlük: nesne alanına göre. Küçük ROI -> 512, orta -> 640, büyük -> 768.
        let croppedSize = CGSize(width: croppedCG.width, height: croppedCG.height)
        let roiArea = rect.width * rect.height
        let imgArea = imageWidth * imageHeight
        let areaRatio = roiArea / imgArea
        let targetLongSide: CGFloat = areaRatio < 0.15 ? 512 : (areaRatio < 0.35 ? 640 : 768)
        let longSide = max(croppedSize.width, croppedSize.height)
        let scale: CGFloat = longSide > targetLongSide ? (targetLongSide / longSide) : 1.0
        let targetSize = CGSize(width: floor(croppedSize.width * scale), height: floor(croppedSize.height * scale))

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let image = renderer.image { _ in
            UIImage(cgImage: croppedCG).draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return image
    }

    // Compute intensity-weighted centroid (image pixel coords)
    private func computeSaliencyCentroid(saliencyPixelBuffer: CVPixelBuffer) -> CGPoint? {
        CVPixelBufferLockBaseAddress(saliencyPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(saliencyPixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(saliencyPixelBuffer) else { return nil }
        let w = CVPixelBufferGetWidth(saliencyPixelBuffer)
        let h = CVPixelBufferGetHeight(saliencyPixelBuffer)
        let bpr = CVPixelBufferGetBytesPerRow(saliencyPixelBuffer)
        let fmt = CVPixelBufferGetPixelFormatType(saliencyPixelBuffer)

        var sum: Double = 0
        var sumX: Double = 0
        var sumY: Double = 0

        if fmt == kCVPixelFormatType_OneComponent8 {
            for y in 0..<h {
                let row = base.advanced(by: y * bpr).assumingMemoryBound(to: UInt8.self)
                for x in 0..<w {
                    let v = Double(row[x])
                    sum += v
                    sumX += v * Double(x)
                    sumY += v * Double(y)
                }
            }
        } else if fmt == kCVPixelFormatType_OneComponent32Float {
            for y in 0..<h {
                let row = base.advanced(by: y * bpr).assumingMemoryBound(to: Float32.self)
                for x in 0..<w {
                    let v = Double(max(0, min(1, row[x]))) * 255.0
                    sum += v
                    sumX += v * Double(x)
                    sumY += v * Double(y)
                }
            }
        } else {
            return nil
        }
        guard sum > 0 else { return nil }
        return CGPoint(x: sumX / sum, y: sumY / sum)
    }

    // Choose the salient rectangle whose center is closest to the centroid
    private func bestRectFromSalientObjects(
        salientObjects: [VNRectangleObservation],
        centroidPx: CGPoint?,
        imageSize: CGSize
    ) -> CGRect? {
        guard !salientObjects.isEmpty else { return nil }
        if let centroidPx = centroidPx {
            let cx = centroidPx.x / imageSize.width
            let cy = centroidPx.y / imageSize.height
            let best = salientObjects.min { a, b in
                let ca = CGPoint(x: a.boundingBox.midX, y: a.boundingBox.midY)
                let cb = CGPoint(x: b.boundingBox.midX, y: b.boundingBox.midY)
                let da = (ca.x - cx)*(ca.x - cx) + (ca.y - cy)*(ca.y - cy)
                let db = (cb.x - cx)*(cb.x - cx) + (cb.y - cy)*(cb.y - cy)
                if da == db { return a.confidence > b.confidence } // tie-breaker: higher confidence first
                return da < db
            }
            if let bb = best?.boundingBox {
                return CGRect(x: bb.origin.x * imageSize.width,
                              y: bb.origin.y * imageSize.height,
                              width: bb.size.width * imageSize.width,
                              height: bb.size.height * imageSize.height)
            }
        }
        // Fallback: highest confidence
        if let bb = salientObjects.max(by: { $0.confidence < $1.confidence })?.boundingBox {
            return CGRect(x: bb.origin.x * imageSize.width,
                          y: bb.origin.y * imageSize.height,
                          width: bb.size.width * imageSize.width,
                          height: bb.size.height * imageSize.height)
        }
        return nil
    }

    private func tightBoundingRectFromSaliency(
        saliencyPixelBuffer: CVPixelBuffer,
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        topPercent: CGFloat
    ) -> CGRect? {
        CVPixelBufferLockBaseAddress(saliencyPixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(saliencyPixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddress(saliencyPixelBuffer) else { return nil }
        let width = CVPixelBufferGetWidth(saliencyPixelBuffer)
        let height = CVPixelBufferGetHeight(saliencyPixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(saliencyPixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(saliencyPixelBuffer)

        // 1) En yüksek topPercent oranındaki pikseller için eşik bul (8-bit veya 32F destek)
        var histogram = [Int](repeating: 0, count: 256)
        if pixelFormat == kCVPixelFormatType_OneComponent8 {
            for y in 0..<height {
                let rowPtr = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
                for x in 0..<width { histogram[Int(rowPtr[x])] += 1 }
            }
        } else if pixelFormat == kCVPixelFormatType_OneComponent32Float {
            for y in 0..<height {
                let rowPtr = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
                // bytesPerRow is in bytes; for Float32 elements per row = bytesPerRow/4
                let elementsPerRow = bytesPerRow / 4
                for x in 0..<width {
                    let v = max(0, min(1, rowPtr[x]))
                    let bin = min(255, Int(v * 255))
                    histogram[bin] += 1
                }
                _ = elementsPerRow // avoid warning
            }
        } else {
            // Unknown format; fallback to full image to avoid crash
            return CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight)
        }
        let total = histogram.reduce(0, +)
        let kept = Int(max(0.0, min(1.0, Double(topPercent))) * Double(total))
        var running = 0
        var thresholdByte: Int = 230
        for i in (0..<256).reversed() { // yüksekten düşüğe
            running += histogram[i]
            if running >= kept { thresholdByte = i; break }
        }

        // Top piksellerin eksen dağılımları ile kuantil kırpma (10%..90%)
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        var countX = [Int](repeating: 0, count: width)
        var countY = [Int](repeating: 0, count: height)

        if pixelFormat == kCVPixelFormatType_OneComponent8 {
            for y in 0..<height {
                let rowPtr = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
                for x in 0..<width {
                    if Int(rowPtr[x]) >= thresholdByte {
                        countX[x] += 1
                        countY[y] += 1
                        if x < minX { minX = x }
                        if y < minY { minY = y }
                        if x > maxX { maxX = x }
                        if y > maxY { maxY = y }
                    }
                }
            }
        } else { // 32F
            for y in 0..<height {
                let rowPtr = base.advanced(by: y * bytesPerRow).assumingMemoryBound(to: Float32.self)
                for x in 0..<width {
                    let bin = min(255, Int(max(0, min(1, rowPtr[x])) * 255))
                    if bin >= thresholdByte {
                        countX[x] += 1
                        countY[y] += 1
                        if x < minX { minX = x }
                        if y < minY { minY = y }
                        if x > maxX { maxX = x }
                        if y > maxY { maxY = y }
                    }
                }
            }
        }

        guard maxX >= minX, maxY >= minY else { return nil }

        func quantileBounds(_ counts: [Int], low: Double, high: Double) -> (Int, Int) {
            let total = counts.reduce(0, +)
            if total == 0 { return (0, counts.count - 1) }
            let lowTarget = Int(Double(total) * low)
            let highTarget = Int(Double(total) * high)
            var cum = 0
            var left = 0, right = counts.count - 1
            for i in 0..<counts.count { cum += counts[i]; if cum >= lowTarget { left = i; break } }
            cum = 0
            for i in (0..<counts.count).reversed() { cum += counts[i]; if cum >= (total - highTarget) { right = i; break } }
            if right < left { right = left }
            return (left, right)
        }

        // 10% - 90% quantile crop per axis
        let (qMinX, qMaxX) = quantileBounds(countX, low: 0.10, high: 0.90)
        let (qMinY, qMaxY) = quantileBounds(countY, low: 0.10, high: 0.90)

        let useMinX = max(minX, qMinX)
        let useMaxX = min(maxX, qMaxX)
        let useMinY = max(minY, qMinY)
        let useMaxY = min(maxY, qMaxY)

        // Map to original image size
        let scaleX = imageWidth / CGFloat(width)
        let scaleY = imageHeight / CGFloat(height)
        var rect = CGRect(
            x: CGFloat(useMinX) * scaleX,
            y: CGFloat(useMinY) * scaleY,
            width: CGFloat(useMaxX - useMinX + 1) * scaleX,
            height: CGFloat(useMaxY - useMinY + 1) * scaleY
        )
        // Min ROI boyutu (çok küçükse biraz büyüt)
        let minSide: CGFloat = 64
        if rect.width < minSide || rect.height < minSide {
            let cx = rect.midX, cy = rect.midY
            rect.size.width = max(rect.width, minSide)
            rect.size.height = max(rect.height, minSide)
            rect.origin.x = max(0, cx - rect.width/2)
            rect.origin.y = max(0, cy - rect.height/2)
            rect = rect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
        }
        return rect
    }

    // MARK: - Save to Photos
    func saveAPIImageToPhotos() async {
        guard let image = apiReadyImage else { return }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            analysisResults.append("⚠️ Photo Library permission denied")
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
            analysisResults.append("✅ Saved to Photos")
        } catch {
            analysisResults.append("❌ Save failed: \(error.localizedDescription)")
        }
    }
    
    private func createUIImage(from pixelBuffer: CVPixelBuffer) async -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    private func createCombinedImage(original: CGImage, saliency: CVPixelBuffer) async -> UIImage? {
        let ciOriginal = CIImage(cgImage: original)
        let ciSaliency = CIImage(cvPixelBuffer: saliency)
        
        // Scale saliency to match original dimensions
        let scaleX = ciOriginal.extent.width / ciSaliency.extent.width
        let scaleY = ciOriginal.extent.height / ciSaliency.extent.height
        
        let scaledSaliency = ciSaliency.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        // Create overlay effect
        let coloredSaliency = scaledSaliency
            .applyingFilter("CIFalseColor", parameters: [
                "inputColor0": CIColor(color: UIColor.clear),
                "inputColor1": CIColor(color: UIColor.red.withAlphaComponent(0.6))
            ])
        
        // Combine images
        let combined = coloredSaliency.composited(over: ciOriginal)
        
        let context = CIContext()
        if let cgImage = context.createCGImage(combined, from: combined.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    func clearResults() {
        originalImage = nil
        saliencyImage = nil
        combinedImage = nil
        analysisResults = []
        isProcessing = false
    }
}
