# Homepage V2 - Resource URL 可访问性监控

> 实现日期: 2026-03-20
> 状态: ✅ 已完成

---

## 📋 需求

为 `Page` 模型添加字段记录 `resource_url` 的可访问性状态，并创建定时任务自动更新。

---

## 🛠️ 实现

### 1. 数据库迁移

**模型修改 (`collection/models.py`):**
```python
resource_url_accessible = models.BooleanField(
    verbose_name='资源URL可访问性',
    default=False
)
```

**迁移生成:**
```bash
docker compose exec web python manage.py makemigrations collection
# 创建 0005_page_resource_url_accessible.py
docker compose exec web python manage.py migrate collection
```

### 2. 定时检查任务

**任务实现 (`collection/tasks.py`):**
- `_check_urls_accessible_impl()`: 实际检查逻辑，返回 (checked, updated)
- `check_urls_accessible()`: 后台任务，每小时执行一次
- 使用 HEAD 请求，超时 10 秒，2xx/3xx 视为可访问
- 仅当状态变化时才保存

**自动调度 (`collection/apps.py`):**
在 `CollectionConfig.ready()` 中启动后台线程延迟调用 `schedule_periodic_check()`，避免应用启动时数据库未就绪。

### 3. 管理命令

**`check_resource_urls` 命令:**
- `--now`: 立即执行同步检查
- 无参数: 加入队列每小时执行

```bash
# 立即执行
python manage.py check_resource_urls --now

# 加入队列 (每小时重复)
python manage.py check_resource_urls
```

### 4. API 序列化

**`collection/serializers.py`:**
将 `resource_url_accessible` 加入 `PageSerializer` 字段列表，API 返回可访问状态。

---

## ✅ 验证

1. **迁移成功:**
```bash
Applying collection.0005_page_resource_url_accessible... OK
```

2. **任务调度:**
```bash
$ python manage.py shell
>>> from background_task.models import Task
>>> Task.objects.count()
2  # 已创建重复任务
>>> Task.objects.first().task_name
'collection.tasks.check_urls_accessible'
```

3. **检查逻辑测试:**
```bash
# 创建测试记录
POST /api/collection/pages/
{
  "address": "https://httpbin.org/status/200",
  "title": "Test Accessible",
  "resource_url": "https://httpbin.org/status/200"
}
# → resource_url_accessible: false (初始)

# 运行检查
$ python manage.py check_resource_urls --now
Checked: 2, Updated: 1

# 验证更新
GET /api/collection/pages/2/
# → resource_url_accessible: true ✅
```

4. **容器状态:**
- `homepage_web`: Up ✅
- `homepage_worker`: Up ✅ (Background task worker 正常)

---

## 🔧 技术细节

### Docker Volume 挂载问题修复

**问题:** Worker 容器反复因 SQLite 损坏退出
**根因:** `docker-compose.yml` 中 web 服务同时使用了 bind mount (`./db.sqlite3:/app/dbdata/db.sqlite3`) 和 named volume (`homepage_data:/app/dbdata`)，两者冲突导致数据不一致。

**解决:** 移除 bind mount 配置，两个服务统一使用 named volume。
```yaml
volumes:
  - homepage_data:/app/dbdata  # 只有这一个挂载
```
重启后数据库损坏问题消失，worker 正常运行。

### 避免 AppConfig.ready() 数据库访问警告

在 `CollectionConfig.ready()` 中使用延迟线程安排任务，避免 Django 启动早期访问数据库。

---

## 📊 影响

- ✅ 新增字段 `resource_url_accessible` 默认 `False`
- ✅ 现有数据: 新字段无值，后续检查会更新
- ✅ API 返回包含可访问状态
- ✅ 每小时自动检查，失败率自动标记

---

## 🎯 后续建议

1. **监控任务队列**
   - 添加 Admin 视图查看 pending/processed 任务
   - 设置失败告警（email/webhook）

2. **检查优化**
   - 支持并发检查（使用线程池）
   - 添加检查历史记录表，跟踪可访问性变化趋势
   - 实现智能重试（短暂失败不立即标记为不可访问）

3. **扩展**
   - 将检查逻辑抽象为可配置的检查策略（HTTP、ICMP、自定义脚本）
   - 支持不同资源类型使用不同检查方法

---

**关联 Ontology:**
- 任务: `task_url_accessible` (done)
- 文档: 本文件
