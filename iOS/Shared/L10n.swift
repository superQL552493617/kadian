import Foundation

/// 原生部分（开屏、系统弹窗、小组件、隐私政策等）的多语言。
/// 语言跟网页里的「语言」设置一致（state.json 里的 prefs.lang）：auto 跟随系统，zh-Hans / zh-Hant / en。
enum L10n {
    private static var cached: (String, Date)?
    static var lang: String {
        if let c = cached, Date().timeIntervalSince(c.1) < 2 { return c.0 }
        let r = resolve(pref)
        cached = (r, Date())
        return r
    }
    /// 数据文件里存的语言设置，注入给网页
    static var pref: String {
        guard let d = try? Data(contentsOf: Persistence.file),
              let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any],
              let p = j["prefs"] as? [String: Any], let l = p["lang"] as? String,
              ["auto", "zh-Hans", "zh-Hant", "en"].contains(l) else { return "auto" }
        return l
    }
    static func resolve(_ pref: String) -> String {
        if ["zh-Hans", "zh-Hant", "en"].contains(pref) { return pref }
        let l = (Locale.preferredLanguages.first ?? "zh-Hans").lowercased()
        if l.hasPrefix("zh") { return (l.contains("hant") || l.contains("-tw") || l.contains("-hk") || l.contains("-mo")) ? "zh-Hant" : "zh-Hans" }
        return "en"
    }
    static func reset() { cached = nil }

    static func t(_ zh: String) -> String {
        let l = lang
        if l == "zh-Hans" { return zh }
        guard let v = dict[zh] else { return zh }
        return l == "en" ? v[0] : v[1]
    }

    /// 原生用到的少量文字：简体 → [英文, 繁体]
    static let dict: [String: [String]] = [
        "意见反馈": ["Feedback", "意見回饋"],
        "完成": ["Done", "完成"],
        "关闭": ["Close", "關閉"],
        "好的": ["OK", "好的"],
        "取消": ["Cancel", "取消"],
        "确定": ["OK", "確定"],
        "解锁": ["Unlock ", "解鎖"],
        "隐私政策": ["Privacy Policy", "隱私權政策"],
        "用户协议": ["Terms of Use", "使用者條款"],
        "今天": ["Today", "今天"],
        "全部完成": ["All done", "全部完成"],
        "今天没有需要完成的事": ["Nothing for today", "今天沒有需要完成的事"],
        "显示今天还没完成的项目，点一下直接完成。": ["Shows today’s unfinished items. Tap one to complete it.", "顯示今天還沒完成的項目，點一下直接完成。"],
        "点一下打开 App 记录今天。": ["Tap to open the app and record today.", "點一下打開 App 記錄今天。"],
        "笔记": ["Notes", "筆記"],
        "打开": ["Open", "打開"],
    ]
}

func L(_ zh: String) -> String { L10n.t(zh) }
