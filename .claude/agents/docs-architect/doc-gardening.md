# Doc-Gardening Playbook

Procedures for maintaining documentation freshness and quality through automated and manual processes.

## Why Doc-Gardening?

Documentation has natural entropy:

- Code changes, docs don't
- Links rot over time
- Patterns evolve, old docs remain
- New features lack documentation
- Team knowledge isn't captured

Regular maintenance prevents compound decay.

## Freshness Metadata

### Required Frontmatter

```yaml
---
last_reviewed: 2026-02-13
review_cycle: quarterly | monthly | weekly
status: current | stale | needs-review | deprecated
owner: team-or-person
---
```

### Status Definitions

| Status | Meaning | Action |
|--------|---------|--------|
| `current` | Recently verified accurate | No action needed |
| `needs-review` | Due for review | Schedule review |
| `stale` | Known to be outdated | Update or deprecate |
| `deprecated` | No longer relevant | Mark for removal |

## Automated Checks

### 1. Link Validation

Check all internal links resolve:

```bash
# Example script structure
for file in docs/**/*.md; do
  extract_links "$file" | while read link; do
    if ! resolves "$link"; then
      report_broken "$file" "$link"
    fi
  done
done
```

### 2. Freshness Linting

Flag documents past their review cycle:

```bash
# Pseudocode
for file in docs/**/*.md; do
  last_reviewed=$(get_frontmatter "$file" last_reviewed)
  cycle=$(get_frontmatter "$file" review_cycle)
  if is_overdue "$last_reviewed" "$cycle"; then
    set_frontmatter "$file" status "needs-review"
  fi
done
```

### 3. Coverage Check

Ensure code has corresponding documentation:

```bash
# For each major module
for module in src/*/; do
  if ! has_doc "docs/reference/${module}.md"; then
    report_missing_doc "$module"
  fi
done
```

### 4. Code-Doc Synchronization

Detect when code and docs diverge:

```bash
# Compare documented APIs with actual endpoints
diff <(extract_api_docs docs/reference/api/) \
     <(extract_api_routes src/routes/)
```

## Doc-Gardening Workflow

### Weekly Tasks

1. **Run automated checks**
   - Link validation
   - Freshness linting
   - Coverage report

2. **Triage results**
   - Categorize issues by severity
   - Assign owners
   - Create tracking issues

3. **Quick fixes**
   - Fix broken links
   - Update timestamps after review
   - Mark deprecated content

### Monthly Tasks

1. **Review needs-review documents**
   - Verify accuracy
   - Update content
   - Refresh metadata

2. **Quality grade updates**
   - Assess each documentation area
   - Update quality scores
   - Identify improvement targets

3. **Orphan detection**
   - Find docs with no incoming links
   - Add to indexes or remove
   - Ensure discoverability

### Quarterly Tasks

1. **Architecture review**
   - Does doc structure still make sense?
   - Are categories still relevant?
   - Is the entry point still accurate?

2. **Beliefs review**
   - Are core beliefs still true?
   - Do we need new beliefs?
   - Should any be retired?

3. **Retirement planning**
   - Identify deprecated content
   - Archive or remove
   - Update indexes

## Quality Grading

### Grade Categories

| Grade | Meaning | Target |
|-------|---------|--------|
| A | Excellent, comprehensive, current | Maintain |
| B | Good, minor gaps or staleness | Improve |
| C | Adequate, needs work | Prioritize |
| D | Poor, significant issues | Urgent attention |
| F | Missing or severely outdated | Critical |

### Grading Criteria

Score each area on:

1. **Accuracy** (0-25): Does it reflect current reality?
2. **Completeness** (0-25): Are all topics covered?
3. **Discoverability** (0-25): Can readers find it?
4. **Freshness** (0-25): Is it recently reviewed?

### Tracking Format

```markdown
# Documentation Quality

Last updated: 2026-02-13

## By Domain

| Domain | Grade | Accuracy | Complete | Discover | Fresh | Notes |
|--------|-------|----------|----------|----------|-------|-------|
| API | B | 20 | 22 | 18 | 20 | Missing rate limit docs |
| Architecture | A | 24 | 23 | 24 | 23 | Strong cross-links |
| Guides | C | 15 | 18 | 20 | 12 | Many stale |

## Trends

- API: B → B (stable)
- Architecture: B → A (improved)
- Guides: B → C (declined)
```

## Recurring Agent Tasks

### Doc-Gardening Agent

Run an agent on schedule to:

1. Scan for stale documents
2. Check for broken links
3. Verify code-doc alignment
4. Open fix-up pull requests

Example agent prompt:

```
Scan docs/ directory for:
1. Documents with status "needs-review" - review and update
2. Documents older than review_cycle - mark for review
3. Broken internal links - fix or report
4. Missing documentation for new code - flag for creation

Open targeted PRs for each category of fix.
```

### Quality Agent

Run monthly to update quality grades:

```
Review each documentation domain:
1. Sample 5 documents per domain
2. Grade on accuracy, completeness, discoverability, freshness
3. Update docs/quality/grades.md
4. Flag domains with declining grades
```

## Integration with CI

### Pre-commit Hooks

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: doc-freshness
        name: Check doc freshness
        entry: scripts/check-doc-freshness.sh
        files: docs/.*\.md
      - id: doc-links
        name: Check doc links
        entry: scripts/check-doc-links.sh
        files: docs/.*\.md
```

### CI Pipeline

```yaml
# .github/workflows/docs.yml
name: Documentation Checks

on:
  pull_request:
    paths: ['docs/**']

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Check links
        run: ./scripts/check-doc-links.sh
      - name: Check freshness
        run: ./scripts/check-doc-freshness.sh
      - name: Check coverage
        run: ./scripts/check-doc-coverage.sh
```

## Handling Stale Documentation

### When Docs Are Wrong

1. **Fix immediately** if trivial
2. **Create issue** if substantial
3. **Mark stale** if can't fix now
4. **Deprecate** if no longer relevant

### Deprecation Process

```markdown
---
status: deprecated
deprecated_date: 2026-02-13
replacement: docs/new-location.md
---

# [DEPRECATED] Old Title

> This document is deprecated. See [New Document](new-location.md) instead.

Content preserved for historical reference...
```

### Removal Process

1. Mark as deprecated
2. Wait one review cycle
3. Verify no incoming links
4. Remove and update indexes

## Templates

### Doc-Gardening Report

```markdown
# Doc-Gardening Report - YYYY-MM-DD

## Summary

- Total documents: X
- Current: X (X%)
- Needs review: X (X%)
- Stale: X (X%)
- Deprecated: X (X%)

## Issues Found

### Broken Links (X)

| File | Link | Action |
|------|------|--------|
| file.md | [broken](link) | Fixed |

### Overdue Reviews (X)

| File | Last Reviewed | Cycle |
|------|---------------|-------|
| file.md | 2025-01-01 | quarterly |

### Missing Coverage (X)

| Code | Missing Doc |
|------|-------------|
| src/module/ | docs/reference/module.md |

## Actions Taken

1. Fixed X broken links
2. Marked X documents for review
3. Created X missing docs
4. Deprecated X obsolete docs
```
