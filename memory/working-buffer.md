# Working Buffer (Danger Zone Log)

**Status:** ACTIVE
**Started:** 2026-03-10 12:58 (Asia/Shanghai)

---

## Purpose
This file captures every exchange when context usage exceeds 60%. It survives context compaction and is used for recovery when the agent wakes up with truncated history.

## When to Log
After context reaches 60%, log EVERY human message + agent response summary.

## Format

```
## [timestamp] Human
[their message]

## [timestamp] Agent (summary)
[1-2 sentence summary of response + key details]
```

---

## Entries

*Empty until 60% threshold is reached.*
