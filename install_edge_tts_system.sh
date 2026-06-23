#!/bin/bash
# Edge TTS API 一键安装脚本（系统 Python 直接安装）
# 端口: 9178

set -e

PORT=9178
INSTALL_DIR="/www/edge-tts-api"

echo "=========================================="
echo "  Edge TTS API 服务安装脚本"
echo "  端口: $PORT"
echo "  模式: 系统 Python 直接安装"
echo "=========================================="

# 检查 Python3
if ! command -v python3 &> /dev/null; then
    echo "[×] Python3 未安装，正在安装..."
    apt update && apt install -y python3 python3-pip
fi

PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "[✓] Python 版本: $PYTHON_VERSION"

# 确保 pip 可用
if ! command -v pip3 &> /dev/null; then
    echo "[→] 安装 pip3..."
    apt install -y python3-pip
fi

# 升级 pip
echo "[→] 升级 pip..."
pip3 install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple

# 安装依赖（直接装到系统 Python）
echo "[→] 安装依赖包到系统 Python..."
pip3 install fastapi uvicorn edge-tts pydantic -i https://pypi.tuna.tsinghua.edu.cn/simple

echo "[✓] 依赖安装完成"

# 创建工作目录
mkdir -p $INSTALL_DIR
cd $INSTALL_DIR

echo "[→] 安装目录: $INSTALL_DIR"

# 创建服务文件
cat > edge_tts_api.py << 'PYEOF'
#!/usr/bin/env python3
"""
Edge TTS API 服务
基于 edge-tts 库的 FastAPI 服务
端口: 9178
"""

import asyncio
import io
import os
import hashlib
from typing import Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.responses import StreamingResponse, FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
import edge_tts

# ============ 配置 ============
PORT = 9178
CACHE_DIR = "/tmp/edge_tts_cache"
MAX_CACHE_SIZE_MB = 500
DEFAULT_VOICE = "zh-CN-XiaoxiaoNeural"

os.makedirs(CACHE_DIR, exist_ok=True)

# 可用语音列表
VOICE_LIST = {
    "zh-CN-XiaoxiaoNeural": "晓晓（女，温柔）",
    "zh-CN-XiaoyiNeural": "晓伊（女，活泼）",
    "zh-CN-YunjianNeural": "云健（男，新闻）",
    "zh-CN-YunxiNeural": "云希（男，少年）",
    "zh-CN-YunxiaNeural": "云夏（男，童声）",
    "zh-CN-YunyangNeural": "云扬（男，解说）",
    "zh-CN-liaoning-XiaobeiNeural": "晓北（东北话）",
    "zh-CN-shaanxi-XiaoniNeural": "晓妮（陕西话）",
    "zh-TW-HsiaoChenNeural": "晓臻（台湾，女）",
    "zh-TW-YunJheNeural": "云哲（台湾，男）",
    "en-US-AriaNeural": "Aria（美，女）",
    "en-US-GuyNeural": "Guy（美，男）",
    "en-GB-SoniaNeural": "Sonia（英，女）",
    "en-GB-RyanNeural": "Ryan（英，男）",
    "ja-JP-NanamiNeural": "七海（女）",
    "ja-JP-KeitaNeural": "圭太（男）",
    "ko-KR-SunHiNeural": "善熙（女）",
    "zh-HK-HiuMaanNeural": "晓曼（粤语，女）",
    "zh-HK-WanLungNeural": "云龙（粤语，男）",
}

# ============ 模型定义 ============
class TTSRequest(BaseModel):
    text: str = Field(..., min_length=1, max_length=5000, description="要合成的文本")
    voice: str = Field(default=DEFAULT_VOICE, description="语音名称")
    rate: str = Field(default="+0%", description="语速调整，如 +20% 或 -10%")
    volume: str = Field(default="+0%", description="音量调整")
    pitch: str = Field(default="+0Hz", description="音调调整，如 +50Hz")
    format: str = Field(default="mp3", description="输出格式: mp3, wav, ogg, webm")

# ============ 缓存管理 ============
def get_cache_key(text, voice, rate, volume, pitch, fmt):
    content = f"{text}|{voice}|{rate}|{volume}|{pitch}|{fmt}"
    return hashlib.md5(content.encode()).hexdigest()

def get_cache_path(cache_key, fmt):
    return os.path.join(CACHE_DIR, f"{cache_key}.{fmt}")

def clean_cache():
    try:
        files = []
        for f in os.listdir(CACHE_DIR):
            fp = os.path.join(CACHE_DIR, f)
            if os.path.isfile(fp):
                files.append((fp, os.path.getsize(fp), os.path.getmtime(fp)))
        total_size = sum(f[1] for f in files) / (1024 * 1024)
        if total_size > MAX_CACHE_SIZE_MB:
            files.sort(key=lambda x: x[2])
            for fp, size, _ in files:
                if total_size <= MAX_CACHE_SIZE_MB * 0.7:
                    break
                os.remove(fp)
                total_size -= size / (1024 * 1024)
    except Exception:
        pass

# ============ FastAPI 应用 ============
app = FastAPI(
    title="Edge TTS API",
    description="基于 edge-tts 的文本转语音 API 服务",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {
        "service": "Edge TTS API",
        "version": "1.0.0",
        "port": PORT,
        "endpoints": {
            "GET /voices": "获取可用语音列表",
            "POST /tts": "文本转语音（POST，返回音频流）",
            "GET /tts": "文本转语音（GET，返回音频流）",
            "GET /health": "健康检查",
        }
    }

@app.get("/health")
async def health():
    return {"status": "ok", "port": PORT, "cache_dir": CACHE_DIR}

@app.get("/voices")
async def list_voices():
    return {
        "count": len(VOICE_LIST),
        "voices": [{"id": k, "name": v} for k, v in VOICE_LIST.items()]
    }

@app.post("/tts")
async def text_to_speech(req: TTSRequest):
    if req.voice not in VOICE_LIST:
        raise HTTPException(status_code=400, detail=f"不支持的语音: {req.voice}")

    cache_key = get_cache_key(req.text, req.voice, req.rate, req.volume, req.pitch, req.format)
    cache_path = get_cache_path(cache_key, req.format)

    if os.path.exists(cache_path):
        media_type = {"mp3": "audio/mpeg", "wav": "audio/wav", "ogg": "audio/ogg", "webm": "audio/webm"}.get(req.format, "audio/mpeg")
        return FileResponse(cache_path, media_type=media_type, headers={"X-Cache": "HIT"})

    try:
        communicate = edge_tts.Communicate(req.text, req.voice, rate=req.rate, volume=req.volume, pitch=req.pitch)
        audio_buffer = io.BytesIO()
        async for chunk in communicate.stream():
            if chunk["type"] == "audio":
                audio_buffer.write(chunk["data"])

        audio_data = audio_buffer.getvalue()

        try:
            with open(cache_path, "wb") as f:
                f.write(audio_data)
            clean_cache()
        except Exception:
            pass

        media_type = {"mp3": "audio/mpeg", "wav": "audio/wav", "ogg": "audio/ogg", "webm": "audio/webm"}.get(req.format, "audio/mpeg")
        return StreamingResponse(io.BytesIO(audio_data), media_type=media_type, headers={"X-Cache": "MISS"})

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"TTS 生成失败: {str(e)}")

@app.get("/tts")
async def text_to_speech_get(
    text: str = Query(..., min_length=1, max_length=5000),
    voice: str = Query(default=DEFAULT_VOICE),
    rate: str = Query(default="+0%"),
    volume: str = Query(default="+0%"),
    pitch: str = Query(default="+0Hz"),
    format: str = Query(default="mp3"),
):
    req = TTSRequest(text=text, voice=voice, rate=rate, volume=volume, pitch=pitch, format=format)
    return await text_to_speech(req)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=PORT)
PYEOF

chmod +x edge_tts_api.py

# 创建 systemd 服务
echo "[→] 创建 systemd 服务..."
cat > /etc/systemd/system/edge-tts-api.service << SVCEOF
[Unit]
Description=Edge TTS API Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/python3 $INSTALL_DIR/edge_tts_api.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
SVCEOF

# 启动服务
systemctl daemon-reload
systemctl enable edge-tts-api
systemctl start edge-tts-api

# 检查服务状态
sleep 2
if systemctl is-active --quiet edge-tts-api; then
    echo ""
    echo "=========================================="
    echo "  [✓] 安装完成！服务运行正常"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "  [×] 服务启动失败，查看日志："
    echo "  journalctl -u edge-tts-api -n 20"
    echo "=========================================="
fi

echo ""
echo "  服务状态: systemctl status edge-tts-api"
echo "  启动命令: systemctl start edge-tts-api"
echo "  停止命令: systemctl stop edge-tts-api"
echo "  重启命令: systemctl restart edge-tts-api"
echo "  查看日志: journalctl -u edge-tts-api -f"
echo ""
echo "  API 地址: http://你的服务器IP:$PORT"
echo "  语音列表: http://你的服务器IP:$PORT/voices"
echo "  测试接口: http://你的服务器IP:$PORT/tts?text=你好世界"
echo ""
echo "  安装目录: $INSTALL_DIR"
echo "  缓存目录: /tmp/edge_tts_cache"
echo ""
echo "=========================================="
