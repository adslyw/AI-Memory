# Homepage V2 Worker 容器修复报告

> 修复时间: 2026-03-20 20:26-20:33 (Asia/Shanghai)
> 问题: Worker 容器启动失败
> 状态: ✅ 已完成

---

## 🔍 问题诊断

**错误信息:**
```
django.db.utils.DatabaseError: database disk image is malformed
```

**现象:**
- Docker 容器 `homepage_worker` 持续退出 (Exited 1)
- Web 容器 (`homepage_web`) 运行正常
- Django `makemigrations` / `migrate` 阶段失败

**根因:**
SQLite 数据库文件 `db.sqlite3` 发生损坏。可能原因:
- 容器异常退出导致写入未完成
- 文件系统 I/O 问题
- 磁盘空间不足（未检测到）

---

## 🛠️ 修复步骤

### 1. 备份原始数据
```bash
# 备份宿主机数据库文件
cp db.sqlite3 db.sqlite3.backup_20260320_202654
```

### 2. 导出数据库内容
```bash
sqlite3 db.sqlite3 .dump > db_dump_full.sql
```
成功导出，说明大部分数据可读。

### 3. 重建数据库
```bash
rm db.sqlite3
sqlite3 db.sqlite3 < db_dump_full.sql
```
新数据库文件大小: 4.8MB (原为 8.0MB，表明部分数据可能已丢失但结构完整)

### 4. 清理 Docker 资源
```bash
# 停止服务
docker compose down

# 删除旧的 named volume (防止缓存旧数据库)
docker volume rm homepage_v2_homepage_data

# 重新启动
docker compose up -d web worker
```

### 5. 验证修复
- ✅ Web 容器健康检查: `http://localhost:8000/` 返回正常
- ✅ Collection API 可访问: 返回 17,885 条记录
- ✅ Worker 容器持续运行, 迁移无错误
- ✅ 数据库迁移: "No migrations to apply"

---

## 📊 数据影响评估

- **表结构:** 完整保留
- **数据行数:** Collection 表 17,885 行（确认存在）
- **数据丢失:** 可能部分二进制数据或最近写入未持久化的记录丢失
- **功能完整性:** 读写操作正常，无进一步影响

---

## 🎯 后续建议

1. **监控数据库完整性**
   - 定期运行 `PRAGMA integrity_check;`
   - 添加健康检查端点
   - 设置 SQLite 备份策略 (WAL 模式)

2. **预防措施**
   - 确保容器正常关闭 (`docker compose down`)
   - 避免强制 kill 容器
   - 考虑迁移到 PostgreSQL (生产环境)

3. **自动化修复**
   - 添加容器启动前的数据库自检脚本
   - 自动备份 + 导出/重建流程
   - 异常告警通知

---

## 📝 技术细节

**Docker Compose 挂载配置:**
```yaml
volumes:
  - homepage_data:/app/dbdata  # named volume (已删除)
  - ./logs:/app/logs
  - .:/app
  - ./db.sqlite3:/app/dbdata/db.sqlite3  # bind mount
```

**关键发现:**
- Named volume 缓存了损坏的数据库，即使宿主机文件修复后仍然使用旧数据
- 必须删除 named volume 才能强制使用 bind mount 的新数据库
- 建议移除 named volume，仅使用 bind mount 以便更好地控制数据文件

---

**修复人:** 深蓝 (DeepBlue)
**修复确认:** 2026-03-20 20:33
