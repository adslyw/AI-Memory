# Proactive Ideas

> What could I build RIGHT NOW that would make my human say "I didn't ask for that but it's amazing"?

## 2026-03-26

**Idea: AppleSite 自动健康检查器**

- **Problem:** AppleSite 可能因为域名失效、API挂掉等原因变成无效站点，但管理员无法实时知道。
- **Solution:** 创建一个后台定时任务（django-background-tasks），每天检查所有启用的 AppleSite 的 API 可达性。对连续失败 N 次的站点自动禁用，并在 Admin 首页显示警告，同时发送飞书消息通知。
- **Delight factor:** 零维护成本，系统自愈能力，防止无效资源站影响用户体验。
- **Implementation effort:** ~2 hours (add model for health tracking, periodic task, admin dashboard widget, feishu notification)
- **Potential extension:** 结合 Star Office 状态同步，在看板上显示站点健康指数。

**其他构想：**
- TVBox 配置一键导出（包含所有站点最新分类）
- 资源访问量统计仪表盘（基于 request logs）
- 自动封面图抓取（针对自定义 CMS）

## 2026-04-10

**Idea: Homepage_v2 空媒体资源自动修复工具**

- **Problem:** 在 `homepage_v2` 项目中发现了 928 条 `resource_type='media'` 且 `resource_url` 和 `poster` 为空的 Page 记录，涉及 71 个不同域名。这些记录无法在 `player.m3u` API 中正常显示。
- **Solution:** 开发一个自动化脚本，按域名对空资源进行分组，针对每个已配置的 `AppleSite` 调用 API 获取缺失的 `resource_url` 和 `poster` 信息，并批量更新数据库。
- **Delight factor:** 自动化数据修复，减少人工干预，提高数据完整性。
- **Implementation effort:** ~3-4 小时（分析域名映射、编写站点特定 API 调用逻辑、批量更新数据库）
- **Bonus:** 可扩展到其他类似的数据修复任务。

## 2026-04-11

**Idea: M3U Player Electron 自动构建和发布流水线**

- **Problem:** M3U Player Electron 应用已经开发完成，但每次更新都需要手动构建和发布，缺乏自动化流程。
- **Solution:** 创建 GitHub Actions 工作流，实现自动构建、测试和发布 Electron 应用到多个平台（Windows、macOS、Linux）。
- **Delight factor:** 一键发布，自动构建，减少手动操作，提高发布效率。
- **Implementation effort:** ~2-3 小时（配置 GitHub Actions、构建脚本、发布流程）
- **Bonus:** 支持自动更新（electron-updater），用户可自动获取新版本。

## 2026-04-11

**Idea: M3U Player Electron 自动构建和发布流水线**

- **Problem:** M3U Player Electron 应用已经开发完成，但每次更新都需要手动构建和发布，缺乏自动化流程。
- **Solution:** 创建 GitHub Actions 工作流，实现自动构建、测试和发布 Electron 应用到多个平台（Windows、macOS、Linux）。
- **Delight factor:** 一键发布，自动构建，减少手动操作，提高发布效率。
- **Implementation effort:** ~2-3 小时（配置 GitHub Actions、构建脚本、发布流程）
- **Bonus:** 支持自动更新（electron-updater），用户可自动获取新版本。

## 2026-04-12

**Idea: M3U Player 桌面应用增强功能**

- **Problem:** 当前 M3U Player 桌面应用功能基本完整，但缺乏一些提升用户体验的增强功能。
- **Solution:** 添加以下增强功能：
  - 系统托盘右键菜单（显示窗口、退出、设置）
  - 快捷键支持（全局快捷键打开应用、播放/暂停）
  - 自动更新检查（在后台定期检查新版本）
  - 播放历史记录（记录最近播放的频道）
  - 皮肤主题切换（支持多种配色主题）
- **Delight factor:** 提升桌面应用的用户体验，更接近原生应用的使用习惯。
- **Implementation effort:** ~4-5 小时（实现托盘菜单、快捷键、自动更新、历史记录功能）
- **Bonus:** 添加设置界面，支持用户自定义配置。

## 2026-03-26 (2)

**Idea: AppleCategory 变更即时通知**

- **Problem:** 分类数据同步完成后，管理员不知道何时更新、更新了多少，需要手动查看。
- **Solution:** 在 `AppleCategorySyncService.sync` 完成后，通过飞书 Bot 发送通知到管理群。消息包括：站点名、同步时间、新增/更新/删除的分类数量。可配置通知阈值（如仅当变化 > 5 时发送）。
- **Delight factor:** 信息透明，及时发现数据异常，减少管理盲区。
- **Implementation effort:** ~1 hour (integrate feishu messaging, add summary stats to sync result, hook into task completion signal).
- **Bonus:** 在 Admin 列表中显示"最后同步时间"-column.
