import Foundation

/// 真机测试记录：只记对时和读链接的结果（不含账号、设备标识），只在内存里。测试包摇一摇可复制出来发给开发。
enum Diag {
    private static let lock = NSLock()
    private static var lines: [String] = []
    static func add(_ s: String) {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; f.locale = Locale(identifier: "en_US_POSIX")
        lock.lock(); defer { lock.unlock() }
        lines.append("\(f.string(from: Date())) \(s)")
        if lines.count > 200 { lines.removeFirst(lines.count - 200) }
    }
    static var text: String {
        lock.lock(); defer { lock.unlock() }
        return lines.joined(separator: "\n")
    }
}
