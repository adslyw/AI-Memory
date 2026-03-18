# Proactive Ideas - 主动惊喜想法

> 记录能让人惊喜的、未被明确请求但极具价值的想法

## 2026-03-11 心跳检查发现

### 立即行动项
- [ ] **项目状态自动报告** - 为主人生成一键式「待办事项 Web 应用」完整状态报告（包括各 agent 进度、阻塞、下一步）
- [ ] **Star Office 健康监控** - 实现自动监控脚本，每 5 分钟检查服务，失败自动重启并通知
- [ ] **PM 激活确认机制** - 创建任务分配确认闭环，确保 Oliver 始终在线协调

### 潜在惊喜想法
- [ ] **每日自动化简报** - 每天早上 8:00 自动生成项目进展、关键指标、风险预警，Telegram/邮件推送
- [ ] **技能使用分析** - 统计各 agent 技能使用频率，识别能力瓶颈，推荐优化方向
- [ ] **代码质量自动化** - 为 Forge 的代码自动运行 lint + 测试覆盖率，生成质量报告
- [ ] **Star Office 看板增强** - 在看板显示项目进度百分比、预计完成时间、阻塞原因标签
- [ ] **知识同步优化** - 为同步过程添加变更摘要，让人一眼看到「今天发生了什么」

## 评估标准
- 是否解决真实痛点？
- 是否能自动化？
- 是否可衡量价值？
- 是否需要外部批准？

---

## 2026-03-17 心跳新增

### Star Office Auto-Recovery Daemon
**Context:** This morning's service outage + recurring ~30min auth expiry requiring manual refresh
**Idea:** Bash daemon with 2-minute health check loop:
- `curl -s http://127.0.0.1:19500/agents` fails → restart via `/home/deepnight/start_star_office.sh`
- DeepBlue auth status "offline" → auto-push presence
- All actions logged to `memory/star-office-monitor.log`
**Impact:** Zero-downtime dashboard, no manual intervention needed
**Effort:** 30 minutes (bash script + install as systemd/cron)
**Priority:** High (reliability improvement)
**Observed TTL:** Auth expires ~30 minutes (2026-03-17 heartbeat checks)

---

## 2026-03-17 心跳新增

### Ready-State Project Acceleration
**Context:** Team idle, infrastructure tested, no active project
**Idea:** Build a "Project Kickoff Framework" to accelerate next assignment by 1-2 days:
- Project template: docs/ (README, API spec), src/ (base structure with Docker), tests/ (E2E scaffold), docker-compose.yml (multi-service ready)
- Oliver's task decomposition utility: CLI that takes plain requirements and outputs structured task breakdown with agent assignments
- CI/CD templates: GitHub Actions for lint, test, build, deploy (Docker + Nginx)
**Impact:** Reduces setup friction, ensures consistency, enables faster delivery
**Effort:** 2-3 hours to create solid templates
**Priority:** Medium (use time when waiting for next project)
