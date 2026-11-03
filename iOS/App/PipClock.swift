import AVKit
import AVFoundation
import CoreMedia
import CoreVideo
import UIKit

// MARK: - 悬浮时钟（系统画中画 cmd:'pip'）
// 用 AVSampleBufferDisplayLayer 把时钟画成视频帧交给系统画中画。位置和大小由系统决定，不承诺任意位置和透明度。
// 音频用 mixWithOthers，开启时不打断别的 App 的音乐。时间线和网页一样：
//   显示时间 = 手机时间 + 偏差 + 微调 + 补偿；倒计时 = 目标（已换算到手机时钟并含补偿）− 手机时间

/// 通话式画中画的内容：系统只显示关闭和回到 App 两个按钮，没有快退快进和播放键
final class PipCallVC: AVPictureInPictureVideoCallViewController {
    var inner: CALayer?
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        inner?.frame = view.bounds
    }
}

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
    private var beginId = UUID()
    /// 用户点了回到 App：这次关闭不算关悬浮窗，一切保留，退出 App 时系统自动再开
    private var restoring = false
    /// 后面几场（JS 在后台不运行，所以提前交过来，到点后原生自己换下一场）
    private var targets: [(at: Double, label: String, name: String, when: String, plat: String)] = []
    private var targetPlat = ""
    private var callVC: PipCallVC?
    private var usedCall = false
    private var targetName = "", targetWhen = "", cdLabel = "倒计时", whenLabel = "开抢时间"
    private var subColor = UIColor.gray, pillColor = UIColor.white, lineColor = UIColor.lightGray

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
        if let v = b["targetName"] as? String { targetName = v }
        if let v = b["targetWhen"] as? String { targetWhen = v }
        if let v = b["targetPlat"] as? String { targetPlat = v }
        if let v = b["cdLabel"] as? String { cdLabel = v }
        if let v = b["whenLabel"] as? String { whenLabel = v }
        if let v = b["sub"] as? String { subColor = Self.color(v) ?? subColor }
        if let v = b["pill"] as? String { pillColor = Self.color(v) ?? pillColor }
        if let v = b["line"] as? String { lineColor = Self.color(v) ?? lineColor }
        if let v = b["targets"] as? [[String: Any]] {
            targets = v.compactMap { d in
                guard let a = (d["at"] as? NSNumber)?.doubleValue else { return nil }
                return (a, d["label"] as? String ?? "", d["name"] as? String ?? "", d["when"] as? String ?? "", d["plat"] as? String ?? "")
            }
        }
        if let v = b["firedLabel"] as? String { firedLabel = v }
        if let v = b["leadLabel"] as? String { leadLabel = v }
        if let v = b["secUnit"] as? String { secUnit = v }
        if active { restartTimer() }
        callVC?.preferredContentSize = sizeForShape()
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
        guard prepare(call: true) else { cleanup(); done(false); return }
        byUser = false
        pending = done
        restartTimer()
        tick()
        begin(fallback: true)
    }

    /// 系统说「可以开」了再开；通话式开不起来就退回普通画中画（有快退快进按钮），再不行才算失败
    private func begin(fallback: Bool) {
        let gen = UUID(); beginId = gen
        possibleObs = controller?.observe(\.isPictureInPicturePossible, options: [.initial, .new]) { [weak self] c, _ in
            guard c.isPictureInPicturePossible else { return }
            DispatchQueue.main.async {
                guard let self, self.pending != nil, self.beginId == gen else { return }
                self.possibleObs = nil
                self.controller?.startPictureInPicture()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self, self.beginId == gen, !self.active, self.pending != nil else { return }
            self.startFailed(fallback: fallback, why: "3 秒内没开起来")
        }
    }

    private func startFailed(fallback: Bool, why: String) {
        Diag.add("悬浮窗 \(usedCall ? "通话式" : "普通") \(why)")
        possibleObs = nil
        if fallback, usedCall {
            controller = nil; callVC = nil; layer?.removeFromSuperlayer(); layer = nil; host?.removeFromSuperview(); host = nil
            pool = nil; format = nil; lastKey = ""
            if prepare(call: false) { tick(); begin(fallback: false); return }
        }
        let p = pending; pending = nil
        cleanup()
        p?(false)
    }

    func stop() {
        byUser = true
        if let c = controller, c.isPictureInPictureActive { c.stopPictureInPicture() } else { cleanup() }
    }

    // MARK: 准备

    private func prepare(call: Bool) -> Bool {
        if controller != nil { return true }
        guard let win = UIApplication.topViewController()?.view.window else { return false }
        let v = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 50))
        v.isUserInteractionEnabled = false
        let l = AVSampleBufferDisplayLayer()
        l.frame = v.bounds
        l.videoGravity = .resizeAspectFill
        win.insertSubview(v, at: 0) // 放在页面底下，用户看不到，但必须在窗口里
        host = v
        layer = l
        let src: AVPictureInPictureController.ContentSource
        if call {
            let vc = PipCallVC()
            vc.preferredContentSize = sizeForShape()
            vc.view.layer.addSublayer(l)
            vc.inner = l
            callVC = vc
            src = AVPictureInPictureController.ContentSource(activeVideoCallSourceView: v, contentViewController: vc)
        } else {
            v.layer.addSublayer(l)
            src = AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer: l, playbackDelegate: self)
        }
        usedCall = call
        Diag.add("悬浮窗 用\(call ? "通话式" : "普通")画中画")
        let c = AVPictureInPictureController(contentSource: src)
        c.delegate = self
        if !call { c.requiresLinearPlayback = true }
        c.canStartPictureInPictureAutomaticallyFromInline = true
        controller = c
        return true
    }

    private func cleanup() {
        timer?.cancel(); timer = nil
        possibleObs = nil
        controller = nil
        callVC = nil
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

    private struct View { var main = "", ms = "", small = "", alert = false, card = false }

    private func compute(_ now: Double) -> View {
        // 上一场到点超过 60 秒，换下一场
        if let n = targets.first(where: { $0.at - now > -60_000 }), n.at != target {
            target = n.at; targetLabel = n.label; targetName = n.name; targetWhen = n.when; targetPlat = n.plat; lastBeep = nil
        }
        let left: Double? = target > 0 ? target - now : nil
        var v = View()
        v.alert = left.map { alertSec > 0 && $0 > 0 && $0 <= Double(alertSec) * 1000 } ?? false
        if mode == "cd", let l = left, l > -60_000 {
            v.small = targetLabel
            v.card = true
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
        let key = "\(v.main)|\(v.ms)|\(v.small)|\(v.alert)|\(shape)|\(targetName)|\(targetWhen)|\(targetPlat)"
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
        case "slim": return CGSize(width: 720, height: 160)
        case "thin": return CGSize(width: 720, height: 120)
        default: return CGSize(width: 828, height: 360) // 样式 A 插画卡（老板 2026-11-02 选定），比例 2.3:1
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
        if shape != "slim" && shape != "thin" && v.card { drawCard(v, size: size, ctx: ctx); return }
        let main = v.alert ? alColor : fg
        let msC = v.alert ? alColor : msColor
        let showSmall = shape != "thin"
        let h = size.height
        // 字号：先按形状定，放不下再缩，数字等宽所以跳动时不抖
        var pt: CGFloat = shape == "thin" ? h * 0.74 : shape == "slim" ? h * 0.54 : h * 0.42
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
            if showSmall {
                let sm = NSAttributedString(string: v.small, attributes: smallAttrs)
                sm.draw(with: CGRect(x: padX, y: h * 0.1, width: size.width - padX * 2, height: h * 0.2), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
            }
            if !leadLabel.isEmpty {
                let m = NSAttributedString(string: leadLabel, attributes: smallAttrs)
                m.draw(at: CGPoint(x: size.width - padX - m.size().width, y: h * 0.1))
            }
            t.draw(at: CGPoint(x: (size.width - ts.width) / 2, y: h * 0.36 + (h * 0.58 - ts.height) / 2))
        }
    }

    /// 样式 A：名称 + 倒计时 + 开抢时间框 + 卡点自己画的小秒表
    private func drawCard(_ v: View, size: CGSize, ctx: CGContext) {
        let w = size.width, h = size.height, pad = w * 0.05
        let ink = v.alert ? alColor : fg
        // 秒表
        let dark = lumi(bg) < 0.3
        let m = h * 0.34, mx = w - pad - m, my = h * 0.05, u = m / 100
        let face = CGRect(x: mx + 14 * u, y: my + 22 * u, width: 72 * u, height: 72 * u)
        ctx.setFillColor(fg.cgColor)
        UIBezierPath(roundedRect: CGRect(x: mx + 41 * u, y: my + 4 * u, width: 18 * u, height: 10 * u), cornerRadius: 4 * u).fill()
        ctx.fill(CGRect(x: mx + 46 * u, y: my + 12 * u, width: 8 * u, height: 10 * u))
        ctx.setStrokeColor(fg.cgColor); ctx.setLineCap(.round); ctx.setLineWidth(7 * u)
        ctx.move(to: CGPoint(x: mx + 78 * u, y: my + 20 * u)); ctx.addLine(to: CGPoint(x: mx + 86 * u, y: my + 28 * u)); ctx.strokePath()
        ctx.setFillColor(UIColor.white.cgColor); ctx.fillEllipse(in: face)
        ctx.setLineWidth(6 * u); ctx.strokeEllipse(in: face)
        let feat = dark ? UIColor(red: 0.06, green: 0.07, blue: 0.08, alpha: 1) : fg
        ctx.setFillColor(feat.cgColor)
        for x in [38.0, 62.0] { ctx.fillEllipse(in: CGRect(x: mx + (x - 4.5) * u, y: my + 49.5 * u, width: 9 * u, height: 9 * u)) }
        ctx.setStrokeColor(feat.cgColor); ctx.setLineWidth(4 * u)
        ctx.move(to: CGPoint(x: mx + 43 * u, y: my + 66 * u)); ctx.addQuadCurve(to: CGPoint(x: mx + 57 * u, y: my + 66 * u), control: CGPoint(x: mx + 50 * u, y: my + 73 * u)); ctx.strokePath()
        ctx.setFillColor(msColor.withAlphaComponent(0.55).cgColor)
        for x in [30.0, 70.0] { ctx.fillEllipse(in: CGRect(x: mx + (x - 5) * u, y: my + 59 * u, width: 10 * u, height: 10 * u)) }
        // 平台
        NSAttributedString(string: targetPlat, attributes: [.font: UIFont.systemFont(ofSize: h * 0.07, weight: .semibold), .foregroundColor: subColor]).draw(at: CGPoint(x: pad, y: h * 0.07))
        // 名称
        let para = NSMutableParagraphStyle(); para.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: targetName, attributes: [.font: UIFont.systemFont(ofSize: h * 0.1, weight: .bold), .foregroundColor: ink, .paragraphStyle: para])
            .draw(with: CGRect(x: pad, y: h * 0.19, width: mx - pad - w * 0.02, height: h * 0.14), options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
        // 开抢时间框
        let pw = w * 0.25, ph = h * 0.33, px = w - pw - w * 0.04, py = h - ph - h * 0.08
        let box = UIBezierPath(roundedRect: CGRect(x: px, y: py, width: pw, height: ph), cornerRadius: h * 0.07)
        pillColor.setFill(); box.fill()
        lineColor.setStroke(); box.lineWidth = 2; box.stroke()
        let center = NSMutableParagraphStyle(); center.alignment = .center; center.lineBreakMode = .byTruncatingTail
        NSAttributedString(string: whenLabel, attributes: [.font: UIFont.systemFont(ofSize: h * 0.06, weight: .medium), .foregroundColor: subColor, .paragraphStyle: center])
            .draw(in: CGRect(x: px + 6, y: py + ph * 0.14, width: pw - 12, height: ph * 0.34))
        NSAttributedString(string: targetWhen, attributes: [.font: UIFont.systemFont(ofSize: h * 0.075, weight: .bold), .foregroundColor: ink, .paragraphStyle: center])
            .draw(in: CGRect(x: px + 6, y: py + ph * 0.5, width: pw - 12, height: ph * 0.4))
        // 倒计时
        NSAttributedString(string: cdLabel, attributes: [.font: UIFont.systemFont(ofSize: h * 0.065, weight: .regular), .foregroundColor: subColor]).draw(at: CGPoint(x: pad, y: h * 0.56))
        let avail = px - pad - w * 0.02
        func num(_ p: CGFloat) -> NSAttributedString {
            let s = NSMutableAttributedString(string: v.main, attributes: [.font: UIFont.monospacedSystemFont(ofSize: p, weight: .bold), .foregroundColor: ink])
            if !v.ms.isEmpty { s.append(NSAttributedString(string: v.ms, attributes: [.font: UIFont.monospacedSystemFont(ofSize: p * 0.72, weight: .bold), .foregroundColor: v.alert ? alColor : msColor])) }
            return s
        }
        var pt = h * 0.21
        var t = num(pt)
        if t.size().width > avail { pt *= avail / t.size().width; t = num(pt) }
        t.draw(at: CGPoint(x: pad, y: h * 0.92 - t.size().height))
    }

    private func lumi(_ c: UIColor) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return 0.3 * r + 0.59 * g + 0.11 * b
    }

    /// #RRGGBB 或 rgba(r,g,b,a)
    static func color(_ s: String) -> UIColor? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("#"), t.count == 7, let v = UInt32(t.dropFirst(), radix: 16) {
            return UIColor(red: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
        }
        if t.hasPrefix("rgb"), let a = t.firstIndex(of: "("), let b = t.firstIndex(of: ")") {
            let p = t[t.index(after: a)..<b].split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            if p.count >= 3 { return UIColor(red: p[0] / 255, green: p[1] / 255, blue: p[2] / 255, alpha: p.count >= 4 ? p[3] : 1) }
        }
        return nil
    }

    // MARK: 系统回调

    func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        active = true
        pending?(true); pending = nil
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, failedToStartPictureInPictureWithError error: Error) {
        startFailed(fallback: true, why: "开启失败：\(error.localizedDescription)")
    }

    func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        if restoring {
            restoring = false
            Diag.add("悬浮窗 回到 App，退出时自动再开")
            return
        }
        let user = byUser
        cleanup()
        if !user { onLost?() }
    }

    func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        restoring = true
        // 不等界面，也不让窗口飞回 App 里（老板觉得这段动画不流畅）。实际效果要真机看
        completionHandler(false)
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
