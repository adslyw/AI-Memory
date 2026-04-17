#!/usr/bin/env python3
"""
唱歌脚本：生成旋律 WAV + 同步歌词朗读
"""

import wave
import struct
import math
import os
import time
import threading
import subprocess

# ============== 配置 ==============
VOICE_RATE = 1.0  # 语音速率
SAMPLE_RATE = 44100
VOLUME = 0.3
# ============== 旋律（频率Hz,歌词,时长） ==============
melody = [
    (261.63, "一闪一闪", 1.0),
    (294.00, "亮晶晶，", 1.0),
    (329.63, "满天都是", 1.0),
    (261.63, "小星星。", 1.2),
]

def generate_melody_wav(filename):
    """生成旋律 WAV"""
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        for freq, lyric, duration in melody:
            n_samples = int(SAMPLE_RATE * duration)
            for i in range(n_samples):
                value = int(32767 * VOLUME * math.sin(2 * math.pi * freq * i / SAMPLE_RATE))
                wav.writeframes(struct.pack('<h', value))
    return filename

def play_wav(filename):
    """播放 WAV"""
    subprocess.run(['aplay', filename], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def sing_lyrics():
    """用 spd-say 朗读歌词（等音乐开始后）"""
    time.sleep(0.5)  # 等音乐开始
    for freq, lyric, duration in melody:
        os.system(f'spd-say "{lyric}"')
        time.sleep(duration + 0.1)

def main():
    print("🎤 开始演唱《小星星》...")

    # 生成音乐
    wav_file = "/tmp/starlight_sing.wav"
    generate_melody_wav(wav_file)
    print(f"✅ 生成旋律: {wav_file}")

    # 双线程：音乐 + 歌词
    t1 = threading.Thread(target=play_wav, args=(wav_file,))
    t2 = threading.Thread(target=sing_lyrics)
    t1.start()
    t2.start()
    t1.join()
    t2.join()

    print("✅ 演唱完成！")

if __name__ == "__main__":
    main()
