# Documentation Index

This index provides a categorized overview of all Zest project documentation.

## Categories

### Architecture

System design and architectural decisions.

| Document | Summary |
|----------|---------|
| [architecture/README.md](/Users/witek/projects/copies/zest/docs/architecture/README.md) | System architecture overview |
| [architecture/calendar-cache.md](/Users/witek/projects/copies/zest/docs/architecture/calendar-cache.md) | Cache-first calendar search pattern |
| [DESIGN.md](/Users/witek/projects/copies/zest/docs/DESIGN.md) | Product design document |

### Guides

How-to documentation for common tasks.

| Document | Summary |
|----------|---------|
| [guides/README.md](/Users/witek/projects/copies/zest/docs/guides/README.md) | All guides index |
| [TDD Guidelines](/Users/witek/projects/copies/zest/docs/TDD_GUIDELINES.md) | Test-driven development workflow |
| [FAQ.md](/Users/witek/projects/copies/zest/docs/FAQ.md) | Common problems and solutions |

### How-To

Step-by-step tutorials for specific tasks.

| Document | Summary |
|----------|---------|
| [how-to/demo-recording.md](/Users/witek/projects/copies/zest/docs/how-to/demo-recording.md) | Recording feature demos with ffmpeg |
| [how-to/add-scheduled-task.md](/Users/witek/projects/copies/zest/docs/how-to/add-scheduled-task.md) | Adding recurring background tasks |
| [how-to/add-llm-tool.md](/Users/witek/projects/copies/zest/docs/how-to/add-llm-tool.md) | Adding new LLM-powered tools |

### Reference

API documentation and technical specifications.

| Document | Summary |
|----------|---------|
| [reference/README.md](/Users/witek/projects/copies/zest/docs/reference/README.md) | API reference index |

### Quality

Quality metrics and tooling documentation.

| Document | Summary |
|----------|---------|
| [quality/README.md](/Users/witek/projects/copies/zest/docs/quality/README.md) | Quality metrics overview |

### Retrospections

Implementation learnings and observations from agent work.

| Document | Summary |
|----------|---------|
| [CONSOLIDATED_LEARNINGS.md](/Users/witek/projects/copies/zest/docs/retrospections/CONSOLIDATED_LEARNINGS.md) | Consolidated technical learnings |

## Story Implementation Map

| Story | Feature | Documentation |
|-------|---------|---------------|
| 1 | Global Command Palette | [OBSERVATIONS_story_001.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_001.md) |
| 2 | Fuzzy Search | [OBSERVATIONS_story_002.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_002.md) |
| 4 | Window Tiling | [OBSERVATIONS_story_004.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_004.md) |
| 5 | Window Movement | [OBSERVATIONS_story_005.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_005.md) |
| 6 | Clipboard History | [OBSERVATIONS_story_006.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_006.md) |
| 7 | Script Execution | [OBSERVATIONS_story_007.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_story_007.md) |
| 8 | File Search | [OBSERVATIONS_Story8_FileSearch.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_Story8_FileSearch.md) |
| 11 | Snippets | [OBSERVATIONS_stories_implementation.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_stories_implementation.md) |
| 12 | System Control | [OBSERVATIONS_stories_implementation.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_stories_implementation.md) |
| 14 | Reminders | [OBSERVATIONS_integration_14_15.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_integration_14_15.md) |
| 15 | Notes | [OBSERVATIONS_integration_14_15.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_integration_14_15.md) |
| 16 | Focus Mode | [OBSERVATIONS_focus_extensions_16_17.md](/Users/witek/projects/copies/zest/docs/retrospections/OBSERVATIONS_focus_extensions_16_17.md) |

## Quick Access

- **Build**: `swift build`
- **Test**: `./scripts/run_tests.sh`
- **Quality**: `./scripts/quality.sh`
- **Lint**: `swiftlint Sources`
- **Format**: `swiftformat Sources`
- **Demo Recording**: `./scripts/demo-recording.sh demo.mp4`
- **Window Coords**: `./scripts/get-window-coords.sh Zest`

---

*Last reviewed: 2026-02-28*
