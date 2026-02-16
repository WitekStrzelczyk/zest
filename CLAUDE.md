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
