import Foundation
import AVFoundation
import UserNotifications

// MARK: - 音效（App/Sounds 里预先渲染好的 wav）

@MainActor
enum SFX {
    private static var players: [Int: AVAudioPlayer] = [:]
    private static var sessionReady = false
    private static var tonePlayer: AVAudioPlayer?
    /// 悬浮窗开着时音频设置归它管，这里不改，否则画中画可能被停掉
    nonisolated(unsafe) static var sessionLocked = false

    /// 完成音效 sfx_<n>.wav：跟随静音键，不打断别的 App 的音乐
    static func play(_ n: Int) {
        if !sessionReady && !sessionLocked {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            sessionReady = true
        }
        let p: AVAudioPlayer
        if let old = players[n] { p = old } else {
            guard let url = Bundle.main.url(forResource: "sfx_\(n)", withExtension: "wav"), let np = try? AVAudioPlayer(contentsOf: url) else { return }
            np.prepareToPlay(); players[n] = np; p = np
        }
        p.currentTime = 0
        p.volume = 0.9
        p.play()
    }

    /// 试听提醒铃声 tone_<n>.wav（静音键打开时也能听到）
    static func playTone(_ n: Int) {
        if !sessionLocked {
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            sessionReady = false
        }
        guard let url = Bundle.main.url(forResource: "tone_\(n)", withExtension: "wav"), let p = try? AVAudioPlayer(contentsOf: url) else { return }
        tonePlayer?.stop(); p.volume = 1; p.play(); tonePlayer = p
    }

    static func stopTone() { tonePlayer?.stop(); tonePlayer = nil }
}

// MARK: - 提醒通知：网页算好时间，这里排进系统

@MainActor
final class Notifier {
    static let shared = Notifier()
    private let center = UNUserNotificationCenter.current()

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func allowed() async -> Bool {
        let st = await center.notificationSettings()
        return st.authorizationStatus == .authorized || st.authorizationStatus == .provisional || st.authorizationStatus == .ephemeral
    }

    /// items：[{id, title, body, h, m, s?(秒，卡点的提醒要到秒), weekday?(1=周日…7=周六), date?("2026-10-26"), tone?(1…10), route?}]
    /// 有 date 的是一次性提醒；有 weekday 的是每周重复；都没有就是每天重复。iOS 最多保留 64 条，这里只排 60 条。
    func schedule(_ items: [[String: Any]]) async {
        center.removeAllPendingNotificationRequests()
        for it in items.prefix(60) {
            guard let id = it["id"] as? String, let h = (it["h"] as? NSNumber)?.intValue, let m = (it["m"] as? NSNumber)?.intValue else { continue }
            let ct = UNMutableNotificationContent()
            ct.title = it["title"] as? String ?? AppConfig.displayName
            ct.body = it["body"] as? String ?? ""
            if let r = it["route"] as? String { ct.userInfo = ["route": r] }
            if let t = (it["tone"] as? NSNumber)?.intValue, Bundle.main.url(forResource: "alm_\(t)", withExtension: "caf") != nil {
                ct.sound = UNNotificationSound(named: UNNotificationSoundName("alm_\(t).caf"))
            } else { ct.sound = .default }
            var dc = DateComponents()
            dc.hour = h; dc.minute = m
            if let sec = (it["s"] as? NSNumber)?.intValue { dc.second = sec }
            var repeats = true
            if let d = it["date"] as? String {
                let p = d.split(separator: "-").compactMap { Int($0) }
                if p.count == 3 { dc.year = p[0]; dc.month = p[1]; dc.day = p[2]; repeats = false }
            } else if let w = (it["weekday"] as? NSNumber)?.intValue { dc.weekday = w }
            try? await center.add(UNNotificationRequest(identifier: id, content: ct, trigger: UNCalendarNotificationTrigger(dateMatching: dc, repeats: repeats)))
        }
    }
}
