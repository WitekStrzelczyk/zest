#!/usr/bin/env swift

import Foundation
import AppKit

print("=== Spotlight Match All Test ===\n")

let tests: [String] = [
    "kMDItemContentModificationDate >= $time.today(-1d)",
    "kMDItemContentModificationDate >= $time.today(-365d)",
    "kMDItemContentModificationDate >= $time.today(-3650d)",
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
        print("  Results: \(query.resultCount) files\n")
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
