import Foundation
import UIKit
import WebKit

// MARK: - 读取用户粘贴的这一个链接（cmd:'linkinfo'）
// 老板决定（决策记录 2026-11-01、11-02）：只在用户粘贴或扫码时，由用户手机打开这一个公开页面，取标题和文字。
// 做法：隐藏的网页视图，和用户自己用手机打开这个页面一样，页面自己的脚本跑完后读屏幕上的文字。
// 不登录、不带 cookie（用一次性的数据空间）、不定时、不批量、不自己拼接口或签名。
// User-Agent 用 iPhone Safari（老板 2026-11-02 给的验证方案要求，页面才按手机网页显示）。
// 碰到验证码或登录页直接放弃，不绕过，走手动填。时间由网页的 parseSaleTime 判断，这里不猜。

@MainActor
final class LinkReader: NSObject, WKNavigationDelegate {
    private static var current: LinkReader?

    /// 只读这些平台的页面。其他网址不读，走手动填
    private static let hosts = ["damai.cn", "taobao.com", "tmall.com", "tb.cn", "jd.com", "3.cn", "maoyan.com",
                                "pinduoduo.com", "yangkeduo.com", "meituan.com", "12306.cn", "piaoxingqiu.com"]
    static func allowed(_ host: String?) -> Bool {
        guard let h = host?.lowercased() else { return false }
        return hosts.contains { h == $0 || h.hasSuffix("." + $0) }
    }

    static func read(_ raw: String, done: @escaping ([String: Any]) -> Void) {
        current?.finish(["cancelled": true])
        guard var comp = URLComponents(string: raw), let sch = comp.scheme?.lowercased(), sch == "https" || sch == "http" else {
            done(["unsupported": true]); return
        }
        guard allowed(comp.host) else {
            Diag.add("读链接 \(comp.host ?? "?") 不在平台名单，没读")
            done(["unsupported": true]); return
        }
        comp.scheme = "https"
        guard let url = comp.url else { done(["unsupported": true]); return }
        let r = LinkReader(done: done)
        current = r
        r.start(url)
    }

    private let done: ([String: Any]) -> Void
    private var web: WKWebView?
    private var began = Date()
    private var finished = false
    private var last: [String: Any] = [:]
    private var host = ""

    private init(done: @escaping ([String: Any]) -> Void) { self.done = done }

    private func start(_ url: URL) {
        host = url.host ?? ""
        began = Date()
        let cfg = WKWebViewConfiguration()
        cfg.websiteDataStore = .nonPersistent()
        cfg.mediaTypesRequiringUserActionForPlayback = .all
        cfg.userContentController.addUserScript(WKUserScript(source: Self.capture, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        let wv = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: cfg)
        wv.customUserAgent = Self.safariUA
        wv.navigationDelegate = self
        wv.isUserInteractionEnabled = false
        wv.alpha = 0.01
        if let win = UIApplication.topViewController()?.view.window { win.insertSubview(wv, at: 0) }
        web = wv
        wv.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8))
        poll()
    }

    static let safariUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    /// 页面加载前放进去：记下页面自己收到的、含关键字的数据。只旁听，不自己发请求、不算签名
    static let capture = """
    (function(){var K=/开抢|开售|开票|开卖|预售|sellStart|sellTime|saleTime|openTime|startTime|itemName|projectName|performName/i;window.__kdCap=[];
    function cut(u){return String(u||'').split('?')[0].slice(0,120)}
    function add(src,t){try{t=typeof t==='string'?t:JSON.stringify(t);var inl=src==='内嵌脚本';if(t&&((window.__kdAll&&!inl)||K.test(t)||/mtop|subpage/.test(String(src)))&&window.__kdCap.length<(window.__kdAll?(inl?12:80):24))window.__kdCap.push({src:cut(src),body:t.slice(0,200000)})}catch(e){}}
    var F=window.fetch;if(F)window.fetch=function(){var a=arguments,u=a[0]&&a[0].url||a[0];return F.apply(this,a).then(function(r){try{r.clone().text().then(function(t){add(u,t)})}catch(e){}return r})};
    var O=XMLHttpRequest.prototype.open,S=XMLHttpRequest.prototype.send;
    XMLHttpRequest.prototype.open=function(m,u){this.__kdU=u;return O.apply(this,arguments)};
    XMLHttpRequest.prototype.send=function(){var x=this;x.addEventListener('load',function(){try{add(x.__kdU,x.responseText)}catch(e){}});return S.apply(this,arguments)};
    function wrap(s){if(!s.src){if(s.textContent)add('内嵌脚本',s.textContent);return}var m=/[?&](?:callback|jsonpCallback)=([\\w$]+)/.exec(s.src);if(!m)return;var n=m[1],f=window[n];if(typeof f==='function'&&!f.__kd){var g=function(d){add(s.src,d);return f.apply(this,arguments)};g.__kd=1;window[n]=g}}
    new MutationObserver(function(ms){ms.forEach(function(x){x.addedNodes.forEach(function(n){if(n.tagName==='SCRIPT')wrap(n)})})}).observe(document,{childList:true,subtree:true});
    })()
    """

    static let snapshot = """
    (function(){var b=document.body,t=b?b.innerText:'',og=document.querySelector('meta[property="og:title"]'),best='',bs=0;
    var els=document.querySelectorAll('h1,h2,h3,[class*=title],[class*=Title],[class*=name],[class*=Name]');
    for(var i=0;i<els.length&&i<200;i++){var e=els[i],s=(e.innerText||'').trim();if(s.length<4||s.length>80||s.indexOf('\\n')>=0)continue;
    var r=e.getBoundingClientRect();if(r.height===0||r.top>innerHeight)continue;var f=parseFloat(getComputedStyle(e).fontSize)||0;if(f>bs){bs=f;best=s}}
    var item='',sell=0,u='',Q=String.fromCharCode(92)+'"',cap=window.__kdCap||[];
    for(var c=0;c<cap.length;c++){if(cap[c].src.indexOf('item.detail.getdetail')<0)continue;var b0=cap[c].body.split(Q).join('"').split(Q).join('"'),m=/"itemName":"([^"]+)"/.exec(b0);if(m){item=m[1];u=b0;var w=/"sellStartTime":"?(\\d{13})/.exec(u);if(w)sell=+w[1];break}}
    // 没有 sellStartTime 时：大麦按场次列出「条件退」规则，每场第一阶段（ruleStage 1）从开卖开始，取它的 startTime 当候选，交给用户选（老板 2026-11-03）
    var cands=[];if(!sell&&u){var cur='',bst={},ord=[],x,re=/"performDate":"([^"]{4,40})"|\{[^{}]*"startTime":"?(\\d{13})[^{}]*\}/g;
    while((x=re.exec(u))){if(x[1]){cur=x[1];continue}var o=x[0];if(!/ruleStage/.test(o))continue;var tt=+x[2],st=/"ruleStage":"?1[^0-9]/.test(o),k=cur||'?',v=bst[k];
    if(!v)ord.push(k);if(!v||(st&&!v.st)||(st===v.st&&tt<v.t))bst[k]={t:tt,st:st}}
    for(var i=0;i<ord.length&&i<12;i++)cands.push({d:ord[i]==='?'?'':ord[i],t:bst[ord[i]].t})}
    return JSON.stringify({title:document.title||'',og:og?(og.content||''):'',head:best,item:item,sell:sell,cands:cands,text:t.slice(0,8000),href:location.href})})()
    """

    private func poll() {
        guard !finished, let wv = web else { return }
        wv.evaluateJavaScript(Self.snapshot) { [weak self] res, _ in
            guard let self, !self.finished else { return }
            if let s = res as? String, let d = s.data(using: .utf8), let j = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
                self.last = j
                let text = j["text"] as? String ?? "", href = j["href"] as? String ?? ""
                if Self.looksBlocked(text, href) {
                    self.finish(self.result(blocked: true)); return
                }
                if Self.hasSaleTime(text) || !(j["item"] as? String ?? "").isEmpty { self.finish(self.result(blocked: false)); return }
            }
            if Date().timeIntervalSince(self.began) > 9 { self.finish(self.result(blocked: false)); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.poll() }
        }
    }

    private static func looksBlocked(_ text: String, _ href: String) -> Bool {
        if href.range(of: "login|punish|captcha|baxia|verify", options: [.regularExpression, .caseInsensitive]) != nil { return true }
        return text.count < 300 && text.range(of: "滑块|验证码|安全验证|请完成验证|访问受限|请登录|访问被拒绝", options: .regularExpression) != nil
    }

    /// 页面上已经有「开抢 + 日期 + 时分」，不用再等
    private static func hasSaleTime(_ t: String) -> Bool {
        t.range(of: "开抢|开售|开票|开卖|预售|发售|抢购", options: .regularExpression) != nil
            && t.range(of: "\\d{1,2}\\s*[月/.\\-]\\s*\\d{1,2}", options: .regularExpression) != nil
            && t.range(of: "\\d{1,2}[:：]\\d{2}", options: .regularExpression) != nil
    }

    private func result(blocked: Bool) -> [String: Any] {
        let item = last["item"] as? String ?? ""
        let head = item.isEmpty ? (last["head"] as? String ?? "") : item, og = last["og"] as? String ?? "", title = last["title"] as? String ?? ""
        let text = last["text"] as? String ?? ""
        // sell 是大麦数据里明确的开抢字段（sellStartTime，毫秒）。有些场次不是第一轮，没有这个字段，就留空，不猜
        let sell = (last["sell"] as? NSNumber)?.doubleValue ?? 0
        return ["head": head, "og": og, "title": title, "text": blocked ? "" : text, "blocked": blocked, "sell": blocked ? 0 : sell, "cands": blocked ? [] : (last["cands"] as? [[String: Any]] ?? [])]
    }

    private func finish(_ r: [String: Any]) {
        guard !finished else { return }
        finished = true
        let ms = Int(Date().timeIntervalSince(began) * 1000)
        let t = last["text"] as? String ?? ""
        var near = ""
        if let rg = t.range(of: "开抢|开售|开票|开卖|预售|发售", options: .regularExpression) {
            let a = t.index(rg.lowerBound, offsetBy: -30, limitedBy: t.startIndex) ?? t.startIndex
            let b = t.index(rg.upperBound, offsetBy: 30, limitedBy: t.endIndex) ?? t.endIndex
            near = String(t[a..<b]).replacingOccurrences(of: "\n", with: " ")
        }
        Diag.add("读链接 \(host) \(ms)ms 被拦\(r["blocked"] as? Bool ?? false) 标题「\(last["title"] as? String ?? "")」大字「\(last["head"] as? String ?? "")」开抢字段\(Int((last["sell"] as? NSNumber)?.doubleValue ?? 0)) 文字\(t.count)字 开抢附近「\(near)」")
        web?.stopLoading()
        web?.navigationDelegate = nil
        web?.removeFromSuperview()
        web = nil
        if Self.current === self { Self.current = nil }
        done(r)
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, let s = url.scheme?.lowercased() else { decisionHandler(.cancel); return }
        // 页面想跳别的 App（taobao://、damai://）一律不跳；主页面只留在平台域名里
        guard s == "https" || s == "http" || s == "about" || s == "blob" || s == "data" else { decisionHandler(.cancel); return }
        if action.targetFrame?.isMainFrame == true, s == "https" || s == "http", !Self.allowed(url.host) { decisionHandler(.cancel); return }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if (error as NSError).code == NSURLErrorCancelled { return }
        finish(result(blocked: false))
    }
}
