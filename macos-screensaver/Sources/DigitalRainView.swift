import ScreenSaver
import MetalKit

@objc(DigitalRainView)
final class DigitalRainView: ScreenSaverView {
    private var mtkView: MTKView?
    private var renderer: RainRenderer?
    private var settings = RainSettings.load()
    private var configSheetController: ConfigSheet?
    private var stopped = false
    private var pendingExit: DispatchWorkItem?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        animationTimeInterval = 1.0 / Double(settings.fps)
        wantsLayer = true
        guard let device = MTLCreateSystemDefaultDevice(),
              let r = RainRenderer(device: device, settings: settings) else { return }
        if isPreview { r.sizeScale = Float(max(0.2, bounds.width / 1440)) }

        // The view only draws when animateOneFrame asks, so the frame-rate setting
        // decides how often the GPU wakes, not the display's refresh rate.
        let v = MTKView(frame: bounds, device: device)
        v.autoresizingMask = [.width, .height]
        v.colorPixelFormat = .bgra8Unorm
        v.colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        v.framebufferOnly = true
        v.isPaused = true
        v.enableSetNeedsDisplay = false
        v.delegate = r
        addSubview(v)
        mtkView = v
        renderer = r

        // Since macOS Sonoma, the screen saver host can keep running after the saver is
        // dismissed, and it may reuse this view next time without calling startAnimation.
        // So drawing resumes on the system-wide "did start" signal, stops on "will stop",
        // and the host quits shortly after stopping unless the saver starts again first.
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(willStop(_:)),
                           name: Notification.Name("com.apple.screensaver.willstop"), object: nil)
        center.addObserver(self, selector: #selector(didStart(_:)),
                           name: Notification.Name("com.apple.screensaver.didstart"), object: nil)
        NSLog("DigitalRain: view created (preview: \(isPreview))")
    }

    private func resume(_ reason: String) {
        pendingExit?.cancel()
        pendingExit = nil
        stopped = false
        NSLog("DigitalRain: drawing resumed (\(reason))")
    }

    override func startAnimation() {
        super.startAnimation()
        resume("startAnimation")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { resume("moved to window") }
    }

    @objc private func didStart(_ note: Notification) {
        resume("didstart")
    }

    override func stopAnimation() {
        super.stopAnimation()
        stopped = true
    }

    override func animateOneFrame() {
        guard !stopped else { return }
        mtkView?.draw()
    }

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
    }

    @objc private func willStop(_ note: Notification) {
        stopped = true
        NSLog("DigitalRain: willstop received")
        guard !isPreview else { return }
        pendingExit?.cancel()
        let work = DispatchWorkItem {
            NSLog("DigitalRain: quitting screen saver host")
            exit(0)
        }
        pendingExit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    // MARK: Options sheet

    override var hasConfigureSheet: Bool { true }

    override var configureSheet: NSWindow? {
        let sheet = ConfigSheet(settings: settings) { [weak self] newSettings, commit in
            self?.apply(newSettings, save: commit)
        }
        configSheetController = sheet
        return sheet.window
    }

    private func apply(_ s: RainSettings, save: Bool) {
        settings = s
        if save { s.save() }
        renderer?.settings = s
        animationTimeInterval = 1.0 / Double(s.fps)
    }
}
