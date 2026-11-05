import Foundation
import EventKit

// MARK: - 从日历读开抢时间（cmd:'calendar'）
// 只有用户点了「从日历添加」才申请权限。只在手机上读，不上传。测试记录只写条数，不写日程内容。
// 回传 {denied:true} 或 {events:[{title,at}]}（未来半年、不含全天日程），选哪条由用户决定。

enum CalendarRead {
    private static let store = EKEventStore()

    static func upcoming(done: @escaping ([String: Any]) -> Void) {
        store.requestFullAccessToEvents { ok, _ in
            guard ok else { DispatchQueue.main.async { done(["denied": true]) }; return }
            let now = Date()
            let end = now.addingTimeInterval(180 * 86400)
            let pred = store.predicateForEvents(withStart: now, end: end, calendars: nil)
            let list = store.events(matching: pred).filter { !$0.isAllDay }
                .sorted { $0.startDate < $1.startDate }
                .prefix(300)
                .map { e -> [String: Any] in ["title": e.title ?? "", "at": e.startDate.timeIntervalSince1970 * 1000] }
            DispatchQueue.main.async { done(["events": Array(list)]) }
        }
    }
}
