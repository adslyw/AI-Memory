const express = require('express');
const Database = require('better-sqlite3');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = 3456;

// 中间件
app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.static(path.join(__dirname)));

// 初始化数据库
const dbPath = process.env.DATABASE_PATH || path.join(__dirname, 'm3u-player.db');
const dbDir = path.dirname(dbPath);
if (!require('fs').existsSync(dbDir)) {
    require('fs').mkdirSync(dbDir, { recursive: true });
}
const db = new Database(dbPath);
db.pragma('journal_mode = WAL');
db.pragma('foreign_keys = ON');

// 创建表
db.exec(`
  CREATE TABLE IF NOT EXISTS channels (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    poster TEXT,
    added_at TEXT NOT NULL,
    last_played TEXT
  );

  CREATE TABLE IF NOT EXISTS m3u_sources (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    poster TEXT,
    added_at TEXT NOT NULL,
    expanded INTEGER DEFAULT 1,
    visible_count INTEGER DEFAULT 200
  );

  CREATE TABLE IF NOT EXISTS sub_channels (
    id TEXT PRIMARY KEY,
    m3u_id TEXT NOT NULL,
    name TEXT NOT NULL,
    url TEXT NOT NULL,
    poster TEXT,
    sort_order INTEGER DEFAULT 0,
    FOREIGN KEY (m3u_id) REFERENCES m3u_sources(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT
  );
`);

// ==================== API 路由 ====================

// 获取所有数据（初始化加载）
app.get('/api/data', (req, res) => {
  const channels = db.prepare('SELECT * FROM channels ORDER BY added_at').all();
  const m3uSources = db.prepare('SELECT * FROM m3u_sources ORDER BY added_at').all();
  
  // 为每个 M3U 源加载子频道
  const sourcesWithSubs = m3uSources.map(source => {
    const subChannels = db.prepare('SELECT * FROM sub_channels WHERE m3u_id = ? ORDER BY sort_order').all(source.id);
    return {
      ...source,
      expanded: !!source.expanded,
      isM3U: true,
      subChannels: subChannels.map(sub => ({
        ...sub,
        id: sub.id.replace(`${source.id}_`, '') // 去掉前缀，保持兼容
      }))
    };
  });

  // 普通频道
  const normalChannels = channels.map(c => ({
    ...c,
    addedAt: c.added_at,
    lastPlayed: c.last_played
  }));

  res.json({
    channels: [...normalChannels, ...sourcesWithSubs],
    settings: {}
  });
});

// 保存普通频道
app.post('/api/channels', (req, res) => {
  const { id, name, url, poster } = req.body;
  const stmt = db.prepare('INSERT OR REPLACE INTO channels (id, name, url, poster, added_at) VALUES (?, ?, ?, ?, ?)');
  stmt.run(id, name, url, poster || null, new Date().toISOString());
  res.json({ success: true });
});

// 删除普通频道
app.delete('/api/channels/:id', (req, res) => {
  const stmt = db.prepare('DELETE FROM channels WHERE id = ?');
  stmt.run(req.params.id);
  res.json({ success: true });
});

// 更新频道最后播放时间
app.patch('/api/channels/:id/played', (req, res) => {
  const stmt = db.prepare('UPDATE channels SET last_played = ? WHERE id = ?');
  stmt.run(new Date().toISOString(), req.params.id);
  res.json({ success: true });
});

// 保存 M3U 源
app.post('/api/m3u-sources', (req, res) => {
  const { id, name, url, poster, expanded, visibleCount, subChannels } = req.body;
  
  const insertSource = db.prepare('INSERT OR REPLACE INTO m3u_sources (id, name, url, poster, added_at, expanded, visible_count) VALUES (?, ?, ?, ?, ?, ?, ?)');
  const insertSub = db.prepare('INSERT OR REPLACE INTO sub_channels (id, m3u_id, name, url, poster, sort_order) VALUES (?, ?, ?, ?, ?, ?)');
  const deleteSubs = db.prepare('DELETE FROM sub_channels WHERE m3u_id = ?');

  const transaction = db.transaction(() => {
    insertSource.run(id, name, url, poster || null, new Date().toISOString(), expanded ? 1 : 0, visibleCount || 200);
    
    // 删除旧的子频道，重新插入
    deleteSubs.run(id);
    
    if (subChannels && subChannels.length > 0) {
      subChannels.forEach((sub, index) => {
        insertSub.run(`${id}_${sub.id}`, id, sub.name, sub.url, sub.poster || null, index);
      });
    }
  });

  transaction();
  res.json({ success: true });
});

// 删除 M3U 源
app.delete('/api/m3u-sources/:id', (req, res) => {
  const stmt = db.prepare('DELETE FROM m3u_sources WHERE id = ?');
  stmt.run(req.params.id); // CASCADE 会自动删除子频道
  res.json({ success: true });
});

// 更新 M3U 源状态（展开/收起、visibleCount）
app.patch('/api/m3u-sources/:id', (req, res) => {
  const { expanded, visibleCount } = req.body;
  const updates = [];
  const params = [];

  if (expanded !== undefined) {
    updates.push('expanded = ?');
    params.push(expanded ? 1 : 0);
  }
  if (visibleCount !== undefined) {
    updates.push('visible_count = ?');
    params.push(visibleCount);
  }

  if (updates.length > 0) {
    params.push(req.params.id);
    const stmt = db.prepare(`UPDATE m3u_sources SET ${updates.join(', ')} WHERE id = ?`);
    stmt.run(...params);
  }
  res.json({ success: true });
});

// 刷新 M3U 源子频道
app.put('/api/m3u-sources/:id/subs', (req, res) => {
  const { subChannels } = req.body;
  const m3uId = req.params.id;

  const deleteSubs = db.prepare('DELETE FROM sub_channels WHERE m3u_id = ?');
  const insertSub = db.prepare('INSERT INTO sub_channels (id, m3u_id, name, url, poster, sort_order) VALUES (?, ?, ?, ?, ?, ?)');

  const transaction = db.transaction(() => {
    deleteSubs.run(m3uId);
    if (subChannels && subChannels.length > 0) {
      subChannels.forEach((sub, index) => {
        insertSub.run(`${m3uId}_${sub.id}`, m3uId, sub.name, sub.url, sub.poster || null, index);
      });
    }
  });

  transaction();
  res.json({ success: true, count: subChannels?.length || 0 });
});

// 批量保存（完整同步）
app.post('/api/sync', (req, res) => {
  const { channels: allChannels } = req.body;
  
  if (!allChannels || !Array.isArray(allChannels)) {
    return res.status(400).json({ error: 'Invalid data' });
  }

  const normalChannels = allChannels.filter(c => !c.isM3U);
  const m3uSources = allChannels.filter(c => c.isM3U);

  const syncTransaction = db.transaction(() => {
    // 清空并重新插入普通频道
    db.prepare('DELETE FROM channels').run();
    const insertChannel = db.prepare('INSERT INTO channels (id, name, url, poster, added_at) VALUES (?, ?, ?, ?, ?)');
    normalChannels.forEach(c => {
      insertChannel.run(c.id, c.name, c.url, c.poster || null, c.addedAt || new Date().toISOString());
    });

    // 清空并重新插入 M3U 源
    db.prepare('DELETE FROM m3u_sources').run(); // CASCADE 删除子频道
    const insertSource = db.prepare('INSERT INTO m3u_sources (id, name, url, poster, added_at, expanded, visible_count) VALUES (?, ?, ?, ?, ?, ?, ?)');
    const insertSub = db.prepare('INSERT INTO sub_channels (id, m3u_id, name, url, poster, sort_order) VALUES (?, ?, ?, ?, ?, ?)');

    m3uSources.forEach(source => {
      insertSource.run(source.id, source.name, source.url, source.poster || null, source.addedAt || new Date().toISOString(), source.expanded ? 1 : 0, source.visibleCount || 200);
      
      if (source.subChannels && source.subChannels.length > 0) {
        source.subChannels.forEach((sub, index) => {
          insertSub.run(`${source.id}_${sub.id}`, source.id, sub.name, sub.url, sub.poster || null, index);
        });
      }
    });
  });

  syncTransaction();
  res.json({ success: true });
});

// 保存设置
app.post('/api/settings', (req, res) => {
  const { key, value } = req.body;
  const stmt = db.prepare('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)');
  stmt.run(key, JSON.stringify(value));
  res.json({ success: true });
});

// 获取设置
app.get('/api/settings/:key', (req, res) => {
  const row = db.prepare('SELECT value FROM settings WHERE key = ?').get(req.params.key);
  res.json({ value: row ? JSON.parse(row.value) : null });
});

// 启动服务器
app.listen(PORT, '0.0.0.0', () => {
  console.log(`M3U Player 服务已启动: http://0.0.0.0:${PORT}`);
});
