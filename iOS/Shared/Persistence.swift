import Foundation

/// 数据放在 App 和小组件共用的 App Group 里。
/// - state.json：网页的全部数据（原样保存网页给的 JSON 字符串）
/// - widget.json：网页整理好的小组件内容
/// - widget_taps.json：在小组件上点过、还没交给网页的项目
enum Persistence {
    static var folder: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfig.appGroup)
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var file: URL { folder.appendingPathComponent("state.json") }
    static var widgetFile: URL { folder.appendingPathComponent("widget.json") }
    static var tapsFile: URL { folder.appendingPathComponent("widget_taps.json") }

    static func loadRaw() -> String? {
        guard let d = try? Data(contentsOf: file) else { return nil }
        return String(data: d, encoding: .utf8)
    }

    static func saveRaw(_ v: String) {
        guard let d = v.data(using: .utf8) else { return }
        try? d.write(to: file, options: [.atomic])
    }

    // MARK: 小组件

    static func saveWidget(_ obj: Any) {
        guard JSONSerialization.isValidJSONObject(obj), let d = try? JSONSerialization.data(withJSONObject: obj) else { return }
        try? d.write(to: widgetFile, options: [.atomic])
    }

    static func loadWidget() -> WidgetData {
        guard let d = try? Data(contentsOf: widgetFile), let w = try? JSONDecoder().decode(WidgetData.self, from: d) else { return WidgetData() }
        return w
    }

    static func takeWidgetTaps() -> [[String: Any]] {
        let taps = (try? Data(contentsOf: tapsFile)).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] } ?? []
        try? FileManager.default.removeItem(at: tapsFile)
        return taps
    }
}

/// 小组件的内容（由网页整理：标题、要显示的项目、全部完成时的话、没内容时的提示）
struct WidgetData: Codable {
    struct Item: Codable, Identifiable {
        var id: String
        var name: String
        /// 一个 emoji 或一两个字，显示在圆圈里
        var mark: String = ""
        /// 圆圈颜色 #RRGGBB
        var color: String = "#7DBF8A"
        var done: Bool = false
        /// 开抢时刻（毫秒，已换算到手机时钟）
        var at: Double? = nil
    }
    var title: String = ""
    var items: [Item] = []
    /// 能不能直接在小组件上点完成
    var tap: Bool = true
    var doneTitle: String = ""
    var doneSub: String = ""
    var emptyTitle: String = ""
    /// 笔记小组件：两句提示语
    var noteTitle: String = ""
    var noteSub: String = ""
    var bg: String = "#FBF7EE"
    var updated: Double = 0
}
