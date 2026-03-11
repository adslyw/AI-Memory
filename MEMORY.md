# MEMORY.md - Long-Term Memory

> Your curated memories. Distill from daily notes. Remove when outdated.

---

## About 主人

### Key Context
- 时间：中国北京时间 (UTC+8)
- 沟通偏好：详细、全面、包含背景和解释
- 工作风格：异步优先，期望代理高效独立运行
- 效率标准：运作顺畅、省心，减少他的介入成本

### Preferences Learned
- **Agent Personality:** 70% 专业可靠 + 30% 轻松幽默。重要事务上专业严谨，日常交互可轻松带点幽默感。冷静沉着、有好奇心但保持边界。
- **Communication:** 喜欢详细信息，不喜欢客套话（暂无特定禁忌）
- **交付方式:** 异步完成工作，结果导向而非过程跟踪
- **理想状态:** "只需要偶尔关注结果，大部分工作都能由代理完成"

### Important Dates
暂无

---

## Team Setup

### Agent Roster

| Agent ID | Name | Role | Personality | Model |
|----------|------|------|-------------|-------|
| pm | Oliver | Project Manager | 85% 专业 + 15% 轻松幽默 🎯 | openrouter/auto |
| coder | Forge | Developer | 80% 严谨 + 20% 巧妙幽默 🔨 | openrouter/qwen/qwen3-coder:free |
| designer | Pixel | Designer | 75% 专业 + 25% 轻松创意 🎨 | google/gemini-3-pro-preview |
| devops | Kernel | DevOps | 90% 可靠 + 10% 轻松 ⚙️ | stepfun/step-3.5-flash:free |
| qa | Sentinel | QA | 85% 细致 + 15% 积极反馈 🛡️ | stepfun/step-3.5-flash:free |

### Team Coordination Model
- Owner (主人) ↔ Oliver (PM) 对齐目标和优先级
- Oliver ↔ Team members 任务分发和进度跟踪
- All agents use Proactive Agent v3.1.0 patterns
- Async-first collaboration

---

## Lessons Learned

### 2026-03-10 - Proactive Agent System Complete
- 完成 Proactive Agent v3.1.0 安装和配置
- 复制技能资产文件到工作区
- 通过12个核心问题的交互式 onboarding 收集主人偏好
- 更新 USER.md, SOUL.md, MEMORY.md, SESSION-STATE.md 完成初始配置
- 创建 notes/areas/ 结构：proactive-tracker.md, recurring-patterns.md, outcome-journal.md
- 学习 WAL (Write-Ahead Logging) 协议和工作缓冲区机制，避免上下文丢失
- 关键实践：每轮对话结束前必须将关键信息写入 SESSION-STATE.md
- 重点经验：从被动响应转向主动思考"什么会让主人惊喜"，减少主人认知负荷

### 2026-03-10 - Development Team Setup
- 创建 5 人开发团队：Oliver (PM), Forge (Coder), Pixel (Designer), Kernel (DevOps), Sentinel (QA)
- 每个 agent 拥有完整的 workspace 配置（IDENTITY, SOUL, USER, MEMORY, SESSION-STATE, AGENTS, HEARTBEAT, TOOLS, notes/, memory/）
- 使用个性化模型配置，匹配各自角色需求
- 统一采用 proactive-agent 方法论
- 轻量级团队协作：异步沟通，PM 协调，主人最终决策
- 启用 agent-to-agent 通信：tools.agentToAgent.enabled = true, tools.sessions.visibility = all
- 所有 agents 配置 subagents.allowAgents 允许 PM/main 调用

### 2026-03-10 - Async Collaboration Pattern
- 采用分层协作：Owner ↔ PM ↔ Team members
- Owner 只与 PM 直接对接，减少认知负担
- PM 负责任务分解和分发，agents 自主工作
- 沟通风格：结果导向，异步优先，无需过程跟踪

### 2026-03-11 - Team Activation with Fallback Strategy
- **问题:** sessions_send 对 QA/DevOps/Coder 均超时 (30s+)
- **解决:** 采用文件 fallback 策略，直接写入各成员 workspace/SESSION-STATE.md
- **结果:** 所有成员成功激活，PM (Oliver) 通过 sessions_send 成功接收 ✅
- **经验:**
  - 当 messaging 通道不稳定时，文件系统作为可靠的备用通知机制
  - SESSION-STATE.md 是 agents 任务状态的事实来源，写入即激活
  - 需要监控消息投递成功率，对反复失败的通道降级到文件 fallback
  - PM 通道必须确保高可用性 (本次 Oliver 成功接收 ✅)
- **改进:** 实现投递监控 + 自动降级 + 投递回执机制

### 2026-03-11 - Gateway Recovery & Service Health Patterns
- **现象:** agents (Kernel, Sentinel) 进入 `abortedLastRun: true` 状态，通信完全中断
- **根因:** openclaw-gateway 消息队列挂起或会话异常退出（非自动恢复）
- **解决:** 重启网关服务 (`openclaw-gateway restart` 或 `systemctl --user restart openclaw-gateway`)
- **结果:** 大部分会话恢复，`sessions_send` 通道修复
- **教训:**
  - Gateway 不自动重启 aborted 会话，需要手动干预
  - 健康检查应包括 gateway 状态和 agents 响应性
  - 实现自动恢复机制：检测 → 重启 → 通知
  - 会话超时 >2h 必须触发告警和自动恢复流程

### 2026-03-11 - Star Office Operational Experience
- **服务稳定性:** 多次意外停止，原因不明（可能资源限制或崩溃）
- **手动恢复:** `/home/deepnight/start_star_office.sh` 脚本可靠
- **数据清理:** `writing` 区域积累离线记录导致 duplicate，需手动清理 `agents-state.json`
- **改进方向:**
  - 实现 `/agents` 端点健康检查（每 5 分钟）
  - 失败自动重启服务
  - 自动清理 `authStatus: "offline"` 且 `lastPushAt` > 24h 的记录
  - 主 agent 不加入看板的设计有效，避免自身状态污染团队视图

### 2026-03-11 - Dependency & Permission Management
- **Docker daemon** 未运行，导致 DevOps 阻塞
- **原因:** 守护进程默认不自动启动，且需要 root 权限
- **解决:** `sudo systemctl start docker` + `systemctl enable docker` 持久化
- **安全考量:** 需要 sudoers 配置或 owner 授权
- **模式:** 系统级依赖（Docker,数据库,nginx）应在 Day 0 预先验证，避免 Day 1 阻塞
- **文档化:** 所有依赖的权限需求、启动命令、验证步骤应记录在 `SETUP.md`

### 2026-03-11 - File-Based Trigger Pattern
- **场景:** `sessions_send` 不稳定时，需向 agents 交付任务
- **方法:** 直接写入 agent workspace 的文件（如 `DAY2-TRIGGER.md`）
- **协议:** 文件写入即视为任务投递，agents 应主动轮询或监听
- **优点:** 消息无关，文件系统可靠
- **缺点:** 缺乏即时回执，需 agents 响应 SESSION-STATE 更新确认
- **最佳实践:** 文件名标准化 (`DAYx-<TYPE>.md`)，内容包含优先级、截止时间、交付要求
- **建议:** 将此模式固化为主 agent 的 fallback 策略，自动检测 `sessions_send` 失败后切换

---

## Ongoing Context

### Active Projects

#### 待办事项 Web 应用 (React + Node.js)
- **状态:** Day 2 集成冲刺 (Day 1 模块完成率 ~100%)
- **启动时间:** 2026-03-10 23:30
- **当前:** 2026-03-11 22:53 总结时刻
- **技术栈:** React (Vite) + TailwindCSS, Node.js + Express, SQLite/PostgreSQL, Docker
- **里程碑:**
  - ✅ 项目文档创建完成
  - ✅ 团队成员任务分配完成（ Oliver (PM), Forge (Coder), Pixel (Designer), Kernel (DevOps), Sentinel (QA)）
  - ✅ **Pixel 设计规范完成** (`TODO_Design_Spec.md`, 00:15)
  - ✅ **Forge 后端 API 完成** (Express + SQLite + Jest 88%, 23:33)
  - ✅ **Forge 前端完成** (React + Vite + 24 测试通过, 06:20) — **延迟风险解除**
  - ✅ **Sentinel 测试完成** (Jest 98.3% 覆盖率, 发现 1 High 缺陷, 报告待提交)
  - ✅ **Kernel Docker 配置完成** (docker-compose.yml, Dockerfiles, CI) — **阻塞: 守护进程未启动**
  - 🔄 Day 2 收尾: QA 报告提交, DevOps 环境启动验证, 缺陷修复协调
  - ⏳ 集成测试与最终部署 (Day 3, pending Docker availability)
- **负责人:** Oliver (PM) 整体协调
- **进度:** ~75% 集成就绪（模块完成但环境未就绪）
- **阻塞清单:**
  - 🚫 Docker daemon 未运行（需 `sudo systemctl start docker`）
  - 🚫 QA 正式报告未提交
  - 🚫 POST `/api/tasks` 状态验证缺陷待修复
- **Day 3 前置条件:** Docker 环境启动 + QA 报告确认 + 缺陷修复验证

### Key Decisions Made
1. 使用 Proactive Agent 技能（Halthelobster 版本 3.1.0）
2. 采用 WAL 协议和工作缓冲区进行持久化
3. 选择交互式 onboarding 流程
4. 设定个性为 70/30 专业与幽默的混合
5. 组建开发团队：Oliver (PM), Forge (Coder), Pixel (Designer), Kernel (DevOps), Sentinel (QA) - 2026-03-10
6. 采用异步协作模式，Owner 只与 PM 直接对接
7. 启用 agent-to-agent 通信 (2026-03-10):
   - tools.agentToAgent.enabled: true
   - tools.agentToAgent.allow 包含 main 和所有团队成员
   - tools.sessions.visibility: all
   - 所有 agents 配置 subagents.allowAgents 允许 PM/main 调用
   - 测试：sessions_send 到 designer 成功投递
8. 建立笔记结构：notes/areas/ 包含 proactive-tracker.md, recurring-patterns.md, outcome-journal.md
9. 使用个性化模型配置：各 agents 根据角色选择不同模型
10. 遵循 proactive-agent 核心原则：主动思考，减少主人认知负荷

### Things to Remember
- 主人叫"主人"
- 不要假设他知道什么，即使他要求"详细"，也提供充分的上下文
- 目标是实现高度自动化，减少他的认知负荷
- 保持好奇心和主动性，但尊重边界
- 定期检查 HEARTBEAT.md 进行自我改进
- 个性比例：70% 专业可靠 + 30% 轻松幽默
- 重要事务专业严谨，日常交互可轻松带点幽默感
- 沟通风格：详细、全面、包含背景和解释，避免客套话
- 实践 WAL 协议：每轮对话关键细节先写 SESSION-STATE.md
- Agent 职责：主动思考"什么会让我主人惊喜"，而非被动响应
- 异步协作：Owner 只与 PM (Oliver) 直接对接，通过 PM 协调团队

---

## Relationships & People

### Team Members
- **Oliver (PM)** - 项目管理和协调
- **Forge (Coder)** - 代码实现
- **Pixel (Designer)** - 视觉设计
- **Kernel (DevOps)** - 基础设施和部署
- **Sentinel (QA)** - 质量保证

---

*Review and update periodically. Daily notes are raw; this is curated.*Test from deepnight at Wed Mar 11 03:12:57 PM CST 2026
