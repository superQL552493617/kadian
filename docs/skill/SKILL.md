---
name: "clone-xiaoman-style-app"
description: "用户想做一款新 App（和小满记同一套方案：网页界面 + iOS 外壳 + GitHub Actions 出包），或想复刻、改造小满记时使用。"
---

# 用起步模板快速做一款新 App（小满记同款）

用户没有 Mac。所有 App 都走同一套方案：
- 界面是单个 HTML 文件，放在 WKWebView 里（「网页版」）
- 原生 Swift 外壳负责网页做不到的事：存储、震动、音效、分享、面容 ID、通知提醒、小组件、内购、开屏、换图标
- GitHub Actions 负责：编译检查、上传 TestFlight、提交 App Store 资料、模拟器截图
- 全程用中文和用户沟通

## 第一件事：拿到真实源代码（不要凭文字描述复刻）

细节和质感都在代码里：CSS 颜色和阴影、圆角、动画曲线、音效参数、组件结构。开工前先把代码接进当前会话：
1. 用 add_repo（push 权限）接入起步模板 `superQL552493617/app-starter`，按提示 clone。
2. 先读模板里的 `CLAUDE.md`、`README.md`、`CHECKLIST.md`。
3. 模板没有的功能，到小满记 `superQL552493617/xiaoman-ios`（read 权限）里找来移植，包括：统计、笔记、回忆、闹钟响铃页、小组件插画、AI 总结。
4. add_repo 报没有权限时，请用户在 github.com/settings/installations → Claude → Configure 里勾上对应仓库。

复刻时直接复制组件和样式代码再改业务，不要重写一遍。

## 模板结构

- `app.json`：这款 App 的全部身份信息，包括名字、Bundle ID、App Group、会员商品和价格、网址、ICP 号、审核备注。
- 改完 `app.json` 运行 `python3 tools/render.py`，会生成：
  - `iOS/project.yml`、`iOS/Shared/AppConfig.swift`
  - `iOS/App/LegalText.swift`（简体、繁体、英文的隐私政策和用户协议）
  - InfoPlist.strings、`iOS/App/Web/app-config.js`、`ci/setup.json`
  - `site/<slug>/` 下三种语言的支持页、隐私政策、用户协议
- `iOS/App/Web/index.html`：全部界面。只改「起步模板：这一段是这款 App 自己的功能」那段：
  - renderToday 首页、openItemEditor 编辑页
  - syncNative 提醒和小组件
  - renderMe 我的、renderBackup 备份
  - 另外还有 GUIDE_TPL、GUIDE_STEPS、VIP_PERKS、openGuide
- 原生 Swift 是通用的，网页通过 cmd 调用原生：
  - 基础：load / save / haptic / sfx / tone / share / copy / open
  - 页面：feedback / doc / appicon / faceid / update / vip / lang
  - notify：网页算好提醒时间，原生排进系统通知
  - widget：网页整理好小组件内容；小组件上点过的项目用 `__xmWidgetTaps` 交回网页
- 多语言：界面文字写简体中文，用 `python3 i18n/build_i18n.py --missing` 列出没翻译的，补进 `i18n/en.json` 和 `i18n/zh-Hant.json`。繁体用 `tools/s2tw.py`（OpenCC 台湾用语）转。
- 签名：
  - 发布证书和 ASC 密钥已经加密放在 `ci/keys/`
  - 新仓库只需要一个 Secret：`SIGNING_PASSPHRASE`（用户自己保管）
  - App Group 只能用户在开发者网站手动建

## 第 0 步：一次问清需求（用 AskUserQuestion，最多两轮）

**必须问用户的：**
1. App 名字（中文、英文）和一句话定位
2. 核心功能 3～5 个，按优先级排；每个功能记录什么数据
3. 首页长什么样：一张参考图，或说「跟小满记一样」
4. 收费方式：哪些功能免费、哪些给会员；价格（中国大陆用人民币，其他地区按美元）
5. 上架地区和语言（只上中国大陆，还是同时上英文和繁体）
6. 自己的素材：插画、图标、Logo，以及授权情况
7. 是否需要 ICP 备案（上中国大陆需要）

**不用问，直接沿用模板的（用户说要改才改）：**
- 视觉：奶油纸感配色、圆角卡片、底部悬浮胶囊 Tab、浅色和深色模式
- 交互：点一下完成、长按编辑、震动和音效
- 通用模块：
  - 首次同意协议弹窗、新手引导、设置页
  - 个性化：主题、字体、配色板、图标形状、排列密度、完成音效、App 图标
  - 密码锁和面容 ID：先面容 ID，失败两次再出密码键盘
  - 会员页、备份和导入、关于
  - 意见反馈：私密问卷（app.json 里的 feedbackForm），自动带上用户 ID
  - ICP 号显示在「我的」底部和「关于」里（只在简体中文界面显示）
- 原生：
  - 开屏页：只在冷启动时显示，至少 1.2 秒；没有插画时只显示一句话
  - 提醒：第一次打开提醒时才请求通知权限
  - 小组件：今天的项目，点一下直接完成
- 三种语言：简体、繁体、英文
- 合规：
  - 隐私政策、用户协议、支持页三个网页放到 `superQL552493617.github.io/<slug>/`
  - 新用户没有预装数据
  - 正式版隐藏未上线的功能

## 第 1 步：原型（1～2 小时）
- 改 `index.html`，在浏览器里预览
- 用 Playwright（`/opt/pw-browsers/chromium`）截图自查：浅色、深色、英文，以及每个弹窗；英文逐页检查文字有没有超出按钮
- 截图一次性发给用户，请用户**编号列出**全部修改意见，一轮改完

## 第 2 步：套外壳出包（2～3 小时）
1. 改 `app.json`，运行 render.py
2. 推送 `ci/setup.json`，注册 App 和小组件两个 Bundle ID
3. 请用户在开发者网站建 App Group，并在两个 Bundle ID 里勾选
4. `ci/setup.json` 的 profiles 改成 true、run 加 1 再推送，生成描述文件；从 `ci-setup` 分支取出，放进 `ci/profiles/`
5. 请用户在 App Store Connect 新建 App
6. `ci/iap.txt` 写 setup，创建会员商品
7. 改 `ci/release.txt`，上传 TestFlight

只在需要时编译，省 macOS 分钟数：编译检查用 `ci/build.txt` 触发，平时只推送，不编译。

## 第 3 步：上架（先过一遍 CHECKLIST.md，防止被拒）
- `ci/asc.txt` 依次写 meta → locales → lshots → review → submit
- 隐私政策和支持网址能打开（必须返回 200）：把 `site/<slug>/` 复制到 `superQL552493617.github.io` 仓库发布，`ci/asc.txt` 写 links 自动检查
- 只支持 iPhone（`TARGETED_DEVICE_FAMILY "1"`，模板已设好），否则会要求 iPad 截图
- 第一次的内购商品要请用户在网页后台加到版本里，一起送审
- 商店截图用 6.9 英寸（1320×2868），由 sim-shots 生成
- 审核备注写清会员入口和免费额度
- 字体和图标只用 OFL、CC 授权或用户自己有授权的；不抄竞品文案和界面

## 已知限制
- 这个账号的私有仓库目前跑不了 Actions，报错是「recent account payments have failed or your spending limit…」。用户在 GitHub 的 Billing 里处理好之前：
  - 新 App 仓库在开发期间设成公开（密钥是加密的）
  - 或者把 iOS 代码（不含 ci/keys）推到公开仓库的临时分支做编译检查
- macOS 编译按 10 倍计算，平时只推送不编译

## 安全规则
- 口令、.p8 密钥、联系电话不写进代码和日志，只放在 GitHub Secrets 或加密文件里
- 提醒用户截图前裁掉手机号和地址
- 不对用户透露 AI 模型的供应商

## 和用户沟通
- 每完成一个阶段汇报一次：做了什么、需要用户做什么
- 用户提意见时，请对方用编号清单加截图，批量处理