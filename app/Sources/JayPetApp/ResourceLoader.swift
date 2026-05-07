import AppKit
import Foundation

@MainActor
enum ResourceLoader {
    private static var cache: [String: NSImage] = [:]
    private static var opaqueInsetsCache: [String: PixelInsets] = [:]

    static func albumImage(named fileName: String) -> NSImage? {
        if let cached = cache[fileName] {
            return cached
        }
        guard let url = resourceURL(named: fileName) else {
            return nil
        }
        guard let raw = NSImage(contentsOf: url) else { return nil }
        cache[fileName] = raw
        return raw
    }

    static func opaqueInsets(named fileName: String) -> PixelInsets {
        if let cached = opaqueInsetsCache[fileName] {
            return cached
        }
        guard
            let image = albumImage(named: fileName),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            return .zero
        }

        let insets = detectOpaqueInsets(in: cgImage)
        opaqueInsetsCache[fileName] = insets
        return insets
    }

    static func preload(sequence: SpriteFrameSequence) {
        sequence.frames.forEach { _ = albumImage(named: $0) }
    }

    private static func resourceURL(named fileName: String) -> URL? {
        if let direct = Bundle.module.url(forResource: fileName, withExtension: nil) {
            return direct
        }

        let path = NSString(string: fileName)
        let resourceName = path.lastPathComponent
        let directory = path.deletingLastPathComponent
        if !directory.isEmpty {
            if let nested = Bundle.module.url(forResource: resourceName, withExtension: nil, subdirectory: directory) {
                return nested
            }
        }
        return Bundle.module.url(forResource: resourceName, withExtension: nil)
    }

    private static func detectOpaqueInsets(in image: CGImage) -> PixelInsets {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else {
            return .zero
        }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo
        ) else {
            return .zero
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        let alphaThreshold: UInt8 = 10
        var minX = width
        var maxX = -1
        var minY = height
        var maxY = -1

        for y in 0 ..< height {
            let rowOffset = y * bytesPerRow
            for x in 0 ..< width {
                let alpha = pixels[rowOffset + (x * bytesPerPixel) + 3]
                if alpha > alphaThreshold {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return .zero
        }

        return PixelInsets(
            left: minX,
            right: max(width - maxX - 1, 0),
            top: max(height - maxY - 1, 0),
            bottom: minY
        )
    }
}
