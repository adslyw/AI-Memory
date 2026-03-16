# M3U Player - 快速部署指南

## 🚀 1 分钟快速启动

### 方式 1: 启动脚本 (推荐)

```bash
cd /home/deepnight/.openclaw/workspace/projects/m3u-player
./start.sh
```

然后访问: **http://localhost:8080**

### 方式 2: 手动启动

```bash
cd /home/deepnight/.openclaw/workspace/projects/m3u-player
python3 -m http.server 8080
```

### 方式 3: 指定端口

```bash
python3 -m http.server 9000  # 使用 9000 端口
```

---

## 📱 使用说明

1. **添加频道:** 点击左侧 "+ 添加频道"
2. **输入信息:**
   - 频道名称 (如: CCTV-1)
   - M3U8 链接 (如: `https://example.com/live.m3u8`)
3. **播放:** 点击频道列表中的项目即可播放
4. **控制:** 使用视频原生控件 (播放/暂停/全屏)

---

## ⌨️ 快捷键

- `空格`: 播放/暂停
- `ESC`: 关闭添加频道窗口

---

## 🎨 主题切换

点击右上角 🌙/☀️ 按钮切换深色/浅色模式。

---

## 📝 测试用 M3U8 链接

你可以使用以下公开测试源 (仅供参考):

```
https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8
https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8
```

---

## 🐛 已知限制

- 需要现代浏览器 (Chrome/Firefox/Safari/Edge)
- HLS 播放依赖 HLS.js (Safari 原生支持)
- 频道数据存储在浏览器 LocalStorage (清除缓存会丢失)
- 不支持 .m3u (只支持 .m3u8 直播流)

---

## 📦 项目结构

```
m3u-player/
├── index.html      # 主页面
├── app.js          # 播放器逻辑
├── start.sh        # 启动脚本
└── README.md       # 本文档
```

---

## 🔧 故障排除

**问题:** 视频无法播放，显示错误
- 检查链接是否为有效的 .m3u8 地址
- 检查网络连接
- 尝试不同的浏览器

**问题:** 页面无法加载
- 确保 Python3 已安装
- 检查端口是否被占用 (默认 8080)

**问题:** 主题切换无效
- 检查浏览器控制台是否有错误

---

**版本:** 1.0 (2026-03-14)
**状态:** 快速部署版
