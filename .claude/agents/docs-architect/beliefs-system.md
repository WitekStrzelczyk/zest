# Beliefs Documentation System

Guide for documenting and maintaining core principles (beliefs) that guide development decisions.

## What Are Beliefs?

Beliefs are core principles and invariants that:

- Guide decision-making
- Define team values
- Establish non-negotiables
- Encode institutional knowledge
- Provide reasoning shortcuts

Unlike rules, beliefs explain *why* not just *what*.

## Belief Documentation Structure

### Directory Layout

```
docs/beliefs/
├── README.md           # Beliefs index
├── beliefs-template.md # Template for new beliefs
├── parse-at-boundaries.md
├── fail-fast.md
├── structured-logging.md
└── ...
```

### Belief Document Template

```markdown
---
category: reliability | security | maintainability | performance
status: active | draft | retired
created: YYYY-MM-DD
last_reviewed: YYYY-MM-DD
---

# [Belief Name]

> One-line summary that captures the essence

## Context

Why does this belief exist? What problem does it solve?

2-3 paragraphs explaining the background and motivation.

## The Belief

Clear statement of the principle.

Use imperative mood: "Always validate input at system boundaries."

## Rationale

Why is this the right approach?

- Reason 1
- Reason 2
- Reason 3

## Application

How to apply this belief in practice.

### Examples

**Good:**

```language
// Code example demonstrating the belief
```

**Bad:**

```language
// Code example violating the belief
```

### Decision Points

When making decisions, ask:

- Question 1?
- Question 2?

## Trade-offs

What do we give up by following this belief?

- Trade-off 1
- Trade-off 2

## Related

- [Related Belief](related-belief.md)
- [Related ADR](../architecture/decisions/adr-xxx.md)
- [External Reference](https://...)

## History

| Date | Change |
|------|--------|
| YYYY-MM-DD | Initial creation |
| YYYY-MM-DD | Updated rationale |
```

## Belief Index Template

```markdown
# Core Beliefs

Principles that guide all decisions in this codebase.

## Categories

### Reliability

| Belief | Summary | Status |
|--------|---------|--------|
| [Fail Fast](fail-fast.md) | Surface errors immediately | Active |
| [Structured Logging](structured-logging.md) | Machine-readable logs | Active |

### Security

| Belief | Summary | Status |
|--------|---------|--------|
| [Parse at Boundaries](parse-at-boundaries.md) | Validate all external input | Active |

### Maintainability

| Belief | Summary | Status |
|--------|---------|--------|
| [Single Source of Truth](single-source.md) | No duplication | Active |

## How to Use Beliefs

1. **When deciding**: Check if a belief applies
2. **When reviewing**: Verify belief adherence
3. **When onboarding**: Read all active beliefs
4. **When questioning**: Propose updates via PR

## Belief Lifecycle

### Proposing

1. Create using [template](beliefs-template.md)
2. Mark status as `draft`
3. Discuss with team
4. Update to `active` after consensus

### Updating

1. Propose change via PR
2. Update `last_reviewed` date
3. Document change in history

### Retiring

1. Set status to `retired`
2. Document why
3. Keep for historical reference

## Verification

- All beliefs reviewed quarterly
- New code must reference relevant beliefs
- Violations require explicit justification
```

## Belief Categories

### Reliability

Beliefs about system stability and error handling:

- Fail fast vs. retry
- Circuit breaker patterns
- Graceful degradation
- Recovery procedures

### Security

Beliefs about security posture:

- Input validation
- Authentication patterns
- Data protection
- Access control

### Maintainability

Beliefs about code quality:

- DRY principle
- Code organization
- Documentation standards
- Testing requirements

### Performance

Beliefs about efficiency:

- Latency targets
- Resource limits
- Caching strategies
- Optimization priorities

## Integrating Beliefs with Code

### Code Comments

Reference beliefs in code:

```typescript
// Belief: parse-at-boundaries
// All external input is validated at the API boundary
const validatedInput = InputSchema.parse(request.body);
```

### PR Templates

```markdown
## Belief Alignment

- [ ] I have reviewed relevant beliefs
- [ ] This change aligns with our core principles
- [ ] Any belief violations are documented below

### Beliefs Applied

- [parse-at-boundaries](../docs/beliefs/parse-at-boundaries.md)
- [fail-fast](../docs/beliefs/fail-fast.md)
```

### Architecture Decisions

ADRs should reference beliefs:

```markdown
## Beliefs

This decision supports:
- [Parse at Boundaries](../beliefs/parse-at-boundaries.md)
- [Fail Fast](../beliefs/fail-fast.md)
```

## Common Belief Examples

### Parse at Boundaries

```markdown
# Parse at Boundaries

> Validate all external input at system boundaries, not internally

## Context

Systems receive input from many sources: APIs, databases,
message queues, file systems. Each source has different
trust levels and data shapes.

## The Belief

Validate and parse all external input immediately upon
receipt. Internal code should only work with validated,
typed data.

## Rationale

- Failures surface at entry points
- Internal code is simpler (no defensive parsing)
- Types can be trusted internally
- Security vulnerabilities are contained

## Application

At API boundaries:

```typescript
// Good: Validate at boundary
app.post('/users', (req, res) => {
  const user = UserSchema.parse(req.body); // Throws if invalid
  // user is now typed and validated
  userService.create(user);
});
```

## Trade-offs

- More upfront validation code
- Stricter contracts with external systems
- May reject valid edge cases
```

### Fail Fast

```markdown
# Fail Fast

> Surface errors immediately rather than hiding or retrying

## Context

Distributed systems encounter failures constantly.
How we handle them determines system reliability.

## The Belief

When something fails, report it immediately. Don't hide
errors, don't silently retry, don't return partial results.

## Rationale

- Problems are easier to debug when fresh
- Cascading failures are prevented
- Operators can respond quickly
- Callers have full context

## Trade-offs

- More visible errors (can be alarming)
- Requires good error handling at call sites
- May seem less "robust" superficially
```

## Maintenance

### Quarterly Review

1. Audit all active beliefs
2. Verify they still apply
3. Update examples if stale
4. Retire beliefs that no longer fit

### Belief Metrics

Track belief effectiveness:

- How often is this belief referenced?
- How many violations occur?
- What's the impact of following it?
