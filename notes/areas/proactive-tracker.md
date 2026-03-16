# Proactive Tracker

Track proactive behaviors and opportunities to surprise the human.

## Overdue Proactive Behaviors

*Check weekly: Any patterns that should be automated?*

- [ ] 检查是否有重复请求需要建立自动化
- [ ] 检查是否有重要的未完成事项需要跟进
- [ ] 检查是否有新工具/技能可以提升效率

## Opportunities Log

*What could I build RIGHT NOW that would make my human say "I didn't ask for that but it's amazing"?*

---

## Ideas (Drip Feed)

Ideas for proactive improvements, filed for later:

- [ ] **Agent Health Monitor** - Based on Day 4 PM dereliction, build a system that:
  - Monitors agent heartbeat/last update timestamp
  - Auto-escalates if agent unresponsive >15 minutes
  - Attempts graceful restart of failed sessions
  - Sends alerts to owner with recovery suggestions
  - This would prevent future communication blackouts

- [ ] **Test Isolation Framework** - E2E test failures highlighted need for:
  - Auto-generated unique test IDs (no collisions)
  - Built-in database cleanup hooks
  - Standardized selector patterns with scoping
  - Could be packaged as a reusable skill for future projects

- [ ] **Pre-Deploy Validator** - Production config mismatch caused Day 3 crash:
  - Validate environment variables match code expectations
  - Check filesystem permissions for mounted volumes
  - Verify port availability before launch
  - Could integrate as CI/CD gate or pre-run script
