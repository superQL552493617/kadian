import UIKit
import PhotosUI
import Vision

// MARK: - 读 App 截图（cmd:'ocr'）
// 用户在平台 App 活动页截图，到卡点选这张图，手机本地识别文字，不上传、不碰平台接口。
// 用系统相册选择器，只拿到用户选的这一张，不要相册权限。
// 回传 {lines:[{text,top,h}]}（top、h 是占整张图高度的比例）；用户取消回传 {cancel:true}。

final class ScreenshotOCR: NSObject, PHPickerViewControllerDelegate {
    private static var current: ScreenshotOCR?
    private let done: ([String: Any]) -> Void

    private init(done: @escaping ([String: Any]) -> Void) { self.done = done }

    static func pick(done: @escaping ([String: Any]) -> Void) {
        guard let top = UIApplication.topViewController() else { done(["cancel": true]); return }
        var c = PHPickerConfiguration()
        c.filter = .screenshots
        c.selectionLimit = 1
        let p = PHPickerViewController(configuration: c)
        let me = ScreenshotOCR(done: done)
        current = me
        p.delegate = me
        top.present(p, animated: true)
    }

    private func finish(_ r: [String: Any]) {
        DispatchQueue.main.async {
            self.done(r)
            ScreenshotOCR.current = nil
        }
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { finish(["cancel": true]); return }
        item.loadObject(ofClass: UIImage.self) { [self] obj, _ in
            guard let cg = (obj as? UIImage)?.cgImage else { finish(["lines": [[String: Any]]()]); return }
            let req = VNRecognizeTextRequest { [self] r, _ in
                let obs = (r.results as? [VNRecognizedTextObservation]) ?? []
                let lines: [[String: Any]] = obs.compactMap { o in
                    guard let t = o.topCandidates(1).first?.string else { return nil }
                    return ["text": t, "top": 1 - o.boundingBox.maxY, "h": o.boundingBox.height]
                }.sorted { ($0["top"] as? CGFloat ?? 0) < ($1["top"] as? CGFloat ?? 0) }
                Diag.add("读截图 识别到 \(lines.count) 行")
                finish(["lines": lines])
            }
            req.recognitionLevel = .accurate
            req.recognitionLanguages = ["zh-Hans", "en-US"]
            req.usesLanguageCorrection = true
            DispatchQueue.global(qos: .userInitiated).async { [self] in
                do { try VNImageRequestHandler(cgImage: cg, options: [:]).perform([req]) } catch { finish(["lines": [[String: Any]]()]) }
            }
        }
    }
}
