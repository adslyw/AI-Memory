/**
 * M3U Player - 极简 M3U8 播放器
 * 支持频道管理、HLS 播放、SQLite 持久化
 */

class M3UPlayer {
    constructor() {
        // API 基础路径
        this.apiBase = '/api';
        
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

        // 数据
        this.channels = [];
        this.currentChannel = null;
        this.hls = null;
        this.searchQuery = '';

        // 初始化
        this.init();
    }

    async init() {
        await this.loadChannels();
        this.bindEvents();
        this.renderChannelList();
        this.restoreLastChannel();
        this.initDragAndDrop(); // 初始化拖拽
    }

    // ==================== 数据持久化 (SQLite API) ====================

    async loadChannels() {
        try {
            const res = await fetch(`${this.apiBase}/data`);
            if (!res.ok) throw new Error(`HTTP ${res.status}`);
            const data = await res.json();
            this.channels = data.channels || [];
            console.log(`从 SQLite 加载 ${this.channels.length} 个频道`);
            
            // 如果 SQLite 为空，检查 localStorage 是否有旧数据需要迁移
            if (this.channels.length === 0) {
                const saved = localStorage.getItem('m3u_channels');
                if (saved) {
                    console.log('检测到 localStorage 旧数据，开始迁移...');
                    this.channels = JSON.parse(saved);
                    this.migrateData();
                    await this.syncToServer();
                    console.log(`迁移完成：${this.channels.length} 个频道已同步到 SQLite`);
                }
            }
        } catch (e) {
            console.error('加载失败，尝试 localStorage 回退:', e);
            try {
                const saved = localStorage.getItem('m3u_channels');
                if (saved) {
                    this.channels = JSON.parse(saved);
                    this.migrateData();
                    await this.syncToServer();
                }
            } catch (e2) {
                this.channels = [];
            }
        }
    }

    async syncToServer() {
        try {
            await fetch(`${this.apiBase}/sync`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ channels: this.channels })
            });
        } catch (e) {
            console.error('同步失败:', e);
        }
    }

    migrateData() {
        this.channels.forEach(c => {
            if (c.isM3U) {
                if (c.expanded === undefined) c.expanded = true;
                if (c.visibleCount === undefined) c.visibleCount = 200;
            }
        });
        this.channels = this.channels.filter(c => !c.parentId);
    }

    async saveChannels() {
        try {
            await fetch(`${this.apiBase}/sync`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ channels: this.channels })
            });
        } catch (e) {
            console.error('保存失败:', e);
        }
    }

    // ==================== 事件绑定 ====================

    bindEvents() {
        // 添加频道按钮
        this.addBtn.addEventListener('click', () => this.showAddModal());

        // 取消添加
        this.cancelBtn.addEventListener('click', () => this.hideAddModal());

        // 表单提交
        this.addForm.addEventListener('submit', (e) => {
            e.preventDefault();
            this.addChannel();
        });

        // 点击模态框背景关闭
        this.addModal.addEventListener('click', (e) => {
            if (e.target === this.addModal) {
                this.hideAddModal();
            }
        });

        // 视频事件
        this.video.addEventListener('play', () => this.updateStatus('播放中'));
        this.video.addEventListener('pause', () => this.updateStatus('已暂停'));
        this.video.addEventListener('ended', () => this.updateStatus('播放结束'));
        this.video.addEventListener('error', (e) => {
            console.error('视频错误:', e);
            this.updateStatus('播放失败');
        });

        // 主题切换
        this.themeBtn.addEventListener('click', () => this.toggleTheme());

        // 侧边栏折叠
        this.toggleSidebarBtn.addEventListener('click', () => this.toggleSidebar());

        // 搜索功能
        this.searchInput.addEventListener('input', (e) => {
            this.searchQuery = e.target.value.trim().toLowerCase();
            this.renderChannelList();
        });

        // 键盘快捷键
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape') {
                this.hideAddModal();
            }
            if (e.key === ' ' && e.target.tagName !== 'INPUT' && e.target.tagName !== 'TEXTAREA') {
                e.preventDefault();
                this.togglePlay();
            }
        });
    }

    // ==================== 拖拽排序 ====================

    initDragAndDrop() {
        this.draggedChannelId = null;
        console.log('拖拽功能已初始化');
    }

    onDragStart(e, channelId) {
        this.draggedChannelId = channelId;
        e.target.classList.add('dragging');
        e.dataTransfer.effectAllowed = 'move';
        e.dataTransfer.setData('text/plain', channelId);
    }

    onDragOver(e, targetChannelId) {
        e.preventDefault();
        e.stopPropagation();
        e.dataTransfer.dropEffect = 'move';
        
        if (this.draggedChannelId && this.draggedChannelId !== targetChannelId) {
            const draggedElement = document.querySelector(`[data-channel-id="${this.draggedChannelId}"]`);
            const targetElement = document.querySelector(`[data-channel-id="${targetChannelId}"]`);
            
            if (draggedElement && targetElement) {
                document.querySelectorAll('.drag-over').forEach(el => {
                    el.classList.remove('drag-over');
                });
                targetElement.classList.add('drag-over');
            }
        }
    }

    onDrop(e, targetChannelId) {
        e.preventDefault();
        e.stopPropagation();
        
        if (!this.draggedChannelId || this.draggedChannelId === targetChannelId) {
            this.onDragEnd(e);
            return;
        }

        const draggedIndex = this.channels.findIndex(c => c.id === this.draggedChannelId && c.isM3U);
        const targetIndex = this.channels.findIndex(c => c.id === targetChannelId && c.isM3U);

        if (draggedIndex === -1 || targetIndex === -1) {
            console.warn('拖拽源或目标不是有效的 M3U 分组');
            this.onDragEnd(e);
            return;
        }

        const [draggedChannel] = this.channels.splice(draggedIndex, 1);
        const newIndex = draggedIndex < targetIndex ? targetIndex - 1 : targetIndex;
        this.channels.splice(newIndex, 0, draggedChannel);

        this.saveChannels();
        this.renderChannelList();
        this.onDragEnd(e);
    }

    onDragEnd(e) {
        if (e && e.target) {
            e.target.classList.remove('dragging');
        }
        document.querySelectorAll('.drag-over').forEach(el => {
            el.classList.remove('drag-over');
        });
        this.draggedChannelId = null;
    }

    // ==================== 搜索 ====================

    renderSearchResults() {
        const results = [];
        const query = this.searchQuery;

        // 搜索普通频道
        this.channels.filter(c => !c.isM3U).forEach(channel => {
            if (channel.name.toLowerCase().includes(query)) {
                results.push({ type: 'channel', channel });
            }
        });

        // 搜索 M3U 子频道
        this.channels.filter(c => c.isM3U).forEach(m3u => {
            m3u.subChannels.forEach(sub => {
                if (sub.name.toLowerCase().includes(query) || m3u.name.toLowerCase().includes(query)) {
                    results.push({ 
                        type: 'sub', 
                        m3u, 
                        sub,
                        id: `${m3u.id}_${sub.id}`
                    });
                }
            });
        });

        if (results.length === 0) {
            this.channelList.innerHTML = `
                <div class="text-center py-8 text-gray-400">
                    <p class="mb-2">未找到 "${this.escapeHtml(this.searchInput.value)}"</p>
                    <p class="text-sm text-gray-500">尝试其他关键词</p>
                </div>
            `;
            return;
        }

        // 渲染搜索结果
        results.forEach(result => {
            const item = document.createElement('div');
            let channelData;

            if (result.type === 'channel') {
                channelData = result.channel;
                const isCurrent = this.currentChannel && this.currentChannel.id === channelData.id;
                item.className = `channel-item flex items-center min-h-16 px-2 py-1 cursor-pointer transition-colors ${
                    isCurrent ? 'bg-blue-50 border-l-4 border-blue-600' : 'hover:bg-gray-50'
                }`;
                
                const thumbHtml = channelData.poster 
                    ? `<img src="${this.escapeHtml(channelData.poster)}" class="w-12 h-12 object-cover flex-shrink-0" loading="lazy" alt="">`
                    : `<div class="w-12 h-12 flex items-center justify-center bg-gray-200 flex-shrink-0">📺</div>`;
                
                item.innerHTML = `
                    ${thumbHtml}
                    <div class="flex-1 min-w-0 px-2">
                        <div class="font-medium truncate text-sm text-gray-800">${this.highlightMatch(channelData.name, query)}</div>
                        <div class="text-xs text-gray-500">普通频道</div>
                    </div>
                `;
                item.addEventListener('click', () => this.playChannel(channelData));
            } else {
                const subId = result.id;
                const isCurrent = this.currentChannel && this.currentChannel.id === subId;
                channelData = {
                    id: subId,
                    name: `${result.m3u.name} - ${result.sub.name}`,
                    url: result.sub.url,
                    poster: result.sub.poster
                };
                item.className = `channel-item flex items-center min-h-16 px-2 py-1 cursor-pointer transition-colors ${
                    isCurrent ? 'bg-blue-50 border-l-4 border-blue-600' : 'hover:bg-gray-50'
                }`;
                
                const thumbHtml = result.sub.poster 
                    ? `<img src="${this.escapeHtml(result.sub.poster)}" class="w-12 h-12 object-cover flex-shrink-0" loading="lazy" alt="">`
                    : `<div class="w-12 h-12 flex items-center justify-center bg-gray-200 flex-shrink-0">📺</div>`;
                
                item.innerHTML = `
                    ${thumbHtml}
                    <div class="flex-1 min-w-0 px-2">
                        <div class="font-medium truncate text-sm text-gray-800">${this.highlightMatch(result.sub.name, query)}</div>
                        <div class="text-xs text-gray-500">📁 ${this.escapeHtml(result.m3u.name)}</div>
                    </div>
                `;
                item.addEventListener('click', () => this.playChannel(channelData));
            }

            this.channelList.appendChild(item);
        });

        // 更新统计
        this.channelCount.textContent = `找到 ${results.length} 个`;
    }

    highlightMatch(text, query) {
        const escaped = this.escapeHtml(text);
        const lowerText = text.toLowerCase();
        const idx = lowerText.indexOf(query);
        if (idx === -1) return escaped;
        const before = this.escapeHtml(text.substring(0, idx));
        const match = this.escapeHtml(text.substring(idx, idx + query.length));
        const after = this.escapeHtml(text.substring(idx + query.length));
        return `${before}<span class="bg-yellow-200 font-bold">${match}</span>${after}`;
    }

    // ==================== 刷新 M3U ====================

    async refreshM3U(m3uId) {
        const m3u = this.channels.find(c => c.id === m3uId && c.isM3U);
        if (!m3u) return;

        const refreshBtn = document.querySelector(`[data-refresh-id="${m3uId}"]`);
        if (refreshBtn) {
            refreshBtn.textContent = '⏳';
            refreshBtn.disabled = true;
        }

        try {
            const subChannels = await this.parseM3U(m3u.url);
            m3u.subChannels = subChannels;
            m3u.visibleCount = 200; // 重置为首批显示
            this.saveChannels();
            this.renderChannelList();
            alert(`刷新成功！共 ${subChannels.length} 个频道`);
        } catch (error) {
            console.error('刷新失败:', error);
            alert('刷新失败，请检查网络或链接');
            if (refreshBtn) {
                refreshBtn.textContent = '🔄';
                refreshBtn.disabled = false;
            }
        }
    }

    renderChannelList() {
        this.channelList.innerHTML = '';

        // 搜索模式：显示扁平搜索结果
        if (this.searchQuery) {
            this.renderSearchResults();
            return;
        }

        if (this.channels.length === 0) {
            this.channelList.innerHTML = `
                <div class="text-center py-8 text-gray-500">
                    <p class="mb-2">暂无频道</p>
                    <p class="text-sm">点击上方"添加频道"按钮开始</p>
                </div>
            `;
        } else {
            this.channels.forEach((channel) => {
                // M3U 源分组标题 - 可点击展开/收起
                if (channel.isM3U) {
                    const isExpanded = channel.expanded !== false; // 默认展开
                    
                    const groupItem = document.createElement('div');
                    groupItem.className = 'group-header flex items-center h-12 px-2 mb-1 border-b border-gray-200 bg-gray-50 cursor-pointer select-none';
                    groupItem.innerHTML = `
                        <div class="flex items-center gap-2 text-gray-700 flex-1 min-w-0">
                            <span class="toggle-icon text-xs transition-transform duration-200 ${isExpanded ? 'rotate-0' : '-rotate-90'}">▼</span>
                            <span>📁</span>
                            <span class="font-medium text-sm truncate">${this.escapeHtml(channel.name)}</span>
                            <span class="text-xs text-gray-500">(${channel.subChannels.length})</span>
                        </div>
                        <button class="refresh-btn text-blue-600 hover:text-blue-800 p-1 transition text-sm" data-refresh-id="${channel.id}" title="刷新频道列表">🔄</button>
                        <button class="delete-btn text-red-600 hover:text-red-800 p-1 transition text-sm" title="删除分组">✕</button>
                    `;
                    
                    // 点击分组标题 - 展开/收起
                    const titleArea = groupItem.querySelector('.flex.items-center.gap-2');
                    titleArea.setAttribute('draggable', 'true');
                    titleArea.dataset.channelId = channel.id;
                    titleArea.classList.add('draggable-group');
                    
                    titleArea.addEventListener('click', (e) => {
                        // 如果不是拖拽操作，则切换展开状态
                        if (!this.draggedChannelId) {
                            this.toggleM3UExpanded(channel.id);
                        }
                    });
                    
                    titleArea.addEventListener('dragstart', (e) => this.onDragStart(e, channel.id));
                    titleArea.addEventListener('dragover', (e) => this.onDragOver(e, channel.id));
                    titleArea.addEventListener('drop', (e) => this.onDrop(e, channel.id));
                    titleArea.addEventListener('dragend', (e) => this.onDragEnd(e));
                    
                    // 刷新按钮
                    const refreshBtn = groupItem.querySelector('.refresh-btn');
                    refreshBtn.addEventListener('click', (e) => {
                        e.stopPropagation();
                        this.refreshM3U(channel.id);
                    });
                    
                    // 删除按钮
                    const deleteBtn = groupItem.querySelector('.delete-btn');
                    deleteBtn.addEventListener('click', (e) => {
                        e.stopPropagation();
                        this.deleteChannel(channel.id);
                    });
                    
                    this.channelList.appendChild(groupItem);
                    
                    // 如果展开，渲染子频道（分批加载）
                    if (isExpanded) {
                        const visibleSubs = channel.subChannels.slice(0, channel.visibleCount);
                        
                        visibleSubs.forEach((sub) => {
                            this.renderSubChannelItem(channel, sub);
                        });
                        
                        // 如果还有更多频道，显示「加载更多」按钮
                        if (channel.subChannels.length > channel.visibleCount) {
                            const remaining = channel.subChannels.length - channel.visibleCount;
                            const loadMoreBtn = document.createElement('div');
                            loadMoreBtn.className = 'text-center py-2 text-blue-600 hover:text-blue-800 cursor-pointer text-sm';
                            loadMoreBtn.textContent = `加载更多 (${remaining} 个剩余)`;
                            loadMoreBtn.addEventListener('click', (e) => {
                                e.stopPropagation();
                                this.loadMoreSubChannels(channel.id);
                            });
                            this.channelList.appendChild(loadMoreBtn);
                        }
                    }
                    return;
                }

                // 普通频道项（非 M3U 子频道）
                const item = document.createElement('div');
                const isCurrent = this.currentChannel && this.currentChannel.id === channel.id;
                
                item.className = `channel-item flex items-center min-h-20 px-2 py-1 cursor-pointer transition-colors ${
                    isCurrent
                        ? 'bg-blue-50 border-l-4 border-blue-600'
                        : 'hover:bg-gray-50'
                }`;
                
                const thumbHtml = channel.poster 
                    ? `<img src="${this.escapeHtml(channel.poster)}" title="${this.escapeHtml(channel.name)}" class="w-18 h-18 object-cover flex-shrink-0" loading="lazy" alt="">`
                    : `<div class="w-18 h-18 flex items-center justify-center bg-gray-200 flex-shrink-0 text-gray-600 text-xl" title="${this.escapeHtml(channel.name)}">📺</div>`;
                
                item.innerHTML = `
                    ${thumbHtml}
                    <div class="flex-1 min-w-0 px-2">
                        <div class="font-medium truncate text-sm leading-tight text-gray-800">${this.escapeHtml(channel.name)}</div>
                    </div>
                    <button class="delete-btn text-red-600 hover:text-red-800 p-1 transition text-sm">✕</button>
                `;

                item.addEventListener('click', (e) => {
                    if (!e.target.closest('.delete-btn')) {
                        this.playChannel(channel);
                    }
                });

                const deleteBtn = item.querySelector('.delete-btn');
                deleteBtn.addEventListener('click', (e) => {
                    e.stopPropagation();
                    this.deleteChannel(channel.id);
                });

                this.channelList.appendChild(item);
            });
        }

        // 统计：普通频道 + 所有 M3U 子频道
        const normalCount = this.channels.filter(c => !c.isM3U).length;
        const m3uSubCount = this.channels.filter(c => c.isM3U).reduce((sum, m) => sum + m.subChannels.length, 0);
        this.channelCount.textContent = normalCount + m3uSubCount;
    }

    updateStatus(text) {
        // 简单状态文本显示（右侧顶部或视频上角）
        console.log('状态:', text);
    }

    // ==================== 频道管理 ====================

    toggleM3UExpanded(m3uId) {
        const m3u = this.channels.find(c => c.id === m3uId && c.isM3U);
        if (m3u) {
            m3u.expanded = !m3u.expanded;
            this.saveChannels();
            this.renderChannelList();
        }
    }

    renderSubChannelItem(m3uSource, sub) {
        const subId = `${m3uSource.id}_${sub.id}`;
        const isCurrent = this.currentChannel && this.currentChannel.id === subId;
        
        const subItem = document.createElement('div');
        subItem.className = `channel-item flex items-center min-h-20 px-2 py-1 pl-8 cursor-pointer transition-colors ${
            isCurrent
                ? 'bg-blue-50 border-l-4 border-blue-600'
                : 'hover:bg-gray-50'
        }`;
        
        const thumbHtml = sub.poster 
            ? `<img src="${this.escapeHtml(sub.poster)}" title="${this.escapeHtml(sub.name)}" class="w-18 h-18 object-cover flex-shrink-0" loading="lazy" alt="">`
            : `<div class="w-18 h-18 flex items-center justify-center bg-gray-200 flex-shrink-0 text-gray-500 text-xl" title="${this.escapeHtml(sub.name)}">📺</div>`;
        
        subItem.innerHTML = `
            ${thumbHtml}
            <div class="flex-1 min-w-0 px-2">
                <div class="truncate text-sm text-gray-700">${this.escapeHtml(sub.name)}</div>
            </div>
        `;
        
        subItem.addEventListener('click', () => {
            this.playChannel({
                id: subId,
                name: `${m3uSource.name} - ${sub.name}`,
                url: sub.url,
                poster: sub.poster
            });
        });
        
        this.channelList.appendChild(subItem);
    }

    loadMoreSubChannels(m3uId) {
        const m3u = this.channels.find(c => c.id === m3uId && c.isM3U);
        if (m3u) {
            m3u.visibleCount += 200;
            this.saveChannels();
            this.renderChannelList();
        }
    }

    showAddModal() {
        this.addModal.classList.remove('hidden');
        this.addModal.classList.add('flex');
        document.getElementById('channel-name').focus();
    }

    hideAddModal() {
        this.addModal.classList.add('hidden');
        this.addModal.classList.remove('flex');
        this.addForm.reset();
    }

    async addChannel() {
        const name = document.getElementById('channel-name').value.trim();
        let url = document.getElementById('channel-url').value.trim();
        const poster = document.getElementById('channel-poster').value.trim() || null;

        if (!name || !url) {
            alert('请填写频道名称和链接');
            return;
        }

        // 验证 URL 格式
        try {
            new URL(url);
        } catch (e) {
            alert('请输入有效的 URL 地址');
            return;
        }

        // 检查是否为 M3U 播放列表链接
        if (url.toLowerCase().endsWith('.m3u')) {
            this.updateStatus('正在解析 M3U...');
            try {
                const subChannels = await this.parseM3U(url);
                if (subChannels.length === 0) {
                    alert('未在播放列表中找到有效的流链接');
                    this.updateStatus('解析失败');
                    return;
                }
                
                // 添加 M3U 源作为父项（子频道只存在 subChannels 中，不单独添加）
                const m3uSource = {
                    id: Date.now().toString(),
                    name: name,
                    url: url,
                    addedAt: new Date().toISOString(),
                    isM3U: true,
                    expanded: true,  // 默认展开
                    visibleCount: 200, // 分批加载，每次显示200个
                    subChannels: subChannels
                };
                
                this.channels.push(m3uSource);
                
                this.saveChannels();
                this.renderChannelList();
                this.hideAddModal();
                
                alert(`成功解析 M3U 播放列表！\n找到 ${subChannels.length} 个频道\n已全部添加到列表`);
                return;
            } catch (error) {
                console.error('M3U 解析失败:', error);
                alert('解析 M3U 播放列表失败，请检查链接是否正确');
                this.updateStatus('解析失败');
                return;
            }
        }

        // 普通频道
        const channel = {
            id: Date.now().toString(),
            name,
            url,
            poster: poster,
            addedAt: new Date().toISOString()
        };

        this.channels.push(channel);
        this.saveChannels();
        this.renderChannelList();
        this.hideAddModal();

        // 如果这是第一个频道，自动播放
        if (this.channels.length === 1) {
            this.playChannel(channel);
        }
    }

    async parseM3U(m3uUrl) {
        console.log('正在解析 M3U:', m3uUrl);
        const response = await fetch(m3uUrl);
        if (!response.ok) {
            throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }
        const text = await response.text();
        console.log('M3U 内容长度:', text.length, '字符');
        const lines = text.split('\n').map(line => line.trim());
        
        const channels = [];
        let currentChannel = null;
        let lineCount = 0;
        
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            lineCount++;
            
            // 跳过空行
            if (!line) continue;
            
            // 处理 #EXTINF 行
            if (line.startsWith('#EXTINF:')) {
                const info = this.parseExtInf(line);
                currentChannel = {
                    id: `sub_${Date.now()}_${i}`,
                    name: info.name || `Channel ${channels.length + 1}`,
                    poster: info.poster || null,
                    url: ''
                };
                continue;
            }
            
            // 跳过其他注释行
            if (line.startsWith('#')) {
                continue;
            }
            
            // URL 行
            if (line.startsWith('http')) {
                if (currentChannel) {
                    currentChannel.url = line;
                    channels.push(currentChannel);
                    currentChannel = null;
                } else {
                    // 有些 M3U 没有 #EXTINF 直接放 URL
                    channels.push({
                        id: `sub_${Date.now()}_${i}`,
                        name: `Channel ${channels.length + 1}`,
                        url: line
                    });
                }
            }
        }
        
        console.log(`解析完成: 共找到 ${channels.length} 个频道 (处理 ${lineCount} 行)`);
        return channels;
    }

    parseExtInf(line) {
        // 支持多种格式:
        // #EXTINF:-1,Channel Name
        // #EXTINF:-1 tvg-name="..." tvg-logo="..." group-title="...",Channel Name
        // 提取名称和海报
        
        // 移除 #EXTINF: 前缀和持续时间
        let afterPrefix = line.replace(/^#EXTINF:[-0-9]+/, '');
        
        // 提取 tvg-logo（海报图片）
        const logoMatch = afterPrefix.match(/tvg-logo="([^"]*)"/);
        const poster = logoMatch ? logoMatch[1] : null;
        
        // 查找最后一个逗号后面的名称
        const lastComma = afterPrefix.lastIndexOf(',');
        let name;
        if (lastComma !== -1) {
            name = afterPrefix.substring(lastComma + 1).trim();
        } else {
            // 如果没有逗号，清理所有属性后取剩余部分
            name = afterPrefix.replace(/tvg-[^=]+="[^"]*"/g, '')
                             .replace(/group-title="[^"]*"/g, '')
                             .replace(/[a-z-]+="[^"]*"/g, '')
                             .replace(/[,"'\s]+/g, ' ')
                             .trim() || 'Unknown';
        }
        
        return { name, poster };
    }

    deleteChannel(id) {
        if (!confirm('确定要删除这个频道吗？')) return;

        // 找到要删除的频道
        const channelToDelete = this.channels.find(c => c.id === id);
        
        if (channelToDelete && channelToDelete.isM3U) {
            // 如果是 M3U 源，同时删除其所有子频道
            this.channels = this.channels.filter(c => c.id !== id && c.parentId !== id);
        } else {
            // 普通频道或子频道
            this.channels = this.channels.filter(c => c.id !== id);
            // 如果是删除子频道，检查是否还有该父源的其他子频道，如果没有，删除父源
            if (channelToDelete && channelToDelete.parentId) {
                const parent = this.channels.find(c => c.id === channelToDelete.parentId);
                if (parent) {
                    const remaining = this.channels.filter(c => c.parentId === parent.id);
                    if (remaining.length === 0) {
                        this.channels = this.channels.filter(c => c.id !== parent.id);
                    }
                }
            }
        }

        // 如果删除的是当前播放频道，停止播放
        if (this.currentChannel && this.currentChannel.id === id) {
            this.stopPlayback();
            this.currentChannel = null;
        }

        this.saveChannels();
        this.renderChannelList();
    }

    // ==================== 播放控制 ====================

    playChannel(channel) {
        if (!channel || !channel.url) return;

        this.currentChannel = channel;
        this.updateStatus(`正在播放: ${channel.name}`);

        // 停止当前播放
        this.stopPlayback();

        const url = channel.url.toLowerCase();

        // 检测是否 HLS 流
        if (Hls.isSupported() && (url.includes('.m3u8') || url.endsWith('.m3u'))) {
            this.hls = new Hls({
                enableWorker: true,
                lowLatencyMode: true,
                backBufferLength: 90
            });

            this.hls.loadSource(channel.url);
            this.hls.attachMedia(this.video);

            this.hls.on(Hls.Events.MANIFEST_PARSED, () => {
                this.video.play().catch(e => console.log('自动播放被阻止:', e));
            });

            this.hls.on(Hls.Events.ERROR, (event, data) => {
                if (data.fatal) {
                    switch (data.type) {
                        case Hls.ErrorTypes.NETWORK_ERROR:
                            console.error('网络错误:', data);
                            this.updateStatus('网络错误');
                            this.hls.startLoad();
                            break;
                        case Hls.ErrorTypes.MEDIA_ERROR:
                            console.error('媒体错误:', data);
                            this.updateStatus('媒体错误');
                            this.hls.recoverMediaError();
                            break;
                        default:
                            console.error('不可恢复错误:', data);
                            this.updateStatus('播放失败');
                            this.stopPlayback();
                            break;
                    }
                }
            });
        } else if (this.video.canPlayType('application/vnd.apple.mpegurl') || url.includes('.m3u8')) {
            // Safari 原生支持 HLS 或 URL 是 m3u8
            this.video.src = channel.url;
            this.video.addEventListener('loadedmetadata', () => {
                this.video.play().catch(e => console.log('自动播放被阻止:', e));
            });
        } else if (this.video.canPlayType('video/mp4') || url.endsWith('.mp4')) {
            // 原生 MP4 支持
            this.video.src = channel.url;
            this.video.addEventListener('loadedmetadata', () => {
                this.video.play().catch(e => console.log('自动播放被阻止:', e));
            });
        } else if (this.video.canPlayType('video/webm') || url.endsWith('.webm')) {
            // 原生 WebM 支持
            this.video.src = channel.url;
            this.video.addEventListener('loadedmetadata', () => {
                this.video.play().catch(e => console.log('自动播放被阻止:', e));
            });
        } else {
            // 尝试直接播放，让浏览器决定
            this.video.src = channel.url;
            this.video.addEventListener('loadedmetadata', () => {
                if (this.video.readyState >= 1) {
                    this.video.play().catch(e => console.log('自动播放被阻止:', e));
                } else {
                    this.updateStatus('不支持的视频格式');
                    console.error('不支持的视频格式:', channel.url);
                }
            });
            this.video.addEventListener('error', (e) => {
                console.error('视频加载失败:', e);
                this.updateStatus('无法播放此视频');
            });
        }

        this.renderChannelList();
    }

    stopPlayback() {
        if (this.hls) {
            this.hls.destroy();
            this.hls = null;
        }
        this.video.src = '';
        this.video.pause();
    }

    togglePlay() {
        if (!this.currentChannel) return;

        if (this.video.paused) {
            this.video.play().catch(e => console.log('播放失败:', e));
        } else {
            this.video.pause();
        }
    }

    // ==================== 恢复上次播放 ====================

    async restoreLastChannel() {
        let lastChannelId = null;
        try {
            const res = await fetch(`${this.apiBase}/settings/last_channel`);
            const data = await res.json();
            lastChannelId = data.value;
        } catch (e) {
            lastChannelId = localStorage.getItem('m3u_last_channel');
        }
        
        if (lastChannelId && this.channels.length > 0) {
            // 在所有频道中查找（包括子频道）
            let channel = this.channels.find(c => c.id === lastChannelId);
            if (!channel) {
                // 搜索子频道
                for (const m3u of this.channels.filter(c => c.isM3U)) {
                    const sub = m3u.subChannels.find(s => `${m3u.id}_${s.id}` === lastChannelId);
                    if (sub) {
                        channel = { id: lastChannelId, name: `${m3u.name} - ${sub.name}`, url: sub.url, poster: sub.poster };
                        break;
                    }
                }
            }
            if (channel) {
                this.playChannel(channel);
            }
        }
    }

    // ==================== 主题切换 ====================

    toggleTheme() {
        const body = document.body;
        const isDark = body.classList.toggle('bg-gray-900');
        body.classList.toggle('bg-gray-100', !isDark);
        body.classList.toggle('text-gray-900', !isDark);
        body.classList.toggle('text-gray-100', isDark);

        // 切换侧边栏主题
        const aside = document.querySelector('aside');
        if (aside) {
            aside.classList.toggle('bg-white', !isDark);
            aside.classList.toggle('bg-gray-800', isDark);
            aside.classList.toggle('border-gray-200', !isDark);
            aside.classList.toggle('border-gray-700', isDark);
        }

        // 切换按钮图标
        this.themeBtn.textContent = isDark ? '☀️' : '🌙';
    }

    // ==================== 侧边栏折叠 ====================

    toggleSidebar() {
        const sidebar = this.sidebar;
        const isCollapsed = sidebar.classList.toggle('collapsed');
        
        // 更改按钮方向
        this.toggleSidebarBtn.textContent = isCollapsed ? '▶' : '◀';
        
        // 折叠时隐藏添加按钮文字，只保留图标
        const addBtn = this.addBtn;
        if (isCollapsed) {
            addBtn.innerHTML = '<span>+</span>';
            addBtn.title = '添加频道';
        } else {
            addBtn.innerHTML = '<span>+</span> <span class="sidebar-text">添加频道</span>';
        }
    }

    // ==================== 工具函数 ====================

    escapeHtml(text) {
        if (!text) return '';
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// ==================== 初始化 ====================

document.addEventListener('DOMContentLoaded', () => {
    window.player = new M3UPlayer();
});

// 保存当前播放频道（API + localStorage 双重备份）
document.getElementById('video').addEventListener('play', () => {
    if (window.player && window.player.currentChannel) {
        const channelId = window.player.currentChannel.id;
        localStorage.setItem('m3u_last_channel', channelId);
        fetch('/api/settings', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ key: 'last_channel', value: channelId })
        }).catch(() => {});
    }
});