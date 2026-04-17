```python
# applecms/signals.py (修改前 - 同步方式)

from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import AppleSite
from .services.category_sync import AppleCategorySyncService

@receiver(post_save, sender=AppleSite)
def sync_apple_categories(sender, instance, created, **kwargs):
    """
    新增 AppleSite 后立即同步分类（同步方式，阻塞请求）
    """
    # 当前实现：保存后立即执行同步
    AppleCategorySyncService.sync_categories(instance)
```

---

```python
# applecms/signals.py (修改后 - 异步方式)

from django.db.models.signals import post_save
from django.dispatch import receiver
from .models import AppleSite
from .tasks import async_sync_apple_categories  # 新导入异步任务

@receiver(post_save, sender=AppleSite)
def schedule_apple_category_sync(sender, instance, created, **kwargs):
    """
    新增 AppleSite 后调度异步任务同步分类（非阻塞）
    """
    # 只对新建的站点或需要更新的站点触发
    # 可根据实际情况调整条件，例如：
    # if created or instance.some_field_changed:
    async_sync_apple_categories(instance.id)
```

---

```python
# applecms/tasks.py (新建或扩展)

import logging
from background_task import background
from .models import AppleSite
from .services.category_sync import AppleCategorySyncService

logger = logging.getLogger(__name__)

@background(schedule=0)  # 立即执行，也可设置为 schedule=30 延迟30秒
def async_sync_apple_categories(site_id):
    """
    异步同步 AppleSite 的分类
    """
    try:
        site = AppleSite.objects.get(id=site_id)
        AppleCategorySyncService.sync_categories(site)
        logger.info(f"成功异步同步站点 {site.name} (ID={site_id}) 的分类")
    except AppleSite.DoesNotExist:
        logger.error(f"异步同步失败：站点 ID={site_id} 不存在，可能已被删除")
    except Exception as e:
        logger.exception(f"异步同步站点 ID={site_id} 的分类时发生异常: {e}")
        # 根据需要可以重新调度任务或记录到错误监控系统
```

---

**关键变更:**

| 维度 | 修改前 | 修改后 |
|------|--------|--------|
| 执行方式 | 同步阻塞 | 异步非阻塞 |
| 响应时间 | 受网络和分类数量影响 | 立即返回 |
| 用户体验 | 保存后需等待 | 即时响应 |
| 失败处理 | 直接返回错误 | 任务队列记录，可重试 |
| 代码位置 | signals.py 直接调用服务 | signals.py 只触发任务，tasks.py 执行 |

**注意事项:**
1. 确保 `AppleCategorySyncService.sync_categories` 是幂等操作（多次执行结果一致），避免重复数据
2. 如果站点可能频繁保存，考虑添加任务去重 (例如使用 `Task.objects.filter(task_name='...', params=[site_id]).exists()`)
3. Worker 需正常运行：`docker compose exec worker python manage.py process_tasks`
4. 任务执行日志可查询数据库表 `background_task_task` 和 `background_task_completedtask`
