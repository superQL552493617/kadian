# App 起步模板（小满记同款方案）

用这个仓库开一款新 App：界面是一个网页文件（`iOS/App/Web/index.html`），装进原生 iOS 外壳；
编译、签名、上传 TestFlight、填写 App Store 资料、截图，全部在 GitHub Actions 里完成，不需要 Mac。

视觉和交互直接沿用小满记：奶油纸感配色、圆角卡片、底部悬浮导航、深浅色模式、点一下完成的动画和音效、
弹窗和底部面板、新手引导、设置、个性化（主题 / 字体 / 配色板 / 图标形状 / 排列密度 / 音效）、
密码锁和面容 ID、会员页、意见反馈、备份导入导出、三种语言（简体 / 繁体 / 英文）。

## 开一款新 App 的步骤

### 1. 复制模板
GitHub 上新建一个**私有**仓库（比如 `my-new-app`），把这个仓库的内容推过去（或者在这个仓库的 Settings 里勾选
「Template repository」，以后点「Use this template」）。
在仓库 Settings → Secrets → Actions 里添加 **一个** Secret：`SIGNING_PASSPHRASE`（和小满记的同一个口令）。
签名用的密钥已经加密放在 `ci/keys/`，发布证书 `ci/dist.cer` 也是同一个团队通用的，不用重新申请。

### 2. 改 `app.json`，再运行
```
python3 tools/render.py
```
它会生成：工程配置（Bundle ID、显示名、权限说明）、原生配置 `AppConfig.swift`、App 内的隐私政策和用户协议、
网页配置 `app-config.js`、签名准备 `ci/setup.json`、三种语言的网站页面 `site/<slug>/`。

### 3. 苹果后台（只能在网页上做）
1. 开发者网站 Identifiers 里新建 App Group：`app.json` 里的 `appGroup`。
2. 推送一次 `ci/setup.json`（自动注册 App 和小组件两个 Bundle ID）。
3. 在两个 Bundle ID 的 App Groups 能力里勾选上一步的 App Group 并保存。
4. 把 `ci/setup.json` 里 `profiles` 改成 `true`、`run` 加 1 再推送，生成描述文件；
   从 `ci-setup` 分支取出两个 `.mobileprovision` 放进 `ci/profiles/`。
5. App Store Connect 新建 App（套装 ID 选上面注册的）。
6. 会员商品：`ci/iap.txt` 写 `setup` 推送，自动创建年度 / 月度订阅和永久买断（价格按 `app.json`）。

### 4. 写这款 App 自己的功能
主要改 `iOS/App/Web/index.html` 里标着「起步模板：这一段是这款 App 自己的功能」的那一段：
- `renderToday` 首页、`openItemEditor` 编辑页、`syncNative` 提醒和小组件、`renderMe` 我的、`renderBackup` 备份
- `GUIDE_TPL` / `GUIDE_STEPS` 新手引导、`VIP_PERKS` 会员权益、`openGuide` 使用指南
其他部分（主题、字体、密码锁、会员页、反馈、弹窗组件）是通用的，一般不用动。

在电脑浏览器里直接打开 `index.html` 就能预览（数据存在浏览器里）。

### 5. 多语言
界面文字直接写简体中文。写完运行：
```
python3 i18n/build_i18n.py --missing
```
列出还没翻译的文字，把英文加进 `i18n/en.json`、繁体加进 `i18n/zh-Hant.json`（繁体可以用 `tools/s2tw.py` 自动转），再运行一次
`python3 i18n/build_i18n.py` 写进页面。

### 6. 出包和上架
| 要做的事 | 改哪个文件后推送 |
|---|---|
| 编译检查 | `ci/build.txt`（随便改一下） |
| 上传 TestFlight | `ci/release.txt`（数字加 1） |
| 模拟器截图 | `ci/shots.txt` |
| App Store 资料 | `ci/asc.txt` 写 `meta` / `locales` / `lshots` / `review` / `submit` / `status` |
| 会员商品 | `ci/iap.txt` 写 `setup` / `check` |

结果和日志在对应的分支：`ci-log`、`ci-log-testflight`、`ci-shots`、`ci-log-asc`、`ci-log-iap`、`ci-setup`。

**⚠️ 私有仓库现在跑不了 Actions**：GitHub 提示「recent account payments have failed or your spending limit needs to be increased」。要先到 GitHub → Settings → Billing and plans 处理付款方式 / 消费上限；处理好之前，新 App 的仓库在开发期间先设成公开（密钥是加密的，不会泄露）。

**私有仓库省编译分钟数**：macOS 编译按 10 倍计算，免费额度每月约 200 分钟 macOS 时间。
编译检查只在改 `ci/build.txt` 时运行，平时推送不编译。

### 7. 网站
把 `site/<slug>/` 整个复制到 `superQL552493617.github.io` 仓库，网址就是 `app.json` 里的 `pagesBase`。
上架前确认这几个网址都能打开（`ci/asc.txt` 写 `links` 会自动检查）。

上架前检查见 [CHECKLIST.md](CHECKLIST.md)。

## 配套技能备份

`docs/skill/SKILL.md` 是 Claude 技能「clone-xiaoman-style-app」的备份。正常情况下它已经保存在 Claude 账号里，会自动启用；如果换了账号或技能丢了，把 `docs/skill/` 文件夹打包成 zip，在 Claude 设置的技能页面上传即可。改了技能后记得同步更新这里。
