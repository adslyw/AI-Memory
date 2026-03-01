# Web Reader Skill

## 功能描述
使用 Trafilatura 提取网页干净正文的工具

## 使用方法
直接调用 `web_reader(url)` 函数，传入需要提取正文的网页链接即可。

## 示例
```python
from skills.web_reader import web_reader

# 提取网页正文
content = web_reader("https://example.com")
print(content)
```

## 注意事项
- 需要先安装 Trafilatura 库
- 对于大型网页，会截取前 3000 字以节省内存
- 如果无法访问网页或提取失败，会返回相应的错误信息