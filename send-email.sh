#!/bin/bash
# 简单的邮件发送脚本
# 使用mail命令发送邮件

# 邮件内容
SUBJECT="OpenClaw 邮件测试"
BODY="这是一封来自OpenClaw的测试邮件，用于验证邮件发送功能。"
TO="你"

# 发送邮件
if command -v mail >/dev/null 2>&1; then
    echo "$BODY" | mail -s "$SUBJECT" "$TO"
    echo "邮件已发送"
elif command -v sendmail >/dev/null 2>&1; then
    echo -e "Subject: $SUBJECT\n\n$BODY" | sendmail "$TO"
    echo "邮件已发送"
else
    echo "错误: 未找到mail或sendmail命令"
    echo "请安装mailutils或sendmail包"
    exit 1
fi