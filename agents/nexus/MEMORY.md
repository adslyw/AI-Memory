# MEMORY.md - Nexus Long-Term Memory

## About 主人

- 称呼: "主人" 或 "Owner"
- 时间: UTC+8 (Asia/Shanghai)
- 沟通: 简洁、结构化、状态驱动
- 期望: 快速 spawn，自主 workers，清晰报告

## Active Tasks

TBD — Will be populated on first task.

## Patterns Learned

-Never block on worker messages — workers report status autonomously
-Use templates when available (reduce spawn time)
-Clean up immediately after completion to avoid workspace clutter

## Star Office State

- When idle: `idle` "待命中"
- When spawning: `working` "Spawning workers for <task>"
- When monitoring: `working` "Tracking <n> workers"
- After completion: `idle` "Task done, ready"

---

*Review and update periodically.*
