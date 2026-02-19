# Zest Documentation

A native macOS command palette application (Raycast alternative) providing quick access to apps, files, and system utilities.

## Quick Links

- [Architecture Overview](/Users/witek/projects/copies/zest/docs/architecture/README.md)
- [Implementation Guides](/Users/witek/projects/copies/zest/docs/guides/README.md)
- [API Reference](/Users/witek/projects/copies/zest/docs/reference/README.md)
- [Quality Metrics](/Users/witek/projects/copies/zest/docs/quality/README.md)

## Core Beliefs

1. **Privacy-first clipboard** - Always exclude password manager content
2. **Mode detection** - Single search bar handles multiple input types
3. **Visual feedback** - Users must always know what's happening
4. **TDD enforced** - Coverage gate catches missing tests
5. **40-second timeout** - Prevents development freezes
6. **Unified scoring** - Centralized relevance algorithm for all search results

## Getting Started

### Build & Run

```bash
swift build
swift run
```

### Quality Checks (Local Only)

This project does NOT use CI/CD. All quality checks run locally:

```bash
./scripts/quality.sh    # Full pipeline: format → lint → build → test → coverage
./scripts/run_tests.sh  # Just tests with 40s timeout
```

The quality pipeline includes:
- SwiftFormat (formatting)
- SwiftLint (linting)
- swift build (compilation)
- swift test (unit tests)
- xccov (code coverage)

## Key Features

| Feature | Story | Status |
|---------|-------|--------|
| Global Command Palette | 1 | Complete |
| Fuzzy Search | 2 | Complete |
| Unified Scoring | 2a | Complete |
| Window Tiling | 4 | Complete |
| Clipboard History | 6 | Complete |
| Script Execution | 7 | Complete |
| File Search | 8 | Complete |

## Documentation Structure

```
/docs/
├── README.md              # This file
├── INDEX.md               # Master index
├── DESIGN.md              # Product design document
├── architecture/          # System design
│   └── README.md
├── guides/                # How-to documentation
│   └── README.md
├── reference/             # API documentation
│   └── README.md
└── quality/               # Quality metrics
    └── README.md
```

## Related Documentation

- [TDD Guidelines](/Users/witek/projects/copies/zest/docs/TDD_GUIDELINES.md)
- [Consolidated Learnings](/Users/witek/projects/copies/zest/docs/retrospections/CONSOLIDATED_LEARNINGS.md)

---

*Last reviewed: 2026-02-19*
