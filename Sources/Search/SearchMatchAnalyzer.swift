import Foundation

enum SearchMatchType: Double {
    case exact = 1.0
    case prefix = 0.95
    case wordStart = 0.9
    case fuzzy = 0.7
    case substring = 0.5
    case none = 0.0
}

struct SearchMatchResult {
    let quality: Double

    let matchType: SearchMatchType

    var isMatch: Bool {
        matchType != .none && quality > 0
    }

    static let noMatch = SearchMatchResult(quality: 0, matchType: .none)
}

final class SearchMatchAnalyzer {
    static let shared = SearchMatchAnalyzer()

    private init() {}

    func analyze(query: String, target: String) -> SearchMatchResult {
        guard !query.isEmpty, !target.isEmpty else { return .noMatch }

        let lowercasedQuery = query.lowercased()
        let lowercasedTarget = target.lowercased()

        if lowercasedTarget == lowercasedQuery {
            return SearchMatchResult(quality: 1.0, matchType: .exact)
        }

        if lowercasedTarget.hasPrefix(lowercasedQuery) {
            return SearchMatchResult(quality: 0.9, matchType: .prefix)
        }

        if let wordStartResult = analyzeWordStartMatch(query: lowercasedQuery, target: lowercasedTarget) {
            return wordStartResult
        }

        let fuzzyResult = analyzeFuzzyMatch(query: lowercasedQuery, target: lowercasedTarget)
        if fuzzyResult.isMatch {
            return fuzzyResult
        }

        if lowercasedTarget.contains(lowercasedQuery) {
            return SearchMatchResult(quality: 0.03, matchType: .substring)
        }

        return .noMatch
    }

    private func analyzeWordStartMatch(query: String, target: String) -> SearchMatchResult? {
        let words = target.components(separatedBy: CharacterSet(charactersIn: " -_"))

        for (index, word) in words.enumerated() where word.hasPrefix(query) {
            let positionPenalty = min(Double(index) * 0.05, 0.25)
            let quality = 0.85 - positionPenalty
            return SearchMatchResult(quality: quality, matchType: .wordStart)
        }

        return nil
    }

    private func analyzeFuzzyMatch(query: String, target: String) -> SearchMatchResult {
        guard !query.isEmpty else { return .noMatch }

        var matchPositions: [Int] = []
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex

        while queryIndex < query.endIndex, targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                matchPositions.append(target.distance(from: target.startIndex, to: targetIndex))
                queryIndex = query.index(after: queryIndex)
            }
            targetIndex = target.index(after: targetIndex)
        }

        guard matchPositions.count == query.count else { return .noMatch }

        var quality = 0.0

        quality += 0.3

        var totalGapPenalty = 0.0
        var consecutiveBonus = 0.0

        for i in 1..<matchPositions.count {
            let gap = matchPositions[i] - matchPositions[i - 1]

            if gap == 1 {
                consecutiveBonus += 0.1
            } else {
                let gapPenalty = Double(gap - 1) * Double(gap - 1) * 0.02
                totalGapPenalty += gapPenalty
            }
        }

        quality += consecutiveBonus
        quality -= totalGapPenalty

        let firstMatchPosition = matchPositions.first ?? 0
        let earlyPositionBonus = max(0, 0.2 - Double(firstMatchPosition) * 0.01)
        quality += earlyPositionBonus

        var wordBoundaryBonus = 0.0
        for position in matchPositions {
            if position == 0 {
                wordBoundaryBonus += 0.05
            } else {
                let prevCharIndex = target.index(target.startIndex, offsetBy: position - 1)
                let prevChar = target[prevCharIndex]
                if prevChar == " " || prevChar == "-" || prevChar == "_" {
                    wordBoundaryBonus += 0.03
                }
            }
        }
        quality += wordBoundaryBonus

        quality = max(0.05, min(0.6, quality))

        return SearchMatchResult(quality: quality, matchType: .fuzzy)
    }
}
