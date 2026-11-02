import Foundation

/// 这款 App 的身份信息。由 tools/render.py 根据 app.json 生成，不要手改。
enum AppConfig {
    static let slug = "kadian"
    static let bundleId = "site.xiaomanhabit.kadian"
    static let appGroup = "group.site.xiaomanhabit.kadian"
    static let urlScheme = "kadian"
    static let nameZh = "卡点"
    static let nameEn = "OnCue"
    static let nameHant = "卡點"
    static var displayName: String { L10n.lang == "en" ? nameEn : L10n.lang == "zh-Hant" ? nameHant : nameZh }
    static let splashQuote = "准点，就是最好的运气。"
    static let splashQuoteEn = "Right on time is the best luck."
    static let splashQuoteHant = "準點，就是最好的運氣。"
    /// 检查更新时查哪个国家的 App Store（只在中国大陆上架就用 cn）
    static let lookupCountry = "cn"
    static let vipEnabled = false
    static let vipYear = "site.xiaomanhabit.kadian.vip.year"
    static let vipMonth = "site.xiaomanhabit.kadian.vip.month"
    static let vipLife = "site.xiaomanhabit.kadian.vip.life"
}
