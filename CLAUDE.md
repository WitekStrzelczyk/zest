# Zest Project

## Agent Workflow (IMPORTANT)

**Follow this exact workflow for ALL tasks:**

```
1. product-owner    → Research & create stories
2. reflective-coding-agent → Implement code (RED → GREEN → verify build)
3. retrospection-agent  → Document learnings & create OBSERVATIONS
```

### NEVER write code directly - ALWAYS use agents above.

## Project Structure

```
Zest/
├── Sources/          # Swift source code
├── Tests/           # Unit tests (XCTest)
├── scripts/         # Build & quality scripts
│   └── quality.sh   # Format → Lint → Build → Test → Coverage
├── docs/            # Documentation
│   └── retrospections/ # Implementation learnings
├── screenshots/     # Test screenshots
├── Package.swift    # Swift Package Manager
└── TODO.md         # User stories (features + QA)
```

## Quality Assurance Pipeline

Run `./scripts/quality.sh` to execute:

1. **Format** - SwiftFormat (if installed)
2. **Lint** - SwiftLint with rules for:
   - Unused code
   - Code complexity
   - Function size
   - Naming conventions
   - Security issues
3. **Build** - `swift build`
4. **Test** - `swift test --enable-code-coverage`
5. **Coverage** - xccov reports

## Mandatory Build Verification (IMPORTANT)

**ALWAYS verify build succeeds with ZERO warnings before considering any task complete.**

### Required Steps After Code Changes

1. **Build the project:**
   ```bash
   swift build 2>&1 | grep -E "(error:|warning:)"
   ```
   If ANY warnings appear, fix them before proceeding.

2. **Run the app to verify it launches:**
   ```bash
   swift run
   ```
   The app should build and run without errors.

3. **Run tests with timeout:**
   ```bash
   ./scripts/run_tests.sh 40
   ```

### Common Warning Types to Fix

| Warning | Cause | Fix |
|---------|-------|-----|
| `no calls to throwing functions occur within 'try' expression` | Using `try?` on non-throwing function | Remove `try?` |
| `initialization of immutable value was never used` | Unused variable | Use `_` or remove |
| `no 'async' operations occur within 'await' expression` | Using `await` on sync function | Remove `await` |

### Why This Matters

- Warnings indicate code quality issues
- Unused variables = dead code
- Incorrect `try?`/`await` = misunderstanding of API
- Zero warnings = clean, maintainable codebase

## Key Patterns

- Menu bar app (LSUIElement = true)
- NSPanel with .nonactivatingPanel for command palette
- Carbon API for global hotkey
- Fuzzy search with scoring algorithm
- TDD: Write tests first (RED), then implement (GREEN), verify build

## Mandatory Timeout Rule (IMPORTANT)

**ALWAYS use a 40-second timeout** for any test execution or background task that could hang.

### Why?
- Prevents infinite loops from freezing the test runner
- Prevents SwiftPM lock issues from hanging forever
- Prevents mdfind/Spotlight queries from blocking indefinitely

### For Tests
```bash
# Use the project's test script (recommended)
./scripts/run_tests.sh 40

# Or use perl alarm directly
perl -e 'alarm 40; exec @ARGV' swift test
```

### For Background Tasks
```bash
# Any command that could hang
perl -e 'alarm 40; exec @ARGV' <command>
```

### In Scripts
The `run_tests.sh` script already enforces this timeout by default (40s).

## CI / Continuous Integration

**Currently not using CI.** All quality checks are run locally via `./scripts/quality.sh`.

## Documentation

- All retrospective notes go in `/docs/retrospections/OBSERVATIONS_[story_name].md`
- Always document: tools used, complexity, lessons learned
