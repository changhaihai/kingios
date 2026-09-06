import UIKit

/// 1:1 port of the Android SettingsWindowService.
final class SettingsWindow {
    static let shared = SettingsWindow()

    private var panelWindow: UIWindow?
    private var panelVC: SettingsPanelViewController?
    private var ballWindow: UIWindow?
    private var calibrationWindow: UIWindow?
    private var calibrationView: CalibrationView?
    private(set) var calibrationScale: CGFloat = 1

    func show() {
        guard panelWindow == nil else { return }
        hideBall()
        let vc = SettingsPanelViewController()
        vc.onHide = { [weak self] in self?.hidePanel(showBallAfter: true) }
        vc.onSettingsChanged = { [weak self] in self?.pushSettings() }
        vc.onSpacingChanged = { [weak self] in
            guard let self = self, self.calibrationWindow != nil else { return }
            self.hideCalibration()
            self.showCalibration()
        }
        vc.onCalibrationToggle = { [weak self] in
            guard let self = self else { return }
            if self.calibrationWindow == nil {
                self.showCalibration()
            } else {
                self.hideCalibration()
            }
        }
        vc.onResolutionFit = { [weak self] _, _, mode in
            guard let self = self else { return }
            if self.calibrationWindow != nil {
                self.hideCalibration()
                self.showCalibration()
            }
            self.showToast("分辨率适配完成  \(mode)")
        }
        let frame = panelFrame()
        let w = UIWindow(frame: frame)
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            w.windowScene = scene
        }
        w.windowLevel = UIWindow.Level.alert + 20
        w.rootViewController = vc
        w.backgroundColor = .clear
        w.isHidden = false
        panelWindow = w
        panelVC = vc
    }

    func stop() {
        hidePanel(showBallAfter: false)
        hideBall()
        hideCalibration()
    }

    func securityChanged() {}

    private func pushSettings() {
        OverlaySession.shared.applySettings()
        OverlaySession.shared.applyTopInfoVisibility()
    }

    private func panelFrame() -> CGRect {
        let bounds = UIScreen.main.bounds
        let widthDp = min(bounds.width * 0.72, 340)
        let heightDp = min(max(bounds.height * 0.42, 300), 360)
        let safeWidth = min(max(widthDp, 240), max(bounds.width - 24, 240))
        let safeHeight = min(max(heightDp, 230), max(bounds.height - 84, 230))
        return CGRect(x: 12, y: 72, width: safeWidth, height: safeHeight)
    }

    private func hidePanel(showBallAfter: Bool) {
        panelVC?.stopPolling()
        panelWindow?.isHidden = true
        panelWindow = nil
        panelVC = nil
        if showBallAfter { showBall() }
    }

    private func showBall() {
        guard ballWindow == nil else { return }
        let size: CGFloat = 38
        let view = BallView(size: size)
        view.onTap = { [weak self] in self?.show() }
        let w = UIWindow(frame: CGRect(x: 14, y: 80, width: size, height: size))
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            w.windowScene = scene
        }
        w.windowLevel = UIWindow.Level.alert + 20
        let vc = UIViewController()
        vc.view = view
        w.rootViewController = vc
        w.backgroundColor = .clear
        w.isHidden = false
        ballWindow = w
    }

    private func hideBall() {
        ballWindow?.isHidden = true
        ballWindow = nil
    }

    private func showCalibration() {
        guard calibrationWindow == nil else { return }
        let bounds = UIScreen.main.bounds
        let mapFactor = CGFloat(min(max(1 + AppPrefs.shared.float("map_spacing", 0) / 100, 0.5), 2))
        let calScale = min(bounds.width / 2400, bounds.height / 1080)
        calibrationScale = calScale
        let maxFrameSize = max(min(bounds.width, bounds.height), 80)
        let frameSize = min(max(340 * mapFactor * calScale, 80), maxFrameSize)
        let xPref = CGFloat(AppPrefs.shared.float("x", 0))
        let yPref = CGFloat(AppPrefs.shared.float("y", 0))
        var x = (xPref + 170 * (1 - mapFactor)) * calScale
        var y = (yPref + 170 * (1 - mapFactor)) * calScale
        x = min(max(x, 0), max(bounds.width - frameSize, 0))
        y = min(max(y, 0), max(bounds.height - frameSize, 0))

        let view = CalibrationView(frame: CGRect(x: 0, y: 0, width: frameSize, height: frameSize))
        let vc = UIViewController()
        vc.view = view
        let w = UIWindow(frame: CGRect(x: x, y: y, width: frameSize, height: frameSize))
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            w.windowScene = scene
        }
        w.windowLevel = UIWindow.Level.alert + 15
        w.rootViewController = vc
        w.backgroundColor = .clear
        w.isHidden = false
        view.onGeometryChange = { [weak self, weak w] _, finished in
            guard let self = self, let w = w, finished else { return }
            self.saveCalibration(w.frame)
        }
        calibrationWindow = w
        calibrationView = view
        panelVC?.setCalibrationButtonTitle("关闭校准框")
    }

    private func hideCalibration() {
        calibrationWindow?.isHidden = true
        calibrationWindow = nil
        calibrationView = nil
        panelVC?.setCalibrationButtonTitle("显示校准框")
    }

    var hasCalibration: Bool { calibrationView != nil }

    private func saveCalibration(_ frame: CGRect) {
        let calScale = calibrationScale
        guard calScale > 0 else { return }
        let currentFactor = min(max(frame.width / (340 * calScale), 0.5), 2)
        AppPrefs.shared.setFloat("x", Float(frame.origin.x / calScale - 170 * (1 - currentFactor)))
        AppPrefs.shared.setFloat("y", Float(frame.origin.y / calScale - 170 * (1 - currentFactor)))
        AppPrefs.shared.setFloat("map_spacing", Float((currentFactor - 1) * 100))
        pushSettings()
        panelVC?.syncSpacingSlider(Int((currentFactor - 1) * 100))
    }

    func showToast(_ text: String) {
        guard let window = panelWindow, let root = window.rootViewController?.view else { return }
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 11)
        label.textColor = Theme.textPrimary
        label.backgroundColor = Theme.cardHeader.withAlphaComponent(0.96)
        label.layer.cornerRadius = 6
        label.clipsToBounds = true
        label.textAlignment = .center
        label.alpha = 0
        let textWidth = (text as NSString).size(withAttributes: [.font: label.font]).width
        let width = min(max(textWidth + 24, 60), root.bounds.width - 16)
        label.frame = CGRect(x: (root.bounds.width - width) / 2, y: 8, width: width, height: 28)
        root.addSubview(label)
        UIView.animate(withDuration: 0.2, animations: { label.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.6, options: [], animations: { label.alpha = 0 }) { _ in
                label.removeFromSuperview()
            }
        }
    }
}

private final class BallView: UIView {
    var onTap: (() -> Void)?
    private var startOrigin = CGPoint.zero
    private var startTouch = CGPoint.zero
    private var moved = false

    init(size: CGFloat) {
        super.init(frame: CGRect(x: 0, y: 0, width: size, height: size))
        backgroundColor = Theme.cardBg
        layer.cornerRadius = size / 2
        layer.borderWidth = 1
        layer.borderColor = Theme.border.cgColor
        let label = UILabel(frame: bounds)
        label.text = "王"
        label.font = .boldSystemFont(ofSize: 14)
        label.textColor = Theme.gold
        label.textAlignment = .center
        addSubview(label)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let w = window else { return }
        let b = UIScreen.main.bounds
        switch g.state {
        case .began:
            startOrigin = w.frame.origin
            startTouch = g.location(in: nil)
            moved = false
        case .changed:
            let loc = g.location(in: nil)
            let dx = loc.x - startTouch.x
            let dy = loc.y - startTouch.y
            if abs(dx) > 4 || abs(dy) > 4 { moved = true }
            var origin = CGPoint(x: startOrigin.x + dx, y: startOrigin.y + dy)
            origin.x = min(max(origin.x, 0), max(b.width - w.frame.width, 0))
            origin.y = min(max(origin.y, 0), max(b.height - w.frame.height, 0))
            w.frame.origin = origin
        case .ended:
            if !moved { onTap?() }
        default:
            break
        }
    }
}

private final class CalibrationView: UIView {
    var onGeometryChange: ((CGRect, Bool) -> Void)?
    private var startFrame = CGRect.zero
    private var startTouch = CGPoint.zero
    private var resizing = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func handlePan(_ g: UIPanGestureRecognizer) {
        guard let w = window else { return }
        let b = UIScreen.main.bounds
        let grip: CGFloat = 36
        switch g.state {
        case .began:
            startFrame = w.frame
            startTouch = g.location(in: nil)
            let local = g.location(in: self)
            resizing = local.x >= bounds.width - grip && local.y >= bounds.height - grip
        case .changed:
            let loc = g.location(in: nil)
            let dx = loc.x - startTouch.x
            let dy = loc.y - startTouch.y
            var frame = w.frame
            if resizing {
                let delta = abs(dx) >= abs(dy) ? dx : dy
                let calScale = SettingsWindow.shared.calibrationScale
                let minSize = max(340 * 0.5 * calScale, 80)
                let maxSize = min(340 * 2 * calScale, min(b.width, b.height))
                let size = min(max(startFrame.width + delta, minSize), maxSize)
                frame.size = CGSize(width: size, height: size)
            } else {
                frame.origin = CGPoint(x: startFrame.origin.x + dx, y: startFrame.origin.y + dy)
            }
            frame.origin.x = min(max(frame.origin.x, 0), max(b.width - frame.width, 0))
            frame.origin.y = min(max(frame.origin.y, 0), max(b.height - frame.height, 0))
            w.frame = frame
            onGeometryChange?(frame, false)
        case .ended, .cancelled:
            onGeometryChange?(w.frame, true)
        default:
            break
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        let border = Theme.green
        ctx.clear(rect)
        ctx.setFillColor(border.withAlphaComponent(28/255.0).cgColor)
        ctx.fill(rect.insetBy(dx: 1, dy: 1))
        ctx.setStrokeColor(border.cgColor)
        ctx.setLineWidth(3)
        ctx.stroke(rect.insetBy(dx: 1, dy: 1))

        let mark: CGFloat = 14
        ctx.move(to: CGPoint(x: 0, y: 0)); ctx.addLine(to: CGPoint(x: mark, y: 0))
        ctx.move(to: CGPoint(x: 0, y: 0)); ctx.addLine(to: CGPoint(x: 0, y: mark))
        ctx.move(to: CGPoint(x: bounds.width, y: 0)); ctx.addLine(to: CGPoint(x: bounds.width - mark, y: 0))
        ctx.move(to: CGPoint(x: bounds.width, y: 0)); ctx.addLine(to: CGPoint(x: bounds.width, y: mark))
        ctx.move(to: CGPoint(x: 0, y: bounds.height)); ctx.addLine(to: CGPoint(x: mark, y: bounds.height))
        ctx.move(to: CGPoint(x: 0, y: bounds.height)); ctx.addLine(to: CGPoint(x: 0, y: bounds.height - mark))
        ctx.move(to: CGPoint(x: bounds.width, y: bounds.height)); ctx.addLine(to: CGPoint(x: bounds.width - mark, y: bounds.height))
        ctx.move(to: CGPoint(x: bounds.width, y: bounds.height)); ctx.addLine(to: CGPoint(x: bounds.width, y: bounds.height - mark))
        ctx.strokePath()

        let grip: CGFloat = 22
        ctx.setFillColor(border.cgColor)
        ctx.fill(CGRect(x: bounds.width - grip, y: bounds.height - grip, width: grip, height: grip))
        ctx.setStrokeColor(UIColor.white.cgColor)
        ctx.setLineWidth(1.5)
        ctx.move(to: CGPoint(x: bounds.width - grip * 0.72, y: bounds.height - grip * 0.18))
        ctx.addLine(to: CGPoint(x: bounds.width - grip * 0.18, y: bounds.height - grip * 0.72))
        ctx.move(to: CGPoint(x: bounds.width - grip * 0.48, y: bounds.height - grip * 0.12))
        ctx.addLine(to: CGPoint(x: bounds.width - grip * 0.12, y: bounds.height - grip * 0.48))
        ctx.strokePath()
    }
}

private struct AutoFitPreset {
    let width: Int
    let height: Int
    let heroX: Double
    let heroY: Double
    let heroSize: Int
    let mapGap: Int

    static let all: [AutoFitPreset] = [
        AutoFitPreset(width: 2376, height: 1080, heroX: 31, heroY: 9, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 3200, height: 1440, heroX: 90, heroY: 16, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2712, height: 1220, heroX: 62, heroY: 12, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2400, height: 1080, heroX: 31, heroY: 9, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2560, height: 1600, heroX: 90, heroY: 16, heroSize: 0, mapGap: -5),
        AutoFitPreset(width: 3192, height: 1368, heroX: 159, heroY: 19, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2340, height: 1080, heroX: 12, heroY: 10, heroSize: -2, mapGap: 0),
        AutoFitPreset(width: 2800, height: 1800, heroX: 73, heroY: 9, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2460, height: 1080, heroX: 159, heroY: 19, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2670, height: 1200, heroX: 45, heroY: 10, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 3168, height: 1440, heroX: 73, heroY: 16, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2800, height: 1968, heroX: -140, heroY: 19, heroSize: -67, mapGap: 0),
        AutoFitPreset(width: 2160, height: 1080, heroX: -77, heroY: 8, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2780, height: 1264, heroX: 54, heroY: 11, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2800, height: 1272, heroX: 55, heroY: 12, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2640, height: 1216, heroX: 28, heroY: 12, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2772, height: 1240, heroX: 70, heroY: 10, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2772, height: 1272, heroX: 42, heroY: 15, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2480, height: 1116, heroX: 47, heroY: 11, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 3216, height: 1440, heroX: -29, heroY: 49, heroSize: -1, mapGap: 2),
        AutoFitPreset(width: 3392, height: 2400, heroX: -30, heroY: 20, heroSize: -8, mapGap: -31),
        AutoFitPreset(width: 2608, height: 1200, heroX: 30, heroY: 10, heroSize: 0, mapGap: 0),
        AutoFitPreset(width: 2656, height: 1220, heroX: 36, heroY: 12, heroSize: 0, mapGap: 0)
    ]
}

private struct SliderBinding {
    let slider: UISlider
    let caption: UILabel
    let label: String
    let min: Int
    let max: Int
    let fraction: Bool
}

final class SettingsPanelViewController: UIViewController {
    var onHide: (() -> Void)?
    var onSettingsChanged: (() -> Void)?
    var onSpacingChanged: (() -> Void)?
    var onCalibrationToggle: (() -> Void)?
    var onResolutionFit: ((Int, Int, String) -> Void)?

    private let switchScroll = UIScrollView()
    private let adjustScroll = UIScrollView()
    private var tabSwitch: TabButton!
    private var tabAdjust: TabButton!
    private var selectedTab = 0
    private var roomValue: UILabel?
    private var statusValue: UILabel?
    private var pollTimer: Timer?
    private var sliderBindings: [String: SliderBinding] = [:]
    private var spacingBinding: SliderBinding?
    private var calibrateButton: UIButton?
    private var fitButton: UIButton?
    private var dragStart = CGPoint.zero

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.pageBg
        view.layer.cornerRadius = 10
        view.layer.borderWidth = 1
        view.layer.borderColor = Theme.border.cgColor
        view.clipsToBounds = true
        buildUI()
        startPolling()
    }

    deinit {
        stopPolling()
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    func setCalibrationButtonTitle(_ title: String) {
        calibrateButton?.setTitle(title, for: .normal)
    }

    func syncSpacingSlider(_ spacing: Int) {
        guard let binding = spacingBinding else { return }
        let current = min(max(spacing, binding.min), binding.max)
        binding.slider.value = Float(current)
        updateCaption(binding, current)
    }

    private func buildUI() {
        let root = UIStackView()
        root.axis = .vertical
        root.spacing = 0
        root.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(root)
        NSLayoutConstraint.activate([
            root.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            root.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            root.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            root.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
        root.addArrangedSubview(buildHeader())
        root.addArrangedSubview(divider())
        root.addArrangedSubview(buildTabBar())
        root.addArrangedSubview(buildContent())
        root.addArrangedSubview(buildFooter())
    }

    private func buildHeader() -> UIView {
        let header = UIStackView()
        header.axis = .horizontal
        header.alignment = .center
        header.spacing = 8
        header.heightAnchor.constraint(equalToConstant: 28).isActive = true

        let mark = UILabel()
        mark.text = "王"
        mark.font = .boldSystemFont(ofSize: 13)
        mark.textColor = Theme.gold
        mark.textAlignment = .center
        mark.backgroundColor = Theme.markBg
        mark.layer.cornerRadius = 6
        mark.layer.borderWidth = 1
        mark.layer.borderColor = Theme.markBorder.cgColor
        mark.widthAnchor.constraint(equalToConstant: 24).isActive = true
        mark.heightAnchor.constraint(equalToConstant: 24).isActive = true

        let room = AppPrefs.shared.room
        let heading = UILabel()
        heading.text = "王者共享    房间 \(room.isEmpty ? "未连接" : room)"
        heading.font = .boldSystemFont(ofSize: 12)
        heading.textColor = Theme.textPrimary
        heading.numberOfLines = 1
        heading.lineBreakMode = .byTruncatingTail

        let hide = UIButton(type: .system)
        hide.setTitle("✕", for: .normal)
        hide.setTitleColor(Theme.textPrimary, for: .normal)
        hide.titleLabel?.font = .systemFont(ofSize: 14)
        hide.backgroundColor = Theme.cardBg
        hide.layer.cornerRadius = 6
        hide.layer.borderWidth = 1
        hide.layer.borderColor = Theme.borderLight.cgColor
        hide.widthAnchor.constraint(equalToConstant: 26).isActive = true
        hide.heightAnchor.constraint(equalToConstant: 24).isActive = true
        hide.addTarget(self, action: #selector(hideTapped), for: .touchUpInside)

        header.addArrangedSubview(mark)
        header.addArrangedSubview(heading)
        header.addArrangedSubview(hide)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        header.addGestureRecognizer(pan)
        return header
    }

    private func divider() -> UIView {
        let v = UIView()
        v.backgroundColor = Theme.border
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    private func buildTabBar() -> UIView {
        let bar = UIStackView()
        bar.axis = .horizontal
        bar.spacing = 8
        bar.heightAnchor.constraint(equalToConstant: 32).isActive = true
        tabSwitch = TabButton(title: "显示")
        tabAdjust = TabButton(title: "调节")
        tabSwitch.addTarget(self, action: #selector(tabSwitchTapped), for: .touchUpInside)
        tabAdjust.addTarget(self, action: #selector(tabAdjustTapped), for: .touchUpInside)
        bar.addArrangedSubview(tabSwitch)
        bar.addArrangedSubview(tabAdjust)
        tabSwitch.isActive = selectedTab == 0
        tabAdjust.isActive = selectedTab == 1
        return bar
    }

    private func buildContent() -> UIView {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false

        switchScroll.translatesAutoresizingMaskIntoConstraints = false
        adjustScroll.translatesAutoresizingMaskIntoConstraints = false
        switchScroll.showsVerticalScrollIndicator = false
        adjustScroll.showsVerticalScrollIndicator = false

        let switchContent = UIStackView()
        switchContent.axis = .vertical
        switchContent.translatesAutoresizingMaskIntoConstraints = false
        addCheckRow(switchContent, "英雄头像与血条", "heroes", true, "不绘制己方英雄", "hide_own_team", false)
        addCheckRow(switchContent, "野怪与资源", "resources", true, "兵线", "minions", true)
        addCheckRow(switchContent, "防御塔血量", "towers", true, "顶部信息", "top_info", true)
        addSectionTitle(switchContent, "接口状态")
        let roomLabel = addInfoRow(switchContent, "房间", AppPrefs.shared.room.isEmpty ? "未连接" : AppPrefs.shared.room)
        let statusLabel = addInfoRow(switchContent, "实时状态", "检测中")
        roomValue = roomLabel
        statusValue = statusLabel
        let bounds = UIScreen.main.bounds
        addInfoRow(switchContent, "屏幕分辨率", "\(Int(max(bounds.width, bounds.height)))\(Int(min(bounds.width, bounds.height)))")
        addInfoRow(switchContent, "客户端版本", "v\(Theme.appVersion)")
        switchScroll.addSubview(switchContent)
        NSLayoutConstraint.activate([
            switchContent.topAnchor.constraint(equalTo: switchScroll.contentLayoutGuide.topAnchor, constant: 2),
            switchContent.bottomAnchor.constraint(equalTo: switchScroll.contentLayoutGuide.bottomAnchor),
            switchContent.leadingAnchor.constraint(equalTo: switchScroll.contentLayoutGuide.leadingAnchor, constant: 4),
            switchContent.trailingAnchor.constraint(equalTo: switchScroll.contentLayoutGuide.trailingAnchor, constant: -4),
            switchContent.widthAnchor.constraint(equalTo: switchScroll.frameLayoutGuide.widthAnchor, constant: -8)
        ])

        let adjustContent = UIStackView()
        adjustContent.axis = .vertical
        adjustContent.translatesAutoresizingMaskIntoConstraints = false
        addSliderRow(adjustContent, "整体 X", "x", -600, 600, Int(AppPrefs.shared.float("x", 0)), "整体 Y", "y", -600, 600, Int(AppPrefs.shared.float("y", 0)))
        addSliderRow(adjustContent, "野怪 X", "resource_x", -600, 600, Int(AppPrefs.shared.float("resource_x", 0)), "野怪 Y", "resource_y", -600, 600, Int(AppPrefs.shared.float("resource_y", 0)))
        addSliderRow(adjustContent, "兵线 X", "minion_x", -600, 600, Int(AppPrefs.shared.float("minion_x", 0)), "兵线 Y", "minion_y", -600, 600, Int(AppPrefs.shared.float("minion_y", 0)))
        addSliderRow(adjustContent, "整体间隔", "map_spacing", -50, 100, Int(AppPrefs.shared.float("map_spacing", 0)), "头像大小", "avatar_size", 60, 180, Int(AppPrefs.shared.float("avatar_size", 1) * 100), fraction2: true)
        addSliderRow(adjustContent, "顶栏 X", "top_x", -600, 600, Int(AppPrefs.shared.float("top_x", 0)), "顶栏 Y", "top_y", -600, 600, Int(AppPrefs.shared.float("top_y", 0)))
        addSliderRow(adjustContent, "顶栏大小", "top_size", 60, 180, Int(AppPrefs.shared.float("top_size", 1) * 100), "顶栏不透明度", "top_opacity", 30, 100, Int(AppPrefs.shared.float("top_opacity", 1) * 100), fraction1: true, fraction2: true)
        addSectionTitle(adjustContent, "快速操作")
        addQuickOps(adjustContent)
        adjustScroll.addSubview(adjustContent)
        NSLayoutConstraint.activate([
            adjustContent.topAnchor.constraint(equalTo: adjustScroll.contentLayoutGuide.topAnchor, constant: 2),
            adjustContent.bottomAnchor.constraint(equalTo: adjustScroll.contentLayoutGuide.bottomAnchor),
            adjustContent.leadingAnchor.constraint(equalTo: adjustScroll.contentLayoutGuide.leadingAnchor, constant: 4),
            adjustContent.trailingAnchor.constraint(equalTo: adjustScroll.contentLayoutGuide.trailingAnchor, constant: -4),
            adjustContent.widthAnchor.constraint(equalTo: adjustScroll.frameLayoutGuide.widthAnchor, constant: -8)
        ])

        container.addSubview(switchScroll)
        container.addSubview(adjustScroll)
        NSLayoutConstraint.activate([
            switchScroll.topAnchor.constraint(equalTo: container.topAnchor),
            switchScroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            switchScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            switchScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            adjustScroll.topAnchor.constraint(equalTo: container.topAnchor),
            adjustScroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            adjustScroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            adjustScroll.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        switchScroll.isHidden = selectedTab != 0
        adjustScroll.isHidden = selectedTab != 1
        return container
    }

    private func buildFooter() -> UIView {
        let footer = UILabel()
        footer.font = .systemFont(ofSize: 9)
        let text = " 已连接  触摸穿透"
        let attr = NSMutableAttributedString(string: text)
        attr.addAttribute(.foregroundColor, value: Theme.green, range: NSRange(location: 0, length: 1))
        attr.addAttribute(.foregroundColor, value: Theme.textSecond, range: NSRange(location: 1, length: text.count - 1))
        footer.attributedText = attr
        footer.heightAnchor.constraint(equalToConstant: 18).isActive = true
        return footer
    }

    private func addSectionTitle(_ stack: UIStackView, _ label: String) {
        let title = UILabel()
        title.text = label
        title.font = .boldSystemFont(ofSize: 10)
        title.textColor = Theme.gold
        title.heightAnchor.constraint(equalToConstant: 18).isActive = true
        stack.addArrangedSubview(title)
    }

    private func addInfoRow(_ stack: UIStackView, _ label: String, _ value: String) -> UILabel {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.heightAnchor.constraint(equalToConstant: 22).isActive = true
        let l = UILabel()
        l.text = label
        l.font = .systemFont(ofSize: 10)
        l.textColor = Theme.textSecond
        let v = UILabel()
        v.text = value
        v.font = .systemFont(ofSize: 10)
        v.textColor = Theme.gold
        v.textAlignment = .right
        row.addArrangedSubview(l)
        row.addArrangedSubview(v)
        stack.addArrangedSubview(row)
        return v
    }

    private func addCheckRow(_ stack: UIStackView, _ label1: String, _ key1: String, _ default1: Bool,
                             _ label2: String, _ key2: String, _ default2: Bool) {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.heightAnchor.constraint(equalToConstant: 28).isActive = true
        row.addArrangedSubview(makeCheck(label1, key1, default1))
        row.addArrangedSubview(makeCheck(label2, key2, default2))
        stack.addArrangedSubview(row)
    }

    private func makeCheck(_ label: String, _ key: String, _ def: Bool) -> UIView {
        let h = UIStackView()
        h.axis = .horizontal
        h.alignment = .center
        let l = UILabel()
        l.text = label
        l.font = .systemFont(ofSize: 11)
        l.textColor = Theme.textPrimary
        let sw = UISwitch()
        sw.isOn = AppPrefs.shared.bool(key, def)
        sw.onTintColor = Theme.green
        sw.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
        sw.accessibilityIdentifier = key
        sw.addTarget(self, action: #selector(checkChanged(_:)), for: .valueChanged)
        h.addArrangedSubview(l)
        h.addArrangedSubview(sw)
        return h
    }

    private func addSliderRow(_ stack: UIStackView, _ label1: String, _ key1: String, _ min1: Int, _ max1: Int, _ val1: Int,
                              _ label2: String, _ key2: String, _ min2: Int, _ max2: Int, _ val2: Int,
                              fraction1: Bool = false, fraction2: Bool = false) {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 4
        row.heightAnchor.constraint(equalToConstant: 34).isActive = true
        row.addArrangedSubview(makeSliderColumn(label1, key1, min1, max1, val1, fraction1))
        row.addArrangedSubview(makeSliderColumn(label2, key2, min2, max2, val2, fraction2))
        stack.addArrangedSubview(row)
    }

    private func makeSliderColumn(_ label: String, _ key: String, _ minV: Int, _ maxV: Int, _ value: Int, _ fraction: Bool) -> UIView {
        let col = UIStackView()
        col.axis = .vertical

        let caption = UILabel()
        caption.font = .systemFont(ofSize: 9)
        caption.heightAnchor.constraint(equalToConstant: 13).isActive = true

        let slider = UISlider()
        slider.minimumValue = Float(minV)
        slider.maximumValue = Float(maxV)
        slider.value = Float(min(max(value, minV), maxV))
        slider.minimumTrackTintColor = Theme.gold
        slider.maximumTrackTintColor = Theme.border
        slider.thumbTintColor = Theme.gold
        slider.accessibilityIdentifier = key
        slider.addTarget(self, action: #selector(sliderChanged(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(sliderReleased(_:)), for: .touchUpInside)

        let minus = stepButton("-", key)
        minus.addTarget(self, action: #selector(stepDown(_:)), for: .touchUpInside)
        let plus = stepButton("+", key)
        plus.addTarget(self, action: #selector(stepUp(_:)), for: .touchUpInside)

        let sliderRow = UIStackView()
        sliderRow.axis = .horizontal
        sliderRow.alignment = .center
        sliderRow.spacing = 3
        sliderRow.heightAnchor.constraint(equalToConstant: 20).isActive = true
        sliderRow.addArrangedSubview(slider)
        sliderRow.addArrangedSubview(minus)
        sliderRow.addArrangedSubview(plus)
        minus.widthAnchor.constraint(equalToConstant: 18).isActive = true
        minus.heightAnchor.constraint(equalToConstant: 18).isActive = true
        plus.widthAnchor.constraint(equalToConstant: 18).isActive = true
        plus.heightAnchor.constraint(equalToConstant: 18).isActive = true

        col.addArrangedSubview(caption)
        col.addArrangedSubview(sliderRow)

        let binding = SliderBinding(slider: slider, caption: caption, label: label, min: minV, max: maxV, fraction: fraction)
        sliderBindings[key] = binding
        if key == "map_spacing" {
            spacingBinding = binding
        }
        updateCaption(binding, min(max(value, minV), maxV))
        return col
    }

    private func stepButton(_ symbol: String, _ key: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(symbol, for: .normal)
        b.setTitleColor(Theme.gold, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 9)
        b.backgroundColor = Theme.cardBg
        b.layer.cornerRadius = 4
        b.layer.borderWidth = 1
        b.layer.borderColor = Theme.borderLight.cgColor
        b.accessibilityIdentifier = key
        return b
    }

    private func addQuickOps(_ stack: UIStackView) {
        let row = UIStackView()
        row.axis = .horizontal
        row.distribution = .fillEqually
        row.spacing = 4
        row.heightAnchor.constraint(equalToConstant: 30).isActive = true

        let fit = quickButton("一键适配分辨率")
        fit.addTarget(self, action: #selector(applyResolutionFit), for: .touchUpInside)
        fitButton = fit

        let calibrate = quickButton(SettingsWindow.shared.hasCalibration ? "关闭校准框" : "显示校准框")
        calibrate.addTarget(self, action: #selector(toggleCalibration), for: .touchUpInside)
        calibrateButton = calibrate

        row.addArrangedSubview(fit)
        row.addArrangedSubview(calibrate)
        stack.addArrangedSubview(row)
    }

    private func quickButton(_ title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(Theme.textPrimary, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 11)
        b.backgroundColor = Theme.cardBg
        b.layer.cornerRadius = 6
        b.layer.borderWidth = 1
        b.layer.borderColor = Theme.borderLight.cgColor
        return b
    }

    private func updateCaption(_ binding: SliderBinding, _ value: Int) {
        let valueText = binding.fraction ? "\(value)%" : "\(value)"
        let full = "\(binding.label)  \(valueText)"
        let attr = NSMutableAttributedString(string: full)
        attr.addAttribute(.foregroundColor, value: Theme.textSecond, range: NSRange(location: 0, length: binding.label.count))
        attr.addAttribute(.foregroundColor, value: Theme.gold, range: NSRange(location: binding.label.count, length: full.count - binding.label.count))
        binding.caption.attributedText = attr
    }

    private func syncSlider(_ key: String, _ value: Int) {
        guard let binding = sliderBindings[key] else { return }
        let current = min(max(value, binding.min), binding.max)
        binding.slider.value = Float(current)
        updateCaption(binding, current)
    }

    @objc private func hideTapped() {
        onHide?()
    }

    @objc private func handleDrag(_ g: UIPanGestureRecognizer) {
        guard let window = view.window else { return }
        switch g.state {
        case .began:
            dragStart = window.frame.origin
        case .changed:
            let t = g.translation(in: view)
            var origin = CGPoint(x: dragStart.x + t.x, y: dragStart.y + t.y)
            let b = UIScreen.main.bounds
            origin.x = min(max(origin.x, 0), max(b.width - window.frame.width, 0))
            origin.y = min(max(origin.y, 0), max(b.height - window.frame.height, 0))
            window.frame.origin = origin
        default:
            break
        }
    }

    @objc private func tabSwitchTapped() { selectTab(0) }
    @objc private func tabAdjustTapped() { selectTab(1) }

    private func selectTab(_ index: Int) {
        selectedTab = index
        switchScroll.isHidden = index != 0
        adjustScroll.isHidden = index != 1
        tabSwitch.isActive = index == 0
        tabAdjust.isActive = index == 1
    }

    @objc private func checkChanged(_ sender: UISwitch) {
        guard let key = sender.accessibilityIdentifier else { return }
        AppPrefs.shared.setBool(key, sender.isOn)
        onSettingsChanged?()
    }

    @objc private func sliderChanged(_ sender: UISlider) {
        guard let key = sender.accessibilityIdentifier, let binding = sliderBindings[key] else { return }
        let current = min(max(Int(sender.value.rounded()), binding.min), binding.max)
        updateCaption(binding, current)
        if binding.fraction {
            AppPrefs.shared.setFloat(key, Float(current) / 100)
        } else {
            AppPrefs.shared.setFloat(key, Float(current))
        }
        onSettingsChanged?()
    }

    @objc private func sliderReleased(_ sender: UISlider) {
        if sender.accessibilityIdentifier == "map_spacing" {
            onSpacingChanged?()
        }
    }

    @objc private func stepDown(_ sender: UIButton) { applyStep(sender.accessibilityIdentifier, -1) }
    @objc private func stepUp(_ sender: UIButton) { applyStep(sender.accessibilityIdentifier, 1) }

    private func applyStep(_ key: String?, _ delta: Int) {
        guard let key = key, let binding = sliderBindings[key] else { return }
        let current = min(max(Int(binding.slider.value.rounded()) + delta, binding.min), binding.max)
        binding.slider.value = Float(current)
        updateCaption(binding, current)
        if binding.fraction {
            AppPrefs.shared.setFloat(key, Float(current) / 100)
        } else {
            AppPrefs.shared.setFloat(key, Float(current))
        }
        onSettingsChanged?()
        if key == "map_spacing" {
            onSpacingChanged?()
        }
    }

    @objc private func toggleCalibration() {
        onCalibrationToggle?()
    }

    @objc private func applyResolutionFit() {
        let bounds = UIScreen.main.bounds
        let width = Int(max(bounds.width, bounds.height))
        let height = Int(min(bounds.width, bounds.height))
        guard width > 0, height > 0 else { return }

        let presets = AutoFitPreset.all
        let exact = presets.first { $0.width == width && $0.height == height }
        let targetRatio = Double(width) / Double(height)
        let preset = exact ?? presets.min { a, b in
            let ratioA = abs(Double(a.width) / Double(a.height) - targetRatio)
            let ratioB = abs(Double(b.width) / Double(b.height) - targetRatio)
            let resA = abs(Double(width) / Double(a.width) - 1) + abs(Double(height) / Double(a.height) - 1)
            let resB = abs(Double(width) / Double(b.width) - 1) + abs(Double(height) / Double(b.height) - 1)
            return ratioA * 3 + resA < ratioB * 3 + resB
        }
        guard let preset = preset else { return }

        let heightRatio = Double(height) / Double(preset.height)
        let offsetX = min(max(preset.heroX * heightRatio, -200), 200)
        let offsetY = min(max(preset.heroY * heightRatio, -100), 100)
        let mapSpacing = min(max(Double(preset.mapGap) / 1.574074, -50), 100)
        let avatarScale = min(max(1 + Double(preset.heroSize) / 40, 0.6), 1.4)

        AppPrefs.shared.setFloat("x", Float(offsetX))
        AppPrefs.shared.setFloat("y", Float(offsetY))
        AppPrefs.shared.setFloat("map_spacing", Float(mapSpacing))
        AppPrefs.shared.setFloat("avatar_size", Float(avatarScale))
        syncSlider("x", Int(offsetX))
        syncSlider("y", Int(offsetY))
        syncSlider("map_spacing", Int(mapSpacing))
        syncSlider("avatar_size", Int(avatarScale * 100))
        onSettingsChanged?()

        fitButton?.setTitle("已适配 \(width)\(height)", for: .normal)
        let mode = exact != nil ? "精确参数" : "相近参数 \(preset.width)\(preset.height)"
        onResolutionFit?(width, height, mode)
    }

    private func startPolling() {
        stopPolling()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.pollTick()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
        pollTick()
    }

    private func pollTick() {
        roomValue?.text = AppPrefs.shared.room.isEmpty ? "未连接" : AppPrefs.shared.room
        let live = OverlaySession.shared.running
        let fresh = Date().timeIntervalSince1970 * 1000 - OverlaySession.shared.lastFrameAt < 3000
        if live && fresh {
            statusValue?.text = "实时绘制中"
            statusValue?.textColor = Theme.green
        } else if live {
            statusValue?.text = "已连接  等待数据"
            statusValue?.textColor = Theme.gold
        } else {
            statusValue?.text = "未连接"
            statusValue?.textColor = Theme.mutedText
        }
    }
}

private final class TabButton: UIControl {
    private let label = UILabel()
    private let underline = UIView()

    var isActive: Bool = false {
        didSet {
            label.textColor = isActive ? Theme.gold : Theme.mutedText
            underline.backgroundColor = isActive ? Theme.gold : .clear
        }
    }

    init(title: String) {
        super.init(frame: .zero)
        label.text = title
        label.font = .systemFont(ofSize: 11)
        label.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [label, underline])
        stack.axis = .vertical
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            label.heightAnchor.constraint(equalToConstant: 24),
            underline.heightAnchor.constraint(equalToConstant: 2)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
