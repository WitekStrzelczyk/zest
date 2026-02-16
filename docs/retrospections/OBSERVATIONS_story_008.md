# OBSERVATIONS - Story 8: File Search

## Date
2026-02-14

## Implementation Summary
Implemented File Search feature using macOS Spotlight API (NSMetadataQuery) to search indexed files by name and content.

---

## Tools Used

### Core APIs
- **NSMetadataQuery** - Core class for querying Spotlight's metadata index
- **NSMetadataItem** - Represents a metadata item from Spotlight
- **NSWorkspace** - For file operations (open, reveal in Finder)
- **CoreServices** - For metadata attribute keys

### Key Attribute Keys
- `NSMetadataItemDisplayNameKey` - File name
- `NSMetadataItemPathKey` - Full file path
- `NSMetadataItemTextContentKey` - File content (text files)
- `NSMetadataItemFSContentChangeDateKey` - File modification date

### Search Scopes
- `NSMetadataQueryUserHomeScope` - User's home directory
- `NSMetadataQueryIndexedLocalComputerScope` - Indexed local volumes

---

## Complexity Encountered

### 1. NSMetadataQuery Predicate Limitations
**Issue**: NSMetadataQuery doesn't support all NSPredicate operations directly.
**Solution**: Used custom predicate blocks with `NSMetadataQueryPredicateItem` for flexible string matching.

### 2. Asynchronous Search Behavior
**Issue**: NSMetadataQuery returns results asynchronously via notifications, but we need synchronous results for immediate display.
**Solution**: Used `gatherUntilTimeout()` for synchronous search with a timeout fallback.

### 3. Performance Considerations
**Issue**: Searching entire Spotlight index can be slow.
**Solution**:
- Limited search scope to indexed local computer
- Implemented debouncing (150ms delay)
- Added max results limit
- Sorted by modification date for relevance

### 4. Privacy - Excluded Directories
**Issue**: Should not expose files in hidden or private directories.
**Solution**: Created excluded directories set:
- `.git`, `node_modules`, `.npm`, `.venv`, `venv`, `build`, `DerivedData`, `.cache`
- Also excludes paths starting with `.` (except `.### 5. Integration with SearchEnginelocalized`)


**Issue**: Need to support both general search and "file:" prefix for file-specific search.
**Solution**: Added prefix detection and conditional search logic.

---

## Scripts/Automations That Would Help

### 1. Spotlight Index Debug Tool
Script to verify Spotlight is indexing the expected directories:
```bash
# Check Spotlight indexing status
mdimport -r ~/Documents
mdimport -r ~/Downloads
mdimport -r ~/Desktop

# List indexed items
mdfind -name "searchterm"
```

### 2. Performance Testing Script
Benchmark file search latency:
```swift
// Measure search time
let start = CFAbsoluteTimeGetCurrent()
let results = FileSearchService.shared.searchSync(query: "test", maxResults: 10)
let elapsed = CFAbsoluteTimeGetCurrent() - start
print("Search took \(elapsed * 1000)ms")
```

### 3. Excluded Paths Validator
Verify that privacy exclusions work correctly by attempting to search for files in excluded directories.

---

## Lessons Learned

### 1. Spotlight Is Not Real-Time
Spotlight index updates are not immediate. For real-time file search, consider:
- Using FSEvents for file system monitoring
- Building a custom index with periodic updates
- Accepting slight delay for comprehensive results

### 2. Query Scope Matters
- `NSMetadataQueryIndexedLocalComputerScope` is faster than `UserHomeScope`
- Narrower scopes = faster results
- Balance between comprehensiveness and speed

### 3. Fuzzy Matching in Spotlight
NSMetadataQuery's built-in fuzzy matching is limited. We added custom fuzzy scoring:
- Bonus for consecutive character matches
- Bonus for match at start of word
- Bonus for match after separators (-, _, space, .)

### 4. Async vs Sync Trade-offs
- Async: Better for large result sets, UI remains responsive
- Sync: Better for immediate feedback, simpler code
- Used sync with timeout for responsive feel without complexity

### 5. Cmd+Enter for Finder Reveal
From acceptance criteria: "When I press Cmd+Enter, Then the file reveals in Finder"
- This requires handling keyboard shortcuts at the UI level
- The FileSearchResult structure supports custom actions
- Need to integrate this in the UI layer (future task)

---

## Future Improvements

1. **Custom File Index**: Build a local index for faster searches
2. **FSEvents Monitoring**: Keep index updated in real-time
3. **File Type Filtering**: Add support for searching by file type (e.g., "pdf:", "doc:")
4. **Recent Files**: Prioritize recently modified files
5. **Cmd+Enter Handler**: Implement Finder reveal at UI level

---

## Files Modified

1. `/Sources/Services/FileSearchService.swift` (new)
2. `/Sources/Services/SearchEngine.swift` (modified)
