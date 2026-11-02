# 给 Claude 的说明

这是用户的 App 起步模板（小满记同款方案）。用户没有 Mac，所有编译和上架都走 GitHub Actions。和用户沟通用中文。

- 开新 App：先读 README.md，按步骤问清 app.json 里的信息（名字、Bundle ID、会员价格等），运行 `python3 tools/render.py`。
- 写功能：只改 `iOS/App/Web/index.html` 里「起步模板：这一段是这款 App 自己的功能」那段；通用部分沿用。
  参考实现在 `superQL552493617/xiaoman-ios`（小满记，功能更完整：统计、笔记、回忆、闹钟响铃页、小组件插画等），需要时用 add_repo 接进来读。
- 网页预览：Playwright（`/opt/pw-browsers/chromium`）直接打开 index.html 截图自查，浅色、深色、英文都看。
- 文字写简体中文，最后用 `i18n/build_i18n.py --missing` 补翻译。
- 私有仓库省 macOS 分钟数：平时只推送不编译；需要时改 `ci/build.txt` 触发编译检查。
- 不要把口令、.p8、联系电话写进代码或日志。上架前过一遍 CHECKLIST.md。
- 这个账号的私有仓库目前跑不了 Actions（付款 / 消费上限问题）。用户没处理好之前，新 App 仓库开发期间设为公开；不要在私有仓库里指望 CI。
