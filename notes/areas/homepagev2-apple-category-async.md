# 任务: Apple Category 异步更新

**来源:** homepagev2 项目
**时间:** 2026-03-26
**状态:** 待实施

## 目标
将新增/更新 AppleSite 后更新 AppleCategory 的逻辑从同步改为后台异步任务。

## 背景
- 当前：保存 AppleSite 时立即同步分类，阻塞请求
- 目标：使用 django-background-tasks 异步执行，提升响应速度

## 实施步骤

### 1. 检查现有信号/重写方法
找到当前执行 category 同步的位置：
- `applecms/signals.py` 中的 `post_save` 信号
- 或 `AppleSiteAdmin.save_model` 方法
- 或自定义的 `AppleCategorySyncService`

### 2. 创建异步任务
在 `applecms/tasks.py` 中定义后台任务：

```python
from background_task import background
from .services.category_sync import AppleCategorySyncService

@background(schedule=0)  # 立即执行
def async_sync_apple_categories(site_id):
    """
    异步同步 AppleSite 的分类
    """
    try:
        site = AppleSite.objects.get(id=site_id)
        AppleCategorySyncService.sync_categories(site)
        logger.info(f"成功同步站点 {site.name} 的分类")
    except AppleSite.DoesNotExist:
        logger.error(f"站点 {site_id} 不存在")
    except Exception as e:
        logger.error(f"同步分类失败: {e}")
```

### 3. 修改触发逻辑
将同步调用改为触发异步任务：

**如果使用 signals.py:**
```python
from .tasks import async_sync_apple_categories

@receiver(post_save, sender=AppleSite)
def schedule_apple_category_sync(sender, instance, created, **kwargs):
    # 只对新建或特定条件触发
    if created or instance.needs_sync:
        async_sync_apple_categories(instance.id)
```

**如果使用 Admin:**
```python
def save_model(self, request, obj, form, change):
    super().save_model(request, obj, form, change)
    async_sync_apple_categories(obj.id)
```

### 4. 配置说明
确保 `settings.py` 已配置：
```python
INSTALLED_APPS = [
    ...
    'background_task',
]

# 可选配置
BACKGROUND_TASK_RUN_ASYNC = True  # 使用线程池异步执行
BACKGROUND_TASK_ASYNC_THREADS = 4
```

### 5. Worker 配置
确认 docker-compose.yml 中 worker 容器正常运行：
```yaml
worker:
  command: python manage.py process_tasks
  # 或使用定时调度: python manage.py process_tasks --queue=default --interval=30
```

### 6. 测试验证
- 保存 AppleSite 后立即返回响应
- 检查任务队列: `python manage.py shell` → `from background_task.models import Task; Task.objects.all()`
- 观察 worker 日志确认异步执行

## 注意事项
- 同步服务 `AppleCategorySyncService` 应保持幂等性，避免多次执行导致重复数据
- 考虑添加任务去重逻辑（相同 site_id 的 pending 任务可合并）
- 记录任务执行状态，便于排查问题
- 如果需要立即看到结果（如 admin 显示），可额外提供手动同步按钮

## 验收标准
- [ ] 保存 AppleSite 响应时间 < 2 秒（不等待分类同步完成）
- [ ] 分类数据最终一致
- [ ] worker 正常处理任务
- [ ] 失败任务有重试或告警机制

---
**依赖:** django-background-tasks 已安装（根据架构文档）
**风险:** 低 - 仅修改触发方式，同步逻辑不变
**预计工时:** 1-2 小时
