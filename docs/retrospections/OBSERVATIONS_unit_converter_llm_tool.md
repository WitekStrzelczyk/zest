# Observations: Unit Converter LLM Tool Implementation

Date: 2026-02-28
Agent: reflective-coding-agent

## Problem Solved
Integrated the existing UnitConverter service with the LLM tool calling system, enabling natural language unit conversion commands like "100 km to miles" and "convert 50 kg to lbs" through the command palette.

---

## For Future Self

### How to Prevent This Problem

- [ ] **Always check existing switch statements** - When adding a new enum case, use `grep` to find ALL switch statements that need updating
- [ ] **Use exhaustive switch warning as guide** - The compiler will tell you which files need updates; fix them systematically
- [ ] **Validate regex patterns with edge cases** - Always test patterns with non-matching inputs (like "4 pm in the cinema")

Example: "Before adding a new LLMTool case, run `grep -r 'switch.*parameters' Sources/` to find all files needing updates"

### How to Find Solution Faster

- Key insight: The `inferUnitConversionParams` regex was matching text that wasn't actually a unit conversion
- Search that works: `grep -r "switch.*toolCall" Sources/`
- Start here: `Sources/Models/LLMToolCall.swift` - define the case first
- Debugging step: Add `isKnownUnit()` validation before returning conversion results

---

## What Helped

| Tool/Approach | How It Helped |
|---------------|---------------|
| Read `docs/how-to/add-llm-tool.md` | Provided the step-by-step pattern for adding new tools |
| Read existing tools (`createCalendarEvent`, `findFiles`) | Showed the exact pattern to follow |
| `swift test --filter LLMToolCatalogTests` | Quickly validated fallback parsing logic |
| `swift build 2>&1 \| grep -E "(error:\|warning:)"` | Caught all non-exhaustive switch errors |

## What Didn't Help

| Tool/Approach | Why It Wasted Time |
|---------------|-------------------|
| Manual tracing of regex patterns | Hard to mentally parse; should have written test cases first |
| Assuming "4 pm in the cinema" would match calendar | Didn't account for missing calendar keywords; test was wrong |
| Adding validation AFTER writing tests | TDD would have caught the regex bug earlier |

---

## Agent Self-Reflection

### My Approach
1. Read reference documentation - worked well, gave clear pattern
2. Read existing code - worked well, understood the architecture
3. Implemented changes - hit multiple non-exhaustive switch errors
4. Fixed switch statements - found 3 additional files needing updates
5. Wrote tests - discovered regex bug with "how many" pattern
6. Fixed regex and validation - tests passed

### What Was Critical for Success
- **Key insight:** The regex pattern `how many X in Y Z` has a different group ordering than `X Y to Z`
- **Right tool:** The reference documentation (`docs/how-to/add-llm-tool.md`) was essential
- **Right question:** "What happens when non-unit text like '4 pm in the cinema' is passed?"

### What I Would Do Differently
- [ ] Use `grep -r "switch.*toolCall"` or `grep -r "switch.*parameters"` BEFORE building to find all affected files
- [ ] Write test cases BEFORE implementing regex patterns
- [ ] Check for "known unit" validation requirement upfront

### TDD Compliance
- [x] Wrote test first (Red) - Added tests for unit conversion parsing
- [x] Minimal implementation (Green) - Implemented parsing and execution
- [x] Refactored while green - Fixed regex pattern and validation
- Tests revealed the bug: `inferUnitConversionParams` was matching non-unit text

---

## Code Changed

- `Sources/Models/LLMToolCall.swift` - Added `UnitConversionParams` struct, `convertUnits` case to enums
- `Sources/Services/LLMToolCatalog.swift` - Added schema, fallback parsing, payload mapping, validation
- `Sources/Services/LLMToolExecutor.swift` - Added `conversionFailed` error case and `executeUnitConversion()` method
- `Sources/State/CommandPaletteStateStore.swift` - Added `convertUnits` intent type and context entities
- `Sources/State/CommandPaletteController.swift` - Added `syntheticUnitConversionResult()` method and switch cases
- `Tests/LLMToolCatalogTests.swift` - Added 7 new tests for unit conversion fallback parsing

## Tests Added

- `LLMToolCatalogTests` - `testFallbackParseUnitConversionKmToMiles` - Basic pattern matching
- `LLMToolCatalogTests` - `testFallbackParseUnitConversionFahrenheitToCelsius` - Temperature conversion
- `LLMToolCatalogTests` - `testFallbackParseUnitConversionConvertKeyword` - "convert X Y to Z" pattern
- `LLMToolCatalogTests` - `testFallbackParseUnitConversionHowMany` - "how many X in Y Z" pattern
- `LLMToolCatalogTests` - `testFallbackParseUnitConversionDoesNotMatchUnknownUnits` - Validation check
- `LLMToolCatalogTests` - `testMapPayloadToToolCallForConvertUnits` - LLM payload mapping
- `LLMToolCatalogTests` - `testFunctionGemmaDeclarationsContainConvertUnits` - Schema verification

## Verification

```bash
# Build with zero warnings
swift build 2>&1 | grep -E "(error:|warning:)" && echo "FAILED" || echo "SUCCESS"

# Run all related tests
swift test --filter "UnitConverter|LLMToolCatalog|LLMToolExecutor"
# Result: 85 tests passed, 0 failures

# Run the app
./scripts/run_app.sh
# Test: Open command palette, type "=100 km to miles", verify conversion result
```

## Key Lessons

1. **Pattern Order Matters**: When regex patterns have different group orders (like "how many X in Y Z"), handle them explicitly with a flag or separate pattern type
2. **Validate Early**: Add validation (like `isKnownUnit()`) before returning results, not after
3. **Check All Switches**: When adding enum cases, search the entire codebase for switch statements
4. **Test Edge Cases**: Always test what happens when input almost matches but shouldn't
