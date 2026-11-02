import AVKit
import AVFoundation
import CoreMedia
import CoreVideo
import UIKit

// MARK: - 悬浮时钟（系统画中画 cmd:'pip'）
// 用 AVSampleBufferDisplayLayer 把时钟画成视频帧交给系统画中画。位置和大小由系统决定，不承诺任意位置和透明度。
// 音频用 mixWithOthers，开启时不打断别的 App 的音乐。时间线和网页一样：
//   显示时间 = 手机时间 + 偏差 + 微调 + 补偿；倒计时 = 目标（已换算到手机时钟并含补偿）− 手机时间

final class PipClock: NSObject, AVPictureInPictureControllerDelegate, AVPictureInPictureSampleBufferPlaybackDelegate {
    static let shared = PipClock()
    var onLost: (() -> Void)?
    private(set) var active = false

    // 配置（网页传来）
    private var name = "", offset = 0.0, adj = 0.0, lead = 0.0
    private var shape = "std", msDigits = 1, alertSec = 10, mode = "clock", sound = false
    private var bg = UIColor.black, fg = UIColor.white, msColor = UIColor.white, alColor = UIColor.red
    private var target = 0.0, targetLabel = "", firedLabel = "已开抢", leadLabel = "", secUnit = "秒"

    private var host: UIView?
    private var layer: AVSampleBufferDisplayLayer?
    private var controller: AVPictureInPictureController?
    private var possibleObs: NSKeyValueObservation?
    private var timer: DispatchSourceTimer?
    private var pool: CVPixelBufferPool?
    private var poolSize = CGSize.zero
    private var format: CMVideoFormatDescription?
    private var lastKey = ""
    private var lastEnqueue = 0.0
    private var byUser = false
    private var pending: ((Bool) -> Void)?
    private var lastBeep: Int?

    // MARK: 命令

    func setTimeInfo(_ b: [String: Any]) {
        if let v = b["name"] as? String { name = v }
        if let v = (b["offset"] as? NSNumber)?.doubleValue { offset = v }
        if let v = (b["adj"] as? NSNumber)?.doubleValue { adj = v }
        if let v = (b["lead"] as? NSNumber)?.doubleValue { lead = v }
        lastKey = ""
    }

    func setConfig(_ b: [String: Any]) {
        if let v = b["shape"] as? String { shape = v }
        if let v = (b["msDigits"] as? NSNumber)?.intValue { msDigits = v }
        if let v = (b["alertSec"] as? NSNumber)?.intValue { alertSec = v }
        if let v = b["mode"] as? String { mode = v }
        if let v = b["sound"] as? Bool { sound = v }
        if let v = b["bg"] as? String { bg = Self.color(v) ?? bg }
        if let v = b["fg"] as? String { fg = Self.color(v) ?? fg }
        if let v = b["msColor"] as? String { msColor = Self.color(v) ?? msColor }
        if let v = b["al"] as? String { alColor = Self.color(v) ?? alColor }
        if let v = (b["target"] as? NSNumber)?.doubleValue { target = v }
        if let v = b["targetLabel"] as? String { targetLabel = v }
        if let v = b["firedLabel"] as? String { firedLabel = v }
        if let v = b["leadLabel"] as? String { leadLabel = v }
        if let v = b["secUnit"] as? String { secUnit = v }
        if active { restartTimer() }
        lastKey = ""
    }

    func start(_ done: @escaping (Bool) -> Void) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { done(false); return }
        if active { done(true); return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch { done(false); return }
        SFX.sessionLocked = true
        guard prepare() else { cleanup(); done(false); return }
        byUser = false
        pending = done
        restartTimer()
        tick()
        // 系统说「可以开」了再开；等太久算失败，不让按钮卡住
        possibleObs = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] c, _ in
            guard c.isPictureInPicturePossible else { return }
            DispatchQueue.main.async {
                guard let self, self.pending != nil else { return }
                self.possibleObs = nil
                self.controller?.startPictureInPicture()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, let p = self.pending else { return }
            self.pending = nil
            self.cleanup()
            Diag.add("悬浮窗 4 秒内没开起来")
            p(false)
        }
    }

    func stop() {
        byUser = true
        if let c = controller, c.isPictureInPictureActive { c.stopPictureInPicture() } else { cleanup() }
    }

    // MARK: 准备

    private func prepare() -> Bool {
        if controller != nil { return true }
        guard let win = UIApplication.topViewController()?.view.window else { return false }
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 50))
        v.isUserInteractionEnabled = false
        let l = AVSampleBufferDisplayLayer()
        l.frame = v.bounds
        l.videoGravity = .resizeAspect
        v.layer.addSublayer(l)
        win.insertSubview(v, at: 0) // 放在页面底下，用户看不到，但必须在窗口里
        host = v
        layer = l
        let src = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: l, playbackDelegate: self)
        let c = AVPictureInPictureController(contentSource: src)
        c.delegate = self
        c.requiresLinearPlayback = true
        c.canStartPictureInPictureAutomaticallyFromInline = false
        controller = c
        return true
    }

    private func cleanup() {
        timer?.cancel(); timer = nil
        possibleObs = nil
        controller = nil
        layer?.flush()
        layer = nil
        host?.removeFromSuperview(); host = nil
        pool = nil; format = nil; lastKey = ""; lastBeep = nil
        active = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        SFX.sessionLocked = false
    }

    private func restartTimer() {
        timer?.cancel()
        // 只在文字变化时才真的画一帧，这里的频率够跟上毫秒位就行
        let hz = msDigits >= 2 ? 30 : msDigits == 1 ? 15 : 8
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(1000 / hz), leeway: .milliseconds(4))
        t.setEventHandler { [weak self] in self?.tick() }
        t.resume()
        timer = t
    }

    // MARK: 每一帧

    private struct View { var main = "", ms = "", small = "", alert = false }

    private func compute(_ now: Double) -> View {
        let left: Double? = target > 0 ? target - now : nil
        var v = View()
        v.alert = left.map { alertSec > 0 && $0 > 0 && $0 <= Double(alertSec) * 1000 } ?? false
        if mode == "cd", let l = left, l > -60_000 {
            v.small = targetLabel
            if l <= 0 {
                v.main = "\(firedLabel) +\(String(format: "%.1f", -l / 1000))\(secUnit)"
                return v
            }
            let tot = Int(l / 1000), d = tot / 86400, h = tot % 86400 / 3600, m = tot % 3600 / 60, s = tot % 60
            if d > 0 { v.main = String(format: "%d天 %02d:%02d:%02d", d, h, m, s) }
            else if h > 0 { v.main = String(format: "%02d:%02d:%02d", h, m, s) }
            else { v.main = String(format: "%02d:%02d", m, s) }
            if d == 0 { v.ms = Self.msPart(l, msDigits) }
            return v
        }
        let t = now + offset + adj + lead
        let c = Calendar.current.dateComponents([.hour, .minute, .second], from: Date(timeIntervalSince1970: t / 1000))
        v.main = String(format: "%02d:%02d:%02d", c.hour ?? 0, c.minute ?? 0, c.second ?? 0)
        v.ms = Self.msPart(t, msDigits)
        v.small = name
        return v
    }

    private static func msPart(_ v: Double, _ n: Int) -> String {
        guard n > 0 else { return "" }
        let m = Int(v.truncatingRemainder(dividingBy: 1000).rounded(.down))
        return "." + String(String(format: "%03d", max(0, m)).prefix(n))
    }

    private func tick() {
        let now = Date().timeIntervalSince1970 * 1000
        beepIfNeeded(now)
        let v = compute(now)
        let key = "\(v.main)|\(v.ms)|\(v.small)|\(v.alert)|\(shape)"
        guard key != lastKey || now - lastEnqueue > 500 else { return }
        guard let l = layer else { return }
        if l.status == .failed { l.flush() }
        guard l.isReadyForMoreMediaData, let sb = makeFrame(v) else { return }
        l.enqueue(sb)
        lastKey = key
        lastEnqueue = now
    }

    private func beepIfNeeded(_ now: Double) {
        guard sound, target > 0 else { lastBeep = nil; return }
        let sc = Int(((target - now) / 1000).rounded(.up))
        guard sc != lastBeep else { return }
        if let lb = lastBeep {
            if sc > 0 && sc <= (alertSec > 0 ? alertSec : 10) { Beep.play(end: false) } else if lb == 1 && sc <= 0 { Beep.play(end: true) }
        }
        lastBeep = sc
    }

    private func sizeForShape() -> CGSize {
        switch shape {
        case "slim": return CGSize(width: 720, height: 180)
        case "thin": return CGSize(width: 720, height: 120)
        default: return CGSize(width: 720, height: 300)
        }
    }

    private func makeFrame(_ v: View) -> CMSampleBuffer? {
        let size = sizeForShape()
        if pool == nil || poolSize != size {
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height),
                kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any](),
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            ]
            var p: CVPixelBufferPool?
            CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &p)
            pool = p; poolSize = size; format = nil
        }
        guard let pool else { return nil }
        var pb: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pb)
        guard let buf = pb else { return nil }
        CVPixelBufferLockBaseAddress(buf, [])
        defer { CVPixelBufferUnlockBaseAddress(buf, []) }
        guard let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                                  bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else { return nil }
        ctx.translateBy(x: 0, y: size.height)
        ctx.scaleBy(x: 1, y: -1)
        UIGraphicsPushContext(ctx)
        draw(v, size: size, ctx: ctx)
        UIGraphicsPopContext()

        if format == nil {
            var f: CMVideoFormatDescription?
            CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buf, formatDescriptionOut: &f)
            format = f
        }
        guard let format else { return nil }
        var timing = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()), decodeTimeStamp: .invalid)
        var sb: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: buf, formatDescription: format, sampleTiming: &timing, sampleBufferOut: &sb)
        if let sb, let arr = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) {
            let d = unsafeBitCast(CFArrayGetValueAtIndex(arr, 0), to: CFMutableDictionary.self)
            CFDictionarySetValue(d, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(), Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
        }
        return sb
    }

    private func draw(_ v: View, size: CGSize, ctx: CGContext) {
        ctx.setFillColor(bg.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        let main = v.alert ? alColor : fg
        let msC = v.alert ? alColor : msColor
        let showSmall = shape != "thin"
        let h = size.height
        // 字号：先按形状定，放不下再缩，数字等宽所以跳动时不抖
        var pt: CGFloat = shape == "thin" ? h * 0.74 : shape == "slim" ? h * 0.56 : h * 0.44
        let padX: CGFloat = 28
        let reserve: CGFloat = shape == "slim" ? size.width * 0.2 : 0
        let avail = size.width - padX * 2 - reserve
        func text(_ p: CGFloat) -> NSAttributedString {
            let s = NSMutableAttributedString(string: v.main, attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: p, weight: .semibold), .foregroundColor: main])
            if !v.ms.isEmpty { s.append(NSAttributedString(string: v.ms, attributes: [.font: UIFont.monospacedDigitSystemFont(ofSize: p * 0.72, weight: .semibold), .foregroundColor: msC])) }
            return s
        }
        var t = text(pt)
        if t.size().width > avail { pt *= avail / t.size().width; t = text(pt) }
        let ts = t.size()
        let smallAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: shape == "slim" ? h * 0.2 : h * 0.14, weight: .medium), .foregroundColor: fg.withAlphaComponent(0.72)]
        switch shape {
        case "slim":
            t.draw(at: CGPoint(x: padX, y: (h - ts.height) / 2))
            let sm = NSAttributedString(string: v.small, attributes: smallAttrs)
            let ss = sm.size()
            sm.draw(in: CGRect(x: size.width - padX - min(ss.width, reserve), y: (h - ss.height) / 2, width: min(ss.width, reserve), height: ss.height))
        case "thin":
            t.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: (h - ts.height) / 2))
        default:
            if showSmall { NSAttributedString(string: v.small, attributes: smallAttrs).draw(at: CGPoint(x: padX, y: h * 0.1)) }
            if !leadLabel.isEmpty {
                let m = NSAttributedString(string: leadLabel, attributes: smallAttrs)
                m.draw(at: CGPoint(x: size.width - padX - m.size().width, y: h * 0.1))
            }
            t.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: h * 0.36 + (h * 0.58 - ts.height) / 2))
        }
    }

    /// #RRGGBB 或 rgba(r,g,b,a)。视频帧不能透明，一律不透明
    static func color(_ s: String) -> UIColor? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("#"), t.count == 7, let v = UInt32(t.dropFirst(), radix: 16) {
            return UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
        }
        if t.hasPrefix("rgb"), let a = t.firstIndex(of: "("), let b = t.firstIndex(of: ")") {
            let p = t[t.index(after: a)..<b].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if p.count >= 3 { return UIColor(red: p[0] / 255, green: p[1] / 255, blue: p[2] / 255, alpha: 1) }
        }
        return nil
    }

    // MARK: 系统回调

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        active = true
        pending?(true); pending = nil
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        Diag.add("悬浮窗开启失败：\(error.localizedDescription)")
        let p = pending; pending = nil
        cleanup()
        p?(false)
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        let user = byUser
        cleanup()
        if !user { onLost?() }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        completionHandler(true)
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool) {}
    func pictureInPictureControllerTimeRangeForPlayback(_ pictureInPictureController: AVPictureInPictureController) -> CMTimeRange {
        CMTimeRange(start: .negativeInfinity, duration: .positiveInfinity)
    }
    func pictureInPictureControllerIsPlaybackPaused(_ pictureInPictureController: AVPictureInPictureController) -> Bool { false }
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, didTransitionToRenderSize newRenderSize: CMVideoDimensions) {}
    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void) { completionHandler() }
}

// MARK: - 倒计时提示音：运行时生成，和别的音频混合

enum Beep {
    private static var players: [Bool: AVAudioPlayer] = [:]
    static func play(end: Bool) {
        if players[end] == nil, let p = try? AVAudioPlayer(data: wav(freq: end ? 1320 : 880, seconds: end ? 0.32 : 0.07, gain: end ? 0.4 : 0.22)) {
            p.prepareToPlay(); players[end] = p
        }
        players[end]?.currentTime = 0
        players[end]?.play()
    }
    private static func wav(freq: Double, seconds: Double, gain: Double) -> Data {
        let rate = 44100, n = Int(Double(rate) * seconds)
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); u32(UInt32(36 + n * 2)); d.append(contentsOf: Array("WAVEfmt ".utf8))
        u32(16); u16(1); u16(1); u32(UInt32(rate)); u32(UInt32(rate * 2)); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(UInt32(n * 2))
        for i in 0..<n {
            let t = Double(i) / Double(rate)
            let env = min(1, t / 0.005) * max(0, 1 - t / seconds)
            let v = sin(2 * .pi * freq * t) * env * gain * 32767
            withUnsafeBytes(of: Int16(v).littleEndian) { d.append(contentsOf: $0) }
        }
        return d
    }
}
