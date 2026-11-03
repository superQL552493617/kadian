import Foundation
import StoreKit

/// 会员：季度（3 个月自动续订，占 month 这一格）、永久（一次性买断）。
/// 商品 ID 在 app.json 里配置，要和 App Store Connect 里创建的一致。价格文字由网页按语言拼，这里只给原始数据。
@MainActor
final class Purchases: ObservableObject {
    static let kinds = ["life", "month"] // month 这一格现在是季度会员（3 个月自动续订）
    static func id(_ kind: String) -> String { kind == "year" ? AppConfig.vipYear : kind == "month" ? AppConfig.vipMonth : AppConfig.vipLife }

    @Published var products: [Product] = []
    @Published var isVIP = false
    @Published var plan: String = "free"    // free / month / year / life
    @Published var expires: Date?
    @Published var trialEligible = true
    @Published var message: String?
    /// 第一次读完购买记录（之前的 plan 还不可信）
    @Published var loaded = false
    @Published var isTestVIP = false
    private var updates: Task<Void, Never>?

    func start() async {
        updates?.cancel()
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let t) = result { await t.finish() }
                await self?.refresh()
            }
        }
        await loadProducts()
        await refresh()
    }

    func loadProducts() async {
        guard AppConfig.vipEnabled else { return }
        products = (try? await Product.products(for: Self.kinds.map(Self.id))) ?? []
        if let y = product("year") { trialEligible = await y.subscription?.isEligibleForIntroOffer ?? false }
    }

    func product(_ kind: String) -> Product? { products.first { $0.id == Self.id(kind) } }

    func refresh() async {
        var p = "free"
        var exp: Date?
        let rank = ["free": 0, "month": 1, "year": 2, "life": 3]
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil else { continue }
            let k = t.productID == AppConfig.vipLife ? "life" : t.productID == AppConfig.vipYear ? "year" : t.productID == AppConfig.vipMonth ? "month" : "free"
            if rank[k, default: 0] > rank[p, default: 0] { p = k; exp = t.expirationDate }
        }
        isTestVIP = p == "free" && TestMode.vip
        if isTestVIP { p = "life"; exp = nil }
        plan = p
        expires = p == "life" ? nil : exp
        isVIP = p != "free"
        loaded = true
    }

    /// 给网页的会员信息：每个商品的价格（App Store 本地货币）、试用、当前方案、到期日
    func info() -> [String: Any] {
        var offers: [String: Any] = [:]
        for k in Self.kinds {
            guard let p = product(k) else { continue }
            var o: [String: Any] = ["price": p.displayPrice, "value": NSDecimalNumber(decimal: p.price).doubleValue,
                                    "currency": p.priceFormatStyle.currencyCode]
            if let s = p.subscription {
                o["period"] = s.subscriptionPeriod.unit == .year ? "year" : s.subscriptionPeriod.unit == .month ? "month" : "other"
                if let intro = s.introductoryOffer, intro.paymentMode == .freeTrial, trialEligible {
                    o["trialDays"] = intro.period.unit == .day ? intro.period.value : intro.period.unit == .week ? intro.period.value * 7 : intro.period.value * 30
                }
            }
            offers[k] = o
        }
        var exp = ""
        if let e = expires {
            let c = Calendar.current.dateComponents([.year, .month, .day], from: e)
            exp = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
        return ["plan": plan, "test": isTestVIP, "expires": exp, "offers": offers]
    }

    @discardableResult
    func buy(kind: String) async -> Bool {
        if products.isEmpty { await loadProducts() }
        guard let p = product(kind) else { message = "store-offline"; return false }
        do {
            switch try await p.purchase() {
            case .success(let v):
                if case .verified(let t) = v { await t.finish(); message = "bought" }
                await refresh()
                return isVIP
            case .userCancelled: return false
            case .pending: message = "pending"; return false
            @unknown default: return false
            }
        } catch {
            message = "failed:" + error.localizedDescription
            return false
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refresh()
            message = isVIP ? "restored" : "nothing"
        } catch { message = "restore-failed" }
    }
}
