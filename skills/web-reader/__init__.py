import trafilatura
import requests
from typing import Annotated

def web_reader(url: Annotated[str, "需要提取正文的网页链接"]):
    """
    抓取并提取指定网页的纯文本正文内容，过滤广告和HTML噪音。
    """
    try:
        # 使用 requests 抓取网页，禁用 SSL 验证
        response = requests.get(url, timeout=10, verify=False)
        if response.status_code != 200:
            return f"错误：无法访问该网页，HTTP 状态码 {response.status_code}"
        
        # 使用 Trafilatura 提取正文
        result = trafilatura.extract(response.text, include_comments=False, include_tables=True)
        if not result:
            return "错误：未能从该网页提取到有效正文内容。"
        
        return result
    except requests.exceptions.RequestException as e:
        return f"网络请求错误: {str(e)}"
    except Exception as e:
        return f"读取网页时发生异常: {str(e)}"

# 注册给 OpenClaw 使用
__name__ = "web_reader"
__description__ = "使用 Trafilatura 提取网页干净正文的工具"