# Zest Retrospection - Improvement Stories

**Analysis Date:** 2026-02-19  
**Score:** 73/100  
**Gap to 100:** 27 points

---

## Problem Summary

| Category | Count | Severity |
|----------|-------|----------|
| NEW problems | 75 | First snapshot |
| File length violations | 5 files | 1 SERIOUS |
| Line length violations | ~20 | Medium |
| Trailing comma violations | ~20 | Low |
| Function body length violations | 5 | Medium |
| SwiftLint config issues | 3 | Medium |
| Test timeout | 1 | High |

---

## [ ] Story R1: Fix SwiftLint Configuration

**As a** maintainer  
**I want** valid SwiftLint configuration so that the linter runs without warnings about invalid rules

**So that** CI/CD pipelines are reliable and new team members have accurate rule documentation

### Baseline
- `variable_name` rule is deprecated (renamed to `identifier_name`)
- `unused_code` is not a valid rule identifier
- `unused_declaration` listed twice in config

### Measurable Target
- SwiftLint runs with 0 config warnings

### Acceptance Criteria

- [ ] **Given** `.swiftlint.yml` file, **When** it contains `variable_name`, **Then** it should be replaced with `identifier_name`
- [ ] **Given** `.swiftlint.yml` file, **When** it contains `unused_code`, **Then** it should be removed (not a valid rule)
- [ ] **Given** `.swiftlint.yml` file, **When** `unused_declaration` appears twice, **Then** duplicate should be removed
- [ ] **Given** SwiftLint runs, **When** executed with `--config-warning`, **Then** no warnings about invalid rules appear

### Verification Command
```bash
swiftlint 2>&1 | grep -E "warning.*valid rule|not a valid rule" | wc -l
# Expected: 0
```

---

## [ ] Story R2: Reduce CommandPaletteWindow File Length

**As a** maintainer  
**I want** CommandPaletteWindow.swift under 1000 lines so that the code is easier to navigate and maintain

**So that** new developers can understand the code structure more easily and bugs are easier to isolate

### Baseline
- Current: 1352 lines
- Limit: 1000 lines
- Over: 352 lines

### Measurable Target
- File length < 1000 lines

### Additional Files to Review
| File | Current Lines | Target |
|------|---------------|--------|
| EmojiData.swift | 582 | < 400 |
| WindowManager.swift | 490 | < 400 |
| SearchEngine.swift | 460 | < 400 |
| PerformanceMetrics.swift | 407 | < 400 |

### Acceptance Criteria

- [ ] **Given** CommandPaletteWindow.swift, **When** line count is measured, **Then** it should be under 1000 lines
- [ ] **Given** search results display logic, **When** it exists in CommandPaletteWindow, **Then** it should be extracted to CommandPaletteWindow+SearchResults.swift
- [ ] **Given** settings UI logic, **When** it exists in CommandPaletteWindow, **Then** it should be extracted to CommandPaletteWindow+Settings.swift
- [ ] **Given** action handlers, **When** they exist in CommandPaletteWindow, **Then** they should be extracted to dedicated handler classes
- [ ] **Given** SwiftLint runs, **When** file_length rule is evaluated, **Then** no file_length errors occur

### Verification Command
```bash
wc -l Sources/UI/CommandPalette/CommandPaletteWindow.swift
# Expected: < 1000
```

---

## [ ] Story R3: Fix Line Length Violations

**As a** maintainer  
**I want** all code lines under 120 characters so that code is readable in narrow editor windows

**So that** code is readable on laptops with smaller screens and diff views in PRs are cleaner

### Baseline
- Current: ~20 violations
- Limit: 120 characters

### Most Affected Files
- AIService.swift
- CommandPaletteWindow.swift
- Snippet.swift

### Acceptance Criteria

- [ ] **Given** AIService.swift, **When** lines are measured, **Then** all lines should be <= 120 characters
- [ ] **Given** CommandPaletteWindow.swift, **When** lines are measured, **Then** all lines should be <= 120 characters
- [ ] **Given** Snippet.swift, **When** lines are measured, **Then** all lines should be <= 120 characters
- [ ] **Given** SwiftLint runs, **When** line_length rule is evaluated, **Then** 0 violations are reported

### Verification Command
```bash
swiftlint 2>&1 | grep "Line should be 120" | wc -l
# Expected: 0
```

---

## [ ] Story R4: Fix Trailing Comma Violations

**As a** maintainer  
**I want** consistent code style without trailing commas so that diffs are cleaner

**So that** Git diffs show only meaningful changes and code reviews are faster

### Baseline
- Current: ~20 violations
- Location: Multiple collection literals across files

### Acceptance Criteria

- [ ] **Given** collection literals in the codebase, **When** formatted, **Then** they should not have trailing commas
- [ ] **Given** SwiftLint runs, **When** trailing_comma rule is evaluated, **Then** 0 violations are reported
- [ ] **Given** a git diff, **When** changes to collection literals are viewed, **Then** trailing comma changes should not appear

### Verification Command
```bash
swiftlint 2>&1 | grep "trailing comma" | wc -l
# Expected: 0
```

---

## [ ] Story R5: Reduce Function Body Length

**As a** maintainer  
**I want** functions under 50 lines so that each function has a single clear purpose

**So that** functions are easier to test in isolation and code is easier to refactor

### Baseline
- Current: 5 functions exceed 50 lines
- Warning limit: 50 lines
- Error limit: 100 lines

### Affected Functions

| File | Function | Current Lines |
|------|----------|---------------|
| CommandPaletteWindow.swift | Function 1 | 76 |
| CommandPaletteWindow.swift | Function 2 | 64 |
| CommandPaletteWindow.swift | Function 3 | 67 |
| SearchEngine.swift | Function 4 | 74 |
| SearchEngine.swift | Function 5 | 93 |

### Acceptance Criteria

- [ ] **Given** CommandPaletteWindow.swift functions, **When** evaluated, **Then** all functions should be < 50 lines
- [ ] **Given** SearchEngine.swift functions, **When** evaluated, **Then** all functions should be < 50 lines
- [ ] **Given** complex logic, **When** extracted into helper functions, **Then** each function has a single clear purpose
- [ ] **Given** SwiftLint runs, **When** function_body_length rule is evaluated, **Then** 0 warnings are reported

### Verification Command
```bash
swiftlint 2>&1 | grep "Function body should span" | wc -l
# Expected: 0
```

---

## [ ] Story R6: Fix Test Timeout Issue

**As a** developer  
**I want** tests to complete reliably so that I can verify my changes quickly

**So that** CI/CD pipelines are more reliable and developers don't waste time waiting for test fixes

### Baseline
- Current: Tests timeout at 40 seconds
- Previous attempts: Timeout increased to 40s in scripts/run_tests.sh

### Root Cause
- Likely SearchEngineTests with CoreData operations
- Complex search operations with CoreData queries

### Measurable Target
- Tests complete in < 60 seconds

### Acceptance Criteria

- [ ] **Given** SearchEngineTests, **When** they run, **Then** they should complete within 60 seconds
- [ ] **Given** all tests, **When** executed via run_tests.sh, **Then** timeout should be set to 60 seconds
- [ ] **Given** CoreData operations in tests, **When** they are slow, **Then** they should be optimized or mocked
- [ ] **Given** async test operations, **When** they hang, **Then** they should have proper cancellation handling

### Recommended Approach

1. Increase timeout to 60s in scripts/run_tests.sh
2. Isolate CoreData-dependent tests
3. Mock CoreData in unit tests where possible
4. Add async/await with proper timeout handling

### Verification Command
```bash
./scripts/run_tests.sh 60
# Expected: All tests pass within 60 seconds
```

---

## Verification Summary

Run these commands to verify all stories are complete:

```bash
# Story R1: SwiftLint config
swiftlint 2>&1 | grep -E "warning.*valid rule|not a valid rule" | wc -l
# Expected: 0

# Story R2: File length
wc -l Sources/UI/CommandPalette/CommandPaletteWindow.swift
# Expected: < 1000

# Story R3: Line length
swiftlint 2>&1 | grep "Line should be 120" | wc -l
# Expected: 0

# Story R4: Trailing comma
swiftlint 2>&1 | grep "trailing comma" | wc -l
# Expected: 0

# Story R5: Function body length
swiftlint 2>&1 | grep "Function body should span" | wc -l
# Expected: 0

# Story R6: Test timeout
./scripts/run_tests.sh 60
# Expected: All tests pass
```

---

## Quality Gate

All 6 stories must pass verification before the next retrospection cycle.

**Target Score:** 100/100
