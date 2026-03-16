# M3U Player - 生产环境 Docker 部署
# 基于 Node.js + Nginx

# ==================== 构建阶段 ====================
FROM node:20-slim AS builder

WORKDIR /app

# 安装构建依赖（better-sqlite3 需要）
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    && rm -rf /var/lib/apt/lists/*

# 复制依赖文件
COPY package*.json ./
RUN npm ci --only=production --no-optional

# 复制源代码
COPY . .

# 复制源代码
COPY . .

# ==================== 运行阶段 ====================
FROM node:20-slim

WORKDIR /app

# 安装运行时依赖和 tini/curl
RUN apt-get update && apt-get install -y \
    tini \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 从构建阶段复制 node_modules 和源代码
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/*.js ./
COPY --from=builder /app/*.html ./
COPY --from=builder /app/*.json ./

# 创建数据目录（用于持久化数据库）
VOLUME /data

# 设置环境变量
ENV NODE_ENV=production
ENV PORT=3456
ENV DATABASE_PATH=/data/m3u-player.db

# 暴露端口
EXPOSE 3000

# 使用 tini 作为 init 进程，正确处理信号
ENTRYPOINT ["/usr/bin/tini", "--"]

# 启动命令
CMD ["node", "server.js"]
