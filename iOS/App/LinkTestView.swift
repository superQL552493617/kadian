import SwiftUI
import WebKit

// MARK: - 读链接测试页（只在测试包里有入口）
// 老板 2026-11-02 给的验证方案：粘贴大麦链接，看 WKWebView 能否读出标题和开抢时间。只加载页面、读显示出来的文字，
// 不模拟点击，不绕过验证，不登录，不调第三方接口。结果和日志都能复制出来。

@MainActor
final class LinkTestModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var link = "https://m.damai.cn/shows/item.html?itemId=1082769026036"
    @Published var title = "", saleTime = "", status = "未开始"
    @Published var pageText = ""
    @Published var log: [String] = []
    let web: WKWebView
    private var runId = 0

    override init() {
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        cfg.mediaTypesRequiringUserActionForPlayback = .all
        web = WKWebView(frame: .zero, configuration: cfg)
        web.customUserAgent = LinkReader.safariUA
        super.init()
        web.navigationDelegate = self
    }

    private func add(_ s: String) { log.append(s); Diag.add("读链接测试 \(s)") }

    func start() {
        runId += 1
        title = ""; saleTime = ""; pageText = ""; log = []
        let raw = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let urlRange = raw.range(of: "https?://[^\\s，。]+", options: .regularExpression), let url = URL(string: String(raw[urlRange])) else { status = "没找到链接"; return }
        guard url.host?.lowercased().hasSuffix("damai.cn") == true else { status = "不是大麦链接"; return }
        guard url.absoluteString.range(of: "itemId=\\d+", options: .regularExpression) != nil else { status = "链接里没有 itemId"; return }
        status = "读取中"
        add("开始加载 \(url.absoluteString)")
        web.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10))
        read(1, runId)
    }

    private func read(_ n: Int, _ id: Int) {
        guard id == runId else { return }
        web.evaluateJavaScript(LinkReader.snapshot) { [weak self] res, _ in
            guard let self, id == self.runId else { return }
            var matched = false
            if let s = res as? String, let d = s.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                let text = j["text"] as? String ?? ""
                self.pageText = String(text.prefix(2000))
                let head = j["head"] as? String ?? "", docTitle = j["title"] as? String ?? ""
                self.title = head.isEmpty ? docTitle : head
                if let t = Self.findSaleTime(text) { self.saleTime = t; matched = true }
                self.add("第 \(n) 次读取：标题「\(docTitle)」大字「\(head)」文字 \(text.count) 字，\(matched ? "读到时间 \(self.saleTime)" : "没有时间")")
            } else { self.add("第 \(n) 次读取：页面还没准备好") }
            if matched { self.status = "已读到"; self.runId += 1; return }
            if n >= 10 { self.status = "未读到开抢时间"; self.runId += 1; return }
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
            Button("复制日志和页面文字") { UIPasteboard.general.string = m.log.joined(separator: "\n") + "\n---\n" + m.pageText }
            ScrollView {
                Text(m.log.joined(separator: "\n") + "\n---\n" + m.pageText).font(.system(size: 12, design: .monospaced)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
            }.frame(maxHeight: .infinity)
            // 网页视图一直在视图层级里，隐藏时只是几乎透明，脚本才会执行
            TestWeb(web: m.web).frame(height: showWeb ? 320 : 2).opacity(showWeb ? 1 : 0.01).allowsHitTesting(showWeb)
        }
        .padding(14)
    }
}
