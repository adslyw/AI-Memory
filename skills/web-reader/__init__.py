import trafilatura
from typing import Annotated

def web_reader(url: Annotated[str, "需要提取正文的网页链接"]):
    """
    抓取并提取指定网页的纯文本正文内容，过滤广告和HTML噪音。
    """
    try:
        # 抓取网页
        downloaded = trafilatura.fetch_url(url)
        if downloaded is None:
            return "错误：无法访问该网页，请检查链接是否有效。"
        
        # 提取正文 (include_comments=False 保证不带评论噪音)
        result = trafilatura.extract(downloaded, include_comments=False, include_tables=True)
        if not result:
            return "错误：未能从该网页提取到有效正文内容。"
        
        # 截断处理：防止正文太长再次导致 422 报错
        # 针对 8GB 内存的 Qwen-3B，建议保留前 3000 字
        return result[:3000] + "\n\n(已截取前 3000 字以节省内存)"
    except Exception as e:
        return f"读取网页时发生异常: {str(e)}"

# 注册给 OpenClaw 使用
__name__ = "web_reader"
__description__ = "使用 Trafilatura 提取网页干净正文的工具"