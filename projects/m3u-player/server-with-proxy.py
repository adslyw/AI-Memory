#!/usr/bin/env python3
"""
M3U Player - 集成 CORS 代理的 HTTP 服务器
在同一个端口 (8080) 上：
- 提供静态文件
- 代理 /api/proxy/* 路径的请求（自动添加 CORS 头）
"""

import http.server
import socketserver
import urllib.request
import urllib.error
import json
import os

PORT = 8080
PROXY_PREFIX = '/api/proxy/'

class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # 代理请求
        if self.path.startswith(PROXY_PREFIX):
            self.handle_proxy()
        else:
            # 正常静态文件
            super().do_GET()

    def do_POST(self):
        if self.path.startswith(PROXY_PREFIX):
            self.handle_proxy()
        else:
            super().do_POST()

    def handle_proxy(self):
        # 获取真实 URL (去掉 /api/proxy/ 前缀)
        target_url = self.path[len(PROXY_PREFIX):]
        if not target_url:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b'Missing target URL')
            return

        # 确保有协议头
        if not target_url.startswith(('http://', 'https://')):
            target_url = 'http://' + target_url

        print(f'[PROXY] {self.command} {target_url}')

        try:
            # 构建请求
            req = urllib.request.Request(
                target_url,
                method=self.command,
                headers={k: v for k, v in self.headers.items() if k.lower() not in ('host', 'connection')}
            )

            # 处理请求体
            if self.command in ('POST', 'PUT'):
                length = int(self.headers.get('Content-Length', 0))
                if length:
                    body = self.rfile.read(length)
                    req.data = body

            # 发送请求
            with urllib.request.urlopen(req, timeout=30) as resp:
                # 复制状态码
                self.send_response(resp.status)

                # 复制并添加 CORS 头
                headers = resp.headers
                for key, value in headers.items():
                    if key.lower() not in ('access-control-allow-origin', 'access-control-allow-methods', 'access-control-allow-headers'):
                        self.send_header(key, value)
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
                self.send_header('Access-Control-Allow-Headers', '*')
                self.end_headers()

                # 转发响应体
                data = resp.read()
                self.wfile.write(data)

        except urllib.error.HTTPError as e:
            print(f'[PROXY ERROR] {e.code} {e.reason}')
            self.send_response(e.code)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(e.read() if hasattr(e, 'read') else b'')
        except Exception as e:
            print(f'[PROXY FAIL] {str(e)}')
            self.send_response(500)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({'error': str(e)}).encode())

    def log_message(self, format, *args):
        # 减少日志噪音
        if '/api/proxy/' in str(args):
            print(f'[PROXY] {args[0]} {args[1]} {args[2]}')
        else:
            super().log_message(format, *args)

if __name__ == '__main__':
    os.chdir(os.path.dirname(os.path.abspath(__file__)))

    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"\n🚀 M3U Player (with built-in CORS proxy) 启动成功！")
        print(f"📍 端口: {PORT}")
        print(f"🌐 主页: http://localhost:{PORT}/")
        print(f"🔧 代理路径: http://localhost:{PORT}{PROXY_PREFIX}<target-url>")
        print(f"\n💡 使用示例:")
        print(f"   原始 M3U: http://localhost:8000/player.m3u")
        print(f"   使用代理: http://localhost:{PORT}{PROXY_PREFIX}http://localhost:8000/player.m3u")
        print(f"\n按 Ctrl+C 停止服务\n")

        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n👋 服务已停止")
            exit(0)
