# HEARTBEAT.md

# Keep this file empty (or with only comments) to skip heartbeat API calls.

# Add tasks below when you want the agent to check something periodically.
# 任务列表
- [ ] 检查今日 `memory/` 目录。
- [ ] 如果有新日志，运行 `qmd index` 更新索引。
- [ ] 执行 `git add . && git commit -m 'Auto-sync memory' && git push origin main` 同步记忆。

### 每日自省任务
1. 阅读最近 3 天的 `memory/` 日志。
2. 识别我（用户）重复纠正你的地方。
3. 如果发现我的偏好有变，直接更新 `USER.md` 或 `SOUL.md` 以适应我的习惯。
4. 检查是否有新安装的工具，如果有，在 `TOOLS.md` 中补充用法示例。

## 每日自我提升任务
1. **分析错误日志**：检索 `logs/` 下的 `error` 关键词。如果发现重复报错（如 401 或 Tool Not Found），总结原因并更新 `TROUBLESHOOTING.md`。
2. **知识蒸馏**：将 `memory/` 里的对话记录压缩。如果我教了你一个 Linux 技巧，把它存入 `shared-knowledge/linux-hacks.md`。
3. **QMD 同步**：自动运行 `qmd index` 确保搜索索引是最新的。
