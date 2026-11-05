import Foundation
import Network

// MARK: - 真实对时（cmd:'timesync'）
// 规则见需求说明 3.1：每次至少取 3 个样本，用往返最快的算偏差；只读时间，不发任何用户信息；没有模拟数据，对不上就返回空。
// 这些地址都是公开的时间接口或普通网页的 Date 响应头，不带私有参数。能不能用、精度多少要真机验证（04_dev/原生说明.md）。

enum TimeSync {
    struct Sample { let offset: Double; let rtt: Double }
    enum Way {
        case json(String, [String])  // 接口返回毫秒时间戳，路径是 JSON 里的字段
        case date(String)            // 只有 Date 响应头，只精确到秒
        case ntp(String)
        var label: String {
            switch self {
            case .json(let u, _), .date(let u): return URL(string: u)?.host ?? u
            case .ntp(let h): return h
            }
        }
    }

    static let allSources = ["ntp", "damai", "taobao", "jd", "maoyan", "12306", "pdd", "meituan", "pxq"]

    static let table: [String: [Way]] = [
        "ntp": [.ntp("ntp.ntsc.ac.cn"), .ntp("ntp.aliyun.com"), .ntp("cn.pool.ntp.org")],
        "damai": [.json("https://mtop.damai.cn/gw/mtop.common.getTimestamp/", ["data", "t"]), .date("https://m.damai.cn/")],
        "taobao": [.json("https://acs.m.taobao.com/gw/mtop.common.getTimestamp/", ["data", "t"]),
                   .json("https://api.m.taobao.com/rest/api3.do?api=mtop.common.getTimestamp", ["data", "t"]),
                   .date("https://m.taobao.com/")],
        "jd": [.json("https://a.jd.com/ajax/queryServerData.html", ["serverTime"]), .date("https://m.jd.com/")],
        "maoyan": [.date("https://m.maoyan.com/")],
        "12306": [.date("https://kyfw.12306.cn/otn/")],
        "pdd": [.json("https://api.pinduoduo.com/api/server/_stm", ["server_time"]), .date("https://mobile.yangkeduo.com/")],
        "pxq": [.date("https://m.piaoxingqiu.com/")],
        "meituan": [.json("https://cube.meituan.com/ipromotion/cube/toc/component/base/getServerCurrentTime", ["data"]), .date("https://i.meituan.com/")],
    ]

    private static let session: URLSession = {
        let c = URLSessionConfiguration.ephemeral
        c.requestCachePolicy = .reloadIgnoringLocalCacheData
        c.urlCache = nil
        c.httpCookieStorage = nil
        c.httpShouldSetCookies = false
        c.timeoutIntervalForRequest = 3
        c.timeoutIntervalForResource = 4
        return URLSession(configuration: c)
    }()

    /// 返回 {offset, rtt, prec}（毫秒）；prec 是精度，只给到秒的源是 1000，其他是 0。全部失败返回 nil
    static func sync(_ src: String) async -> [String: Any]? {
        for way in table[src] ?? [] {
            var best: Sample?
            for _ in 0..<3 {
                if let s = await sample(way), best == nil || s.rtt < best!.rtt { best = s }
                if Task.isCancelled { return nil }
            }
            guard let b = best else {
                continue
            }
            var prec = 0
            if case .date = way { prec = 1000 }
            return ["offset": b.offset.rounded(), "rtt": b.rtt.rounded(), "prec": prec]
        }
        return nil
    }

    private static func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

    private static func sample(_ way: Way) async -> Sample? {
        switch way {
        case .ntp(let host): return await ntp(host)
        case .json(let u, let path):
            guard let url = URL(string: u) else { return nil }
            let t0 = nowMs()
            guard let (data, _) = try? await session.data(from: url) else { return nil }
            let t1 = nowMs()
            guard let any = try? JSONSerialization.jsonObject(with: data), let server = number(any, path) else { return nil }
            return checked(server: server, t0: t0, t1: t1)
        case .date(let u):
            guard let url = URL(string: u) else { return nil }
            var req = URLRequest(url: url); req.httpMethod = "HEAD"
            let t0 = nowMs()
            guard let (_, resp) = try? await session.data(for: req), let h = resp as? HTTPURLResponse,
                  let v = h.value(forHTTPHeaderField: "Date"), let d = dateFormatter.date(from: v) else { return nil }
            let t1 = nowMs()
            // Date 头把毫秒截掉了，平均少 500 毫秒
            return checked(server: d.timeIntervalSince1970 * 1000 + 500, t0: t0, t1: t1)
        }
    }

    private static func checked(server: Double, t0: Double, t1: Double) -> Sample? {
        let mid = (t0 + t1) / 2
        guard abs(server - mid) < 86_400_000 else { return nil } // 差一天以上肯定是接口语义不对，不信它
        return Sample(offset: server - mid, rtt: t1 - t0)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    /// 按路径取毫秒时间戳，数字或字符串都认；不是 13 位毫秒的不要
    private static func number(_ root: Any, _ path: [String]) -> Double? {
        var cur: Any = root
        for k in path {
            guard let d = cur as? [String: Any], let n = d[k] else { return nil }
            cur = n
        }
        let v: Double?
        if let n = cur as? NSNumber { v = n.doubleValue } else if let s = cur as? String { v = Double(s) } else { v = nil }
        guard let x = v, x > 1_000_000_000_000 else { return nil }
        return x
    }

    private final class Once {
        private let lock = NSLock(); private var done = false
        func fire() -> Bool { lock.lock(); defer { lock.unlock() }; if done { return false }; done = true; return true }
    }

    private static func ntp(_ host: String) async -> Sample? {
        await withCheckedContinuation { (cont: CheckedContinuation<Sample?, Never>) in
            let conn = NWConnection(host: NWEndpoint.Host(host), port: 123, using: .udp)
            let q = DispatchQueue(label: "kadian.ntp")
            let once = Once()
            let finish: (Sample?) -> Void = { s in
                if once.fire() { conn.cancel(); cont.resume(returning: s) }
            }
            q.asyncAfter(deadline: .now() + 2) { finish(nil) }
            conn.stateUpdateHandler = { st in
                switch st {
                case .ready:
                    var pkt = [UInt8](repeating: 0, count: 48)
                    pkt[0] = 0x23 // LI=0 VN=4 Mode=3（客户端）
                    let t1 = nowMs()
                    conn.send(content: Data(pkt), completion: .contentProcessed { _ in })
                    conn.receiveMessage { data, _, _, _ in
                        let t4 = nowMs()
                        guard let d = data, d.count >= 48 else { finish(nil); return }
                        let b = [UInt8](d)
                        let ts: (Int) -> Double = { i in
                            let sec = (UInt32(b[i]) << 24) | (UInt32(b[i + 1]) << 16) | (UInt32(b[i + 2]) << 8) | UInt32(b[i + 3])
                            let fra = (UInt32(b[i + 4]) << 24) | (UInt32(b[i + 5]) << 16) | (UInt32(b[i + 6]) << 8) | UInt32(b[i + 7])
                            return (Double(sec) - 2_208_988_800 + Double(fra) / 4_294_967_296) * 1000
                        }
                        let t2 = ts(32), t3 = ts(40)
                        guard t3 > 0, abs(t3 - t4) < 86_400_000 else { finish(nil); return }
                        finish(Sample(offset: ((t2 - t1) + (t3 - t4)) / 2, rtt: (t4 - t1) - (t3 - t2)))
                    }
                case .failed, .cancelled: finish(nil)
                default: break
                }
            }
            conn.start(queue: q)
        }
    }
}
