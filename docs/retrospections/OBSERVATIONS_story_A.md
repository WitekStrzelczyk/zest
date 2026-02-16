# OBSERVATIONS - Story A: Fix Duplicate Search Results

## Story Summary
Fixed bug where search results showed duplicate applications.

---

## Tools Used

| Tool | Purpose | Result |
|------|---------|--------|
| `Grep` | Find pending stories | ✅ |
| `Read` | Read SearchEngine.swift | ✅ |
| `Edit` | Fix deduplication logic | ✅ |
| `Bash` `swift build` | Verify fix compiles | ✅ |
| `Bash` `take_screenshots.sh` | Verify fix works | ✅ |

---

## Root Cause

Apps were appearing twice because:
1. Same app can exist in both `runningApplications` AND `/Applications` folder
2. Search results combined clipboard + app results without deduplication
3. No dedup by bundleID was happening

---

## Fix Applied

Added two-level deduplication:
1. **During app search:** Use `seenBundleIDs` Set to track unique bundleIDs
2. **Final pass:** Use `seenTitles` Set to prevent any duplicates

```swift
var seenBundleIDs: Set<String> = []
// ... during mapping ...
guard !seenBundleIDs.contains(item.app.bundleID) else { return nil }
seenBundleIDs.insert(item.app.bundleID)

// Final deduplication pass
var seenTitles: Set<String> = []
```

---

## Acceptance Criteria Status

| Criterion | Status |
|-----------|--------|
| "sa" shows FaceTime only once | ✅ Verified in screenshot |
| "saf" shows Safari only once | ✅ Verified in screenshot |
| No duplicates in results | ✅ |

---

## Lessons Learned

1. **Screenshot testing works** - Automated screenshots helped catch and verify the fix
2. **Set-based deduplication** - Using Set for O(1) lookups is efficient
3. **Two-pass dedup** - Sometimes need multiple passes for complete dedup

---

## Next Steps

- Story 4: Window Tiling (needs Accessibility API)
- Story 9: Calculator (simple to add)
- Story 10: Emoji Picker

---

*Generated: 2026-02-14*
