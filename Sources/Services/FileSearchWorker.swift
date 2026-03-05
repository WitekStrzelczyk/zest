import Foundation

struct FileSearchIntent {
    var fileExtension: String?
    var date: Date?
    var dateType: DateType = .modified
    var isLarge: Bool = false
    var searchTerm: String?

    enum DateType {
        case created
        case modified
        case opened

        var attribute: String {
            switch self {
            case .created: "kMDItemContentCreationDate"
            case .modified: "kMDItemContentModificationDate"
            case .opened: "kMDItemLastUsedDate"
            }
        }
    }
}

class FileSearchWorker {
    static let shared = FileSearchWorker()
    private init() {}

    func parse(context: QueryContext) -> FileSearchIntent {
        var intent = FileSearchIntent()
        let lower = context.normalized.lowercased()

        // 1. Detect Large Files
        if lower.contains("large") {
            intent.isLarge = true
        }

        // 2. Detect Extensions (Generic detection)
        let scanner = Scanner(string: lower)
        while !scanner.isAtEnd {
            if scanner.scanString(".") != nil {
                if let ext = scanner.scanCharacters(from: .letters) {
                    intent.fileExtension = String(ext)
                }
            } else {
                if !scanner.isAtEnd { _ = scanner.scanCharacter() }
            }
        }

        // Word-based: "pdf files"
        let commonExtensions = ["pdf", "jpg", "png", "txt", "swift", "md", "doc", "docx", "xls", "xlsx"]
        if intent.fileExtension == nil {
            for ext in commonExtensions {
                if lower.contains("\(ext) ") || lower.hasSuffix(ext) || lower.contains(" \(ext)") {
                    intent.fileExtension = ext
                    break
                }
            }
        }

        // 3. Detect Date Type
        if lower.contains("created") {
            intent.dateType = .created
        } else if lower.contains("opened") || lower.contains("last used") {
            intent.dateType = .opened
        } else if lower.contains("modified") || lower.contains("changed") {
            intent.dateType = .modified
        }

        // 4. Use pre-extracted date from context
        intent.date = context.dates.first

        // 5. Build clean search term
        var term = context.semanticTerm
        let fileWords = ["files", "file", "images", "image", "docs", "doc"]
        for word in fileWords {
            term = term.replacingOccurrences(of: word, with: "", options: .caseInsensitive)
        }

        let finalTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalTerm.count > 1 {
            intent.searchTerm = finalTerm
        }

        return intent
    }

    func buildPredicate(from intent: FileSearchIntent) -> NSPredicate {
        var subpredicates: [NSPredicate] = []

        if let term = intent.searchTerm {
            subpredicates.append(NSPredicate(format: "kMDItemDisplayName CONTAINS[cd] %@", term))
        }

        if let ext = intent.fileExtension {
            subpredicates.append(NSPredicate(
                format: "kMDItemFSName == %@ OR kMDItemFSName ENDSWITH %@",
                "*.\(ext)",
                ".\(ext)"
            ))
        }

        if let date = intent.date {
            subpredicates.append(NSPredicate(format: "%K >= %@", intent.dateType.attribute, date as NSDate))
        }

        if intent.isLarge {
            subpredicates.append(NSPredicate(format: "kMDItemFSSize > %d", 100 * 1024 * 1024))
        }

        if subpredicates.isEmpty {
            return NSPredicate(format: "kMDItemFSName == '*'")
        }

        if subpredicates.count == 1 {
            return subpredicates[0]
        }

        return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
    }
}
