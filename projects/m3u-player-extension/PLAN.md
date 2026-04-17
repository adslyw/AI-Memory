# M3U Player Chrome 插件移植计划

## 目标
将 Web 版 M3U Player 完全移植为 Chrome 插件，解决 CORS 限制

## 关键变更
1. **数据存储**: 从 SQLite + localStorage 改为 `chrome.storage.local`
2. **网络权限**: 通过 `host_permissions: ["http://*/*", "https://*/*"]` 获得跨域能力
3. **架构**: 单文件 popup，无需 background service worker 代理（因为 popup 本身有跨域权限）
4. **图标**: 使用简单占位图标（后续可优化）

## 移植清单

- [x] 创建项目结构
- [x] 编写 manifest.json
- [x] 下载 hls.min.js
- [x] 提取并创建 tailwind.css
- [x] 修改 popup.html 引用本地资源
- [ ] 重写 app.js → popup.js（核心移植）
  - [ ] 移除所有 `/api` 调用
  - [ ] 替换 `localStorage` 为 `chrome.storage.local`
  - [ ] 保留所有 UI 交互、拖拽、搜索、播放逻辑
- [ ] 测试基本功能（添加频道、播放、排序）
- [ ] 生成图标占位符
- [ ] 编写安装说明

## 预期问题
- HLS.js 在扩展页面中正常工作（测试验证）
- 跨域 m3u8 链接应能播放（扩展页面的 fetch 享有 host_permissions）
- 拖拽排序在扩展 popup 中正常（需要测试）

## 下一步
开始移植 popup.js，逐步将 app.js 的逻辑迁移过来。
