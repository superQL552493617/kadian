#!/usr/bin/env python3
"""根据 app.json 生成所有和「这款 App 是谁」有关的文件。改完 app.json 运行一次：

    python3 tools/render.py

生成：
- iOS/Shared/AppConfig.swift        原生代码里用的名字、Bundle ID、App Group、商品 ID…
- iOS/project.yml                   xcodegen 工程（Bundle ID、显示名、权限说明、字体、签名）
- iOS/App/LegalText.swift           App 内的隐私政策、用户协议（简体 / 繁体 / 英文）
- iOS/*/Localized/*.lproj/InfoPlist.strings   桌面名字、权限说明的多语言
- iOS/App/Web/app-config.js         网页里用的 window.APP
- ci/setup.json                     签名准备（注册 Bundle ID、创建描述文件）
- site/<slug>/                      隐私政策、用户协议、支持页三个网页（三种语言），复制到 github.io 仓库发布
"""
import json, os, re, sys, glob, html, datetime
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, 'tools'))
from s2tw import conv

C = json.load(open(os.path.join(ROOT, 'app.json'), encoding='utf8'))
TW_FIX = [('周', '週'), ('小元件', '小工具'), ('面容 ID', 'Face ID'), ('觸控 ID', 'Touch ID'), ('賬戶', '帳號'), ('賬號', '帳號')]
def hant(s):
    t = conv(s)
    for a, b in TW_FIX: t = t.replace(a, b)
    return t
def w(path, text):
    p = os.path.join(ROOT, path); os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'w', encoding='utf8').write(text); print('wrote', path)
def sw(s): return s.replace('\\', '\\\\').replace('"', '\\"')

name, nameEn, nameHant = C['name'], C['nameEn'], C.get('nameHant') or hant(C['name'])
today = datetime.date.today()
DATE = f"{today.year} 年 {today.month} 月 {today.day} 日"
DATE_EN = today.strftime('%B %-d, %Y')
vip = C.get('vip', {})
perm = C.get('permissions', {})
quoteHant = C.get('splashQuoteHant') or hant(C.get('splashQuote', ''))

# ---------- AppConfig.swift ----------
w('iOS/Shared/AppConfig.swift', f'''import Foundation

/// 这款 App 的身份信息。由 tools/render.py 根据 app.json 生成，不要手改。
enum AppConfig {{
    static let slug = "{sw(C['slug'])}"
    static let bundleId = "{sw(C['bundleId'])}"
    static let appGroup = "{sw(C['appGroup'])}"
    static let urlScheme = "{sw(C['urlScheme'])}"
    static let nameZh = "{sw(name)}"
    static let nameEn = "{sw(nameEn)}"
    static let nameHant = "{sw(nameHant)}"
    static var displayName: String {{ L10n.lang == "en" ? nameEn : L10n.lang == "zh-Hant" ? nameHant : nameZh }}
    static let splashQuote = "{sw(C.get('splashQuote', ''))}"
    static let splashQuoteEn = "{sw(C.get('splashQuoteEn', ''))}"
    static let splashQuoteHant = "{sw(quoteHant)}"
    /// 检查更新时查哪个国家的 App Store（只在中国大陆上架就用 cn）
    static let lookupCountry = "{sw(C.get('lookupCountry', 'cn'))}"
    static let vipEnabled = {'true' if vip.get('enabled') else 'false'}
    static let vipYear = "{sw(vip.get('year', {}).get('id', ''))}"
    static let vipMonth = "{sw(vip.get('month', {}).get('id', ''))}"
    static let vipLife = "{sw(vip.get('life', {}).get('id', ''))}"
}}
''')

# ---------- project.yml ----------
fonts = sorted(os.path.basename(f) for f in glob.glob(os.path.join(ROOT, 'iOS/App/Web/fonts/*.ttf')))
alt = C.get('altIcons', [])
fontlines = ''.join(f'\n          - {f}' for f in fonts)
w('iOS/project.yml', f'''# 由 tools/render.py 根据 app.json 生成，不要手改
name: App
options:
  bundleIdPrefix: {C['bundleId'].rsplit('.', 1)[0]}
  deploymentTarget:
    iOS: "17.0"
  createIntermediateGroups: true
  developmentLanguage: zh-Hans
settings:
  base:
    SWIFT_VERSION: "5.0"
    MARKETING_VERSION: "{C.get('marketingVersion', '1.0.0')}"
    CURRENT_PROJECT_VERSION: "1"
    DEVELOPMENT_TEAM: {C['teamId']}
    CODE_SIGN_STYLE: Automatic
    TARGETED_DEVICE_FAMILY: "1"
    ENABLE_PREVIEWS: YES
targets:
  App:
    type: application
    platform: iOS
    sources:
      - path: App
      - path: Shared
    info:
      path: App/Info.plist
      properties:
        CFBundleDisplayName: {name}
        # 系统语言不是中文或英文时（日文、韩文等），权限说明等用英文
        CFBundleDevelopmentRegion: en
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        UILaunchScreen:
          UIColorName: LaunchPaper
        UISupportedInterfaceOrientations:
          - UIInterfaceOrientationPortrait
        UIRequiresFullScreen: true
        UIFileSharingEnabled: true
        LSSupportsOpeningDocumentsInPlace: true
        CFBundleURLTypes:
          - CFBundleURLName: {C['bundleId']}
            CFBundleURLSchemes: [{C['urlScheme']}]
        ITSAppUsesNonExemptEncryption: false
        # 卡点：悬浮时钟（系统画中画）在后台要继续走；灵动岛用实时活动
        UIBackgroundModes:
          - audio
        NSSupportsLiveActivities: true
        NSFaceIDUsageDescription: {perm.get('faceId', '')}
        NSPhotoLibraryUsageDescription: {perm.get('photos', '')}
        NSCameraUsageDescription: {perm.get('camera', '')}
        NSCalendarsFullAccessUsageDescription: {perm.get('calendars', '')}
        UIAppFonts:{fontlines}
    entitlements:
      path: App/App.entitlements
      properties:
        com.apple.security.application-groups:
          - {C['appGroup']}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {C['bundleId']}
        PRODUCT_NAME: App
        TARGETED_DEVICE_FAMILY: "1"   # 只支持 iPhone（不用提供 iPad 截图）
        ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon
        ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME: AccentColor{chr(10) + '        ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES: ' + ' '.join(alt) + chr(10) + '        ASSETCATALOG_COMPILER_INCLUDE_ALL_APPICON_ASSETS: YES' if alt else ''}
      configs:
        Release:
          CODE_SIGN_STYLE: Manual
          CODE_SIGN_IDENTITY: Apple Distribution
          PROVISIONING_PROFILE_SPECIFIER: AppStore {C['bundleId']}
    dependencies:
      - target: AppWidget
  AppWidget:
    type: app-extension
    platform: iOS
    sources:
      - path: Widget
      - path: Shared
    info:
      path: Widget/Info.plist
      properties:
        CFBundleDisplayName: {name}
        CFBundleShortVersionString: $(MARKETING_VERSION)
        CFBundleVersion: $(CURRENT_PROJECT_VERSION)
        NSExtension:
          NSExtensionPointIdentifier: com.apple.widgetkit-extension
    entitlements:
      path: Widget/AppWidget.entitlements
      properties:
        com.apple.security.application-groups:
          - {C['appGroup']}
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: {C['bundleId']}.widget
        TARGETED_DEVICE_FAMILY: "1"
        SKIP_INSTALL: YES
      configs:
        Release:
          CODE_SIGN_STYLE: Manual
          CODE_SIGN_IDENTITY: Apple Distribution
          PROVISIONING_PROFILE_SPECIFIER: AppStore {C['bundleId']}.widget
''')

# ---------- InfoPlist.strings ----------
def ip(lang, d):
    return ''.join(f'"{k}" = "{sw(v)}";\n' for k, v in d.items())
w('iOS/App/Localized/zh-Hans.lproj/InfoPlist.strings', ip('zh-Hans', {"CFBundleDisplayName": name, "NSCalendarsFullAccessUsageDescription": perm.get('calendars', ''), "NSFaceIDUsageDescription": perm.get('faceId', ''), "NSPhotoLibraryUsageDescription": perm.get('photos', ''), "NSCameraUsageDescription": perm.get('camera', '')}))
w('iOS/App/Localized/zh-Hant.lproj/InfoPlist.strings', ip('zh-Hant', {"CFBundleDisplayName": nameHant, "NSCalendarsFullAccessUsageDescription": hant(perm.get('calendars', '')), "NSFaceIDUsageDescription": hant(perm.get('faceId', '')), "NSPhotoLibraryUsageDescription": hant(perm.get('photos', '')), "NSCameraUsageDescription": hant(perm.get('camera', ''))}))
w('iOS/App/Localized/en.lproj/InfoPlist.strings', ip('en', {"CFBundleDisplayName": nameEn, "NSCalendarsFullAccessUsageDescription": perm.get('calendarsEn', ''), "NSFaceIDUsageDescription": perm.get('faceIdEn', ''), "NSPhotoLibraryUsageDescription": perm.get('photosEn', ''), "NSCameraUsageDescription": perm.get('cameraEn', '')}))
for lang, n in (('zh-Hans', name), ('zh-Hant', nameHant), ('en', nameEn)):
    w(f'iOS/Widget/Localized/{lang}.lproj/InfoPlist.strings', ip(lang, {"CFBundleDisplayName": n}))

# ---------- 隐私政策 / 用户协议 ----------
T = lambda f: open(os.path.join(ROOT, 'tools/templates', f), encoding='utf8').read().strip()
def fill(t, lang):
    return (t.replace('{NAME_EN}', nameEn).replace('{NAME}', nameHant if lang == 'hant' else name)
             .replace('{DEV}', C.get('developer', '')).replace('{DATE_EN}', DATE_EN).replace('{DATE}', DATE))
legal = {
    'privacyZH': fill(T('privacy.zh.md'), 'zh'), 'termsZH': fill(T('terms.zh.md'), 'zh'),
    'privacyEN': fill(T('privacy.en.md'), 'en'), 'termsEN': fill(T('terms.en.md'), 'en'),
}
legal['privacyHant'] = hant(fill(T('privacy.zh.md'), 'hant'))
legal['termsHant'] = hant(fill(T('terms.zh.md'), 'hant'))
body = ''.join(f'\n    static let {k} = """\n{v.replace(chr(92), chr(92) * 2)}\n"""\n' for k, v in legal.items())
w('iOS/App/LegalText.swift', f'''import Foundation

/// App 内的隐私政策、用户协议。由 tools/render.py 根据 tools/templates/*.md 生成，要改内容请改模板。
enum LegalText {{
    static var privacy: String {{ L10n.lang == "en" ? privacyEN : L10n.lang == "zh-Hant" ? privacyHant : privacyZH }}
    static var terms: String {{ L10n.lang == "en" ? termsEN : L10n.lang == "zh-Hant" ? termsHant : termsZH }}
{body}}}
''')

# ---------- 网页配置 ----------
webcfg = {k: C.get(k) for k in ('slug', 'name', 'nameEn', 'icp', 'feedbackForm', 'pagesBase', 'developer')}
webcfg['nameHant'] = nameHant
webcfg['vip'] = bool(vip.get('enabled'))
webcfg['altIcons'] = alt
webcfg['vipPrices'] = {k: {'cny': vip.get(k, {}).get('cny', ''), 'usd': vip.get(k, {}).get('usd', '')} for k in ('year', 'month', 'life')}
webcfg['appStoreId'] = C.get('appStoreId', '')
w('iOS/App/Web/app-config.js', '/* 由 tools/render.py 根据 app.json 生成，不要手改 */\nwindow.APP=' + json.dumps(webcfg, ensure_ascii=False, indent=1) + ';\n')

# ---------- 签名准备 ----------
setup_p = os.path.join(ROOT, 'ci/setup.json')
old = json.load(open(setup_p)) if os.path.exists(setup_p) else {}
old.update({"bundleId": C['bundleId'], "name": nameEn, "profilePrefix": "AppStore", "certificateId": C.get("certificateId", "")})
old.setdefault("createCertificate", False); old.setdefault("profiles", False); old.setdefault("run", 1)
w('ci/setup.json', json.dumps(old, ensure_ascii=False, indent=1) + '\n')

# ---------- 网站：支持页 / 隐私政策 / 用户协议（三种语言） ----------
CSS = '''<style>:root{color-scheme:light dark}body{margin:0;background:#FBF8F2;color:#3E3532;font:16px/1.75 -apple-system,"PingFang SC","PingFang TC",sans-serif}main{max-width:720px;margin:0 auto;padding:32px 20px 60px}h1{font-size:24px}h2{font-size:18px;margin-top:28px}a{color:#C97A22}.lang{font-size:13px;color:#9A9084}
@media (prefers-color-scheme:dark){body{background:#1B1B1A;color:#ECE6DA}}</style>'''
LANGS = [('zh-CN', '', '简体中文'), ('zh-Hant', 'zh-Hant/', '繁體中文'), ('en', 'en/', 'English')]
def md(t):
    out = []; first = True
    for p in t.split('\n'):
        p = p.strip()
        if not p: continue
        m = re.fullmatch(r'\*\*(.+)\*\*', p)
        if m: out.append(('<h1>' if first else '<h2>') + html.escape(m.group(1)) + ('</h1>' if first else '</h2>')); first = False; continue
        out.append('<p>' + re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', html.escape(p)) + '</p>')
    return '\n'.join(out)
def page(lang, prefix, title, inner, fname):
    up = '../' if prefix else ''
    sw_ = ' · '.join(f'<a href="{up}{p}{fname}">{n}</a>' for l, p, n in LANGS)
    nm = {'zh-CN': (name, '支持', '隐私政策', '用户协议'), 'zh-Hant': (nameHant, '支援', '隱私權政策', '使用者條款'), 'en': (nameEn, 'Support', 'Privacy Policy', 'Terms of Use')}[lang]
    icp = (' · ' + C['icp']) if C.get('icp') else ''
    foot = f'<p style="margin-top:40px;color:#9A9084;font-size:13px">{nm[0]} · <a href="index.html">{nm[1]}</a> · <a href="privacy.html">{nm[2]}</a> · <a href="terms.html">{nm[3]}</a>{icp}</p>'
    return f'<!doctype html><html lang="{lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>{html.escape(title)}</title>\n{CSS}</head><body><main>\n<p class="lang">{sw_}</p>\n{inner}\n{foot}</main></body></html>'
fb = C.get('feedbackForm') or ''
sup = {
 'zh-CN': f'<h1>{name} · 帮助与支持</h1>\n<p>{html.escape(C.get("subtitle", ""))}</p>\n<h2>常见问题</h2>\n<p><b>数据保存在哪里？</b><br>全部保存在你的手机上，我们没有服务器。可以在 App 里导出备份。</p>\n<p><b>要付费吗？</b><br>全部功能免费，没有广告。</p>\n<p><b>为什么和抢购页面上的倒计时不一样？</b><br>抢购页面的倒计时是手机自己算的，可能差 1 秒左右。卡点对齐平台的服务器时间，选对平台后看卡点的时间就行。对不上时界面会写明，这时显示的是手机时间。</p>\n<p><b>会替我抢吗？</b><br>不会。卡点只帮你看准时间，下单要你自己点。</p>\n<h2>联系我们</h2>\n<p>在 App 里点「意见反馈」' + (f'，或直接打开 <a href="{fb}">反馈问卷</a>' if fb else '') + '，我们会尽快回复。</p>',
 'en': f'<h1>{nameEn} · Help &amp; Support</h1>\n<h2>FAQ</h2>\n<p><b>Where is my data stored?</b><br>Everything stays on your phone; we have no servers. You can export a backup in the app.</p>\n<p><b>Does it cost anything?</b><br>All features are free, with no ads.</p>\n<p><b>Why does it differ from the countdown on the sale page?</b><br>The sale page’s countdown is calculated by your phone and can be off by about a second. {nameEn} syncs with the platform’s server, so once you pick the right platform, go by {nameEn}. If it can’t sync, the screen says so and shows your phone’s time.</p>\n<p><b>Will it buy for me?</b><br>No. {nameEn} only helps you time it; you place the order yourself.</p>\n<h2>Contact us</h2>\n<p>Tap “Feedback” in the app' + (f', or open the <a href="{fb}">feedback form</a>' if fb else '') + '. We’ll get back to you soon.</p>',
}
sup['zh-Hant'] = hant(sup['zh-CN'])
S = f"site/{C['slug']}/"
for lang, prefix, _ in LANGS:
    k = {'zh-CN': 'ZH', 'zh-Hant': 'Hant', 'en': 'EN'}[lang]
    w(S + prefix + 'index.html', page(lang, prefix, {'zh-CN': name + ' 帮助与支持', 'zh-Hant': nameHant + ' 幫助與支援', 'en': nameEn + ' Help & Support'}[lang], sup[lang], 'index.html'))
    for d in ('privacy', 'terms'):
        t = legal[d + k]
        w(S + prefix + d + '.html', page(lang, prefix, re.match(r'\*\*(.+?)\*\*', t).group(1), md(t), d + '.html'))
print('done. 记得：site/%s/ 复制到 github.io 仓库发布；改了 project.yml 相关的身份要重新跑签名准备（ci/setup.json）。' % C['slug'])
