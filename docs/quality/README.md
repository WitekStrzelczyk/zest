# Quality Metrics

Quality assurance infrastructure and metrics for the Zest project.

## Quality Pipeline

Run `./scripts/quality.sh` to execute the full pipeline:

1. **Format** - SwiftFormat
2. **Lint** - SwiftLint
3. **Build** - `swift build`
4. **Test** - `swift test` with 40s timeout
5. **Coverage** - xccov reports

## Current Metrics

### Test Execution

| Metric | Current | Target |
|--------|---------|--------|
| Test execution time | ~40s (timeout) | <30s |
| Test count | 85+ | - |
| Test files | 15 | - |

### Code Quality

| Tool | Status | Version |
|------|--------|---------|
| SwiftLint | Active | 0.63.2 |
| SwiftFormat | Active | 0.59.1 |

### Coverage

- **Minimum threshold:** 50%
- **Gate enforced:** Yes (via quality.sh)

## SwiftLint Rules

Configured in `.swiftlint.yml`:

| Rule | Severity | Configuration |
|------|----------|---------------|
| force_cast | Error | - |
| cyclomatic_complexity | Warning | 10, Error 20 |
| function_body_length | Warning | 50, Error 100 |
| type_name | Warning | min 3, max 50 |
| identifier_name | Warning | min 1, max 50 |
| unused_declaration | Analyzer | - |

## Common Issues

See [OBSERVATIONS_test_automation_review.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_test_automation_review.md) for detailed analysis.

### Known Violations (as of last review)

- 34 total SwiftLint violations
- 12 serious (force_cast, identifier_name, type_body_length)
- Primary files: WindowManager, EmojiSearchService

### Test Timeouts

- Tests timeout at 40 seconds
- Root cause: mdfind/Spotlight queries in tests
- Solution: Use NSMetadataQuery (implemented)

## Debugging Commands

```bash
# Run quality checks
./scripts/quality.sh

# Run tests with timeout
./scripts/run_tests.sh

# Run single test
swift test --filter TestName

# Run with coverage
swift test --enable-code-coverage

# Run SwiftLint
swiftlint Sources

# Run SwiftFormat
swiftformat Sources
```

## Related Documentation

- [TDD Guidelines](/Users/witek/projects/copies/zest/docs/TDD_GUIDELINES.md)
- [OBSERVATIONS_debt_implementation.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_debt_implementation.md) - Diagnostics and benchmarks

---

*Last reviewed: 2026-02-14*
