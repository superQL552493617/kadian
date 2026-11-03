import SwiftUI
import WebKit
import UIKit
import LocalAuthentication
import WidgetKit
import UserNotifications
import Security
import StoreKit

// MARK: - 网页界面 + 原生能力
// 整个界面是 App/Web/index.html（一个网页文件），原生只负责网页做不到的事：
// 存储、震动、音效、分享导出、意见反馈、面容 ID、通知提醒、桌面小组件、会员内购、换图标、开屏页。
// 网页通过 window.webkit.messageHandlers.native.postMessage({cmd:...}) 调用，命令见 WebBridge.userContentController。

/// 用户 ID：8 位数字，第一次打开时生成，存在钥匙串里（开了 iCloud 钥匙串会跟着 Apple ID 同步）
enum UserID {
    private static var service: String { AppConfig.bundleId + ".uid" }
    static let value: String = {
        if let s = read(), !s.isEmpty { return s }
        let n = String(Int.random(in: 10_000_000...99_999_999))
        write(n)
        return n
    }()
    private static func base() -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: "uid"]
    }
    private static func read() -> String? {
        var q = base()
        q[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &out) == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
    private static func write(_ s: String) {
        var a = base()
        a[kSecAttrSynchronizable as String] = true
        a[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        a[kSecValueData as String] = Data(s.utf8)
        if SecItemAdd(a as CFDictionary, nil) != errSecSuccess {
            a[kSecAttrSynchronizable as String] = false
            SecItemAdd(a as CFDictionary, nil)
        }
    }
}

/// 测试包（Xcode 调试、TestFlight）：默认当作会员，方便测会员功能；摇一摇可以关掉，用来测购买流程
enum TestMode {
    static var isTestBuild: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }
    static let vipKey = "testVIP"
    static var vip: Bool {
        guard isTestBuild else { return false }
        let d = UserDefaults.standard
        return d.object(forKey: vipKey) == nil ? true : d.bool(forKey: vipKey)
    }
    static func setVip(_ on: Bool) { UserDefaults.standard.set(on, forKey: vipKey) }
}

enum DeviceInfo {
    static var model: String {
        var sys = utsname()
        uname(&sys)
        let mirror = Mirror(reflecting: sys.machine)
        return mirror.children.reduce("") { id, el in
            guard let v = el.value as? Int8, v != 0 else { return id }
            return id + String(UnicodeScalar(UInt8(v)))
        }
    }
    static var osVersion: String { UIDevice.current.systemVersion }
    static var appVersion: String { (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0" }
    static var build: String { (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1" }
}

// MARK: - 开屏页（只在冷启动时出现，卡点取消最短时长（需求说明 3.7），网页好了就消失）

struct SplashView: View {
    var body: some View {
        ZStack {
            Color("LaunchPaper").ignoresSafeArea()
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // 有插画时放 splash_art（浅色 / 深色两张），没有就只显示一句话
                if UIImage(named: "splash_art") != nil {
                    Image(L10n.lang == "en" && UIImage(named: "splash_art_en") != nil ? "splash_art_en" : "splash_art")
                        .resizable().scaledToFit().frame(maxWidth: 330, maxHeight: 560).padding(.horizontal, 30)
                        .accessibilityLabel(L10n.lang == "en" ? AppConfig.splashQuoteEn : AppConfig.splashQuote)
                } else {
                    Text(L10n.lang == "en" ? AppConfig.splashQuoteEn : L10n.lang == "zh-Hant" ? AppConfig.splashQuoteHant : AppConfig.splashQuote)
                        .font(.system(size: 24, weight: .medium, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color(red: 0.23, green: 0.21, blue: 0.19))
                        .padding(.horizontal, 40)
                }
                Spacer(minLength: 0)
                Text(AppConfig.displayName)
                    .font(.system(size: 12, weight: .medium, design: .serif)).tracking(4)
                    .foregroundStyle(Color(red: 0.6, green: 0.565, blue: 0.518))
                    .padding(.bottom, 24)
            }
        }
    }
}

struct WebRootView: View {
    @EnvironmentObject var purchases: Purchases
    @StateObject private var bridge = WebBridge()
    @Environment(\.scenePhase) private var phase
    @State private var splashGone = false
    @State private var minShown = false
    @State private var pendingRoute: String?
    @State private var askTest = false

    /// 从小组件、通知、网址打开某个页面：网页准备好、开屏结束后交给网页（网页会先等密码锁验证）
    private func route(_ r: String) {
        if splashGone && bridge.ready {
            bridge.webView?.evaluateJavaScript("window.__xmRoute&&window.__xmRoute('\(r)')", completionHandler: nil)
        } else { pendingRoute = r }
    }

    private func endSplash() {
        guard !splashGone else { return }
        splashGone = true
        bridge.webView?.evaluateJavaScript("window.__XM_SPLASH_DONE=true;window.__xmSplashDone&&window.__xmSplashDone()", completionHandler: nil)
        if let r = pendingRoute { pendingRoute = nil; DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { route(r) } }
    }

    var body: some View {
        WebContainer(bridge: bridge)
            .ignoresSafeArea()
            .background(Color(UIColor.systemBackground).ignoresSafeArea())
            .overlay {
                if !splashGone {
                    SplashView().contentShape(Rectangle())
                        .onTapGesture { if bridge.ready { endSplash() } }
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: splashGone)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { minShown = true; if bridge.ready { endSplash() } }
            }
            .onChange(of: bridge.ready) { _, r in if r && minShown { endSplash() } }
            // <scheme>://<页面>，比如 starter://note（小组件用）
            .onOpenURL { url in if let h = url.host, !h.isEmpty { route(h) } }
            .onReceive(NotificationCenter.default.publisher(for: .openRoute)) { _ in
                if let r = WebBridge.pendingNotificationRoute { WebBridge.pendingNotificationRoute = nil; route(r) }
            }
            .sheet(item: $bridge.feedback) { f in
                NavigationStack {
                    WebFeedbackView(url: f.url, fill: f.fill)
                        .navigationTitle(L("意见反馈")).navigationBarTitleDisplayMode(.inline)
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button(L("完成")) { bridge.feedback = nil } } }
                }
            }
            .sheet(isPresented: Binding(get: { bridge.doc != nil }, set: { if !$0 { bridge.doc = nil } })) {
                NavigationStack {
                    DocView(title: L(bridge.doc == "privacy" ? "隐私政策" : "用户协议"), text: bridge.doc == "privacy" ? LegalText.privacy : LegalText.terms)
                        .toolbar { ToolbarItem(placement: .topBarLeading) { Button(L("关闭")) { bridge.doc = nil } } }
                }
            }
            .onAppear { bridge.purchases = purchases }
            .onChange(of: purchases.plan) { _, _ in bridge.syncVip() }
            .onChange(of: purchases.loaded) { _, _ in bridge.syncVip() }
            .onChange(of: phase) { _, p in
                if p == .active { bridge.deliverWidgetTaps() }
                if p == .background { bridge.flush { WidgetCenter.shared.reloadAllTimelines() } }
            }
            // 测试包：摇一摇打开测试菜单（复制对时和读链接的记录，发给开发）
            .onReceive(NotificationCenter.default.publisher(for: .deviceDidShake)) { _ in if TestMode.isTestBuild { askTest = true } }
            .confirmationDialog("测试菜单", isPresented: $askTest, titleVisibility: .visible) {
                Button("测一遍所有时间源，复制结果") {
                    Task {
                        for src in TimeSync.allSources { _ = await TimeSync.sync(src) }
                        UIPasteboard.general.string = Diag.text
                    }
                }
                Button("复制测试记录") { UIPasteboard.general.string = Diag.text }
                Button("读链接测试") { UIApplication.topViewController()?.present(UIHostingController(rootView: LinkTestView()), animated: true) }
                Button("取消", role: .cancel) {}
            } message: { Text("这个菜单只在测试包里出现。") }
    }
}

struct FeedbackFields: Identifiable {
    let id = UUID()
    let url: URL
    let fill: String
}

// MARK: - 文本页面（隐私政策、用户协议）

struct DocView: View {
    let title: String
    let text: String
    var body: some View {
        ScrollView {
            Text(LocalizedStringKey(text))
                .font(.system(size: 15)).lineSpacing(5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - WKWebView 容器

struct WebContainer: UIViewRepresentable {
    @ObservedObject var bridge: WebBridge

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.setURLSchemeHandler(LocalSchemeHandler(), forURLScheme: LocalSchemeHandler.scheme)
        cfg.allowsInlineMediaPlayback = true
        cfg.mediaTypesRequiringUserActionForPlayback = []
        let ucc = cfg.userContentController
        ucc.addScriptMessageHandler(bridge, contentWorld: .page, name: "native")
        ucc.addUserScript(WKUserScript(source: WebBridge.startScript, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        ucc.addUserScript(WKUserScript(source: WebBridge.endScript, injectionTime: .atDocumentEnd, forMainFrameOnly: true))
        let wv = WKWebView(frame: .zero, configuration: cfg)
        wv.isOpaque = false
        wv.backgroundColor = .systemBackground
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.scrollView.bounces = true
        wv.scrollView.alwaysBounceVertical = true
        wv.scrollView.alwaysBounceHorizontal = false
        wv.underPageBackgroundColor = .systemBackground
        wv.allowsLinkPreview = false
        wv.navigationDelegate = bridge
        wv.uiDelegate = bridge
        #if DEBUG
        if #available(iOS 16.4, *) { wv.isInspectable = true }
        #endif
        bridge.webView = wv
        wv.load(URLRequest(url: URL(string: "\(LocalSchemeHandler.scheme)://app/index.html")!))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - 本地页面服务（自定义网址，让网页有固定来源，存储更可靠）

final class LocalSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "app-local"

    func webView(_ webView: WKWebView, start task: WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        var name = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if name.isEmpty { name = "index.html" }
        let base = (name as NSString).deletingPathExtension, ext = (name as NSString).pathExtension
        // 资源打包时会放到同一层（比如 fonts/xm_kai.ttf 实际在包的根目录）
        let flat = ((name as NSString).lastPathComponent as NSString).deletingPathExtension
        guard let file = Bundle.main.url(forResource: base, withExtension: ext) ?? Bundle.main.url(forResource: flat, withExtension: ext),
              let data = try? Data(contentsOf: file) else {
            task.didReceive(HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: [:])!)
            task.didFinish(); return
        }
        let mime: String
        switch ext.lowercased() {
        case "html": mime = "text/html; charset=utf-8"
        case "js": mime = "text/javascript"
        case "css": mime = "text/css"
        case "png": mime = "image/png"
        case "jpg", "jpeg": mime = "image/jpeg"
        case "svg": mime = "image/svg+xml"
        case "json": mime = "application/json"
        case "ttf": mime = "font/ttf"
        case "otf": mime = "font/otf"
        default: mime = "application/octet-stream"
        }
        task.didReceive(HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": mime, "Content-Length": "\(data.count)", "Cache-Control": ext == "ttf" ? "max-age=31536000" : "no-store"])!)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: WKURLSchemeTask) {}
}

// MARK: - 网页 ↔ 原生

@MainActor
final class WebBridge: NSObject, ObservableObject, WKScriptMessageHandlerWithReply, WKNavigationDelegate, WKUIDelegate {
    weak var webView: WKWebView?
    @Published var feedback: FeedbackFields?
    @Published var ready = false
    @Published var doc: String?
    weak var purchases: Purchases?
    static var pendingNotificationRoute: String?
    private var postTask: Task<Void, Never>?

    /// 页面加载前注入：环境信息、存储、触感、剪贴板、分享
    static var startScript: String {
        """
        (function(){
          var N=function(m){return window.webkit.messageHandlers.native.postMessage(m)};
          window.__XM_NATIVE__=true;
          window.__XM_VER__={v:'\(DeviceInfo.appVersion)',b:'\(DeviceInfo.build)'};
          window.__XM_UID__='\(UserID.value)';
          window.__XM_TEST__=\(TestMode.isTestBuild ? "true" : "false");
          window.__XM_SYSLANG__='\(Locale.preferredLanguages.first ?? "zh-Hans")';
          window.__XM_LANGPREF__='\(L10n.pref)';
          try{Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:function(t){return N({cmd:'copy',text:String(t)}).then(function(){})},readText:function(){return N({cmd:'paste'}).then(function(v){return v||''})}}})}catch(e){}
          window.storage={
            get:function(k){return N({cmd:'load'}).then(function(v){return v?{value:v}:null})},
            set:function(k,v){return N({cmd:'save',value:v}).then(function(){return true})}
          };
          try{Object.defineProperty(navigator,'vibrate',{configurable:true,value:function(p){N({cmd:'haptic',kind:Array.isArray(p)?'success':(p>=20?'medium':'light')}).catch(function(){});return true}})}catch(e){}
          var toB64=function(f){return new Promise(function(res,rej){var r=new FileReader();r.onload=function(){res(String(r.result).split(',')[1]||'')};r.onerror=rej;r.readAsDataURL(f)})};
          try{navigator.canShare=function(d){return !!(d&&((d.files&&d.files.length)||d.text||d.url))}}catch(e){}
          try{navigator.share=function(d){d=d||{};return Promise.all((d.files||[]).map(function(f){return toB64(f).then(function(b){return {name:f.name||'file',mime:f.type||'',b64:b}})}))
            .then(function(files){return N({cmd:'share',files:files,text:d.text||'',url:d.url||'',title:d.title||''})})
            .then(function(r){if(r!=='shared'){var e=new Error('cancel');e.name='AbortError';throw e}})}}catch(e){}
        })();
        """
    }

    /// 页面加载后注入：面容 ID 走系统验证
    static let endScript = """
    (function(){
      var N=function(m){return window.webkit.messageHandlers.native.postMessage(m)};
      if(typeof window.faceScan==='function'){
        window.faceScan=function(onOk,label,onFail,bio){window.__XM_FACE_BUSY=true;var done=function(){setTimeout(function(){window.__XM_FACE_BUSY=false},1500)};
          N({cmd:'faceid',label:(window.T?T(label||''):(label||'')),bio:!!bio}).then(function(ok){done();if(ok===true){onOk&&onOk()}else{onFail&&onFail(ok)}}).catch(function(){done();onFail&&onFail()})};
      }
    })();
    """

    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage,
                               replyHandler: @escaping (Any?, String?) -> Void) {
        guard let body = message.body as? [String: Any], let cmd = body["cmd"] as? String else { replyHandler(nil, nil); return }
        switch cmd {
        case "load":
            replyHandler(Persistence.loadRaw(), nil)
        case "save":
            if let v = body["value"] as? String { Persistence.saveRaw(v); schedulePostSave() }
            replyHandler(true, nil)
        case "haptic":
            switch body["kind"] as? String {
            case "success": UINotificationFeedbackGenerator().notificationOccurred(.success)
            case "medium": UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            default: UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.85)
            }
            replyHandler(true, nil)
        case "sfx":
            // 完成音效：App/Sounds/sfx_<n>.wav（跟随静音键，和别的 App 的音乐混音）
            if let n = (body["n"] as? NSNumber)?.intValue { SFX.play(n) }
            replyHandler(true, nil)
        case "tone":
            if let n = (body["n"] as? NSNumber)?.intValue { SFX.playTone(n) } else { SFX.stopTone() }
            replyHandler(true, nil)
        case "share":
            share(body) { replyHandler($0, nil) }
        case "copy":
            UIPasteboard.general.string = body["text"] as? String ?? ""
            replyHandler(true, nil)
        case "open":
            guard let s = body["url"] as? String, let u = URL(string: s) else { replyHandler(false, nil); return }
            UIApplication.shared.open(u, options: [:]) { ok in replyHandler(ok, nil) }
        case "beep":
            Beep.play(end: (body["end"] as? Bool) == true)
            replyHandler(true, nil)
        case "calendar":
            CalendarRead.upcoming { replyHandler($0, nil) }
        case "openapp":
            AppLink.open(body["url"] as? String ?? "") { replyHandler($0, nil) }
        case "linktest":
            guard let top = UIApplication.topViewController(), TestMode.isTestBuild else { replyHandler(false, nil); return }
            top.present(UIHostingController(rootView: LinkTestView()), animated: true)
            replyHandler(true, nil)
        case "paste":
            // 系统会弹「想从某 App 粘贴」的提示，所以只在用户点了粘贴或「使用」后才读
            replyHandler(UIPasteboard.general.string ?? "", nil)
        case "clipcheck":
            // 只问系统「像不像网址」，不读内容，不弹提示
            UIPasteboard.general.detectPatterns(for: [.probableWebURL]) { res in
                let has: Bool
                if case .success(let set) = res { has = set.contains(.probableWebURL) } else { has = false }
                DispatchQueue.main.async { replyHandler(has, nil) }
            }
        case "timesync":
            let src = body["src"] as? String ?? ""
            Task { replyHandler(await TimeSync.sync(src), nil) }
        case "linkinfo":
            LinkReader.read(body["url"] as? String ?? "") { replyHandler($0, nil) }
        case "scan":
            guard let top = UIApplication.topViewController() else { replyHandler(["cancel": true], nil); return }
            let vc = QRScannerController()
            vc.modalPresentationStyle = .fullScreen
            vc.onDone = { replyHandler($0, nil) }
            top.present(vc, animated: true)
        case "timeinfo":
            PipClock.shared.setTimeInfo(body)
            replyHandler(true, nil)
        case "pipconfig":
            PipClock.shared.setConfig(body)
            replyHandler(true, nil)
        case "pip":
            PipClock.shared.setTimeInfo(body)
            PipClock.shared.setConfig(body)
            if (body["on"] as? Bool) == true {
                PipClock.shared.onLost = { [weak self] in
                    self?.webView?.evaluateJavaScript("window.__kdPipLost&&__kdPipLost()", completionHandler: nil)
                }
                PipClock.shared.start { replyHandler($0, nil) }
            } else {
                PipClock.shared.stop()
                replyHandler(true, nil)
            }
        case "pipstate":
            replyHandler(PipClock.shared.active, nil)
        case "live":
            let items = body["items"] as? [[String: Any]] ?? []
            Task { replyHandler(await LiveCountdown.apply(items), nil) }
        case "feedback":
            // 私密反馈问卷（腾讯问卷等）：页面里标题含「用户 ID」的填空题自动填上
            if let s = body["url"] as? String, let u = URL(string: s) { feedback = FeedbackFields(url: u, fill: body["fill"] as? String ?? UserID.value) }
            replyHandler(true, nil)
        case "doc":
            doc = (body["doc"] as? String) == "privacy" ? "privacy" : "terms"
            replyHandler(true, nil)
        case "appicon":
            // 换桌面图标：空字符串 = 默认图标，其他 = Assets 里的备用图标名（project.yml 里也要登记）
            let n = body["name"] as? String ?? ""
            let target: String? = n.isEmpty ? nil : n
            guard UIApplication.shared.supportsAlternateIcons else { replyHandler(false, nil); return }
            if UIApplication.shared.alternateIconName == target { replyHandler(true, nil); return }
            UIApplication.shared.setAlternateIconName(target) { err in DispatchQueue.main.async { replyHandler(err == nil, nil) } }
        case "faceid":
            faceID(body) { replyHandler($0, nil) }
        case "update":
            Task {
                var r: [String: Any] = [:]
                if let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(AppConfig.bundleId)&country=\(AppConfig.lookupCountry)&t=\(Int(Date().timeIntervalSince1970))"),
                   let (d, _) = try? await URLSession.shared.data(from: url),
                   let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any],
                   let first = (j["results"] as? [[String: Any]])?.first {
                    r["latest"] = first["version"] as? String ?? ""
                    r["notes"] = first["releaseNotes"] as? String ?? ""
                    r["id"] = first["trackId"] ?? ""
                }
                replyHandler(r, nil)
            }
        case "vip":
            vip(body) { replyHandler($0, nil) }
        case "notify":
            // 网页算好要提醒的时间，原生负责排进系统通知（最多 60 条）
            let items = body["items"] as? [[String: Any]] ?? []
            Task {
                if (body["ask"] as? Bool) == true { _ = await Notifier.shared.requestPermission() }
                await Notifier.shared.schedule(items)
                replyHandler(await Notifier.shared.allowed(), nil)
            }
        case "widget":
            // 网页把小组件要显示的内容整理好发过来
            if let w = body["data"] { Persistence.saveWidget(w); WidgetCenter.shared.reloadAllTimelines() }
            replyHandler(true, nil)
        case "lang":
            L10n.reset()
            WidgetCenter.shared.reloadAllTimelines()
            replyHandler(true, nil)
        default:
            replyHandler(nil, nil)
        }
    }

    private func faceID(_ body: [String: Any], done: @escaping (Any) -> Void) {
        let ctx = LAContext()
        var err: NSError?
        // bio=true：只用面容 ID（认不出来由网页数次数，再换成网页里的密码键盘）；false：允许用手机密码验证（忘记密码时）
        let bio = body["bio"] as? Bool ?? false
        let policy: LAPolicy = bio ? .deviceOwnerAuthenticationWithBiometrics : .deviceOwnerAuthentication
        if bio { ctx.localizedFallbackTitle = "" }
        guard ctx.canEvaluatePolicy(policy, error: &err) else { done(false); return }
        let reason = (body["label"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? L("解锁") + AppConfig.displayName
        ctx.evaluatePolicy(policy, localizedReason: reason) { ok, err in
            // true 成功；"retry" 系统取消（App 还没回到前台等），网页会自动再试；"cancel" 用户取消；false 没认出来
            var r: Any = ok
            if !ok, let e = err as? LAError {
                switch e.code {
                case .appCancel, .systemCancel, .notInteractive: r = "retry"
                case .userCancel, .userFallback: r = "cancel"
                default: r = false
                }
            }
            DispatchQueue.main.async { done(r) }
        }
    }

    private func vip(_ body: [String: Any], done: @escaping (Any) -> Void) {
        let op = body["op"] as? String ?? "info"
        guard let p = purchases else { done(["plan": "free"]); return }
        Task { @MainActor in
            switch op {
            case "buy": _ = await p.buy(kind: body["kind"] as? String ?? "year")
            case "restore": await p.restore()
            default: if p.products.isEmpty { await p.loadProducts() }
            }
            var r = p.info(); r["msg"] = p.message ?? ""; p.message = nil
            done(r)
        }
    }

    /// 把 App Store 里的会员状态告诉网页（网页里的会员功能以它为准）
    func syncVip() {
        guard let p = purchases, p.loaded, ready else { return }
        webView?.evaluateJavaScript("window.__xmVipSync&&__xmVipSync({plan:'\(p.plan)'})")
    }

    /// 在桌面小组件上点过的项目，交给网页记录（小组件不能直接改网页的数据）
    func deliverWidgetTaps() {
        guard ready else { return }
        let taps = Persistence.takeWidgetTaps()
        guard !taps.isEmpty, let d = try? JSONSerialization.data(withJSONObject: taps), let s = String(data: d, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.__xmWidgetTaps&&__xmWidgetTaps(\(s))")
    }

    private func schedulePostSave() {
        postTask?.cancel()
        postTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    /// 切到后台前，让网页把最后的修改写完
    func flush(_ done: @escaping () -> Void) {
        webView?.evaluateJavaScript("try{typeof saveNow==='function'&&saveNow()}catch(e){}") { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { done() }
        }
    }

    private func share(_ body: [String: Any], done: @escaping (String) -> Void) {
        var items: [Any] = []
        for f in (body["files"] as? [[String: Any]]) ?? [] {
            guard let b64 = f["b64"] as? String, let data = Data(base64Encoded: b64) else { continue }
            let name = (f["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "file"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
            if (try? data.write(to: url, options: .atomic)) != nil { items.append(url) }
        }
        if items.isEmpty {
            if let t = body["text"] as? String, !t.isEmpty { items.append(t) }
            if let u = body["url"] as? String, let url = URL(string: u), !u.isEmpty { items.append(url) }
        }
        guard !items.isEmpty, let top = UIApplication.topViewController() else { done("cancel"); return }
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in done(completed ? "shared" : "cancel") }
        if let pop = vc.popoverPresentationController { pop.sourceView = top.view; pop.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.maxY - 40, width: 1, height: 1) }
        top.present(vc, animated: true)
    }

    // 外部链接用系统浏览器打开，本地页面留在 App 里
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url else { decisionHandler(.cancel); return }
        if url.scheme == LocalSchemeHandler.scheme || url.scheme == "about" || url.scheme == "blob" || url.scheme == "data" { decisionHandler(.allow); return }
        if action.navigationType == .linkActivated || action.targetFrame == nil || action.targetFrame?.isMainFrame == true {
            UIApplication.shared.open(url); decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        if let url = action.request.url { UIApplication.shared.open(url) }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.ready = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.syncVip()
            self?.deliverWidgetTaps()
        }
        // 截图测试用：启动参数 -shotJS <base64 脚本>，页面加载后执行
        if let b = UserDefaults.standard.string(forKey: "shotJS"), let d = Data(base64Encoded: b), let js = String(data: d, encoding: .utf8) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in self?.webView?.evaluateJavaScript(js) }
        }
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { webView.reload() }

    // 网页里的 alert / confirm / prompt
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: L("好的"), style: .default) { _ in completionHandler() })
        guard let top = UIApplication.topViewController() else { completionHandler(); return }
        top.present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let a = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        a.addAction(UIAlertAction(title: L("取消"), style: .cancel) { _ in completionHandler(false) })
        a.addAction(UIAlertAction(title: L("确定"), style: .default) { _ in completionHandler(true) })
        guard let top = UIApplication.topViewController() else { completionHandler(false); return }
        top.present(a, animated: true)
    }

    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
        let a = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        a.addTextField { $0.text = defaultText }
        a.addAction(UIAlertAction(title: L("取消"), style: .cancel) { _ in completionHandler(nil) })
        a.addAction(UIAlertAction(title: L("确定"), style: .default) { _ in completionHandler(a.textFields?.first?.text) })
        guard let top = UIApplication.topViewController() else { completionHandler(nil); return }
        top.present(a, animated: true)
    }
}

// MARK: - 小工具

extension UIApplication {
    static func topViewController() -> UIViewController? {
        let scene = shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first { $0.activationState == .foregroundActive }
            ?? shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        var top = scene?.windows.first { $0.isKeyWindow }?.rootViewController ?? scene?.windows.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
}

extension Notification.Name {
    static let deviceDidShake = Notification.Name("deviceDidShake")
}

extension UIWindow {
    open override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake { NotificationCenter.default.post(name: .deviceDidShake, object: nil) }
        super.motionEnded(motion, with: event)
    }
}
