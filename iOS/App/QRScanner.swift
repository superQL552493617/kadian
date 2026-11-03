import UIKit
import AVFoundation
import PhotosUI
import CoreImage
import Vision

// MARK: - 扫码（cmd:'scan'）
// 点了才要相机权限；可从相册识别（系统选择器，不要整库权限）。只把内容交给网页，不自动打开。
// 结果：{text} 扫到了；{cancel:true} 用户关掉了。

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, PHPickerViewControllerDelegate {
    var onDone: (([String: Any]) -> Void)?
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "kadian.scan")
    private let msg = UILabel()
    private var finished = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let close = UIButton(type: .system)
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = .white
        close.accessibilityLabel = L("关闭")
        close.addTarget(self, action: #selector(tapClose), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false

        let frameView = UIView()
        frameView.layer.borderColor = UIColor.white.cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 18
        frameView.isUserInteractionEnabled = false
        frameView.translatesAutoresizingMaskIntoConstraints = false

        msg.text = L("正在打开相机…")
        msg.textColor = .white
        msg.font = .systemFont(ofSize: 15)
        msg.numberOfLines = 0
        msg.textAlignment = .center
        msg.translatesAutoresizingMaskIntoConstraints = false

        var cfg = UIButton.Configuration.filled()
        cfg.title = L("从相册选")
        cfg.baseBackgroundColor = UIColor(white: 1, alpha: 0.18)
        cfg.baseForegroundColor = .white
        cfg.cornerStyle = .capsule
        let pick = UIButton(configuration: cfg)
        pick.addTarget(self, action: #selector(tapAlbum), for: .touchUpInside)
        pick.translatesAutoresizingMaskIntoConstraints = false

        [frameView, close, msg, pick].forEach { view.addSubview($0) }
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            close.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            close.widthAnchor.constraint(equalToConstant: 44), close.heightAnchor.constraint(equalToConstant: 44),
            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            frameView.widthAnchor.constraint(equalToConstant: 250), frameView.heightAnchor.constraint(equalToConstant: 250),
            msg.topAnchor.constraint(equalTo: frameView.bottomAnchor, constant: 24),
            msg.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            msg.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            pick.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            pick.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pick.heightAnchor.constraint(equalToConstant: 46),
        ])

        AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
            DispatchQueue.main.async { if ok { self?.startCamera() } else { self?.cameraOff() } }
        }
    }

    private func cameraOff() { msg.text = L("相机没打开。可以从相册选，或去系统设置打开相机权限。") }

    private func startCamera() {
        guard let dev = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: dev), session.canAddInput(input) else { cameraOff(); return }
        session.addInput(input)
        let out = AVCaptureMetadataOutput()
        guard session.canAddOutput(out) else { cameraOff(); return }
        session.addOutput(out)
        out.setMetadataObjectsDelegate(self, queue: .main)
        out.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        msg.text = L("把二维码放进框里")
        queue.async { [session] in session.startRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let s = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue, !s.isEmpty else { return }
        finish(["text": s])
    }

    @objc private func tapClose() { finish(["cancel": true]) }

    @objc private func tapAlbum() {
        var c = PHPickerConfiguration()
        c.filter = .images
        c.selectionLimit = 1
        let p = PHPickerViewController(configuration: c)
        p.delegate = self
        present(p, animated: true)
    }

    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else { return }
        item.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
            let code = (obj as? UIImage).flatMap { Self.decode($0) }
            DispatchQueue.main.async {
                if let code { self?.finish(["text": code]) } else { self?.msg.text = L("这张图里没找到二维码") }
            }
        }
    }

    /// 海报角落的小二维码（带 Logo）整张识别不出来：先整张试，再把图切块放大逐块试
    private static func decode(_ img: UIImage) -> String? {
        guard let cg = img.cgImage else { return nil }
        if let t = vision(cg) ?? detector(cg) { return t }
        let w = CGFloat(cg.width), h = CGFloat(cg.height)
        // 右下角优先，海报的二维码最常在那里
        for n in [2, 3] {
            let cw = w / CGFloat(n), ch = h / CGFloat(n)
            for row in (0..<n).reversed() {
                for col in (0..<n).reversed() {
                    // 每块多切一点，二维码跨在分界线上也能完整
                    let rect = CGRect(x: CGFloat(col) * cw - cw * 0.15, y: CGFloat(row) * ch - ch * 0.15, width: cw * 1.3, height: ch * 1.3)
                        .intersection(CGRect(x: 0, y: 0, width: w, height: h)).integral
                    guard let part = cg.cropping(to: rect), let big = enlarge(part, by: 3) else { continue }
                    if let t = vision(big) ?? detector(big) { return t }
                }
            }
        }
        return nil
    }

    private static func vision(_ cg: CGImage) -> String? {
        let req = VNDetectBarcodesRequest()
        req.symbologies = [.qr]
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([req])
        return req.results?.compactMap { $0.payloadStringValue }.first
    }

    private static func detector(_ cg: CGImage) -> String? {
        let det = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
        return det?.features(in: CIImage(cgImage: cg)).compactMap { ($0 as? CIQRCodeFeature)?.messageString }.first
    }

    private static func enlarge(_ cg: CGImage, by k: CGFloat) -> CGImage? {
        let size = CGSize(width: min(CGFloat(cg.width) * k, 3000), height: min(CGFloat(cg.height) * k, 3000))
        let f = UIGraphicsImageRendererFormat(); f.scale = 1
        return UIGraphicsImageRenderer(size: size, format: f).image { _ in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }

    private func finish(_ r: [String: Any]) {
        guard !finished else { return }
        finished = true
        queue.async { [session] in session.stopRunning() }
        dismiss(animated: true) { [onDone] in onDone?(r) }
    }
}
