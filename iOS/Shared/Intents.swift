import AppIntents
import WidgetKit

/// 小组件上点一项：标成完成（或取消），App 下次打开时同步进数据
struct ToggleItemIntent: AppIntent {
    static var title: LocalizedStringResource = "完成"
    static var description = IntentDescription("在小组件上完成今天的一项")
    @Parameter(title: "项目") var itemId: String

    init() {}
    init(itemId: String) { self.itemId = itemId }

    func perform() async throws -> some IntentResult {
        Persistence.widgetTap(itemId)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

/// 控制中心 / 快捷指令：打开 App
struct OpenAppIntent: AppIntent {
    static var title: LocalizedStringResource = "打开"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult { .result() }
}
