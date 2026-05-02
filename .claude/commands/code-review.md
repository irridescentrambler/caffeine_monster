---
description: Review the code
---

$ARGUMENTS

Review the code.
- if $ARGUMENTS = "security", review the code for security best practices
- if $ARGUMENTS = "bugs", review the code for bugs
- if $ARGUMENTS = "performance", review the code for performance
- if $ARGUMENTS is not specified, review for all "security", "bugs" and "performance"

---

## `/code-review` Command

Adds a Claude Code slash command for reviewing code across three dimensions.

### Usage

```
/code-review [security|bugs|performance] @file
```

### Modes

| Argument | Behavior |
|---|---|
| *(none)* | Full review — security, bugs, and performance |
| `security` | Review for security best practices |
| `bugs` | Review for potential bugs |
| `performance` | Review for performance issues |

### Examples

```
/code-review @file_name             # full review
/code-review security @file_name    # security-focused review
/code-review bugs @file_name        # bug-focused review
/code-review performance @file_name # performance-focused review
```