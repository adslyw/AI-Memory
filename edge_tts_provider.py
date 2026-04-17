#!/usr/bin/env python3
"""
OpenClaw Edge TTS Provider Wrapper
实现 OpenClaw talk provider 接口，调用 edge-tts 生成语音
"""

import os
import sys
import json
import subprocess
import tempfile

def main():
    # 从 stdin 读取请求
    request = json.loads(sys.stdin.read())
    
    text = request.get("text", "")
    voice_id = request.get("voiceId", "zh-CN-XiaoyiNeural")
    output_format = request.get("outputFormat", "mp3_44100_128")
    
    if not text:
        print(json.dumps({"error": "No text provided"}))
        sys.exit(1)
    
    # 解析输出格式
    if output_format.startswith("mp3"):
        ext = "mp3"
    elif output_format.startswith("wav"):
        ext = "wav"
    else:
        ext = "mp3"
    
    # 创建临时文件
    with tempfile.NamedTemporaryFile(suffix=f".{ext}", delete=False) as f:
        output_path = f.name
    
    # edge-tts 路径
    edge_tts = "/home/deepnight/src/homepage_v2/venv/bin/edge-tts"
    
    # 调用 edge-tts
    cmd = [
        edge_tts,
        "--voice", voice_id,
        "--text", text,
        "--write-media", output_path
    ]
    
    result = subprocess.run(cmd, capture_output=True, text=True)
    
    if result.returncode != 0:
        error_msg = result.stderr or "Edge TTS failed"
        print(json.dumps({"error": error_msg}))
        sys.exit(1)
    
    # 读取音频文件并输出 base64
    with open(output_path, "rb") as f:
        audio_data = f.read()
    
    # 清理临时文件
    os.unlink(output_path)
    
    # 返回响应
    response = {
        "format": ext,
        "data": audio_data.hex(),  # 十六进制，OpenClaw 应该能处理
        "size": len(audio_data)
    }
    
    print(json.dumps(response))

if __name__ == "__main__":
    main()
