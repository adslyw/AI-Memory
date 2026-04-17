#!/bin/bash
# Edge TTS 测试脚本
# 用法: ./test_edge_tts.sh [voice]

VENV_PYTHON="/home/deepnight/src/homepage_v2/venv/bin/python"
TEXT="你好，我是深蓝，很高兴为你服务。现在使用的是 Microsoft Edge TTS 语音合成技术。"

# 默认声音
VOICE="${1:-zh-CN-XiaoxiaoNeural}"
OUTPUT="/tmp/edge_tts_${VOICE}.mp3"

echo "🎤 使用声音: $VOICE"
echo "📝 文本: $TEXT"

# 生成语音
"$VENV_PYTHON" -m edge_tts --voice "$VOICE" --text "$TEXT" --write-media "$OUTPUT" 2>&1

if [ -f "$OUTPUT" ]; then
    echo "✅ 生成成功: $OUTPUT ($(du -h $OUTPUT | cut -f1))"
    echo "🔊 播放中..."
    aplay "$OUTPUT"
else
    echo "❌ 生成失败"
    exit 1
fi
