# Homepage V2 - player.m3u 接口优化

> 修改日期: 2026-03-20 22:37 (Asia/Shanghai)
> 修改文件: `collection/views.py`
> 状态: ✅ 已完成

---

## 🎯 需求

`player.m3u` 接口只返回 `resource_url_accessible=True` 的资源，避免播放不可用的流。

---

## 🔧 修改内容

### Before
```python
def media_playlist_m3u(request):
    pages = Page.objects.filter(accessable=True, resource_type='media')
```

### After
```python
def media_playlist_m3u(request):
    pages = Page.objects.filter(
        accessable=True,
        resource_type='media',
        resource_url_accessible=True  # 新增：只返回可访问的资源
    )
```

---

## ✅ 验证结果

**数据库统计:**
- `accessable=True` + `resource_type='media'`: 498 条
- `resource_url_accessible=True`: 370 条
- `resource_url_accessible=False`: 128 条

**M3U 接口返回:**
```bash
$ curl -s "http://localhost:8000/player.m3u" | grep -c "^#EXTINF"
370
```

✅ 只返回 370 条可访问资源，128 条不可访问资源已被过滤

---

## 📊 影响

- ✅ 播放器列表更精准，避免无效链接
- ✅ 减少客户端加载时间
- ✅ 与 admin 筛选逻辑保持一致
- ✅ 不破坏现有兼容性（仍是 M3U 格式）

---

**Ontology 任务:** `task_m3u_filter` (done)
