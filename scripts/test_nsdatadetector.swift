#!/usr/bin/env swift

import Foundation

print("=== NSDataDetector Test for Duration ===\n")

let testInputs = [
    "files modified 500 minutes ago",
    "files modified 2 hours ago",
    "files modified today", "2 days ago",
    "files created yesterday",
    "show me files from last 30 minutes",
]

do {
    let detector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    
    for input in testInputs {
        print("Input: \(input)")
        let range = NSRange(input.startIndex..<input.endIndex, in: input)
        let matches = detector.matches(in: input, options: [], range: range)
        
        if matches.isEmpty {
            print("  No date detected")
        } else {
            for match in matches {
                if let date = match.date {
                    print("  Detected date: \(date)")
                    if let dateRange = Range(match.range, in: input) {
                        print("  Matched text: \(input[dateRange])")
                    }
                }
            }
        }
        print("")
    }
} catch {
    print("Error: \(error)")
}
