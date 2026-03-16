# 待办事项 Web 应用 - 项目文档

## 概述
一个简洁的待办事项管理 Web 应用，支持任务增删改查和状态过滤。

## 技术栈
- **前端:** React (Vite) + TailwindCSS
- **后端:** Node.js + Express
- **数据库:** SQLite (开发) / PostgreSQL (生产)
- **部署:** Docker + nginx

## 核心功能
1. **任务管理**
   - 添加任务（标题必填，描述可选）
   - 编辑任务（inline editing）
   - 删除任务（confirm 确认）
   - 标记完成/未完成（checkbox toggle）

2. **状态过滤**
   - 全部 / 待办 / 已完成 三个视图
   - 实时切换，无需刷新

3. **UI/UX 要求**
   - 移动端优先，响应式设计
   - 简洁清爽，避免过度装饰
   - 完成态任务显示灰色+删除线
   - 添加/编辑任务使用模态框或 inline input

4. **数据持久化**
   - RESTful API 设计
   - 支持 CORS（前后端分离开发）
   - 数据库表：`tasks(id, title, description, completed, created_at, updated_at)`

## 非功能性需求
- 代码清晰，注释充分
- 单元测试覆盖率 > 80%
- End-to-end 测试覆盖核心用户流
- CI/CD 自动化部署

## 项目里程碑

### Day 1: 设计 + 后端 API
- [ ] Pixel 输出 Figma 线框图（含移动端/桌面端布局，2 小时内）
- [ ] Forge 完成后端 CRUD API（Node.js + Express + SQLite，24 小时内）
- [ ] Sentinel 编写测试计划（单元 + E2E，Day 1 结束前）

### Day 2: 前端 + 联调
- [ ] Pixel 提供设计规范（配色、字体、间距）
- [ ] Forge 前端 React 实现（基于设计稿，12 小时内）
- [ ] Kernel 准备 Docker 开发环境 + CI/CD 配置（Day 2 开始）
- [ ] Sentinel 执行测试 + 提交 bug 报告（Day 2 下午）

### Day 3: 部署 + 交付
- [ ] Kernel 生产环境部署（Docker compose + nginx）
- [ ] Forge 修复 bug，优化性能
- [ ] Sentinel 回归测试确认
- [ ] Oliver 整理项目文档，交付验收

## 任务分配建议

| Agent | 主要职责 | 交付物 |
|-------|----------|--------|
| **Oliver (PM)** | 整体协调、进度跟踪、每日汇报、文档整理 | 项目计划表、进度周报、最终交付包 |
| **Pixel (Designer)** | 线框图 + 视觉设计规范 + 设计组件库 | Figma 设计稿 + 样式指南 |
| **Forge (Coder)** | 后端 API + 前端 React 实现 | GitHub 代码库 + README |
| **Kernel (DevOps)** | 开发环境 + CI/CD + 生产部署 | Dockerfile + docker-compose.yml + CI 脚本 |
| **Sentinel (QA)** | 测试计划 + 自动化测试用例 + 测试报告 | Jest 单元测试 + Playwright E2E + 测试报告 |

## 沟通与同步
- 每日 18:00 Oliver 向主人汇报进度
- 各 agent 更新 `SESSION-STATE.md` 反映真实任务状态
- Star Office UI 每 2 分钟自动同步状态

## 已知风险
- 技术栈选择可能引发讨论（需要快速决策）
- 前端框架选项：React vs Vue（建议快速 POC）
- 数据库迁移路径：SQLite → PostgreSQL
- 时间紧迫：需全员并行，避免阻塞

---

**项目状态:** 未启动 → 等待 Oliver 分解任务并分配
