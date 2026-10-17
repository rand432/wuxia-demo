# tools/doubao —— 豆包（火山方舟 / AI Hub）能力包

给《江湖游历》接的外部能力。脑子还是 DeepSeek，豆包只当手：出图、出片、看图、生成音频、配音、联网。
产物统一落 `.ark-out/`（已在 .gitignore，不会被 30 分钟一次的 autocommit 推上 Gitee）。

## 凭证分三套（重要）

| 能力 | 网关 | 需要什么 |
|---|---|---|
| 图像 Seedream / 视频 Seedance / 视觉理解 | `ark.cn-beijing.volces.com/api/v3` | 方舟 API Key（`apiKey`） |
| **音频生成 SeedAudio** | `openspeech.bytedance.com/api/v3/tts/create` | AI Hub API Key（`audio.apiKey`，走 `X-Api-Key` 头） |
| 语音合成 TTS（经典） | `openspeech.bytedance.com/api/v1/tts` | 豆包语音 appid + access token |
| 联网搜索 | `…/bots/chat/completions` | 方舟智能体 `bot-xxxx` |

**AI Hub 的 Key 不认方舟接口**（实测 Bearer 与 X-Api-Key 都是 401），两把钥匙不能互换。

## 配置

工程根 `.ark.json`（照 `.ark.example.json` 抄）：

```json
{
  "apiKey": "方舟 Key",
  "models": { "vision": "doubao-seed-evolving-latest-version", "image": "doubao-seedream-5-0-pro-260628", "video": "doubao-seedance-2-0-260128", "tts": "" },
  "tts": { "appid": "", "token": "", "voice": "zh_female_shuangkuaisisi_moon_bigtts", "cluster": "volcano_tts" },
  "audio": { "apiKey": "AI Hub Key", "model": "seed-audio-1.0" },
  "search": { "botId": "" }
}
```

模型 ID 以控制台「开通管理」/ AI Hub 模型卡片显示的为准。也可全走环境变量：`ARK_API_KEY`、`DOUBAO_AUDIO_KEY`、`DOUBAO_TTS_APPID`、`DOUBAO_BOT_ID` 等。

自检（不带 `--live` 不发任何计费请求）：

```powershell
node tools/doubao/probe.mjs
node tools/doubao/probe.mjs --live
```

## 六条命令

### 1. 音频生成 SeedAudio（一条提示词生成整段音频）

场景、环境声、音乐、带情绪的对白写在同一句里：

```powershell
# 对白场景
node tools/doubao/audio.mjs --prompt "深夜客栈，木门吱呀推开，远处虫鸣，掌柜用沙哑嗓音说：客官，打尖还是住店？" --name inn-01
# 纯音效
node tools/doubao/audio.mjs --prompt "一声清亮的剑鸣，剑刃缓缓入鞘，山谷回声渐渐安静" --name sword-01
# 配乐
node tools/doubao/audio.mjs --prompt "轻快的马林巴与琵琶，武侠赶路，节奏明快" --name bgm-01 --sample-rate 44100
```

参数：`--format mp3`、`--sample-rate`、`--speed`（语速 -50~100）、`--pitch`、`--loudness`、`--name`。
实测一句描述约 3 秒成品、几十 KB，返回 base64 MP3，脚本直接落盘。

### 2. 图像 Seedream

```powershell
node tools/doubao/image.mjs --prompt "水墨山门，晨雾，竖构图" --size 2K --name shanmen
node tools/doubao/image.mjs --prompt "同样的角色，改成侧面三视图" --ref 正面立绘.png
```

### 3. 视频 Seedance

```powershell
node tools/doubao/video.mjs --prompt "雨夜山道，剑客回首，衣摆被风带起" --dur 5 --ratio 9:16
node tools/doubao/video.mjs --batch tools/ark_plan.json
```

比老的 `tools/ark_video.mjs` 多了：垫图走本地文件、批量默认跳过已产物、失败带建议。老脚本保留不动。

### 4. 视觉理解

```powershell
node tools/doubao/vision.mjs --img 出图.png --prompt "这版能直接用于切片吗？指出构图问题"
node tools/doubao/vision.mjs --img a.png --img b.png --prompt "对比两版风格差异" --save docs/验收.md
```

### 5. 语音合成 TTS（经典逐句配音）

```powershell
node tools/doubao/tts.mjs --text "少侠留步，此地不宜久留。" --voice zh_female_shuangkuaisisi_moon_bigtts
```

有 `tts.appid/token` 走豆包语音原生；只配了 `models.tts` 时走方舟 `/audio/speech`。
逐句对白用这条；带音效/环境/音乐的整段场景用 SeedAudio。

### 6. 联网搜索

```powershell
node tools/doubao/search.mjs --query "2026 武侠手游买量素材的趋势"
```

走智能体（bot）形态。DSH 自带的 `web_search` 已经能联网，这条的价值在豆包的检索与摘要口味。

## 成本

- 图像 0.3 元/张、输入图 0.02 元/张（AI Hub 展示价）。
- 视频按 token：16–31 元/百万 tokens，最贵，先跑 1 条 5s 验货，别直接 `--batch`。
- 音频/语音按次或按字符，量小。
- `probe.mjs` 不带 `--live` 时零计费。

## 排错

| 现象 | 原因 | 处理 |
|---|---|---|
| The API key doesn't exist | 拿 AI Hub 的 Key 打方舟接口 | 两套凭证别混用 |
| ModelNotOpen / 404 | 模型没开通 | 控制台开通，或改 `models` 里的 ID |
| 音频接口 401 | 少了 X-Api-Key 头或 Key 不对 | 用 `audio.apiKey`，不是 `apiKey` |
| 视频一直 queued | 排队 | 别重复提交，稍后控制台取 |
| 语音 code 3006 | appid/token 与语音应用不匹配 | 两个值一起换 |

## 文件

```
tools/doubao/
  lib.mjs      公共客户端（凭证、超时、退避重试、错误提示、CLI 解析）
  audio.mjs    SeedAudio 音频生成（对白/音效/配乐）
  image.mjs    Seedream 出图
  video.mjs    Seedance 出片（含批量）
  vision.mjs   视觉理解
  tts.mjs      经典 TTS（原生 / 方舟双后端）
  search.mjs   联网搜索（bot 形态）
  probe.mjs    自检
```
