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

---

## Ongoing Context

### Active Projects
暂无

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

*Review and update periodically. Daily notes are raw; this is curated.*