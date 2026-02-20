# Observations: Unit Converter Business Scenarios

Date: 2026-02-20
Agent: reflective-coding-agent

## Problem Solved
Added comprehensive test coverage for Story 23 (Unit Conversion) including edge cases, bidirectional conversions, temperature variations, data units, case sensitivity, and decimal precision. Fixed issues with negative number support and kilo suffix handling.

---

## For Future Self

### How to Prevent This Problem
- [ ] Always run full business scenario tests after implementing a feature
- [ ] Check edge cases: empty input, whitespace, negative numbers
- [ ] Test common user mistakes: no space between value and unit
- [ ] Test bidirectional conversions (both directions)
- [ ] Test all variations (temperature: f→c, c→f, f→k, k→f)
- [ ] Update TDD guidelines to emphasize RED phase planning

### How to Find Solution Faster
- **Key insight:** The `isMathExpression` function was rejecting valid unit conversions because "-" was detected as a math operator
- **Search that works:** `grep -r "isMathExpression" Sources/`
- **Start here:** `UnitConverter.swift` - check `isConversionExpression` first
- **Debugging step:** Add print statements to trace where conversion fails

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| Debug test output | Found `isMathExpression` returning true for "-100 km to miles" |
| grep "isConversionExpression" | Traced the flow from convert() → isConversionExpression() |
| Test-driven approach | Each failing test defined a specific requirement |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Initially focusing on regex only | Regex was fine, issue was upstream in isMathExpression check |
| Changing unit display logic | Made things worse by breaking existing tests |

---

## Agent Self-Reflection

### My Approach
1. Added comprehensive new tests for business scenarios
2. Ran tests to see failures (RED state verification)
3. Fixed issues one by one:
   - Fixed negative number support by adding conversion indicator check to Calculator
   - Fixed kilo suffix by adding 'k' to regex character class
4. Verified all 51 tests pass

### What Was Critical for Success
- **Key insight:** Adding debug output to tests to trace where `isConversionExpression` returns false
- **Finding:** The Calculator's `isMathExpression` was incorrectly classifying "-100 km to miles" as a math expression
- **Fix:** Added conversion indicator check ("to ", " in ", "->") to reject unit conversions early

### What I Would Do Differently
- [ ] Add comprehensive tests for business scenarios earlier in development
- [ ] Test edge cases like negative numbers from the start
- [ ] Create a checklist of business scenarios to test for each feature

### TDD Compliance
- [x] Wrote test first (RED) - Added new tests, saw them fail
- [x] Minimal implementation (GREEN) - Fixed issues with targeted code changes
- [x] Refactored while green - Cleaned up debug output, verified tests pass
- [x] Verified build compiles with zero warnings

---

## Code Changed
- `Tests/UnitConverterTests.swift` - Added 30 new business scenario tests
- `Sources/Services/UnitConverter.swift` - Added negative number and kilo suffix support
- `Sources/Services/Calculator.swift` - Added conversion indicator check to prevent false positives
- `docs/TDD_GUIDELINES.md` - Updated to better explain RED phase and API planning

## Tests Added
- Edge cases: empty input, whitespace handling, no space between value/unit
- Common user mistakes: "100km to miles", "100k m to cm" (k suffix)
- Bidirectional: miles↔km, kg↔lbs
- All temperature variations: f↔c, f↔k, c↔k
- Data units: KB↔B, GB↔MB
- Case sensitivity: "KM to Miles" vs "km to miles"
- Decimal precision and rounding

## Verification
```bash
swift test --filter UnitConverterTests
# Executed 51 tests, with 0 failures

swift build
# Build complete! (0.22s) - no warnings
```
