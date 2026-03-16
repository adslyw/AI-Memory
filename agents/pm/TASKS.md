# M3U Player - 1 小时上线任务清单

## 🎯 总体目标

**17:20 前完成可用的 M3U Player 播放器**

---

## 👥 任务分配

### 1. Forge (Coder) - 核心修复和测试

**时间:** 30 分钟 (16:55-17:25)

**任务:**
- [ ] 在本地启动服务器测试应用
- [ ] 使用测试 m3u8 链接验证播放功能
- [ ] 识别并修复任何阻塞性 Bug
- [ ] 增强 HLS 错误处理 (确保 graceful degradation)
- [ ] 检查 LocalStorage 异常处理
- [ ] 移除或注释掉所有 console.log (可选)
- [ ] 提交最终代码

**快速测试命令:**
```bash
cd /home/deepnight/.openclaw/workspace/projects/m3u-player
python3 -m http.server 8080
# 浏览器访问 http://localhost:8080
```

**测试链接:**
```
https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
```

**验收标准:**
- 能添加频道
- 能播放 HLS 流
- 无控制台错误
- 频道列表持久化有效

---

### 2. Kernel (DevOps) - 部署脚本

**时间:** 20 分钟 (16:55-17:15)

**任务:**
- [ ] `start.sh` 已创建 (已完成)
- [ ] 测试启动脚本可用
- [ ] 可选: 创建 `stop.sh` 杀死进程
- [ ] 可选: 添加端口检查 (避免冲突)
- [ ] 提供部署文档 (README.md 已完成)

**文件名:** `/home/deepnight/.openclaw/workspace/projects/m3u-player/start.sh`

**交付物:**
- 可执行 `./start.sh`
- 服务在 http://localhost:8080 运行

---

### 3. Pixel (Designer) - UI 快速优化

**时间:** 15 分钟 (16:55-17:10)

**任务:**
- [ ] 美化自定义滚动条 (已完成基础样式)
- [ ] 添加加载状态 spinner (HLS 加载时显示)
- [ ] 优化按钮 hover 效果
- [ ] 检查响应式布局 (移动端基本可用)
- [ ] 调整间距和字体大小

**修改文件:** `index.html` (内联样式) 或创建 `styles.css`

**交付物:**
- 视觉上更精致的 UI
- 加载状态反馈
- 深色主题协调

---

### 4. Sentinel (QA) - Smoke Test

**时间:** 10-15 分钟 (17:05-17:20)

**任务:**
- [ ] 启动应用 (使用 Kernel 的脚本)
- [ ] 执行快速功能测试清单
- [ ] 记录任何阻塞性 Bug
- [ ] 给出 Go/No-Go 建议

** Smoke Test 清单:**
- [ ] 页面加载无错误
- [ ] 添加频道功能
- [ ] 播放 HLS 流成功
- [ ] 暂停/播放控制
- [ ] 删除频道
- [ ] 刷新后数据持久化
- [ ] 无前端错误 (Console)

**报告格式:**
```
✅ 通过: [列表]
❌ 失败: [列表] (阻塞性)
⏳ 建议: [改进建议]
最终 verdict: [GO / NO-GO]
```

---

### 5. Oliver (PM) - 协调和验收

**时间:** 持续

**任务:**
- [ ] 每小时检查一次各成员进度
- [ ] 解决任何阻塞
- [ ] 17:15 收集最终状态
- [ ] 17:20 进行快速验收
- [ ] 通知主人项目可用了

**快速验收检查:**
- [ ] Forge 完成代码修复
- [ ] Kernel 提供可运行脚本
- [ ] Pixel 完成 UI 优化
- [ ] Sentinel 给出 GO  verdict
- [ ] 主 agent 能启动服务

---

## ⏰ 时间线

| 时间 | 里程碑 |
|------|--------|
| 16:55 | 任务分配完成，团队开始工作 |
| 17:10 | Pixel (Designer) 完成 UI 优化 |
| 17:15 | Kernel (DevOps) 完成部署脚本 + 开始测试 |
| 17:20 | Forge (Coder) 完成代码修复 + QA 完成 Smoke Test |
| 17:25 | Oliver (PM) 验收并通知主人 |

---

## 🚨 阻塞 escalation

任何成员遇到阻塞 > 10 分钟，立即报告 PM Oliver 和主 agent。

---

**准备就绪，开始冲刺！** 🏃💨
