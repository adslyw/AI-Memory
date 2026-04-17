#!/usr/bin/env python3
"""
OpenClaw Edge TTS Wrapper
用于将文本转换为语音，支持多种中文声音
"""

import sys
import subprocess
import os
import argparse

# Edge TTS 配置
VENV_PYTHON = "/home/deepnight/src/homepage_v2/venv/bin/python"
EDGE_TTS_MODULE = "edge_tts"

# 声音映射（默认声音）
DEFAULT_VOICE = "zh-CN-XiaoxiaoNeural"

def parse_args():
    parser = argparse.ArgumentParser(description="Edge TTS Wrapper for OpenClaw")
    parser.add_argument("text", help="要转换为语音的文本")
    parser.add_argument("--voice", default=DEFAULT_VOICE, help="声音ID，如 zh-CN-XiaoxiaoNeural")
    parser.add_argument("--output", help="输出文件路径，不指定则临时文件")
    parser.add_argument("--play", action="store_true", help="生成后自动播放")
    return parser.parse_args()

def generate_tts(text, voice, output_path):
    """使用 edge-tts 生成音频"""
    cmd = [
        VENV_PYTHON, "-m", EDGE_TTS_MODULE,
        "--voice", voice,
        "--text", text,
        "--write-media", output_path
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        print(f"❌ Edge TTS 生成失败: {result.stderr}", file=sys.stderr)
        return False
    return True

def main():
    args = parse_args()

    # 输出文件
    if not args.output:
        output = f"/tmp/edge_tts_{os.getpid()}.mp3"
    else:
        output = args.output

    # 生成
    if generate_tts(args.text, args.voice, output):
        print(output)  # 输出文件路径供调用者使用
        if args.play:
            subprocess.run(["aplay", output])
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
