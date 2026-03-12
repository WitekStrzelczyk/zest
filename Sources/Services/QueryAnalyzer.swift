import Foundation
import NaturalLanguage

final class QueryAnalyzer {
    static let shared = QueryAnalyzer()

    private init() {}

    func analyze(_ query: String) -> QueryContext {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return QueryContext(raw: query, normalized: "", dates: [], numbers: [], location: nil, semanticTerm: "")
        }

        var dates: [Date] = []
        var detectedLocation: String?
        var rangesToRemove: [NSRange] = []

        // 1a. Detect Relative Offsets (regex-based for reliability)
        let relativePatterns = [
            #"(\d+)\s+(minute|hour|day|week|month|year)s?\s+ago"#,
            #"\blast\s+(minute|hour|day|week|month|year)\b"#,
            #"\btoday\b"#,
            #"\byesterday\b"#,
            #"\btomorrow\b"#,
        ]

        for pattern in relativePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let nsString = normalized as NSString
                let matches = regex.matches(
                    in: normalized,
                    options: [],
                    range: NSRange(location: 0, length: nsString.length)
                )
                for match in matches {
                    let matchedText = nsString.substring(with: match.range)
                    if let date = DateTimeParser.shared.parseDate(matchedText) {
                        dates.append(date)
                        rangesToRemove.append(match.range)
                    }
                }
            }
        }

        // 1b. Use NSDataDetector for other dates/addresses
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue | NSTextCheckingResult
            .CheckingType.address.rawValue)
        let matches = detector?.matches(
            in: normalized,
            options: [],
            range: NSRange(location: 0, length: normalized.utf16.count)
        ) ?? []

        for match in matches {
            // Skip if this range was already handled by relative patterns
            if rangesToRemove.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
                continue
            }

            if match.resultType == .date, let date = match.date {
                dates.append(date)
                rangesToRemove.append(match.range)
            } else if match.resultType == .address {
                detectedLocation = (normalized as NSString).substring(with: match.range)
                rangesToRemove.append(match.range)
            }
        }

        // 2. Extract Numbers using Scanner
        var numbers: [Int] = []
        let scanner = Scanner(string: normalized)
        while !scanner.isAtEnd {
            if let num = scanner.scanInt() {
                numbers.append(num)
            } else {
                if !scanner.isAtEnd { _ = scanner.scanCharacter() }
            }
        }

        // 3. Extract Locations using NLTagger (if detector missed it)
        if detectedLocation == nil {
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = normalized
            tagger.enumerateTags(
                in: normalized.startIndex..<normalized.endIndex,
                unit: .word,
                scheme: .nameType,
                options: [.omitWhitespace, .omitPunctuation, .joinNames]
            ) { tag, range in
                if tag == .placeName || tag == .organizationName {
                    detectedLocation = String(normalized[range])
                    return false
                }
                return true
            }
        }

        // 4. Build semantic term (strip metadata)
        var semantic = normalized
        // Remove dates/locations found by detector
        for range in rangesToRemove.sorted(by: { $0.location > $1.location }) {
            if let swiftRange = Range(range, in: semantic) {
                semantic.removeSubrange(swiftRange)
            }
        }

        // Clean up common connector words (ensure we leave spaces)
        let noise = [" at ", " in ", " on ", " using ", " with ", " for "]
        for word in noise {
            semantic = semantic.replacingOccurrences(of: word, with: " ", options: .caseInsensitive)
        }

        let cleanTerm = semantic.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "  ", with: " ")

        return QueryContext(
            raw: query,
            normalized: normalized,
            dates: dates,
            numbers: numbers,
            location: detectedLocation,
            semanticTerm: cleanTerm
        )
    }
}
