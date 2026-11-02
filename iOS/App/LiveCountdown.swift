import Foundation
import ActivityKit

// MARK: - 灵动岛和锁屏倒计时（cmd:'live'）
// 只显示最近一场，到秒。网页传的 at 已经换算到手机时钟并含反应补偿。
// 没有服务器不能远程推送，只能在 App 打开时启动。到点后靠 staleDate 让界面变成「已开抢」。

@MainActor
enum LiveCountdown {
    /// 返回 false 表示用户关了实时活动权限
    static func apply(_ items: [[String: Any]]) async -> Bool {
        let info = ActivityAuthorizationInfo()
        let first = items.first
        let want: (id: String, name: String, srcName: String, target: Date)? = first.flatMap { it in
            guard let id = it["id"] as? String, let at = (it["at"] as? NSNumber)?.doubleValue else { return nil }
            return (id, it["name"] as? String ?? "", it["srcName"] as? String ?? "", Date(timeIntervalSince1970: at / 1000))
        }
        for a in Activity<CountdownAttributes>.activities {
            if let w = want, a.attributes.id == w.id, a.attributes.name == w.name, a.attributes.srcName == w.srcName {
                if abs(a.content.state.target.timeIntervalSince(w.target)) >= 0.5 {
                    await a.update(ActivityContent(state: .init(target: w.target), staleDate: w.target))
                }
            } else {
                await a.end(nil, dismissalPolicy: .immediate)
            }
        }
        guard info.areActivitiesEnabled else { return false }
        guard let w = want, w.target > Date(), !Activity<CountdownAttributes>.activities.contains(where: { $0.attributes.id == w.id }) else { return true }
        do {
            _ = try Activity.request(attributes: CountdownAttributes(id: w.id, name: w.name, srcName: w.srcName),
                                     content: ActivityContent(state: .init(target: w.target), staleDate: w.target),
                                     pushType: nil)
        } catch {
            Diag.add("灵动岛启动失败：\(error.localizedDescription)")
        }
        return true
    }
}
