import Foundation
import CoreGraphics
import CoreVideo
import ImageIO
import UniformTypeIdentifiers
import Vision

struct CutoutResult: Sendable {
    enum Method: String, Codable, Sendable { case vision, backgroundKey }

    let png: Data
    let method: Method
    let instances: Int
    /// Instances left out because they were not the main subject, such as a repeated copy beside it.
    let droppedInstances: Int
    /// Fraction of the generated image covered by the subject.
    let coverage: Double
    /// Distance from the subject's bounding box center to the image center, as a fraction of half the width.
    let centerOffset: Double
    let touchesEdge: Bool
}

/// Removes the background from a generated image and centers the subject on a transparent square canvas.
/// Vision's foreground instance mask runs first. When it finds no subject, pixels that match the border
/// color and connect to the border are removed, so a plain background comes out while matching colors inside
/// the subject stay.
enum SubjectCutout {
    static func process(_ image: CGImage, canvas: Int = 512, fill: Double = 0.8) async throws -> CutoutResult? {
        guard let pixels = RGBAPixels(image) else { return nil }
        var method = CutoutResult.Method.vision
        var instances = 0
        var dropped = 0
        var alpha = try await visionMask(for: image, width: pixels.width, height: pixels.height,
                                         instances: &instances, dropped: &dropped)
        if alpha == nil {
            method = .backgroundKey
            alpha = backgroundKeyMask(pixels)
            instances = alpha == nil ? 0 : 1
        }
        guard let alpha, let box = boundingBox(alpha, width: pixels.width, height: pixels.height) else { return nil }
        let covered = alpha.reduce(0) { $0 + ($1 > 0.5 ? 1 : 0) }
        let centerX = Double(box.midX) / Double(pixels.width) - 0.5
        let centerY = Double(box.midY) / Double(pixels.height) - 0.5
        let touchesEdge = box.minX <= 1 || box.minY <= 1 || box.maxX >= pixels.width - 1 || box.maxY >= pixels.height - 1
        guard let png = compose(pixels, alpha: alpha, box: box, canvas: canvas, fill: fill) else { return nil }
        return CutoutResult(png: png, method: method, instances: instances, droppedInstances: dropped,
                            coverage: Double(covered) / Double(alpha.count),
                            centerOffset: (centerX * centerX + centerY * centerY).squareRoot() * 2,
                            touchesEdge: touchesEdge)
    }

    /// Keeps one instance: the one under the image center, or else the largest. Instances that touch three or more
    /// image edges are treated as background, which Vision sometimes returns when two copies frame the center.
    private static func visionMask(for image: CGImage, width: Int, height: Int,
                                   instances: inout Int, dropped: inout Int) async throws -> [Float]? {
        let handler = ImageRequestHandler(image)
        guard let observation = try await handler.perform(GenerateForegroundInstanceMaskRequest()),
              !observation.allInstances.isEmpty else { return nil }
        instances = observation.allInstances.count
        var candidates: [(mask: [Float], area: Int, containsCenter: Bool, edges: Int)] = []
        for instance in observation.allInstances {
            let buffer = try observation.generateScaledMask(for: IndexSet(integer: instance), scaledToImageFrom: handler)
            guard let mask = floatMask(buffer, width: width, height: height),
                  let box = boundingBox(mask, width: width, height: height) else { continue }
            let edges = [box.minX <= 1, box.minY <= 1, box.maxX >= width - 2, box.maxY >= height - 2].filter { $0 }.count
            candidates.append((mask, mask.reduce(0) { $0 + ($1 > 0.5 ? 1 : 0) },
                               mask[(height / 2) * width + width / 2] > 0.5, edges))
        }
        let subjects = candidates.filter { $0.edges < 3 }
        let pool = subjects.isEmpty ? candidates : subjects
        guard let primary = pool.first(where: \.containsCenter) ?? pool.max(by: { $0.area < $1.area }) else { return nil }
        dropped = instances - 1
        return primary.mask
    }

    /// Flood fills from the border through pixels close to the median border color.
    static func backgroundKeyMask(_ pixels: RGBAPixels, tolerance: Double = 60) -> [Float]? {
        let width = pixels.width, height = pixels.height
        var border: [Int] = []
        for x in 0..<width { border += [x, (height - 1) * width + x] }
        for y in 0..<height { border += [y * width, y * width + width - 1] }
        let key = (0..<3).map { channel in
            border.map { Int(pixels.data[$0 * 4 + channel]) }.sorted()[border.count / 2]
        }
        func matches(_ index: Int) -> Bool {
            let distance = (0..<3).reduce(0.0) { sum, channel in
                let delta = Double(Int(pixels.data[index * 4 + channel]) - key[channel])
                return sum + delta * delta
            }
            return distance.squareRoot() < tolerance
        }
        var alpha = [Float](repeating: 1, count: width * height)
        var stack = border.filter(matches)
        for index in stack { alpha[index] = 0 }
        while let index = stack.popLast() {
            let x = index % width, y = index / width
            for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)] where nx >= 0 && ny >= 0 && nx < width && ny < height {
                let next = ny * width + nx
                if alpha[next] == 1 && matches(next) {
                    alpha[next] = 0
                    stack.append(next)
                }
            }
        }
        let remaining = alpha.reduce(0, +) / Float(alpha.count)
        // Nothing removed means there was no plain background; everything removed means there was no subject.
        return remaining > 0.02 && remaining < 0.98 ? alpha : nil
    }

    private static func floatMask(_ buffer: CVPixelBuffer, width: Int, height: Int) -> [Float]? {
        guard CVPixelBufferGetWidth(buffer) == width, CVPixelBufferGetHeight(buffer) == height else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        var mask = [Float](repeating: 0, count: width * height)
        switch CVPixelBufferGetPixelFormatType(buffer) {
        case kCVPixelFormatType_OneComponent32Float:
            for y in 0..<height {
                let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: Float.self)
                for x in 0..<width { mask[y * width + x] = row[x] }
            }
        case kCVPixelFormatType_OneComponent8:
            for y in 0..<height {
                let row = base.advanced(by: y * rowBytes).assumingMemoryBound(to: UInt8.self)
                for x in 0..<width { mask[y * width + x] = Float(row[x]) / 255 }
            }
        default:
            return nil
        }
        return mask
    }

    static func boundingBox(_ alpha: [Float], width: Int, height: Int) -> (minX: Int, minY: Int, maxX: Int, maxY: Int, midX: Int, midY: Int)? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] > 0.5 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return nil }
        return (minX, minY, maxX, maxY, (minX + maxX) / 2, (minY + maxY) / 2)
    }

    private static func compose(_ pixels: RGBAPixels, alpha: [Float], box: (minX: Int, minY: Int, maxX: Int, maxY: Int, midX: Int, midY: Int),
                                canvas: Int, fill: Double) -> Data? {
        var premultiplied = pixels.data
        for index in 0..<alpha.count {
            let a = max(0, min(1, alpha[index]))
            for channel in 0..<3 {
                premultiplied[index * 4 + channel] = UInt8(Float(premultiplied[index * 4 + channel]) * a)
            }
            premultiplied[index * 4 + 3] = UInt8(a * 255)
        }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let provider = CGDataProvider(data: Data(premultiplied) as CFData),
              let masked = CGImage(width: pixels.width, height: pixels.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                   bytesPerRow: pixels.width * 4, space: space, bitmapInfo: CGBitmapInfo(rawValue: info),
                                   provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent),
              let subject = masked.cropping(to: CGRect(x: box.minX, y: box.minY,
                                                       width: box.maxX - box.minX + 1, height: box.maxY - box.minY + 1)),
              let context = CGContext(data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: info) else { return nil }
        let scale = Double(canvas) * fill / Double(max(subject.width, subject.height))
        let size = CGSize(width: Double(subject.width) * scale, height: Double(subject.height) * scale)
        context.interpolationQuality = .high
        context.draw(subject, in: CGRect(x: (Double(canvas) - size.width) / 2, y: (Double(canvas) - size.height) / 2,
                                         width: size.width, height: size.height))
        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}

/// Unpremultiplied RGBA8 pixels in top-to-bottom row order.
struct RGBAPixels {
    let width: Int
    let height: Int
    let data: [UInt8]

    init?(_ image: CGImage) {
        let width = image.width, height = image.height
        self.width = width
        self.height = height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = buffer.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height, bitsPerComponent: 8,
                                          bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        data = buffer
    }
}
