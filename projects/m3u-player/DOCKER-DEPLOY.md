# Docker 部署指南

## 🚀 快速开始

### 1. 前置要求
- Docker 20.10+
- Docker Compose 2.0+
- 至少 512MB 可用内存

### 2. 一键部署

```bash
cd /home/deepnight/.openclaw/workspace/projects/m3u-player

# 给脚本执行权限
chmod +x deploy.sh

# 启动服务
./deploy.sh start
```

### 3. 访问应用
- 🌐 **应用地址**: http://localhost
- 🔌 **API 地址**: http://localhost/api/data

---

## 📦 架构说明

```
┌─────────────────┐     ┌──────────────┐     ┌─────────────┐
│    浏览器       │────▶│   Nginx      │────▶│  Node.js    │
│ (访问 localhost)│     │  (Port 80)   │     │  (Port 3000)│
└─────────────────┘     └──────────────┘     └─────────────┘
                                                      │
                                                      ▼
                                               ┌─────────────┐
                                               │  SQLite DB  │
                                               │  (持久化)   │
                                               └─────────────┘
```

### 组件
- **app**: Node.js 应用 (端口 3000)
- **nginx**: 反向代理 (端口 80/443)
- **data volume**: `./data` 目录持久化数据库

---

## 🔧 常用命令

```bash
# 查看状态
./deploy.sh status

# 查看日志
./deploy.sh logs app      # 应用日志
./deploy.sh logs nginx    # Nginx 日志

# 重启服务
./deploy.sh restart

# 停止服务
./deploy.sh stop

# 进入容器调试
./deploy.sh shell

# 备份数据库
./deploy.sh backup

# 更新代码
./deploy.sh update

# 清理所有（谨慎！）
./deploy.sh clean
```

---

## ⚙️ 配置说明

### 环境变量
可在 `docker-compose.yml` 中修改：
- `PORT`: 应用端口（默认 3000）
- `NODE_ENV`: 运行环境（production/development）
- `DATABASE_PATH`: 数据库路径（默认 `/data/m3u-player.db`）

### Nginx 配置
- 配置文件: `nginx.conf`
- 修改 `server_name` 为你的域名
- HTTPS 配置需取消注释并放置证书到 `ssl/` 目录

### 持久化数据
- 数据库文件: `./data/m3u-player.db`
- 应用日志: `./logs/` (可选)

---

## 🐛 故障排除

### 端口冲突
如果 80 或 3000 端口被占用，修改 `docker-compose.yml` 中的端口映射。

### 数据库权限
确保 `./data` 目录对容器可写：
```bash
mkdir -p data
chmod 755 data
```

### 查看容器日志
```bash
docker-compose logs -f app
docker-compose logs -f nginx
```

### 健康检查失败
等待 40 秒让应用启动，或查看日志：
```bash
docker-compose logs app
```

---

## 🔒 安全建议

1. **修改默认端口**: 避免使用 80，改用非标准端口
2. **启用 HTTPS**: 使用 Let's Encrypt 免费证书
3. **配置防火墙**: 仅开放必要端口
4. **定期备份**: 使用 `./deploy.sh backup`
5. **更新依赖**: 定期 `docker-compose pull` 更新基础镜像

---

## 📊 性能优化

### 资源限制
在 `docker-compose.yml` 的 `app` 服务中添加：
```yaml
deploy:
  resources:
    limits:
      cpus: '0.5'
      memory: 512M
```

### 数据库清理
定期清理过期频道和 WAL 文件：
```sql
-- 在容器中执行
VACUUM;
PRAGMA wal_checkpoint(TRUNCATE);
```

---

## 🔄 更新升级

```bash
# 1. 拉取最新代码
git pull

# 2. 重新构建镜像
./deploy.sh build

# 3. 重启服务
./deploy.sh restart
```

---

## 📝 注意事项

- 首次启动会自动创建数据库表结构
- 频道数据存储在 `./data/m3u-player.db`
- 如果更换服务器，复制 `data/` 目录即可迁移数据
- 生产环境建议使用 `docker-compose -f docker-compose.prod.yml` 并配置监控

---

## 🆘 需要帮助？

查看日志：
```bash
./deploy.sh logs
```

检查容器状态：
```bash
./deploy.sh status
```

进入容器调试：
```bash
./deploy.sh shell
```

---

**版本**: 1.0 | **更新日期**: 2026-03-15
