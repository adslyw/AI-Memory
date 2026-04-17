/**
 * M3U Player - Chrome 扩展版本
 * 完全独立，使用 chrome.storage.local 持久化
 * 支持跨域 m3u8 播放
 */

class M3UPlayer {
  constructor() {
    // DOM 元素
    this.video = document.getElementById('video');
    this.channelList = document.getElementById('channel-list');
    this.currentChannelName = document.getElementById('current-channel-name');
    this.currentChannelUrl = document.getElementById('current-channel-url');
    this.channelCount = document.getElementById('channel-count');
    this.addModal = document.getElementById('add-modal');
    this.addForm = document.getElementById('add-channel-form');
    this.addBtn = document.getElementById('add-channel-btn');
    this.cancelBtn = document.getElementById('cancel-add');
    this.themeBtn = document.getElementById('toggle-theme');
    this.sidebar = document.getElementById('sidebar');
    this.toggleSidebarBtn = document.getElementById('toggle-sidebar');
    this.searchInput = document.getElementById('search-input');
    this.importBanner = document.getElementById('import-banner');
    this.importBtn = document.getElementById('import-btn');

    // 数据
    this.channels = [];
    this.filteredChannels = [];
    this.currentChannel = null;
    this.hls = null;
    this.searchQuery = '';
    this.isSidebarCollapsed = false; // 默认展开

    // 拖拽状态
    this.dragSrcEl = null;

    // 初始化
    this.init();
  }

  async init() {
    console.log('M3UPlayer 初始化开始');
    await this.loadChannels();
    await this.loadSidebarState();
    
    // 检查关键 DOM 元素
    console.log('DOM 元素检查:');
    console.log(' - video:', this.video);
    console.log(' - channelList:', this.channelList);
    console.log(' - addBtn:', this.addBtn);
    console.log(' - importBtn:', this.importBtn);
    console.log(' - importBanner:', this.importBanner);
    
    this.bindEvents();
    this.applySidebarState();
    this.renderChannelList();
    this.restoreLastChannel();
    this.initDragAndDrop();
    console.log('初始化完成');
  }

  async loadSidebarState() {
    try {
      const result = await chrome.storage.local.get(['sidebarCollapsed']);
      this.isSidebarCollapsed = result.sidebarCollapsed === true;
    } catch (e) {
      this.isSidebarCollapsed = false;
    }
  }

  async toggleSidebar() {
    this.isSidebarCollapsed = !this.isSidebarCollapsed;
    this.applySidebarState();
    await chrome.storage.local.set({ sidebarCollapsed: this.isSidebarCollapsed });
  }

  // ==================== 数据持久化 ====================

  async loadChannels() {
    try {
      const result = await chrome.storage.local.get(['m3u_channels']);
      this.channels = result.m3u_channels || [];
      console.log(`从 chrome.storage 加载 ${this.channels.length} 个频道`);
    } catch (e) {
      console.error('加载频道失败:', e);
      this.channels = [];
    }
  }

  async saveChannels() {
    try {
      console.log('保存频道数据到 chrome.storage:', this.channels);
      await chrome.storage.local.set({ m3u_channels: this.channels });
      console.log('保存成功，频道数:', this.channels.length);
      // 验证保存
      const result = await chrome.storage.local.get(['m3u_channels']);
      console.log('验证读取:', result.m3u_channels ? result.m3u_channels.length : 0, '个频道');
    } catch (e) {
      console.error('保存频道失败:', e);
      alert('保存失败: ' + e.message);
    }
  }

  async saveLastChannel(channel) {
    await chrome.storage.local.set({ lastChannelId: channel.id });
  }

  async restoreLastChannel() {
    try {
      const result = await chrome.storage.local.get(['lastChannelId']);
      const lastId = result.lastChannelId;
      if (lastId) {
        const channel = this.channels.find(c => c.id === lastId);
        if (channel) {
          this.playChannel(channel);
        }
      }
    } catch (e) {
      console.error('恢复上次播放失败:', e);
    }
  }

  // ==================== 渲染 ====================

  renderChannelList() {
    const query = this.searchQuery.toLowerCase();
    this.filteredChannels = this.channels.filter(ch =>
      ch.name.toLowerCase().includes(query) ||
      ch.url.toLowerCase().includes(query)
    );

    this.channelList.innerHTML = '';

    this.filteredChannels.forEach((channel, index) => {
      const el = this.createChannelElement(channel, index);
      this.channelList.appendChild(el);
    });

    this.updateCount();
  }

  createChannelElement(channel, index) {
    const div = document.createElement('div');
    div.className = 'channel-item bg-gray-50 hover:bg-blue-50 rounded-lg p-2 cursor-grab flex items-center gap-2 mb-1 border border-gray-200';
    div.draggable = true;
    div.dataset.id = channel.id;
    div.dataset.index = index;

    // 拖拽事件
    div.addEventListener('dragstart', (e) => this.handleDragStart(e, channel));
    div.addEventListener('dragover', (e) => this.handleDragOver(e));
    div.addEventListener('drop', (e) => this.handleDrop(e, channel));
    div.addEventListener('dragend', (e) => this.handleDragEnd(e));

    // 点击播放
    div.addEventListener('click', (e) => {
      if (!e.target.closest('button')) {
        this.playChannel(channel);
      }
    });

    // 海报缩略图
    const img = document.createElement('img');
    img.src = channel.poster || 'data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="40" height="40"><rect fill="%23ddd" width="40" height="40"/><text x="50%" y="50%" fill="%23999" font-size="10" text-anchor="middle" dy=".3em">无海报</text></svg>';
    img.className = 'w-10 h-10 rounded object-cover flex-shrink-0 bg-gray-200';
    img.crossOrigin = 'anonymous';

    // 文本信息
    const info = document.createElement('div');
    info.className = 'flex-1 min-w-0';
    info.innerHTML = `
      <div class="font-medium text-gray-800 truncate sidebar-text">${this.escapeHtml(channel.name)}</div>
      <div class="text-xs text-gray-500 truncate sidebar-text">${this.escapeHtml(channel.url)}</div>
    `;

    // 删除按钮
    const delBtn = document.createElement('button');
    delBtn.className = 'delete-btn text-red-500 hover:text-red-700 p-1 flex-shrink-0';
    delBtn.innerHTML = '🗑';
    delBtn.title = '删除频道';
    delBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      if (confirm(`删除 "${channel.name}"？`)) {
        this.removeChannel(channel.id);
      }
    });

    div.appendChild(img);
    div.appendChild(info);
    div.appendChild(delBtn);

    return div;
  }

  escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
  }

  updateCount() {
    this.channelCount.textContent = this.filteredChannels.length;
  }

  // ==================== 播放控制 ====================

  async playChannel(channel) {
    this.currentChannel = channel;
    const url = channel.url;
    const video = this.video;

    // 销毁之前的 HLS 实例
    if (this.hls) {
      this.hls.destroy();
      this.hls = null;
    }

    // 停止视频
    video.pause();
    video.removeAttribute('src');

    // 尝试使用 HLS.js
    if (Hls.isSupported()) {
      this.hls = new Hls({
        enableWorker: true,
        lowLatencyMode: true,
        backBufferLength: 90
      });
      this.hls.loadSource(url);
      this.hls.attachMedia(video);
      this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
        video.play().catch(e => console.log('自动播放失败（需要用户交互）:', e));
      });
      this.hls.on(Hls.Events.ERROR, (event, data) => {
        if (data.fatal) {
          console.error('HLS 错误:', data);
          let errorMsg = `播放失败\n类型: ${data.type}\n详情: ${data.message || '未知错误'}`;
          if (data.details) {
            errorMsg += `\n细节: ${data.details}`;
          }
          if (data.response) {
            errorMsg += `\nHTTP状态: ${data.response.code}`;
          }
          switch (data.type) {
            case Hls.ErrorTypes.NETWORK_ERROR:
              console.error('网络错误，尝试恢复...');
              errorMsg += '\n\n这可能是 CORS 限制或网络连接问题。请确认：\n1. m3u8 链接是否可在浏览器直接访问\n2. 服务器是否允许跨域\n3. 网络连接是否正常';
              this.hls.startLoad();
              setTimeout(() => alert(errorMsg), 100);
              break;
            case Hls.ErrorTypes.MEDIA_ERROR:
              console.error('媒体错误，尝试恢复...');
              this.hls.recoverMediaError();
              setTimeout(() => alert('媒体错误，已尝试恢复\n\n如果持续出现，可能是流格式不支持'), 100);
              break;
            default:
              setTimeout(() => alert(errorMsg), 100);
              break;
          }
        }
      });
    } else if (video.canPlayType('application/vnd.apple.mpegurl')) {
      // Safari 原生支持
      video.src = url;
      video.addEventListener('loadedmetadata', () => {
        video.play().catch(e => console.log('自动播放失败:', e));
      });
    } else {
      alert('您的浏览器不支持 HLS 播放');
      return;
    }

    // 更新 UI
    if (this.currentChannelName) {
      this.currentChannelName.textContent = channel.name;
    }
    if (this.currentChannelUrl) {
      this.currentChannelUrl.textContent = url;
    }

    // 保存播放记录
    this.saveLastChannel(channel);
  }

  // ==================== 频道管理 ====================

  async addChannel(name, url, poster = '') {
    console.log('addChannel 调用:', { name, url, poster });
    const channel = {
      id: Date.now().toString(),
      name: name.trim(),
      url: url.trim(),
      poster: poster.trim(),
      expanded: true,
      visibleCount: 200
    };
    console.log('新建频道对象:', channel);
    this.channels.push(channel);
    console.log('this.channels 现在:', this.channels);
    await this.saveChannels();
    console.log('saveChannels 完成，准备渲染');
    this.renderChannelList();
    this.updateCount();
    console.log('渲染完成，频道列表长度:', this.filteredChannels.length);
  }

  async removeChannel(id) {
    this.channels = this.channels.filter(c => c.id !== id);
    await this.saveChannels();
    this.renderChannelList();
    this.updateCount();
  }

  // ==================== 拖拽排序 ====================

  initDragAndDrop() {
    // 已在 createChannelElement 中绑定
  }

  handleDragStart(e, channel) {
    this.dragSrcEl = e.target;
    e.dataTransfer.effectAllowed = 'move';
    e.dataTransfer.setData('text/plain', channel.id);
    e.target.classList.add('opacity-50');
  }

  handleDragOver(e) {
    e.preventDefault();
    e.dataTransfer.dropEffect = 'move';
    const target = e.target.closest('.channel-item');
    if (target && target !== this.dragSrcEl) {
      target.classList.add('bg-blue-100');
    }
  }

  handleDrop(e, targetChannel) {
    e.preventDefault();
    const target = e.target.closest('.channel-item');
    if (target) {
      target.classList.remove('bg-blue-100');
    }

    const srcId = e.dataTransfer.getData('text/plain');
    const srcChannel = this.channels.find(c => c.id === srcId);
    if (!srcChannel) return;

    const srcIndex = this.channels.indexOf(srcChannel);
    const tgtIndex = this.channels.indexOf(targetChannel);

    if (srcIndex !== -1 && tgtIndex !== -1 && srcIndex !== tgtIndex) {
      // 移动数组元素
      this.channels.splice(srcIndex, 1);
      const newTgtIndex = this.channels.findIndex(c => c.id === targetChannel.id);
      this.channels.splice(newTgtIndex, 0, srcChannel);
      this.saveChannels();
      this.renderChannelList();
    }
  }

  handleDragEnd(e) {
    e.target.classList.remove('opacity-50');
    this.dragSrcEl = null;
    // 清理可能残留的高亮
    const highlighted = this.channelList.querySelectorAll('.bg-blue-100');
    highlighted.forEach(el => el.classList.remove('bg-blue-100'));
  }

  // ==================== 事件绑定 ====================

  bindEvents() {
    // 添加频道
    this.addBtn.addEventListener('click', () => this.showAddModal());
    this.cancelBtn.addEventListener('click', () => this.hideAddModal());
    this.addForm.addEventListener('submit', (e) => this.handleAddChannel(e));

    // 搜索
    this.searchInput.addEventListener('input', (e) => {
      this.searchQuery = e.target.value.trim();
      this.renderChannelList();
    });

    // 侧边栏收起
    this.toggleSidebarBtn.addEventListener('click', () => this.toggleSidebar());

    // 主题切换（简单暗色模式）
    this.themeBtn.addEventListener('click', () => this.toggleTheme());

    // 诊断按钮
    const diagBtn = document.getElementById('diagnostics-btn');
    if (diagBtn) {
      diagBtn.addEventListener('click', () => {
        chrome.runtime.getURL('test.html', (url) => {
          chrome.tabs.create({ url: url });
        });
      });
    }

    // 导入数据
    if (this.importBtn) {
      this.importBtn.addEventListener('click', () => this.showImportModal());
    }

    // 键盘快捷键
    document.addEventListener('keydown', (e) => {
      if (e.key === 'Escape' && this.addModal.classList.contains('flex')) {
        this.hideAddModal();
      }
    });
  }

  showAddModal() {
    this.addModal.classList.remove('hidden');
    this.addModal.classList.add('flex');
    document.getElementById('channel-name').value = '';
    document.getElementById('channel-url').value = '';
    document.getElementById('channel-poster').value = '';
    document.getElementById('channel-name').focus();
  }

  hideAddModal() {
    this.addModal.classList.add('hidden');
    this.addModal.classList.remove('flex');
  }

  handleAddChannel(e) {
    e.preventDefault();
    const name = document.getElementById('channel-name').value;
    const url = document.getElementById('channel-url').value;
    const poster = document.getElementById('channel-poster').value || '';
    console.log('表单提交:', { name, url, poster });
    if (name && url) {
      console.log('调用 addChannel');
      this.addChannel(name, url, poster);
      this.hideAddModal();
    } else {
      console.warn('表单验证失败 - 名称或URL为空');
      alert('请填写频道名称和链接');
    }
  }

  applySidebarState() {
    if (this.isSidebarCollapsed) {
      this.sidebar.classList.add('collapsed');
      this.toggleSidebarBtn.textContent = '▶';
    } else {
      this.sidebar.classList.remove('collapsed');
      this.toggleSidebarBtn.textContent = '◀';
    }
  }

  toggleTheme() {
    const body = document.body;
    if (body.classList.contains('dark')) {
      body.classList.remove('dark');
      this.themeBtn.textContent = '🌙';
    } else {
      body.classList.add('dark');
      this.themeBtn.textContent = '☀️';
    }
  }

  showImportModal() {
    // 简化：使用 prompt 粘贴 JSON
    const json = prompt('请粘贴频道 JSON 数据（旧版 LocalStorage 内容）:');
    if (json) {
      try {
        const data = JSON.parse(json);
        if (Array.isArray(data) && data.length > 0) {
          if (confirm(`检测到 ${data.length} 个频道，将覆盖当前数据？`)) {
            this.channels = data.map(c => ({
              id: Date.now().toString() + Math.random().toString(36).substr(2, 9),
              name: c.name || c.title || '未知',
              url: c.url || c.link || '',
              poster: c.poster || '',
              expanded: true,
              visibleCount: 200
            })).filter(c => c.name && c.url);
            this.saveChannels();
            this.renderChannelList();
            alert(`成功导入 ${this.channels.length} 个频道`);
          }
        } else {
          alert('数据格式错误：需要频道数组');
        }
      } catch (e) {
        alert('JSON 解析失败: ' + e.message);
      }
    }
  }
}

// 启动应用
document.addEventListener('DOMContentLoaded', () => {
  window.player = new M3UPlayer();
});
