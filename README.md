# Edge TTS API

> 基于 Microsoft Edge 在线语音服务的免费文本转语音 HTTP API
> 
> 在线体验：https://api.kina.ink

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/yourname/edge-tts-api)
[![License](https://img.shields.io/badge/license-MIT-green)](https://github.com/yourname/edge-tts-api/blob/main/LICENSE)

---

## 功能特性

- **完全免费**：无需 Azure 订阅或 API Key
- **多语言支持**：19 种语音，覆盖中、英、日、韩及多种方言
- **本地缓存**：重复请求秒级响应
- **异步处理**：基于 FastAPI，支持高并发
- **部署简单**：单文件即可运行，支持 systemd 托管

---

## 项目结构

```
edge-tts-api/
├── edge_tts_api.py            # 核心服务代码
├── install_edge_tts_system.sh # 一键安装脚本
├── requirements.txt           # Python 依赖
├── nginx.conf                 # Nginx 反向代理配置
├── README.md                  # 本文档
└──  LICENSE                   # MIT 许可证（含第三方声明）
```

---

## 安装部署

### 环境要求

- Debian 12 / Ubuntu 22.04 / CentOS 8+
- Python 3.11+
- pip3
- Nginx（用于反向代理和 SSL）

### 方式一：一键安装（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/yourname/edge-tts-api.git
cd edge-tts-api

# 2. 执行安装脚本
chmod +x install_edge_tts_system.sh
./install_edge_tts_system.sh
```

脚本会自动完成：
- 安装 Python 依赖（fastapi、uvicorn、edge-tts、pydantic）
- 创建服务目录 `/www/edge-tts-api/`
- 创建 systemd 服务并启动
- 服务运行在 `0.0.0.0:9178`

### 方式二：手动安装

```bash
# 1. 安装 Python 依赖
pip3 install --break-system-packages -r requirements.txt

# 2. 创建服务目录
mkdir -p /www/edge-tts-api
cp edge_tts_api.py /www/edge-tts-api/

# 3. 创建 systemd 服务
sudo tee /etc/systemd/system/edge-tts-api.service > /dev/null << 'EOF'
[Unit]
Description=Edge TTS API Service
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/www/edge-tts-api
ExecStart=/usr/bin/python3 /www/edge-tts-api/edge_tts_api.py
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# 4. 启动服务
sudo systemctl daemon-reload
sudo systemctl enable edge-tts-api
sudo systemctl start edge-tts-api

# 5. 查看状态
sudo systemctl status edge-tts-api
```

### 服务管理命令

| 命令 | 说明 |
|------|------|
| `systemctl status edge-tts-api` | 查看服务状态 |
| `systemctl start edge-tts-api` | 启动服务 |
| `systemctl stop edge-tts-api` | 停止服务 |
| `systemctl restart edge-tts-api` | 重启服务 |
| `journalctl -u edge-tts-api -f` | 查看实时日志 |

---

## 使用方法

### 测试服务

```bash
# 健康检查
curl http://127.0.0.1:9178/health

# 获取语音列表
curl http://127.0.0.1:9178/voices

# 生成语音（保存为文件）
curl "http://127.0.0.1:9178/tts?text=你好世界" -o hello.mp3

# 指定语音和语速
curl "http://127.0.0.1:9178/tts?text=你好&voice=zh-CN-YunxiNeural&rate=+20%" -o hello.mp3
```

### 在代码中调用

#### JavaScript

```javascript
async function speak(text, voice = 'zh-CN-XiaoxiaoNeural') {
  const url = `https://tts.kina.ink/tts?${new URLSearchParams({
    text: text,
    voice: voice,
    rate: '+0%'
  })}`;

  const response = await fetch(url);
  const blob = await response.blob();
  const audioUrl = URL.createObjectURL(blob);

  const audio = new Audio(audioUrl);
  audio.play();
}

speak('你好世界');
```

#### Python

```python
import requests

def tts(text, voice='zh-CN-XiaoxiaoNeural', output='output.mp3'):
    url = 'https://tts.kina.ink/tts'
    params = {
        'text': text,
        'voice': voice,
        'rate': '+0%'
    }

    response = requests.get(url, params=params, timeout=60)

    if response.status_code == 200:
        with open(output, 'wb') as f:
            f.write(response.content)
        print(f'已保存到 {output}')

tts('你好世界')
```

#### PHP

```php
<?php
function tts($text, $voice = 'zh-CN-XiaoxiaoNeural', $output = 'output.mp3') {
    $url = 'https://tts.kina.ink/tts?' . http_build_query([
        'text' => $text,
        'voice' => $voice,
        'rate' => '+0%'
    ]);

    $audio = file_get_contents($url);
    file_put_contents($output, $audio);
    echo "已保存到 $output\n";
}

tts('你好世界');
```

#### Node.js

```javascript
const https = require('https');
const fs = require('fs');

function tts(text, voice = 'zh-CN-XiaoxiaoNeural', output = 'output.mp3') {
  const url = `https://tts.kina.ink/tts?text=${encodeURIComponent(text)}&voice=${voice}`;

  https.get(url, (res) => {
    const file = fs.createWriteStream(output);
    res.pipe(file);
    file.on('finish', () => {
      file.close();
      console.log(`已保存到 ${output}`);
    });
  });
}

tts('你好世界');
```

---

## API 文档

### 接口列表

| 接口 | 方法 | 说明 |
|------|------|------|
| `/` | GET | 服务信息 |
| `/health` | GET | 健康检查 |
| `/voices` | GET | 可用语音列表 |
| `/tts` | GET/POST | 文本转语音 |

### GET `/tts` 参数

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| `text` | string | 是 | - | 要合成的文本，最长 5000 字 |
| `voice` | string | 否 | `zh-CN-XiaoxiaoNeural` | 语音 ID |
| `rate` | string | 否 | `+0%` | 语速：`-50%` ~ `+50%` |
| `volume` | string | 否 | `+0%` | 音量：`-50%` ~ `+50%` |
| `pitch` | string | 否 | `+0Hz` | 音调：`-50Hz` ~ `+50Hz` |
| `format` | string | 否 | `mp3` | `mp3` / `wav` / `ogg` / `webm` |

### 语音列表

| 语音 ID | 名称 | 语言 |
|---------|------|------|
| `zh-CN-XiaoxiaoNeural` | 晓晓 | 中文（温柔女声） |
| `zh-CN-XiaoyiNeural` | 晓伊 | 中文（活泼女声） |
| `zh-CN-YunjianNeural` | 云健 | 中文（新闻男声） |
| `zh-CN-YunxiNeural` | 云希 | 中文（少年男声） |
| `zh-CN-YunxiaNeural` | 云夏 | 中文（童声男声） |
| `zh-CN-YunyangNeural` | 云扬 | 中文（解说男声） |
| `zh-CN-liaoning-XiaobeiNeural` | 晓北 | 中文（东北话） |
| `zh-CN-shaanxi-XiaoniNeural` | 晓妮 | 中文（陕西话） |
| `zh-TW-HsiaoChenNeural` | 晓臻 | 中文（台湾女声） |
| `zh-TW-YunJheNeural` | 云哲 | 中文（台湾男声） |
| `zh-HK-HiuMaanNeural` | 晓曼 | 中文（粤语女声） |
| `zh-HK-WanLungNeural` | 云龙 | 中文（粤语男声） |
| `en-US-AriaNeural` | Aria | 英文（美式女声） |
| `en-US-GuyNeural` | Guy | 英文（美式男声） |
| `en-GB-SoniaNeural` | Sonia | 英文（英式女声） |
| `en-GB-RyanNeural` | Ryan | 英文（英式男声） |
| `ja-JP-NanamiNeural` | 七海 | 日文（女声） |
| `ja-JP-KeitaNeural` | 圭太 | 日文（男声） |
| `ko-KR-SunHiNeural` | 善熙 | 韩文（女声） |

---

## Nginx 反向代理

### 宝塔面板配置

1. 登录宝塔面板 → 网站 → 添加站点
2. 域名填写：`tts.kina.ink`
3. 选择 PHP 版本为**纯静态**
4. 点击设置 → 配置文件
5. 在 `server` 块内添加以下内容：

```nginx
location / {
    proxy_pass http://127.0.0.1:9178;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_connect_timeout 60s;
    proxy_send_timeout 60s;
    proxy_read_timeout 60s;
    proxy_buffering off;
    proxy_cache off;
}
```

6. 保存并申请 SSL 证书
7. 防火墙放行 9178 端口（如果直接访问 IP:端口）

### 手动配置

将 `nginx.conf` 中的配置复制到你的 Nginx 配置文件中，修改域名和证书路径即可。

### 配置说明

| 配置项 | 说明 |
|--------|------|
| `proxy_pass` | 转发到本地 9178 端口 |
| `proxy_connect_timeout` | 连接超时 60 秒 |
| `proxy_read_timeout` | 读取超时 60 秒（TTS 生成需要时间） |
| `proxy_buffering off` | 关闭缓冲，音频流实时传输 |
| `proxy_cache off` | 关闭缓存，避免音频被截断 |

---

## 技术原理

### 核心思路

Microsoft Edge 浏览器内置了"大声朗读"功能，该功能调用微软的在线 TTS 服务（`speech.platform.bing.com`），且**完全免费、无需认证**。

`edge-tts` 库通过逆向工程，模拟 Edge 浏览器的 WebSocket 请求，实现了对该免费服务的程序化调用。

```
用户请求 → FastAPI → edge-tts 库 → WebSocket → 微软服务 → 音频流
```

### 与 Azure Speech Services 的区别

| | Edge TTS API | Azure Speech Services |
|---|---|---|
| 费用 | 免费 | 按量付费 |
| 认证 | 无需 | 需要 API Key |
| 稳定性 | 无 SLA | 有 SLA |
| 质量 | 接近 Azure | 官方标准 |
| 风险 | 微软服务可能变更 | 稳定可靠 |

---

## 注意事项

1. **文本长度限制**：单次请求最长 5000 字，超出请分段调用
2. **超时设置**：TTS 生成需要 3-10 秒，建议设置 60 秒超时
3. **缓存机制**：相同参数的请求会被缓存，首次生成后秒级响应
4. **音频格式**：默认 MP3，兼容性最好
5. **网络要求**：服务器需能访问微软服务
6. **风险提示**：edge-tts 是非官方方案，微软服务变更可能导致失效

---

## 作者

**kina漫记** · [kina.ink](https://kina.ink)

---

## License

本项目采用 [MIT](LICENSE) 许可证。

本项目使用了 [edge-tts](https://github.com/rany2/edge-tts) 库，该库采用 [LGPL-3.0](https://github.com/rany2/edge-tts/blob/master/LICENSE) 许可证。
