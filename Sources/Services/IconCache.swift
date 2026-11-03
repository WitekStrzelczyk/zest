import AppKit

final class IconCache {
    static let shared = IconCache()

    private let side: CGFloat = 34
    private let icons: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 200
        return cache
    }()

    private init() {}

    func cachedIcon(for path: String) -> NSImage? {
        icons.object(forKey: path as NSString)
    }

    func renderedIcon(for path: String) -> NSImage {
        if let icon = cachedIcon(for: path) { return icon }
        let icon = render(NSWorkspace.shared.icon(forFile: path))
        icons.setObject(icon, forKey: path as NSString)
        return icon
    }

    private func render(_ source: NSImage) -> NSImage {
        let pixels = Int(side * 2)
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixels,
            pixelsHigh: pixels,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return source }
        bitmap.size = NSSize(width: side, height: side)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        source.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: bitmap.size)
        image.addRepresentation(bitmap)
        return image
    }
}
