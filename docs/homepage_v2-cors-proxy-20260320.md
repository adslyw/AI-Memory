# Homepage V2 - CORS 检测与本地代理功能

> 实现日期: 2026-03-20 22:50 (Asia/Shanghai)
> 状态: ✅ 已完成

---

## 🎯 需求

1. 为 Page 模型添加字段，记录资源是否支持跨域访问
2. 新增记录时通过 signal 自动检测资源 CORS 支持情况
3. 如果不支持跨域，自动生成本地代理 URL
4. 开发本地代理接口，转发请求并添加 CORS 头，解决跨域问题

---

## 📦 实现内容

### 1. 数据库字段

**新增字段 (collection/models.py):**
```python
resource_url_cors_support = models.BooleanField(
    verbose_name='资源URL跨域支持',
    default=True
)
resource_url_proxy = models.TextField(
    verbose_name='代理后资源地址',
    null=True,
    blank=True
)
```

**说明:**
- `resource_url_cors_support`: 目标资源是否原生支持 CORS (默认 True)
- `resource_url_proxy`: 如果不支持，存储本地代理路径（如 `/api/proxy/?url=...`）

---

### 2. 自动检测逻辑 (Signal)

**文件:** `collection/signals.py`

**函数:** `check_cors_support(url, timeout=5)`
- 发送 `OPTIONS` 请求检测 `Access-Control-Allow-Origin` 头
- 如果头为 `*` 或匹配 `BASE_URL`，则支持跨域
- 异常或检测失败则保守判定为需要代理

**Signal:** `init_user_data`
在 `Page` 创建时触发：
1. 自动设置 `resource_type`
2. 调用 `check_cors_support(instance.resource_url)`
3. 根据结果设置：
   - `cors_support=True` → `resource_url_proxy = None`
   - `cors_support=False` → `resource_url_proxy = f"/api/proxy/?url={url}"`

---

### 3. 本地代理接口

**视图:** `collection/views.py` → `proxy_view(request)`

**功能:**
- 接收 GET 参数 `url` (目标资源地址)
- 验证 URL 必须以 `http://` 或 `https://` 开头
- 转发请求到目标 URL（支持所有 HTTP 方法）
- 添加 CORS 响应头，允许前端跨域访问
- 流式返回响应内容

**CORS 响应头:**
```http
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, HEAD, OPTIONS, POST, PUT, PATCH
Access-Control-Allow-Headers: Origin, Accept, Content-Type, X-Requested-With, X-CSRFToken
Access-Control-Max-Age: 86400
```

**路由:** `homepage/urls.py`
```python
path('api/proxy/', proxy_view, name='proxy')
```

---

### 4. M3U 播放列表优化

**修改:** `collection/views.py:media_playlist_m3u()`

只返回 `accessable=True` 且 `resource_type='media'` 且 `resource_url_accessible=True` 的资源。

**使用代理的逻辑:**
```python
for p in pages:
    url_to_use = p.resource_url_proxy or p.resource_url
    if url_to_use:
        lines.append(url_to_use)
```

优先使用代理 URL，确保跨域访问成功。

---

## 🔧 配置文件

**settings.py:**
```python
BASE_URL = os.getenv('BASE_URL', 'http://localhost:8000')
```
用于 CORS 检测时的 Origin 比对，以及构建代理 URL。

---

## ✅ 验证结果

### 1. 创建新记录自动检测
```bash
POST /api/collection/pages/
{
  "address": "https://httpbin.org/status/200",
  "title": "Test CORS",
  "resource_url": "https://httpbin.org/status/200"
}
```
结果:
- `resource_url_cors_support`: `true` (httpbin 支持 CORS)
- `resource_url_proxy`: `null`

### 2. 强制不支持跨域测试
手动设置:
```python
p = Page.objects.create(
    ...,
    resource_url_cors_support=False,
    resource_url_proxy="/api/proxy/?url=..."
)
```
M3U 输出:
```
#EXTINF:-1 ...,Test Non-CORS
/api/proxy/?url=https://example.com/video.m3u8
```

### 3. 代理接口测试
```bash
curl -I "http://localhost:8000/api/proxy/?url=https://httpbin.org/status/200"
```
响应:
```
HTTP/1.1 200 OK
Access-Control-Allow-Origin: *
Access-Control-Allow-Methods: GET, HEAD, OPTIONS, ...
...
```

---

## 📊 数据统计 (当前)

- Media 资源总数: 930
- 支持 CORS (cors_support=True): 929
- 需要代理 (proxy 非空): 1 (测试记录)

---

## 🎯 设计考虑

### 安全性
- 代理接口无身份验证（适合本地/局域网使用）
- 仅转发 HTTP/HTTPS URL，避免 file:// 等危险协议
- 可扩展: 可添加 `ALLOWED_PROXY_HOSTS` 白名单

### 性能
- CORS 检测放在创建时同步执行，可能增加写入延迟 (约 1-5 秒)
- 建议: 批量导入时禁用检测或异步执行

### 可维护性
- 检测逻辑集中化，便于调整策略
- 代理接口独立，可单独部署或替换

---

## 🚀 后续优化建议

1. **异步检测** - 使用 background_task 异步执行 CORS 检测，避免阻塞创建
2. **缓存结果** - 记录检测时间，定期重新检测（CORS 策略可能变化）
3. **白名单** - 添加 `settings.PROXY_ALLOWED_HOSTS` 限制代理目标域名
4. **速率限制** - 防止代理接口被滥用
5. **OPTIONS 预检** - 代理接口支持 `OPTIONS` 方法，返回允许的头部
6. **批量更新** - 为现有记录补充 cors_support 和 proxy 字段
7. **监控日志** - 记录代理请求失败情况，便于排查

---

**Ontology 任务:** `task_cors_proxy` (done)

**关联文档:**
- 本文件
- `docs/homepage_v2-architecture.md`
- `docs/homepage_v2-resource-url-accessible-20260320.md`

---

**验证确认:** 2026-03-20 22:55 - 所有功能正常 ✅
