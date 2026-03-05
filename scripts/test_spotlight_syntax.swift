#!/usr/bin/env swift

import Foundation
import AppKit

print("=== Spotlight Query Syntax Test ===\n")

let tests: [String] = [
    "kMDItemDisplayName == \"*mo*\" && kMDItemContentModificationDate >= $time.today(-30d)",
    "kMDItemDisplayName == \"*.swift\" && kMDItemContentModificationDate >= $time.today(-30d)",
]

var currentTest = 0

func runNextTest() {
    guard currentTest < tests.count else {
        print("=== Done ===")
        CFRunLoopStop(CFRunLoopGetCurrent())
        return
    }
    
    let queryString = tests[currentTest]
    currentTest += 1
    
    print("Test: \(queryString)")
    
    guard let predicate = NSPredicate(fromMetadataQueryString: queryString) else {
        print("  ERROR: Failed to create predicate\n")
        runNextTest()
        return
    }
    
    print("  Predicate: \(predicate.predicateFormat)")
    
    let query = NSMetadataQuery()
    query.searchScopes = [NSMetadataQueryUserHomeScope]
    query.predicate = predicate
    
    var finished = false
    var observer: NSObjectProtocol?
    
    observer = NotificationCenter.default.addObserver(
        forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
        object: query,
        queue: .main
    ) { _ in
        guard !finished else { return }
        finished = true
        query.disableUpdates()
        print("  Results: \(query.resultCount) files")
        if query.resultCount > 0 {
            for i in 0..<min(5, query.resultCount) {
                if let item = query.result(at: i) as? NSMetadataItem,
                   let url = item.value(forAttribute: NSMetadataItemPathKey) as? URL {
                    print("    - \(url.lastPathComponent)")
                }
            }
        }
        print("")
        query.stop()
        if let obs = observer { NotificationCenter.default.removeObserver(obs) }
        runNextTest()
    }
    
    query.start()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
        if !finished {
            finished = true
            print("  TIMEOUT\n")
            query.stop()
            if let obs = observer { NotificationCenter.default.removeObserver(obs) }
            runNextTest()
        }
    }
}

runNextTest()
CFRunLoopRun()
