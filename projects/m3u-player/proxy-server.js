#!/usr/bin/env node
/**
 * M3U Player - CORS 代理服务器
 * 用于解决跨域问题，为所有请求添加 Access-Control-Allow-Origin 头
 */

const http = require('http');
const https = require('https');
const url = require('url');

const PORT = 8081; // 代理服务器端口
const TARGET_PREFIX = 'http://'; // 需要代理的 URL 前缀（可配置）

const server = http.createServer(async (req, res) => {
    const targetUrl = req.url.substring(1); // 去掉开头的 /

    if (!targetUrl) {
        res.writeHead(200, { 'Content-Type': 'text/plain' });
        res.end('M3U Player Proxy Server\nUsage: http://localhost:8081/<url-to-proxy>');
        return;
    }

    try {
        // 确保有协议头
        let finalUrl = targetUrl;
        if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
            finalUrl = 'http://' + finalUrl;
        }

        console.log(`[PROXY] ${req.method} ${finalUrl}`);

        // 发起请求
        const parsed = url.parse(finalUrl);
        const isHttps = parsed.protocol === 'https:';
        const client = isHttps ? https : http;

        const proxyReq = client.request(finalUrl, {
            method: req.method,
            headers: {
                ...req.headers,
                'Accept': '*/*',
                'Accept-Language': '*'
            }
        }, (proxyRes) => {
            // 复制响应头，添加 CORS
            const headers = { ...proxyRes.headers };
            headers['Access-Control-Allow-Origin'] = '*';
            headers['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS';
            headers['Access-Control-Allow-Headers'] = '*';

            res.writeHead(proxyRes.statusCode || 200, headers);
            proxyRes.pipe(res);
        });

        proxyReq.on('error', (err) => {
            console.error('[PROXY ERROR]', err.message);
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: err.message }));
        });

        // 处理 POST 数据
        req.pipe(proxyReq);

    } catch (err) {
        console.error('[SERVER ERROR]', err.message);
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: err.message }));
    }
});

server.listen(PORT, () => {
    console.log(`\n🚀 M3U Player Proxy 启动成功！`);
    console.log(`📍 代理端口: http://localhost:${PORT}/`);
    console.log(`🌐 使用方法:`);
    console.log(`   原始 URL: https://example.com/video.m3u8`);
    console.log(`   代理 URL: http://localhost:${PORT}/https://example.com/video.m3u8`);
    console.log(`\n💡 在 M3U Player 中使用代理后的 URL 即可绕过 CORS 限制\n`);
});
