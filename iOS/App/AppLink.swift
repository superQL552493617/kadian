import UIKit

// MARK: - 跳到平台 App 的活动页（cmd:'openapp'）
// 顺序：① 通用链接，只在 App 里打开；② 平台 App 的网址协议；③ 都不行才用浏览器，并告诉用户。
// 协议地址是凭记忆写的，各平台是否支持、能否到具体活动页要真机逐个试（见 04_dev/原生说明.md）。

enum AppLink {
    static func candidates(_ url: URL) -> [URL] {
        guard let host = url.host?.lowercased() else { return [] }
        let comp = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let q: (String) -> String? = { n in comp?.queryItems?.first { $0.name == n }?.value }
        let id = q("itemId") ?? q("id")
        let rest = url.absoluteString.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
        var out: [String] = []
        if host.hasSuffix("damai.cn") {
            if let id { out.append("damai://V1/ProjectPage?id=\(id)") }
            out.append("damai://")
        } else if host.hasSuffix("tmall.com") {
            if let id { out.append("tmall://page.tm/itemDetail?id=\(id)") }
            out.append("taobao://\(rest)")
        } else if host.hasSuffix("taobao.com") || host.hasSuffix("tb.cn") {
            out.append("taobao://\(rest)")
        } else if host.hasSuffix("jd.com") || host.hasSuffix("3.cn") {
            let params = "{\"category\":\"jump\",\"des\":\"m\",\"url\":\"\(url.absoluteString)\"}"
            if let e = params.addingPercentEncoding(withAllowedCharacters: .alphanumerics) { out.append("openapp.jdmobile://virtual?params=\(e)") }
        } else if host.hasSuffix("pinduoduo.com") || host.hasSuffix("yangkeduo.com") {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            out.append("pinduoduo://com.xunmeng.pinduoduo/\(path)\(url.query.map { "?\($0)" } ?? "")")
        } else if host.hasSuffix("meituan.com") {
            if let e = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .alphanumerics) { out.append("imeituan://www.meituan.com/web?url=\(e)") }
        }
        return out.compactMap { URL(string: $0) }
    }

    /// 回传 "app"（进了 App）/ "browser"（只能用浏览器）/ false（打不开）
    static func open(_ raw: String, done: @escaping (Any) -> Void) {
        guard let url = URL(string: raw) else { done(false); return }
        UIApplication.shared.open(url, options: [.universalLinksOnly: true]) { ok in
            if ok { Diag.add("跳转 \(url.host ?? "") 通用链接成功"); done("app"); return }
            tryNext(candidates(url), url, done)
        }
    }

    private static func tryNext(_ list: [URL], _ url: URL, _ done: @escaping (Any) -> Void) {
        guard let first = list.first else {
            UIApplication.shared.open(url, options: [:]) { ok in
                Diag.add("跳转 \(url.host ?? "") 用浏览器 \(ok)")
                done(ok ? "browser" : false)
            }
            return
        }
        UIApplication.shared.open(first, options: [:]) { ok in
            Diag.add("跳转 \(first.scheme ?? "") \(ok ? "成功" : "失败")")
            if ok { done("app") } else { tryNext(Array(list.dropFirst()), url, done) }
        }
    }
}
