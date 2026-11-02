import WidgetKit
import SwiftUI
import AppIntents

// MARK: - 桌面小组件
// 内容全部由网页整理后通过 cmd:'widget' 写进 widget.json（见 Persistence.WidgetData），这里只负责画出来。
// 「今天」：显示还没完成的项目，点一下直接完成（打完的自动消失）；全部完成后显示一句鼓励。
// 「笔记」：一句提示语，点一下打开 App 的 note 页面（不在桌面上显示用户写的内容，保护隐私）。

struct Entry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry { Entry(date: Date(), data: sample) }
    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        let d = Persistence.loadWidget()
        completion(Entry(date: Date(), data: d.items.isEmpty && context.isPreview ? sample : d))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        // 过了零点要刷新成新的一天：下一次在明天 0:01
        let next = Calendar.current.nextDate(after: Date(), matching: DateComponents(hour: 0, minute: 1), matchingPolicy: .nextTime) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [Entry(date: Date(), data: Persistence.loadWidget())], policy: .after(next)))
    }
    var sample: WidgetData {
        var w = WidgetData()
        w.title = L("今天")
        w.items = [.init(id: "a", name: "🌱", mark: "🌱", color: "#7DBF8A"), .init(id: "b", name: "📖", mark: "📖", color: "#F29D38"),
                   .init(id: "c", name: "💧", mark: "💧", color: "#50A8B0"), .init(id: "d", name: "🧘", mark: "🧘", color: "#A58BD6")]
        return w
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }
}

struct ItemDot: View {
    let item: WidgetData.Item
    let size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: item.color).opacity(item.done ? 1 : 0.22))
            Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: item.done ? [] : [2.5, 2.5])).foregroundStyle(Color(hex: item.color))
            Text(item.mark.isEmpty ? String(item.name.prefix(1)) : item.mark)
                .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                .foregroundStyle(item.done ? .white : Color(hex: item.color))
                .minimumScaleFactor(0.5).lineLimit(1)
        }
        .frame(width: size, height: size)
    }
}

struct TodayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry

    private var cap: Int { family == .systemSmall ? 4 : family == .systemMedium ? 8 : 16 }
    private var cols: Int { family == .systemSmall ? 2 : 4 }

    var body: some View {
        let d = entry.data
        let todo = d.items.filter { !$0.done }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(d.title.isEmpty ? L("今天") : d.title).font(.system(size: 12.5, weight: .semibold)).lineLimit(1)
                Spacer()
                if !d.items.isEmpty { Text("\(d.items.count - todo.count)/\(d.items.count)").font(.system(size: 11)).foregroundStyle(.secondary) }
            }
            if d.items.isEmpty {
                Spacer()
                Text(d.emptyTitle.isEmpty ? L("今天没有需要完成的事") : d.emptyTitle).font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
            } else if todo.isEmpty {
                Spacer()
                Text(d.doneTitle.isEmpty ? L("全部完成") : d.doneTitle).font(.system(size: 15, weight: .bold))
                if !d.doneSub.isEmpty { Text(d.doneSub).font(.system(size: 12)).foregroundStyle(.secondary) }
                Spacer()
            } else {
                let size: CGFloat = family == .systemSmall ? 44 : 46
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: cols), spacing: 8) {
                    ForEach(todo.prefix(cap)) { it in
                        if d.tap {
                            Button(intent: ToggleItemIntent(itemId: it.id)) { cell(it, size) }.buttonStyle(.plain)
                        } else { cell(it, size) }
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .containerBackground(for: .widget) { Color(hex: d.bg) }
    }

    @ViewBuilder private func cell(_ it: WidgetData.Item, _ size: CGFloat) -> some View {
        VStack(spacing: 3) {
            ItemDot(item: it, size: size)
            if family != .systemSmall { Text(it.name).font(.system(size: 10)).lineLimit(1) }
        }
    }
}

struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodayWidget", provider: Provider()) { TodayView(entry: $0) }
            .configurationDisplayName(L("今天"))
            .description(L("显示今天还没完成的项目，点一下直接完成。"))
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct NoteView: View {
    let entry: Entry
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer()
            Text(entry.data.noteTitle.isEmpty ? L("笔记") : entry.data.noteTitle).font(.system(size: 16, weight: .bold))
            if !entry.data.noteSub.isEmpty { Text(entry.data.noteSub).font(.system(size: 12)).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "\(AppConfig.urlScheme)://note"))
        .containerBackground(for: .widget) { Color(hex: entry.data.bg) }
    }
}

struct NoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NoteWidget", provider: Provider()) { NoteView(entry: $0) }
            .configurationDisplayName(L("笔记"))
            .description(L("点一下打开 App 记录今天。"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct StarterWidgets: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        NoteWidget()
    }
}
