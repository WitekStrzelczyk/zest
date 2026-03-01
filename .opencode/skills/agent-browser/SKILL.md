---
name: agent-browser
description: Browser automation using agent-browser CLI. Navigate pages, take snapshots with refs (@e1, @e2), click, fill forms, take screenshots. Use snapshot-ref workflow for reliable element selection.
license: Apache-2.0
compatibility: opencode
---

# Agent-Browser: Browser Automation for AI Agents

Headless browser automation CLI for AI agents. Fast Rust CLI with Playwright backend.

## Installation

```bash
npm install -g agent-browser
agent-browser install  # Download Chromium
```

## Core Workflow (Snapshot-Ref Pattern)

**This is the optimal pattern for AI agents:**

```bash
# 1. Navigate to page
agent-browser open https://example.com

# 2. Get accessibility tree with element refs
agent-browser snapshot -i

# Output shows interactive elements with refs:
# - button "Submit" [ref=e1]
# - textbox "Email" [ref=e2]
# - link "Learn more" [ref=e3]

# 3. Interact using refs (deterministic, fast)
agent-browser fill @e2 "test@example.com"
agent-browser click @e1

# 4. Re-snapshot after page changes
agent-browser snapshot -i
```

## Essential Commands

### Navigation
```bash
agent-browser open <url>              # Navigate to URL
agent-browser back                    # Go back
agent-browser forward                 # Go forward
agent-browser reload                  # Reload page
agent-browser close                   # Close browser
```

### Page Information
```bash
agent-browser snapshot                # Full accessibility tree
agent-browser snapshot -i             # Interactive elements only (recommended)
agent-browser snapshot -i -c          # Interactive + compact
agent-browser get text @e1            # Get text content
agent-browser get url                 # Get current URL
agent-browser get title               # Get page title
agent-browser screenshot [path]       # Take screenshot
agent-browser screenshot --annotate   # Screenshot with numbered labels
```

### Interactions
```bash
agent-browser click @e1               # Click element
agent-browser fill @e1 "text"         # Clear and fill input
agent-browser type @e1 "text"         # Type into input
agent-browser press Enter             # Press key
agent-browser hover @e1               # Hover element
agent-browser check @e1               # Check checkbox
agent-browser uncheck @e1             # Uncheck checkbox
agent-browser select @e1 "option"     # Select dropdown option
```

### Waiting
```bash
agent-browser wait @e1                # Wait for element visible
agent-browser wait 1000               # Wait 1 second
agent-browser wait --text "Welcome"   # Wait for text to appear
agent-browser wait --load networkidle # Wait for network idle
```

### Semantic Locators (Alternative to refs)
```bash
agent-browser find role button click --name "Submit"
agent-browser find label "Email" fill "test@test.com"
agent-browser find text "Sign In" click
```

## Sessions & Persistence

```bash
# Isolated sessions
agent-browser --session agent1 open site-a.com

# Persistent profiles (cookies/logins)
agent-browser --profile ~/.myapp-profile open myapp.com

# Auto-save session state
agent-browser --session-name twitter open twitter.com
```

## JSON Output

```bash
agent-browser snapshot -i --json
agent-browser get text @e1 --json
```

## Command Chaining

```bash
agent-browser open example.com && agent-browser wait --load networkidle && agent-browser snapshot -i
agent-browser fill @e1 "user@example.com" && agent-browser click @e2
```

## Options

| Flag | Description |
|------|-------------|
| `--headed` | Show browser window (debugging) |
| `--session <name>` | Isolated session |
| `--profile <path>` | Persistent profile directory |
| `--json` | JSON output for agents |

## Common Patterns

### Login Flow
```bash
agent-browser open https://app.example.com/login
agent-browser snapshot -i
agent-browser find label "Email" fill "user@example.com"
agent-browser find label "Password" fill "secret"
agent-browser find role button click --name "Sign In"
agent-browser wait --url "**/dashboard"
```

### Form Submission
```bash
agent-browser open https://example.com/contact
agent-browser snapshot -i
agent-browser fill @e1 "John Doe"
agent-browser fill @e2 "john@example.com"
agent-browser click @e3  # Submit
```

### Scrape Data
```bash
agent-browser open https://example.com/products
agent-browser snapshot -i
agent-browser get text @e1  # Product name
agent-browser get text @e2  # Price
```

## Tips

1. **Use refs (`@e1`)** - Deterministic and fast
2. **Use `snapshot -i`** - Only interactive elements, less noise
3. **Wait for stability** - `wait --load networkidle` after navigation
4. **Re-snapshot after changes** - Refs may change when DOM updates
5. **Chain commands** - More efficient than separate invocations

## Full Reference

```bash
agent-browser --help
```
