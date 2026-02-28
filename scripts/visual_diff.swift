#!/usr/bin/env swift

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct Args {
    var actual = ""
    var reference = ""
    var outputDiff = ""
    var outputJson = ""
}

struct Metrics: Codable {
    let width: Int
    let height: Int
    let mae: Double
    let rmse: Double
    let changedPixelsRatio: Double
    let similarity: Double
}

func usage() {
    let text = """
    Usage:
      swift scripts/visual_diff.swift \
        --actual <actual.png> \
        --reference <reference.png> \
        --output-diff <diff.png> \
        --output-json <metrics.json>
    """
    print(text)
}

func parseArgs() -> Args? {
    var args = Args()
    var i = 1
    let argv = CommandLine.arguments
    while i < argv.count {
        let key = argv[i]
        if i + 1 >= argv.count {
            return nil
        }
        let value = argv[i + 1]
        switch key {
        case "--actual": args.actual = value
        case "--reference": args.reference = value
        case "--output-diff": args.outputDiff = value
        case "--output-json": args.outputJson = value
        default:
            return nil
        }
        i += 2
    }
    if args.actual.isEmpty || args.reference.isEmpty || args.outputDiff.isEmpty || args.outputJson.isEmpty {
        return nil
    }
    return args
}

func cgImage(from path: String) -> CGImage? {
    guard let image = NSImage(contentsOfFile: path) else { return nil }
    var rect = NSRect(origin: .zero, size: image.size)
    return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
}

func rgbaBuffer(from image: CGImage, width: Int, height: Int) -> [UInt8]? {
    var data = [UInt8](repeating: 0, count: width * height * 4)
    guard let ctx = CGContext(
        data: &data,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        return nil
    }
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    return data
}

func savePNG(_ image: CGImage, to path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        return false
    }
    CGImageDestinationAddImage(destination, image, nil)
    return CGImageDestinationFinalize(destination)
}

func writeJSON<T: Encodable>(_ value: T, path: String) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    try data.write(to: URL(fileURLWithPath: path))
}

func main() throws {
    guard let args = parseArgs() else {
        usage()
        exit(2)
    }

    guard let actualImage = cgImage(from: args.actual) else {
        fputs("Failed to load actual image: \(args.actual)\n", stderr)
        exit(1)
    }
    guard let referenceImage = cgImage(from: args.reference) else {
        fputs("Failed to load reference image: \(args.reference)\n", stderr)
        exit(1)
    }

    let width = referenceImage.width
    let height = referenceImage.height

    guard let actual = rgbaBuffer(from: actualImage, width: width, height: height),
          let reference = rgbaBuffer(from: referenceImage, width: width, height: height) else {
        fputs("Failed to build RGBA buffers\n", stderr)
        exit(1)
    }

    var diff = [UInt8](repeating: 0, count: width * height * 4)
    var absSum = 0.0
    var sqSum = 0.0
    var changedPixels = 0
    let n = Double(width * height * 3)

    for px in 0..<(width * height) {
        let i = px * 4
        let dr = abs(Double(actual[i]) - Double(reference[i]))
        let dg = abs(Double(actual[i + 1]) - Double(reference[i + 1]))
        let db = abs(Double(actual[i + 2]) - Double(reference[i + 2]))
        let delta = (dr + dg + db) / 3.0

        absSum += dr + dg + db
        sqSum += dr * dr + dg * dg + db * db

        let normalized = min(1.0, delta / 64.0)
        if normalized > 0.08 {
            changedPixels += 1
        }

        diff[i] = UInt8(255 * normalized)
        diff[i + 1] = UInt8(50 * (1.0 - normalized))
        diff[i + 2] = UInt8(20 * (1.0 - normalized))
        diff[i + 3] = UInt8(255 * min(1.0, normalized * 1.2))
    }

    let mae = (absSum / n) / 255.0
    let rmse = sqrt(sqSum / n) / 255.0
    let changedPixelsRatio = Double(changedPixels) / Double(width * height)
    let similarity = max(0.0, 1.0 - mae)

    guard let diffCtx = CGContext(
        data: &diff,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ), let diffImage = diffCtx.makeImage() else {
        fputs("Failed to create diff image\n", stderr)
        exit(1)
    }

    let diffDir = URL(fileURLWithPath: args.outputDiff).deletingLastPathComponent().path
    let jsonDir = URL(fileURLWithPath: args.outputJson).deletingLastPathComponent().path
    try FileManager.default.createDirectory(atPath: diffDir, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(atPath: jsonDir, withIntermediateDirectories: true)

    guard savePNG(diffImage, to: args.outputDiff) else {
        fputs("Failed to write diff image: \(args.outputDiff)\n", stderr)
        exit(1)
    }

    let metrics = Metrics(
        width: width,
        height: height,
        mae: mae,
        rmse: rmse,
        changedPixelsRatio: changedPixelsRatio,
        similarity: similarity
    )
    try writeJSON(metrics, path: args.outputJson)

    print(String(format: "Similarity: %.4f | MAE: %.4f | RMSE: %.4f | ChangedPixels: %.2f%%",
                 similarity, mae, rmse, changedPixelsRatio * 100.0))
    print("Diff: \(args.outputDiff)")
    print("Metrics: \(args.outputJson)")
}

do {
    try main()
} catch {
    fputs("visual_diff failed: \(error)\n", stderr)
    exit(1)
}
