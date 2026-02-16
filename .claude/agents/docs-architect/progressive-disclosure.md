# Progressive Disclosure Implementation Patterns

Detailed guide on implementing progressive disclosure in documentation systems.

## The Problem

Traditional documentation fails for both humans and agents when:

- Everything is in one giant file
- Entry points require reading everything
- No clear navigation hierarchy
- Information is duplicated and drifts apart
- Stale content is indistinguishable from current

## The Solution: Layered Disclosure

### Layer 1: Entry Point (50-100 lines)

The entry point serves as a map, not a manual.

**Purpose:** Orient the reader and point to deeper sources.

**Contents:**
- Project description (1-2 sentences)
- Quick links to major documentation areas
- 3-5 core beliefs or invariants (one-line each)
- Where to find help

**Example:**

```markdown
# Project Alpha

A service for processing widget requests.

## Quick Navigation

- [Architecture](docs/architecture/) - System design and decisions
- [API Reference](docs/reference/api/) - Endpoint documentation
- [Contributing](docs/guides/contributing/) - Development setup

## Core Beliefs

1. **Parse at boundaries** - Validate all external input
2. **Fail fast** - Surface errors immediately
3. **Log structurally** - Machine-readable logs everywhere

## Getting Help

See [troubleshooting](docs/guides/troubleshooting.md) or open an issue.
```

### Layer 2: Category Indexes (100-200 lines)

Each documentation category has its own index.

**Purpose:** Provide context and summaries for a domain.

**Contents:**
- Category description
- Categorized list of documents with 1-line summaries
- Links to related categories
- Freshness/verification status

**Example:**

```markdown
# Architecture Documentation

System design documents for Project Alpha.

## Overview

These documents describe the high-level architecture,
key decisions, and design patterns used in the system.

## Documents

### Decisions

| Document | Summary | Status |
|----------|---------|--------|
| [ADR-001: Use PostgreSQL](decisions/adr-001.md) | Primary database choice | Current |
| [ADR-002: Event sourcing](decisions/adr-002.md) | Event model for state | Current |

### Patterns

| Document | Summary | Status |
|----------|---------|--------|
| [Repository Pattern](patterns/repository.md) | Data access abstraction | Current |
| [CQRS](patterns/cqrs.md) | Read/write separation | Needs Review |

## Related

- [Beliefs](../beliefs/) - Core principles driving architecture
- [API Reference](../reference/api/) - Endpoint specifications

## Verification

- Last reviewed: 2026-02-13
- Review cycle: monthly
```

### Layer 3: Detailed Documents (Variable length)

Individual documents provide depth on specific topics.

**Purpose:** Comprehensive coverage of a single topic.

**Contents:**
- Clear title and summary
- Detailed explanation
- Code examples
- Cross-references
- Metadata for tracking

### Layer 4: Executable Specifications

Tests that encode documented behavior.

**Purpose:** Ensure documentation matches implementation.

**Pattern:**

```markdown
## Behavior

As documented in [api-spec](../reference/api/spec.md):

- Endpoint returns 400 for invalid input
- Endpoint returns 404 for missing resources
- Endpoint returns 200 with data for valid requests
```

```typescript
// Test that validates documented behavior
describe('API behavior per spec', () => {
  it('returns 400 for invalid input', async () => {
    const response = await request.post('/api/widgets').send({ invalid: true });
    expect(response.status).toBe(400);
  });
});
```

## Cross-Linking Strategy

### Bidirectional Links

Documents should reference each other:

```markdown
<!-- In docs/architecture/decisions/adr-001.md -->
Related: [ADR-002: Event sourcing](adr-002.md)

<!-- In docs/architecture/decisions/adr-002.md -->
Related: [ADR-001: Use PostgreSQL](adr-001.md)
```

### Upward References

Always link back to parent index:

```markdown
<!-- At the top of detailed docs -->
> Part of [Architecture Documentation](../README.md)
```

### Lateral References

Link to related documents in other categories:

```markdown
## See Also

- [API Reference](../../reference/api/endpoints.md) - Endpoint details
- [Contributing Guide](../../guides/contributing.md) - How to modify
```

## Navigation Patterns

### Breadcrumbs

Include path context in documents:

```markdown
# ADR-001: Use PostgreSQL

[Architecture](../) > [Decisions](./) > ADR-001
```

### Tags

Use consistent tags for discovery:

```markdown
---
tags: [architecture, database, decision]
---
```

### Search Optimization

Structure for agent searchability:

- Use consistent naming conventions
- Include keywords in summaries
- Place important terms in headings

## Avoiding Common Pitfalls

### Duplication

**Problem:** Same information in multiple places drifts apart.

**Solution:** Single source of truth with links.

```markdown
<!-- Don't -->
See the API documentation for rate limits (5 req/sec).

<!-- Do -->
See [Rate Limits](../reference/api/rate-limits.md) for current values.
```

### Implicit References

**Problem:** "As mentioned above" fails when document is read in parts.

**Solution:** Explicit links.

```markdown
<!-- Don't -->
As discussed earlier, we use PostgreSQL.

<!-- Do -->
As discussed in [ADR-001](decisions/adr-001.md), we use PostgreSQL.
```

### Orphaned Documents

**Problem:** Documents with no incoming links are undiscoverable.

**Solution:** Every document must be linked from an index.

### Missing Context

**Problem:** Documents assume reader has context.

**Solution:** Every document is self-contained with links for depth.

```markdown
## Prerequisites

This document assumes familiarity with:
- [Event Sourcing](../patterns/event-sourcing.md)
- [CQRS](../patterns/cqrs.md)
```

## Implementation Checklist

For each documentation area:

1. [ ] Entry point document is under 100 lines
2. [ ] Each category has a README.md index
3. [ ] All documents are linked from an index
4. [ ] Cross-references use explicit links
5. [ ] Documents include freshness metadata
6. [ ] Key concepts link to definitions
7. [ ] Tests exist for critical documented behavior
