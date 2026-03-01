# Async Testing Best Practices

Practical guide to testing asynchronous Swift code without `Thread.sleep`.

---
last_reviewed: 2026-03-01
status: current
---

## Why Avoid Thread.sleep

Using `Thread.sleep` (or `usleep`) in tests is an anti-pattern:

| Problem | Impact |
|---------|--------|
| **Flaky** | May not wait long enough on slow machines/CI |
| **Slow** | Always waits full duration, even if operation finishes early |
| **Blocks parallelism** | XCTest can't run other tests during sleep |
| **Wastes CPU** | Thread is blocked but still consumes resources |

```swift
// ❌ BAD - Flaky and slow
func test_fetchData() {
    sut.fetchData()
    Thread.sleep(forTimeInterval: 1.0)  // Hope 1s is enough...
    XCTAssertEqual(sut.data.count, 5)   // May fail on slow CI!
}
```

## Replacement Techniques

### 1. XCTestExpectation (Callback-based)

For delegate, completion handler, or notification-based async:

```swift
// ✅ GOOD - Waits exactly until callback fires
func test_fetchData_completes() {
    let expectation = XCTestExpectation(description: "Fetch completes")
    
    sut.fetchData { result in
        XCTAssertNotNil(result)
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)  // Max wait, not fixed wait
}
```

### 2. async/await (Xcode 13+)

The modern, preferred approach:

```swift
// ✅ GOOD - Natural async/await testing
func test_fetchData_returnsResults() async throws {
    let result = try await sut.fetchData()
    XCTAssertEqual(result.count, 5)
}
```

### 3. withCheckedContinuation (Bridging Callbacks)

Convert callback-based APIs to async/await in tests:

```swift
// ✅ GOOD - Bridge callback to async/await
func test_legacyCallback_api() async throws {
    let result = try await withCheckedThrowingContinuation { continuation in
        legacyAPI.fetch { result, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: result)
            }
        }
    }
    
    XCTAssertEqual(result.count, 5)
}
```

### 4. Mock Time Controllers (Time-based Operations)

For debouncing, throttling, delays - inject a time controller:

```swift
// Protocol for time-based operations
protocol TimeController {
    var now: Date { get }
    func schedule(after interval: TimeInterval, _ work: @escaping () -> Void)
}

// Production implementation
struct RealTimeController: TimeController {
    var now: Date { Date() }
    func schedule(after interval: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }
}

// Test implementation with manual time control
class MockTimeController: TimeController {
    var now = Date()
    private var scheduledWork: [(interval: TimeInterval, work: () -> Void)] = []
    
    func schedule(after interval: TimeInterval, _ work: @escaping () -> Void) {
        scheduledWork.append((interval, work))
    }
    
    func advance(by interval: TimeInterval) {
        now.addTimeInterval(interval)
        // Execute all work scheduled within the advanced time
        scheduledWork.forEach { if $0.interval <= interval { $0.work() } }
        scheduledWork.removeAll { $0.interval <= interval }
    }
}

// ✅ GOOD - Test with instant, deterministic time control
func test_debounce_waitsBeforeProcessing() {
    let mockTime = MockTimeController()
    let sut = SearchController(timeController: mockTime)
    
    sut.search("query")
    XCTAssertNil(sut.lastSearch)  // Not processed yet
    
    mockTime.advance(by: 0.3)     // Advance time instantly
    XCTAssertEqual(sut.lastSearch, "query")
}
```

---

## Code Examples: Bad vs Good

### Callback-based Async

```swift
// ❌ BAD
func test_login_succeeds() {
    var receivedResult: Result<User, Error>?
    authManager.login(email: "test@test.com", password: "pass") { result in
        receivedResult = result
    }
    Thread.sleep(forTimeInterval: 2.0)
    XCTAssertNotNil(receivedResult)
}

// ✅ GOOD
func test_login_succeeds() {
    let expectation = XCTestExpectation(description: "Login completes")
    var receivedResult: Result<User, Error>?
    
    authManager.login(email: "test@test.com", password: "pass") { result in
        receivedResult = result
        expectation.fulfill()
    }
    
    wait(for: [expectation], timeout: 5.0)
    XCTAssertNotNil(receivedResult)
}

// ✅ BETTER (async/await)
func test_login_succeeds() async throws {
    let result = try await authManager.login(email: "test@test.com", password: "pass")
    XCTAssertEqual(result.email, "test@test.com")
}
```

### Multiple Async Operations

```swift
// ❌ BAD - Multiple sleeps
func test_multipleRequests() {
    sut.fetchUsers()
    Thread.sleep(forTimeInterval: 1.0)
    sut.fetchPosts()
    Thread.sleep(forTimeInterval: 1.0)
    XCTAssertEqual(sut.users.count + sut.posts.count, 20)
}

// ✅ GOOD - Single wait for all expectations
func test_multipleRequests() async throws {
    async let users = sut.fetchUsers()
    async let posts = sut.fetchPosts()
    
    let (usersResult, postsResult) = try await (users, posts)
    XCTAssertEqual(usersResult.count + postsResult.count, 20)
}

// ✅ GOOD - Sequential with expectations
func test_multipleRequests_sequential() {
    let usersExpectation = XCTestExpectation(description: "Users fetched")
    let postsExpectation = XCTestExpectation(description: "Posts fetched")
    
    sut.fetchUsers { _ in usersExpectation.fulfill() }
    sut.fetchPosts { _ in postsExpectation.fulfill() }
    
    wait(for: [usersExpectation, postsExpectation], timeout: 10.0)
}
```

### Dispatch Queues

```swift
// ❌ BAD
func test_backgroundProcessing() {
    sut.processInBackground()
    Thread.sleep(forTimeInterval: 0.5)
    XCTAssertTrue(sut.isProcessed)
}

// ✅ GOOD - Expectation on main queue
func test_backgroundProcessing() {
    let expectation = XCTestExpectation(description: "Processing complete")
    
    sut.processInBackground {
        DispatchQueue.main.async {
            expectation.fulfill()
        }
    }
    
    wait(for: [expectation], timeout: 5.0)
    XCTAssertTrue(sut.isProcessed)
}

// ✅ GOOD - Using async/await with Task
func test_backgroundProcessing() async throws {
    try await sut.processInBackground()
    XCTAssertTrue(sut.isProcessed)
}
```

### Time-based Operations (Debounce/Throttle)

```swift
// ❌ BAD - Real sleep makes test slow
func test_debounce_ignoresRapidChanges() {
    let sut = DebouncedSearch()
    
    sut.search("a")
    sut.search("ab")
    sut.search("abc")
    
    Thread.sleep(forTimeInterval: 0.5)  // Slow!
    
    XCTAssertEqual(sut.lastQuery, "abc")
}

// ✅ GOOD - Mock time for instant testing
func test_debounce_ignoresRapidChanges() {
    let mockTime = MockTimeController()
    let sut = DebouncedSearch(timeController: mockTime)
    
    sut.search("a")
    sut.search("ab")
    sut.search("abc")
    
    mockTime.advance(by: 0.5)  // Instant!
    
    XCTAssertEqual(sut.lastQuery, "abc")
}
```

### Publishers (Combine)

```swift
// ❌ BAD
func test_publisher_emitsValues() {
    var values: [Int] = []
    let cancellable = sut.numbers.sink { values.append($0) }
    
    sut.emitNumbers()
    Thread.sleep(forTimeInterval: 1.0)
    
    XCTAssertEqual(values, [1, 2, 3])
    cancellable.cancel()
}

// ✅ GOOD - Using expectation
func test_publisher_emitsValues() {
    var values: [Int] = []
    let expectation = XCTestExpectation(description: "All values received")
    expectation.expectedFulfillmentCount = 3
    
    let cancellable = sut.numbers.sink { _ in
        expectation.fulfill()
    } receiveValue: { value in
        values.append(value)
    }
    
    sut.emitNumbers()
    wait(for: [expectation], timeout: 5.0)
    
    XCTAssertEqual(values, [1, 2, 3])
    cancellable.cancel()
}

// ✅ GOOD - Collect publisher values
func test_publisher_emitsValues() async throws {
    let values = try await sut.numbers
        .collect()
        .timeout(.seconds(5), scheduler: DispatchQueue.main)
        .values.first()
    
    XCTAssertEqual(values, [1, 2, 3])
}
```

### Delegates

```swift
// ❌ BAD
func test_delegate_receivesCallback() {
    sut.delegate = self
    sut.doWork()
    Thread.sleep(forTimeInterval: 1.0)
    XCTAssertTrue(didReceiveCallback)
}

// ✅ GOOD - Use expectation in delegate callback
class DelegateExpectationTests: XCTestCase, MyDelegate {
    var sut: SystemUnderTest!
    var callbackExpectation: XCTestExpectation!
    
    func test_delegate_receivesCallback() {
        callbackExpectation = XCTestExpectation(description: "Delegate called")
        sut.delegate = self
        sut.doWork()
        wait(for: [callbackExpectation], timeout: 5.0)
    }
    
    func didComplete() {
        callbackExpectation.fulfill()
    }
}

// ✅ GOOD - Modern approach with mock delegate
func test_delegate_receivesCallback() {
    let mockDelegate = MockDelegate()
    let expectation = mockDelegate.expectation(description: "Delegate called")
    mockDelegate.didCompleteHandler = { expectation.fulfill() }
    
    sut.delegate = mockDelegate
    sut.doWork()
    
    wait(for: [expectation], timeout: 5.0)
}
```

---

## Quick Reference Table

| Technique | Use When | Example |
|-----------|----------|---------|
| `XCTestExpectation` | Callbacks, delegates, notifications | `wait(for: [exp], timeout: 5)` |
| `async/await` | Modern Swift (Xcode 13+) | `let x = try await sut.fetch()` |
| `withCheckedContinuation` | Bridge legacy callbacks to async | `await withCheckedContinuation { ... }` |
| Mock Time Controller | Debounce, throttle, delays | `mockTime.advance(by: 0.5)` |
| `XCTWaiter` | Multiple expectations with control | `XCTWaiter.wait(for: [exp1, exp2])` |
| `.collect()` (Combine) | Collect all publisher values | `pub.collect().values.first()` |
| `expectation(for:evaluatingWith:)` | KVO, NSNotification | `expectation(forNotification: ...)` |

### Timeout Guidelines

```swift
// Unit tests: 1-5 seconds (fast operations)
wait(for: [expectation], timeout: 5.0)

// Integration tests: 10-30 seconds (network, disk)
wait(for: [expectation], timeout: 30.0)

// CI tests: Consider 2x normal timeout
wait(for: [expectation], timeout: 10.0)  // Would be 5.0 locally
```

---

## Performance Impact

### How Sleeps Affect Parallel Testing

```
Sequential with sleeps:
Test 1: [====sleep====] 1.0s
Test 2: [====sleep====] 1.0s  
Test 3: [====sleep====] 1.0s
Total: 3.0s

Parallel with expectations:
Test 1: [=] 0.1s (actual work)
Test 2: [=] 0.1s (actual work)
Test 3: [=] 0.1s (actual work)
Total: ~0.3s (10x faster!)
```

### Why Removing Sleeps Improves Test Speed

1. **No wasted time**: Tests complete as soon as assertions pass
2. **Parallel execution**: XCTest can run tests concurrently
3. **Faster feedback**: Developers get results in seconds, not minutes
4. **CI efficiency**: Lower compute costs, faster pipelines

### Benchmark Example

```swift
// With Thread.sleep in 10 tests × 1s sleep = 10+ seconds
// With expectations in 10 tests × 0.1s actual work = ~1 second

// Real project example:
// Before (sleeps):  47 tests in 89 seconds
// After (expectations): 47 tests in 12 seconds
```

---

## Checklist for Async Tests

- [ ] No `Thread.sleep`, `usleep`, or `DispatchQueue.asyncAfter` in tests
- [ ] Using expectations for callback-based code
- [ ] Using `async/await` for modern Swift APIs
- [ ] Mocking time for debounce/throttle/delay testing
- [ ] Timeout is reasonable (5-30s depending on operation)
- [ ] Tests are deterministic (same result every run)

---

## See Also

- [TDD Guidelines](/Users/witek/projects/copies/zest/docs/TDD_GUIDELINES.md) - RED-GREEN-REFACTOR workflow
- [FAQ](/Users/witek/projects/copies/zest/docs/FAQ.md) - Common problems and solutions
