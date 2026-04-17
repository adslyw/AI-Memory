# MEMORY.md - UX-1 Long-Term Memory

## About 主人

- 称呼: "主人"
- 时间: UTC+8
- 沟通: 详细技术说明，偏好结构化更新
- 期望: 高质量 UI，快速交付

## Active Tasks

- TBD: Homepage V2 前端页面实现

## Design System (from Pixel)

- Color palette: TBD (waiting for Pixel's spec)
- Typography: system fonts + custom headings
- Components: Button, Card, Table, Modal, Alert
- Icons: heroicons or custom SVG

## API Contracts (from Forge)

Base URL: `http://localhost:8000/api/`
Endpoints:
- `GET /collection/` — list media resources
- `GET /collection/{id}/` — detail
- `GET /player.m3u` — HLS playlist (with CORS proxy if needed)
- `POST /import/` — batch import (admin only)

## Patterns

- 使用 `fetch()` + async/await
- Error handling: try/catch with user-friendly messages
- Loading states: skeleton screens where appropriate
- Responsive: mobile-first, breakpoints at 640px, 768px, 1024px

## Gotchas

- M3U8 播放需要 HLS.js 库 (已引入)
- CORS 代理 URL 由后端动态生成 (Forge 配置)
- 数据量可能很大 (17k+ items), 使用 pagination/infinite scroll

---

*Review and update periodically.*
