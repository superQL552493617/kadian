import Foundation
import ActivityKit

/// 灵动岛和锁屏倒计时的内容。App 和小组件都要编译这个文件
struct CountdownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// 已经换算到手机时钟、含反应补偿的开抢时刻
        var target: Date
    }
    var id: String
    var name: String
    var srcName: String
}
