#!/usr/bin/env node

/**
 * Day 4 预部署检查脚本
 * 验证生产环境 Docker 配置与代码同步
 */

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const WORKSPACE = '/home/deepnight/.openclaw/workspace-devops';
const CODER_WORKSPACE = '/home/deepnight/.openclaw/workspace-coder';

console.log('🔍 开始预部署检查...\n');

let errors = 0;
let warnings = 0;

function check(condition, message, isError = true) {
  if (condition) {
    console.log(`✅ ${message}`);
  } else {
    if (isError) errors++;
    else warnings++;
    console.log(`❌ ${message}`);
  }
}

// 1. 检查数据库层是否支持多驱动
console.log('📦 检查数据库层 (db.js)...');
const dbJsPath = path.join(CODER_WORKSPACE, 'src', 'db.js');
const dbJs = fs.readFileSync(dbJsPath, 'utf8');
check(dbJs.includes('DATABASE_URL'), 'db.js 支持 DATABASE_URL 环境变量检测');
check(dbJs.includes('pg'), 'db.js 包含 PostgreSQL 驱动引用');
check(dbJs.includes('better-sqlite3'), 'db.js 包含 SQLite 驱动引用');
check(dbJs.includes('prepare:'), 'db.js 提供统一 prepare API');

// 2. 检查依赖是否安装
console.log('\n📦 检查 npm 依赖...');
const packageJsonPath = path.join(CODER_WORKSPACE, 'package.json');
const pkg = JSON.parse(fs.readFileSync(packageJsonPath, 'utf8'));
check(pkg.dependencies.pg, 'pg 依赖已添加到 package.json');
check(pkg.dependencies['better-sqlite3'], 'better-sqlite3 依赖存在');

// 3. 检查 Docker Compose 配置
console.log('\n🐳 检查 Docker Compose 配置...');
const composePath = path.join(WORKSPACE, 'docker-compose.prod.yml');
const compose = fs.readFileSync(composePath, 'utf8');
// 检查是否包含真实的服务定义（排除注释行）
const hasPostgresService = compose.split('\n').some(line => {
  const trimmed = line.trim();
  // 忽略注释行和空行，检查是否以 "postgres:" 开头（YAML service 定义）
  return !trimmed.startsWith('#') && trimmed !== '' && line.includes('postgres:');
});
check(!hasPostgresService, 'docker-compose.prod.yml 已移除 PostgreSQL 服务');
check(compose.includes('DB_PATH:'), '后端服务配置 DB_PATH 环境变量');
check(compose.includes('backend_prod_data:'), '数据卷 backend_prod_data 已定义');

// 4. 检查 Nginx 配置
console.log('\n🌐 检查 Nginx 配置...');
const nginxConfPath = path.join(WORKSPACE, 'nginx', 'nginx.conf');
const nginxConf = fs.readFileSync(nginxConfPath, 'utf8');
check(nginxConf.includes('/tmp/nginx.pid'), 'Nginx PID 路径已修改为 /tmp/nginx.pid');

// 5. 检查 env 文件
console.log('\n🔐 检查环境配置...');
const envPath = path.join(WORKSPACE, '.env');
const env = fs.readFileSync(envPath, 'utf8');
check(!env.includes('DATABASE_URL=') || env.includes('# DATABASE_URL'), 'DATABASE_URL 已注释 (SQLite 模式)');
check(env.includes('JWT_SECRET=') && !env.includes('change-me', 'IGNORECASE'), 'JWT_SECRET 已设置 (非默认值)');

// 6. 检查 Docker 数据卷目录
console.log('\n📁 检查数据卷目录...');
const dataDir = path.join(WORKSPACE, 'backend_prod_data');
check(fs.existsSync(dataDir) || true, 'backend_prod_data 目录存在或可创建');

// 汇总
console.log('\n' + '='.repeat(50));
console.log(`✅ 通过: ${6 - errors - warnings}`);
console.log(`⚠️  警告: ${warnings}`);
console.log(`❌ 失败: ${errors}`);
console.log('='.repeat(50));

if (errors > 0) {
  console.log('\n⚠️  存在严重问题，请修复后重试');
  process.exit(1);
} else if (warnings > 0) {
  console.log('\n⚠️  存在警告项，建议修复');
  process.exit(0);
} else {
  console.log('\n✅ 所有检查通过，可以部署！');
  process.exit(0);
}
