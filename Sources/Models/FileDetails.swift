import Foundation

struct FileDetails {
    let summary: String
    let size: String

    private static let relativeDate: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    private static let byteCount: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter
    }()

    init(path: String) {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let ext = URL(fileURLWithPath: path).pathExtension.uppercased()
        let typeText = ext.isEmpty ? "File" : "\(ext) Document"
        let modifiedText = (attributes?[.modificationDate] as? Date)
            .map { "Updated \(Self.relativeDate.localizedString(for: $0, relativeTo: Date()))" } ?? "Updated recently"
        summary = "\(modifiedText)  •  \(typeText)"

        switch (attributes?[.size] as? NSNumber)?.int64Value {
        case nil: size = "--"
        case 0: size = "empty"
        case let bytes?: size = Self.byteCount.string(fromByteCount: bytes)
        }
    }

    static func location(of path: String) -> String {
        let folder = URL(fileURLWithPath: path).deletingLastPathComponent()
        let components = folder.pathComponents
        guard components.count > 3 else { return folder.path }
        return "/" + components.suffix(3).joined(separator: "/")
    }
}
