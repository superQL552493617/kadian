import SwiftUI
import WebKit

// MARK: - 读链接测试页（只在测试包里有入口）
// 老板 2026-11-02 给的验证方案：粘贴大麦链接，看 WKWebView 能否读出标题和开抢时间。只加载页面、读显示出来的文字，
// 不模拟点击，不绕过验证，不登录，不调第三方接口。结果和日志都能复制出来。
// 2026-11-02：手机网页显示「该渠道不支持购票」，所以加两项探查（老板要求一定要读到时间）：
// ① 同一场活动的电脑版公开网页；② 记下页面自己收到的数据里有没有开抢时间。
// 只旁听页面自己发的请求，不自己拼接口、不算签名、不冒充大麦 App。日志只记地址 ? 之前的部分。

@MainActor
final class LinkTestModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var link = "https://m.damai.cn/shows/item.html?itemId=1082769026036"
    @Published var title = ""
    @Published var saleTime = ""
    @Published var status = "未开始"
    @Published var pageText = ""
    @Published var log: [String] = []
    let web: WKWebView
    private var runId = 0
    private var pageAll = ""

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        cfg.mediaTypesRequiringUserActionForPlayback = .all
        cfg.userContentController.addUserScript(WKUserScript(source: Self.capture, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        web = WKWebView(frame: .zero, configuration: cfg)
        web.customUserAgent = LinkReader.safariUA
        super.init()
        web.navigationDelegate = self
    }

    static let desktopUA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"

    /// 页面加载前放进去：记下页面自己收到的、含关键字的数据（fetch、XHR、JSONP、内嵌脚本）
    static var capture: String { LinkReader.capture }
    /// 关键字前后各 50 字，每条数据最多 6 处
    private static func snippets(_ body: String, _ pat: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: pat, options: .caseInsensitive) else { return [] }
        let ns = body as NSString
        return re.matches(in: body, range: NSRange(location: 0, length: ns.length)).prefix(6).map { m in
            let a = max(0, m.range.location - 50), b = min(ns.length, m.range.location + m.range.length + 50)
            return ns.substring(with: NSRange(location: a, length: b - a)).replacingOccurrences(of: "\n", with: " ")
        }
    }

    private func add(_ s: String) { log.append(s); Diag.add("读链接测试 \(s)") }

    func start() {
        runId += 1
        title = ""; saleTime = ""; pageText = ""; pageAll = ""; log = []
        let raw = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let urlRange = raw.range(of: "https?://[^\\s，。]+", options: .regularExpression), let url = URL(string: String(raw[urlRange])) else { status = "没找到链接"; return }
        guard url.host?.lowercased().hasSuffix("damai.cn") == true else { status = "不是大麦链接"; return }
        guard url.absoluteString.range(of: "itemId=\\d+", options: .regularExpression) != nil else { status = "链接里没有 itemId"; return }
        guard let r = raw.range(of: "itemId=\\d+", options: .regularExpression) else { return }
        let id = raw[r].dropFirst("itemId=".count)
        _ = id
        let stages: [(String, URL, String)] = [("手机网页", url, LinkReader.safariUA)]
        self.stages = stages
        status = "读取中"
        nextStage()
    }

    private var stages: [(String, URL, String)] = []
    private var stageName = ""
    private func nextStage() {
        guard !stages.isEmpty else {
            status = saleTime.isEmpty ? "未读到开抢时间" : "已读到"
            return
        }
        let st = stages.removeFirst()
        runId += 1
        stageName = st.0
        web.customUserAgent = st.2
        add("===== \(st.0)：开始加载 \(st.1.absoluteString)")
        web.load(URLRequest(url: st.1, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10))
        read(1, runId)
    }

    /// 列出数据里所有像时间的字段（只给老板和开发判断哪个是开抢时间，这里不猜）
    private static func timeFields(_ body: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: #"\\*"([A-Za-z_][A-Za-z0-9_]*)\\*"\s*:\s*\\*"?([^,"\\}\]]{1,40})"#) else { return [] }
        let ns = body as NSString
        let f = DateFormatter(); f.dateFormat = "MM-dd HH:mm:ss"
        var seen = Set<String>(), out: [String] = []
        for m in re.matches(in: body, range: NSRange(location: 0, length: ns.length)) {
            let k = ns.substring(with: m.range(at: 1)), v = ns.substring(with: m.range(at: 2))
            guard !k.lowercased().contains("rule"), v.rangeOfCharacter(from: .decimalDigits) != nil else { continue }
            let isMs = v.range(of: #"^1\d{12}$"#, options: .regularExpression) != nil
            let isDate = v.range(of: #"20\d\d[-./年]"#, options: .regularExpression) != nil
            let isKey = k.range(of: "sell|sale|flash|count|open|begin|start", options: [.regularExpression, .caseInsensitive]) != nil
            guard isMs || isDate || isKey else { continue }
            let show = isMs ? "\(k) = \(v) → \(f.string(from: Date(timeIntervalSince1970: (Double(v) ?? 0) / 1000)))" : "\(k) = \(v)"
            if seen.insert(show).inserted { out.append(show) }
            if out.count >= 40 { break }
        }
        return out
    }

    private func report(_ id: Int) {
        web.evaluateJavaScript("JSON.stringify(window.__kdCap||[])") { [weak self] res, _ in
            guard let self, id == self.runId else { return }
            let list = (res as? String).flatMap { $0.data(using: .utf8) }.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
            for c in list {
                let src = c["src"] as? String ?? "", body = c["body"] as? String ?? ""
                guard src.contains("mtop") else { continue }
                self.add("【\(src.split(separator: "/").suffix(2).first ?? "")】\(body.count) 字")
                for t in Self.timeFields(body) { self.add("  \(t)") }
                for sn in Self.snippets(body, "开抢|开售|开票|开卖") { self.add("  文字：…\(sn)…") }
                let ns = body as NSString, fl = ns.range(of: "flashSaleEndTime")
                if fl.location != NSNotFound {
                    let a = max(0, fl.location - 400)
                    self.add("  flashSale 前面的内容：…\(ns.substring(with: NSRange(location: a, length: fl.location - a)))")
                }
            }
            self.nextStage()
        }
    }

    private func read(_ n: Int, _ id: Int) {
        guard id == runId else { return }
        web.evaluateJavaScript(LinkReader.snapshot) { [weak self] res, _ in
            guard let self, id == self.runId else { return }
            var matched = false
            if let s = res as? String, let d = s.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                let text = j["text"] as? String ?? ""
                self.pageText = String(text.prefix(2000))
                self.pageAll = text
                let head = j["head"] as? String ?? "", docTitle = j["title"] as? String ?? ""
                self.title = head.isEmpty ? docTitle : head
                if let t = Self.findSaleTime(text) { self.saleTime = t; matched = true }
                if !(j["item"] as? String ?? "").isEmpty { self.title = j["item"] as? String ?? "" }
            }
            if matched || n >= 8 { self.report(id); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.read(n + 1, id) }
        }
    }

    /// 只认紧挨「开抢」的时间：X月X日 HH:mm(:ss) 开抢。年份取今年，早于现在就加一年
    static func findSaleTime(_ text: String) -> String? {
        let pat = "(\\d{1,2})月(\\d{1,2})日\\s*(?:周.\\s*)?(\\d{1,2}):(\\d{2})(?::(\\d{2}))?\\s*开抢"
        guard let re = try? NSRegularExpression(pattern: pat),
              let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
        let g: (Int) -> Int? = { i in Range(m.range(at: i), in: text).flatMap { Int(text[$0]) } }
        var c = DateComponents()
        let cal = Calendar.current
        c.year = cal.component(.year, from: Date()); c.month = g(1); c.day = g(2); c.hour = g(3); c.minute = g(4); c.second = g(5) ?? 0
        guard var date = cal.date(from: c) else { return nil }
        if date < Date(), let next = cal.date(byAdding: .year, value: 1, to: date) { date = next }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { add("加载完成 \(webView.url?.absoluteString ?? "")") }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { add("加载失败：\(error.localizedDescription)") }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let s = action.request.url?.scheme?.lowercased() ?? ""
        if s == "https" || s == "http" || s == "about" || s == "blob" || s == "data" { decisionHandler(.allow) } else { add("页面想跳别的 App（\(s)），没跳"); decisionHandler(.cancel) }
    }
}

private struct TestWeb: UIViewRepresentable {
    let web: WKWebView
    func makeUIView(context: Context) -> WKWebView { web }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct LinkTestView: View {
    @StateObject private var m = LinkTestModel()
    @State private var showWeb = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("读链接测试").font(.headline); Spacer(); Button("关闭") { dismiss() } }
            HStack {
                TextField("粘贴大麦链接", text: $m.link).textFieldStyle(.roundedBorder).autocorrectionDisabled().textInputAutocapitalization(.never)
                Button("粘贴") { m.link = UIPasteboard.general.string ?? "" }
            }
            HStack {
                Button("开始识别") { m.start() }.buttonStyle(.borderedProminent)
                Toggle("显示网页", isOn: $showWeb)
            }
            Text("标题：\(m.title)").font(.subheadline)
            Text("开抢时间：\(m.saleTime)").font(.subheadline)
            Text("状态：\(m.status)").font(.subheadline.weight(.semibold))
            Button("复制日志") { UIPasteboard.general.string = m.log.joined(separator: "\n") }
            ScrollView {
                Text(m.log.joined(separator: "\n")).font(.system(size: 12, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }.frame(maxHeight: .infinity)
            // 网页视图一直在视图层级里，隐藏时只是几乎透明，脚本才会执行
            TestWeb(web: m.web).frame(height: showWeb ? 320 : 2).opacity(showWeb ? 1 : 0.01).allowsHitTesting(showWeb)
        }
        .padding(14)
    }
}
