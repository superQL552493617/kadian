import WidgetKit
import SwiftUI
import ActivityKit

// MARK: - 桌面小组件：下一场名称 + 倒计时（到秒）；没有活动时显示「添加一场抢购」，点击打开 App
// 内容由网页通过 cmd:'widget' 写进 widget.json，这里只负责画。

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
        let d = Persistence.loadWidget(), now = Date()
        var entries = [Entry(date: now, data: d)]
        // 到点时刷新一次，显示「已开抢」
        if let at = d.items.first?.at, at / 1000 > now.timeIntervalSince1970 {
            entries.append(Entry(date: Date(timeIntervalSince1970: at / 1000), data: d))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
    var sample: WidgetData {
        var w = WidgetData()
        w.title = L("下一场")
        w.items = [.init(id: "a", name: L("添加一场抢购"), mark: "", color: "#F0558A", at: (Date().timeIntervalSince1970 + 3725) * 1000)]
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

private let ink = Color(red: 0.13, green: 0.12, blue: 0.11)
private let inkSoft = Color(red: 0.13, green: 0.12, blue: 0.11).opacity(0.62)

struct NextView: View {
    let entry: Entry
    var body: some View {
        let d = entry.data
        VStack(alignment: .leading, spacing: 6) {
            if let it = d.items.first, let at = it.at {
                let target = Date(timeIntervalSince1970: at / 1000)
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: it.color)).frame(width: 8, height: 8)
                    Text(d.title.isEmpty ? L("下一场") : d.title).font(.system(size: 12, weight: .semibold)).foregroundStyle(inkSoft).lineLimit(1)
                }
                Text(it.name).font(.system(size: 15, weight: .semibold)).foregroundStyle(ink).lineLimit(2)
                Spacer(minLength: 0)
                if target > entry.date {
                    Text(timerInterval: entry.date...target, countsDown: true)
                        .font(.system(size: 26, weight: .semibold)).monospacedDigit()
                        .foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6)
                } else {
                    Text(L("已开抢")).font(.system(size: 22, weight: .semibold)).foregroundStyle(ink)
                }
            } else {
                Spacer(minLength: 0)
                Text(d.emptyTitle.isEmpty ? L("添加一场抢购") : d.emptyTitle).font(.system(size: 15, weight: .semibold)).foregroundStyle(ink)
                Text(d.noteSub.isEmpty ? L("点一下打开准点时钟") : d.noteSub).font(.system(size: 12)).foregroundStyle(inkSoft)
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .widgetURL(URL(string: "\(AppConfig.urlScheme)://today"))
        .containerBackground(for: .widget) { Color(hex: d.bg) }
    }
}

struct NextWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "NextWidget", provider: Provider()) { NextView(entry: $0) }
            .configurationDisplayName(L("下一场"))
            .description(L("显示下一场的名称和倒计时。"))
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - 灵动岛和锁屏

private struct CountdownText: View {
    let target: Date
    let stale: Bool
    var body: some View {
        if stale || target <= Date() {
            Text(L("已开抢"))
        } else {
            Text(timerInterval: Date()...target, countsDown: true).monospacedDigit()
        }
    }
}

struct CountdownLive: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CountdownAttributes.self) { ctx in
            VStack(alignment: .leading, spacing: 4) {
                Text("\(ctx.attributes.srcName) · \(ctx.attributes.name)").font(.system(size: 14, weight: .medium)).lineLimit(1)
                CountdownText(target: ctx.state.target, stale: ctx.isStale).font(.system(size: 34, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .widgetURL(URL(string: "\(AppConfig.urlScheme)://today"))
        } dynamicIsland: { ctx in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(ctx.attributes.srcName).font(.system(size: 13, weight: .medium)).lineLimit(1).padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(target: ctx.state.target, stale: ctx.isStale).font(.system(size: 22, weight: .semibold)).multilineTextAlignment(.trailing).padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(ctx.attributes.name).font(.system(size: 14)).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer")
            } compactTrailing: {
                CountdownText(target: ctx.state.target, stale: ctx.isStale).font(.system(size: 13, weight: .semibold)).multilineTextAlignment(.trailing).frame(maxWidth: 70)
            } minimal: {
                Image(systemName: "timer")
            }
            .widgetURL(URL(string: "\(AppConfig.urlScheme)://today"))
        }
    }
}

@main
struct KadianWidgets: WidgetBundle {
    var body: some Widget {
        NextWidget()
        CountdownLive()
    }
}
