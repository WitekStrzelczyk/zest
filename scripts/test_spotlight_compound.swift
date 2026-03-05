#!/usr/bin/env swift

import Foundation
import AppKit

print("=== Spotlight Compound Predicate Test ===\n")

// Test 1: Single predicate (works in main test)
print("Test 1: Single date predicate")
let query1 = NSMetadataQuery()
query1.searchScopes = [NSMetadataQueryUserHomeScope]

guard let pred1 = NSPredicate(fromMetadataQueryString: "kMDItemContentModificationDate >= $time.today(-1d)") else {
    print("  ERROR: Failed to create predicate")
    exit(1)
}
print("  Predicate: \(pred1.predicateFormat)")
query1.predicate = pred1

var finished1 = false
var observer1: NSObjectProtocol?
observer1 = NotificationCenter.default.addObserver(
    forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
    object: query1,
    queue: .main
) { _ in
    guard !finished1 else { return }
    finished1 = true
    query1.disableUpdates()
    print("  Results: \(query1.resultCount) files\n")
    query1.stop()
    if let obs = observer1 { NotificationCenter.default.removeObserver(obs) }
    
    // Run test 2
    runTest2()
}

query1.start()

DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
    if !finished1 {
        finished1 = true
        print("  TIMEOUT\n")
        query1.stop()
        if let obs = observer1 { NotificationCenter.default.removeObserver(obs) }
        runTest2()
    }
}

// Test 2: Compound predicate (date + name LIKE *)
func runTest2() {
    print("Test 2: Compound predicate (date + name LIKE *)")
    
    guard let datePred = NSPredicate(fromMetadataQueryString: "kMDItemContentModificationDate >= $time.today(-1d)") else {
        print("  ERROR: Failed to create date predicate")
        CFRunLoopStop(CFRunLoopGetCurrent())
        return
    }
    
    let namePred = NSPredicate(format: "%K LIKE[cd] %@", NSMetadataItemFSNameKey, "*")
    let compoundPred = NSCompoundPredicate(andPredicateWithSubpredicates: [datePred, namePred])
    
    print("  Predicate: \(compoundPred.predicateFormat)")
    
    let query2 = NSMetadataQuery()
    query2.searchScopes = [NSMetadataQueryUserHomeScope]
    query2.predicate = compoundPred
    
    var finished2 = false
    var observer2: NSObjectProtocol?
    observer2 = NotificationCenter.default.addObserver(
        forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
        object: query2,
        queue: .main
    ) { _ in
        guard !finished2 else { return }
        finished2 = true
        query2.disableUpdates()
        print("  Results: \(query2.resultCount) files\n")
        query2.stop()
        if let obs = observer2 { NotificationCenter.default.removeObserver(obs) }
        
        // Run test 3
        runTest3()
    }
    
    query2.start()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        if !finished2 {
            finished2 = true
            print("  TIMEOUT\n")
            query2.stop()
            if let obs = observer2 { NotificationCenter.default.removeObserver(obs) }
            runTest3()
        }
    }
}

// Test 3: Use fromMetadataQueryString for entire query
func runTest3() {
    print("Test 3: Single fromMetadataQueryString with date only")
    
    let queryString = "kMDItemContentModificationDate >= $time.today(-1d)"
    guard let predicate = NSPredicate(fromMetadataQueryString: queryString) else {
        print("  ERROR: Failed to create predicate")
        print("\n=== Test Complete ===")
        CFRunLoopStop(CFRunLoopGetCurrent())
        return
    }
    
    print("  Predicate: \(predicate.predicateFormat)")
    
    let query3 = NSMetadataQuery()
    query3.searchScopes = [NSMetadataQueryUserHomeScope]
    query3.predicate = predicate
    
    var finished3 = false
    var observer3: NSObjectProtocol?
    observer3 = NotificationCenter.default.addObserver(
        forName: NSNotification.Name.NSMetadataQueryDidFinishGathering,
        object: query3,
        queue: .main
    ) { _ in
        guard !finished3 else { return }
        finished3 = true
        query3.disableUpdates()
        print("  Results: \(query3.resultCount) files\n")
        query3.stop()
        if let obs = observer3 { NotificationCenter.default.removeObserver(obs) }
        
        print("=== Test Complete ===")
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
    
    query3.start()
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
        if !finished3 {
            finished3 = true
            print("  TIMEOUT\n")
            query3.stop()
            if let obs = observer3 { NotificationCenter.default.removeObserver(obs) }
            print("=== Test Complete ===")
            CFRunLoopStop(CFRunLoopGetCurrent())
        }
    }
}

CFRunLoopRun()
