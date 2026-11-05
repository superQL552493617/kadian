#!/usr/bin/env python3
"""生成 App 备案要填的信息（腾讯云「新增 App」），开发窗口运行后把输出整段发给老板。

用法：python3 tools/icp_info.py [输出文件夹，默认 /tmp/icp]
会生成：
  <输出文件夹>/备案信息.md        —— 要填的全部内容，可以直接贴进聊天
  <输出文件夹>/<App名>_备案图标_512.png —— 要上传的图标，用 SendUserFile 发给老板

只读 app.json、ci/dist.cer（发布证书，公开信息）和 App 图标，不碰任何密钥。
"""
import json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/icp"
DOMAIN = "xiaomanhabit.site"          # 老板备案用的实名域名（小满记、准点时钟都用它）
MAIN_ICP = "鄂ICP备2026060859号"       # 主体备案号，新 App 一般是「…号-<序号>A」

app = json.load(open(os.path.join(ROOT, "app.json"), encoding="utf-8"))
cer = os.path.join(ROOT, "ci", "dist.cer")

def ssl(*args):
    return subprocess.check_output(["openssl", "x509", "-inform", "der", "-in", cer, "-noout", *args], text=True).strip()

modulus = ssl("-modulus").split("=", 1)[1]
sha1_colon = ssl("-fingerprint", "-sha1").split("=", 1)[1]
sha1 = sha1_colon.replace(":", "")
subject = ssl("-subject").split("CN = ", 1)[-1].split(",")[0]
until = ssl("-enddate").split("=", 1)[1]

os.makedirs(OUT, exist_ok=True)
icon_src = os.path.join(ROOT, "iOS", "Shared", "Assets.xcassets", "AppIcon.appiconset", "icon-1024.png")
icon_out = os.path.join(OUT, f"{app['name']}_备案图标_512.png")
try:
    from PIL import Image
    Image.open(icon_src).convert("RGB").resize((512, 512), Image.LANCZOS).save(icon_out, optimize=True)
except Exception as e:  # 没有 PIL 时提示手动导出
    icon_out = f"（没生成，{e}；把 {icon_src} 缩成 512×512 再发）"

md = f"""# {app['name']}：App 备案要填的信息

在腾讯云备案（控制台搜「备案」，或微信小程序「腾讯云网站备案」）选「**新增 App**」，选已有主体（主体备案号 {MAIN_ICP}）。

**App 信息**
- App 名称：{app['name']}（和 App Store 名称一致）
- 域名：`{DOMAIN}`（和之前的 App 同一个；万一提示被占用，填 `{app['bundleId'].split('.')[-1]}.{DOMAIN}`）
- 运行平台：只选苹果 iOS
- 服务类型：按 App Store 分类选（比如「工具」「效率」）
- 外部 SDK：无　对外提供 SDK：否
- App 简介：{app.get('subtitle') or '（一句话说明这款 App 做什么）'}。数据只存在手机上，不收集个人信息。

**包信息（苹果平台）**
- Bundle ID：
```
{app['bundleId']}
```
- 公钥（一整行复制）：
```
{modulus}
```
- 签名 MD5 值（苹果平台填证书 SHA-1）：
```
{sha1}
```
  要冒号格式就填：`{sha1_colon}`

**图标**：上传「{os.path.basename(icon_out)}」（512×512）。

**之后**：腾讯云初审 1～2 个工作日（可能来电核实）→ 管局审核，**收到工信部核验短信 24 小时内回复** → 3～20 个工作日出备案号 → 备案号发给开发，写进 `app.json` 的 `icp` 和 App Store Connect。

（证书：{subject}，{until} 到期；续签后公钥和 SHA-1 会变，所有已备案的 App 都要去腾讯云做变更。）
"""
open(os.path.join(OUT, "备案信息.md"), "w", encoding="utf-8").write(md)
print(md)
print("图标：", icon_out)
