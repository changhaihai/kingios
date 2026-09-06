import UIKit

/// 1:1 port of the Android OverlayService:
/// - full-screen non-touchable map window (alpha 0.4, pass-through)
/// - non-touchable top info strip window
/// - secure mode hides the overlays while the screen is being recorded
/// - the WebSocket pipeline feeds both renderers
final class OverlaySession {
    static let shared = OverlaySession()

    private(set) var running = false
    private(set) var lastFrameAt: TimeInterval = 0

    private var mapWindow: UIWindow?
    private var topWindow: UIWindow?
    private var mapView: MapOverlayView?
    private var topView: TopInfoOverlayView?
    private var socket: RoomWebSocket?
    private var room: String = ""
    private var secureObserver: NSObjectProtocol?

    func connect(room: String) {
        stopSocket()
        self.room = room
        AppPrefs.shared.room = room
        ensureWindows()
        applySettings()
        applyTopInfoVisibility()
        let ws = RoomWebSocket(room: room, onState: { _ in }, onFrame: { [weak self] raw in
            guard let self = self else { return }
            self.lastFrameAt = Date().timeIntervalSince1970 * 1000
            if let frame = BattleFrameParser.parse(raw) {
                DispatchQueue.main.async {
                    self.mapView?.submit(frame)
                    self.topView?.submit(frame)
                }
            }
        })
        socket = ws
        ws.start()
    }

    func stop() {
        stopSocket()
        room = ""
        removeWindows()
        running = false
        lastFrameAt = 0
        SettingsWindow.shared.stop()
    }

    func applySettings() {
        mapView?.updateSettings(AppPrefs.shared.displaySettings())
        topView?.updateScale(CGFloat(AppPrefs.shared.topSizeScale()))
        if let topWindow = topWindow {
            topWindow.frame = topInfoFrame()
            let opacity = AppPrefs.shared.topOpacity()
            topWindow.alpha = min(max(0.5 * opacity, 0.15), 0.5)
        }
        mapWindow?.alpha = 0.4
    }

    func applyTopInfoVisibility() {
        let enabled = AppPrefs.shared.bool(AppPrefs.topInfoKey, true)
        topWindow?.isHidden = !enabled
    }

    func securityChanged() {
        applySettings()
        applySecureState()
    }

    private func ensureWindows() {
        if mapWindow == nil {
            let v = MapOverlayView(frame: UIScreen.main.bounds)
            v.updateSettings(AppPrefs.shared.displaySettings())
            let vc = UIViewController()
            vc.view = v
            let w = UIWindow(frame: UIScreen.main.bounds)
            w.windowLevel = UIWindow.Level.alert + 10
            w.rootViewController = vc
            w.isUserInteractionEnabled = false
            w.alpha = 0.4
            w.isHidden = false
            mapWindow = w
            mapView = v
        }
        if topWindow == nil {
            let v = TopInfoOverlayView(frame: topInfoFrame())
            v.updateScale(CGFloat(AppPrefs.shared.topSizeScale()))
            let vc = UIViewController()
            vc.view = v
            let w = UIWindow(frame: topInfoFrame())
            w.windowLevel = UIWindow.Level.alert + 11
            w.rootViewController = vc
            w.isUserInteractionEnabled = false
            let opacity = AppPrefs.shared.topOpacity()
            w.alpha = min(max(0.5 * opacity, 0.15), 0.5)
            w.isHidden = false
            topWindow = w
            topView = v
        }
        running = true
        observeCapture()
    }

    private func topInfoFrame() -> CGRect {
        let sizeScale = CGFloat(AppPrefs.shared.topSizeScale())
        let height = max(52 * sizeScale, 30)
        let width = max(278 * sizeScale, 1)
        let screenW = UIScreen.main.bounds.width
        let centeredX = (screenW - width) / 2
        let x = centeredX + CGFloat(AppPrefs.shared.topX())
        let y = CGFloat(AppPrefs.shared.topY())
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func observeCapture() {
        if secureObserver == nil {
            secureObserver = NotificationCenter.default.addObserver(
                forName: UIScreen.capturedDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.applySecureState()
            }
        }
        applySecureState()
    }

    private func applySecureState() {
        let secure = AppPrefs.shared.secureOverlay && UIScreen.main.isCaptured
        mapWindow?.isHidden = secure
        topWindow?.isHidden = secure || !AppPrefs.shared.bool(AppPrefs.topInfoKey, true)
    }

    private func removeWindows() {
        mapWindow?.isHidden = true
        mapWindow = nil
        mapView = nil
        topWindow?.isHidden = true
        topWindow = nil
        topView = nil
        if let observer = secureObserver {
            NotificationCenter.default.removeObserver(observer)
            secureObserver = nil
        }
    }

    private func stopSocket() {
        socket?.stop()
        socket = nil
    }
}
