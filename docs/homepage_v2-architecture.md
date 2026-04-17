# Homepage V2 项目架构分析

> 生成时间: 2026-03-20
> 分析人: 深蓝 (DeepBlue)

## 📋 项目概览

这是一个生产就绪的 Docker 化 Django 项目，用于提供视频资源管理、EPG 生成、M3U 播放列表和 TVBox 配置。项目采用 SQLite 数据库，并使用 django-background-tasks 处理异步任务。

**技术栈:**
- Django 5.1
- SQLite (开发) / PostgreSQL (生产配置)
- Django REST Framework
- django-background-tasks
- Whitenoise (静态文件)
- Docker + Docker Compose

## 🏗️ 应用架构

### 核心应用

#### 1. `collection` - 资源收集与管理
**用途:** 管理媒体资源（视频、图片等），提供 API 和播放列表。

**模型 (`Page`):**
```python
class Page(models.Model):
    address = models.TextField()           # 原始页面/资源链接
    title = models.TextField()            # 标题
    accessable = models.BooleanField()    # 是否可访问（用于过滤）
    resource_type = CharField()           # 类型: page/pic/media
    poster = models.TextField()           # 封面图 URL
    resource_url = models.TextField()     # 实际媒体地址（.m3u8 等）
    desc = models.TextField()             # 描述
    created_at = models.DateTimeField()
```

**自动处理逻辑 (`signals.py`):**
- 监听 `post_save` 信号
- 根据文件扩展名自动设置 `resource_type`:
  - `.m3u8` → `media`
  - `.webp`, `.gif`, `.jpg` → `pic`
- 为 `media` 类型自动生成封面图 (针对特定站点)

**API 端点:**
- `GET /api/collection/pages/` - CRUD 操作 (REST)
- `GET /api/provide/vod` - TVBox VOD API 兼容
- `GET /api/provide/vod/detail` - 详情 API
- `GET /api/provide/vod/class` - 分类列表
- `GET /player.m3u` - M3U 播放列表
- `GET /epg.xml` - XMLTV EPG 格式
- `GET /tvbox.json` - TVBox 配置

#### 2. `applecms` - 苹果 CMS 站点集成
**用途:** 管理外部苹果CMS站点，同步分类信息。

**模型:**
```python
class AppleSite(models.Model):
    key = CharField(unique=True)
    name = CharField()
    api_base = URLField()                 # 对外 API 地址
    enabled = BooleanField()
    searchable, quick_search, filterable = BooleanField()
    is_adult = BooleanField()
    timeout = PositiveIntegerField()

class AppleCategory(models.Model):
    site = ForeignKey(AppleSite, related_name='categories')
    type_id = CharField()                 # 远程分类ID
    type_name = CharField()
    order = PositiveIntegerField()        # 排序
    enabled = BooleanField()
```

**管理功能:**
- Admin 内嵌分类同步按钮
- `AppleCategorySyncService` 自动拉取远程分类
- TVBox 配置生成 (`/tvbox.json`) 动态生成

#### 3. `app` - 健康检查与任务
**用途:** 系统健康检查端点，背景任务示例。

**视图:**
- `/` - 健康检查，返回 "Django is running 🚀"
- `/run-task/` - 触发后台任务
- `/get-csrf/` - 获取 CSRF token

**后台任务 (`tasks.py`):**
```python
@background(schedule=5)
def say_hello(name):
    # 5秒后执行
    ...
```

## 🔄 系统流程

### 资源录入流程
1. 管理员在 Admin 或通过 API 创建 `Page` 对象
2. `post_save` 信号自动:
   - 根据 `address` 后缀判断 `resource_type`
   - 对于媒体资源，根据域名生成封面图
3. 用户可通过 M3U/EPG/TVBox API 访问已发布资源 (`accessable=True`)

### TVBox 集成
- TVBox 配置 (`/tvbox.json`) 列出所有启用的 `AppleSite`
- 每个站点提供 VOD API 和分类
- 客户端通过 `ac` 参数调用不同端点:
  - `ac=class` → 分类
  - `wd=xxx` → 搜索
  - `t=xxx` → 按分类筛选

## 🐳 容器化部署

**docker-compose.yml:**
- `web` 服务: Gunicorn 运行，端口 8000
- `worker` 服务: 处理后台任务
- 卷挂载: 数据库持久化 (`homepage_data`), 日志 (`./logs`)
- 数据库路径: `/app/dbdata/db.sqlite3`

**启动:** `docker compose up -d`

## 🔧 当前状态

截至 2026-03-20:
- ✅ Docker 容器运行正常 (web: Up 2 days)
- ⚠️ Worker 容器退出 (Exited 1) - 需要检查日志
- 数据库: `db.sqlite3` 已存在，位于 `dbdata/`
- 静态文件通过 Whitenoise 服务
- CORS 配置支持 Chrome 扩展和本地开发

## 🎯 优化与开发方向

### 潜在改进点

1. **性能优化**
   - 添加数据库查询缓存（如 Redis）
   - 分页优化（大型数据集）
   - 静态文件 CDN 或 Nginx 反向代理

2. **功能增强**
   - 批量导入 Page (CSV/JSON)
   - 封面图生成器扩展更多站点
   - 用户认证和权限控制
   - API 限流和监控

3. **可靠性与监控**
   - Worker 容器自动重启 (`restart: unless-stopped`)
   - 添加健康检查端点 (`/health/`)
   - 日志轮转和聚合
   - 错误告警（邮件/Webhook）

4. **代码质量**
   - 单元测试覆盖率提升
   - API 文档 (OpenAPI/Swagger)
   - 配置管理 (环境变量验证)
   - 数据库迁移优化

5. **安全性**
   - 生产 `SECRET_KEY` 严格保密
   - 数据库连接池
   - API 认证机制 (Token/JWT)
   - 输入验证和 XSS/CSRF 防护

## 📊 数据库快照（预估）

**collection_page** (主要资源表):
- 字段: id, address, title, accessable, resource_type, poster, resource_url, desc, created_at
- 预计存储: 每日新增 100-500 条，长期可达到 10k+

**applecms_applesite** & **applecms_applecategory**:
- 配置外部资源站，数量少（个位数到十几）

## 🤝 与现有系统集成

- 可配合 M3U Player 前端进行播放
- 生成的 EPG/M3U 可被第三方播放器使用
- TVBox 配置直接导入使用

## 📚 参考

- `collection/views.py` - 核心业务逻辑
- `collection/models.py` - 数据模型
- `collection/signals.py` - 自动处理
- `applecms/services/category_sync.py` - 第三方集成
- `homepage/settings.py` - 完整配置

---

**下一步建议:** 根据具体优化和功能需求，制定分阶段实施计划。
