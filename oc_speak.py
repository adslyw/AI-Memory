#!/usr/bin/env python3
"""
OpenClaw 语音对话助手
将文本回复转换为语音并播放
"""

import sys
import subprocess
import os

def speak_text(text, voice="zh-CN-XiaoxiaoNeural"):
    """将文本转换为语音并播放"""
    edge_tts = "/home/deepnight/src/homepage_v2/venv/bin/edge-tts"
    mp3_file = f"/tmp/oc_speak_{os.getpid()}.mp3"
    
    # 生成 MP3
    cmd = [edge_tts, "--voice", voice, "--text", text, "--write-media", mp3_file]
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        print(f"❌ TTS 生成失败: {result.stderr}", file=sys.stderr)
        return False
    
    # 播放
    subprocess.run(["mpg123", mp3_file], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return True

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: oc_speak.py [文本] [--voice 声音ID]")
        sys.exit(1)
    
    text = sys.argv[1]
    voice = "zh-CN-XiaoxiaoNeural"
    
    # 解析参数
    if "--voice" in sys.argv:
        idx = sys.argv.index("--voice")
        if idx + 1 < len(sys.argv):
            voice = sys.argv[idx + 1]
    
    if speak_text(text, voice):
        print(f"✅ 已播放: {text[:50]}...")
