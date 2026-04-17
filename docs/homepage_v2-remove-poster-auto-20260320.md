# Homepage V2 - 删除自动封面图生成功能

> 修改日期: 2026-03-20 21:01 (Asia/Shanghai)
> 修改文件: `collection/signals.py`
> 状态: ✅ 已完成

---

## 📋 变更概述

**目标:**
删除 `collection/signals.py` 中针对特定站点的媒体封面图自动生成逻辑，保留文件扩展名自动识别 `resource_type` 功能。

**原因:**
- 自动生成的封面图可能不准确或不适用于新站点
- 简化系统，减少硬编码逻辑
- 鼓励管理员手动维护高质量封面

---

## 🔧 具体修改

### Before (`signals.py`)

```python
def generate_poster(instance):
    page_url = instance.address
    if 'missav.ai' in page_url:
        poster_name = page_url.split('/')[-1]
        poster = f"https://fourhoi.com/{poster_name}/cover.jpg"
        return poster
    if '123av.com' in page_url:
        ...
    if 'javxx.com' in page_url:
        ...
    if 'www.ffuuff.com' in page_url or 'xiongmao63' in page_url:
        ...
    return None

@receiver(post_save, sender=Page)
def init_user_data(sender, instance, created, **kwargs):
    if created:
        # 自动设置 resource_type (保留)
        ...
        if instance.resource_type == 'media':
            poster = generate_poster(instance)  # ❌ 已删除
            if poster:
                instance.poster = poster
        instance.save()
```

### After (`signals.py`)

```python
@receiver(post_save, sender=Page)
def init_user_data(sender, instance, created, **kwargs):
    if created:
        # 根据文件扩展名自动设置资源类型（保留）
        if instance.address.endswith('.m3u8'):
            instance.resource_type = 'media'
        if instance.address.endswith('.webp'):
            instance.resource_type = 'pic'
        if instance.address.endswith('.gif'):
            instance.resource_type = 'pic'
        if '.jpg' in instance.address:
            instance.resource_type = 'pic'

        # 注意：不再自动生成封面图，poster 需手动填写

        instance.save()
```

---

## ✅ 验证结果

**测试用例:**
```bash
POST /api/collection/pages/
{
  "address": "https://example.com/test.m3u8",
  "title": "Test Media",
  "accessable": false
}
```

**响应:**
- `resource_type`: `"media"` ✅ (自动识别)
- `poster`: `null` ✅ (无自动生成)
- 无错误

**容器状态:**
- `homepage_web`: Up ✅
- `homepage_worker`: Up ✅
- API 访问正常 ✅

---

## 📊 影响评估

### 对现有数据
- ❌ **不影响**：已存在的记录保留原有 poster 值
- ✅ **新记录**：不再自动填充 poster，需手动录入或通过其他方式补充

### 对功能
- ✅ EPG 生成 (`/epg.xml`) - 使用 `poster` 字段作为频道图标，为空时仍然有效
- ✅ M3U 播放列表 (`/player.m3u`) - 同样使用 poster，缺失不影响播放
- ✅ TVBox VOD API - poster 作为 `vod_pic` 返回，可为空

### 用户体验
- 需要管理员手动为重要资源上传封面
- 减少自动生成的不准确图片
- 更清晰的职责分离

---

## 🎯 后续建议

1. **批量补全 poster**
   - 如需为现有媒体资源批量添加 poster，可以:
     - 编写数据迁移脚本
     - 在 Admin 中批量编辑
     - 通过 API 批量更新

2. **自定义封面图生成器**
   - 如果未来需要自动生成，建议:
     - 将逻辑外置为独立服务 (如 `services/poster_generator.py`)
     - 支持插件化规则，易于扩展
     - 提供配置界面 (Admin 可自定义规则)

3. **封面图存储优化**
   - 考虑将 poster 存储为 `URLField` 或 `ImageField` (使用云存储)
   - 支持 CDN 加速
   - 添加缩略图生成

---

## 📝 关联 Ontology

- ✅ 任务: `task_remove_poster_auto` (done)
- ⚠️ 任务: `task_poster_gen` (cancelled - 不再需要)
- 📄 文档: 本文件已录入知识图谱

---

**修改人:** 深蓝 (DeepBlue)
**确认状态:** 已完成，系统运行正常
