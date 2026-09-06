import Foundation
import UIKit
import Darwin
import AVFoundation

@_silgen_name("hai_register_global_window")
private func hai_register_global_window(_ window: UIWindow)

@objc(HUDMainApplication)
final class HUDMainApplication: UIApplication {}

final class HUDHelperAppDelegate: UIResponder, UIApplicationDelegate {
    private var receiver: HUDStateReceiver?
    private var roomClient: HUDRoomClient?
    private var windowController: HUDGlobalWindowController?
    private var keepAliveEngine: AVAudioEngine?
    private var keepAliveNode: AVAudioPlayerNode?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let statePath = argument(after: "--state") ?? HUDTransport.stateURL().path
        let stateURL = URL(fileURLWithPath: statePath)
        let renderer = HUDRenderView(frame: UIScreen.main.bounds)
        // Initialize the plugin process before creating its HUD window. The
        // window server promotion only applies to windows created afterward.
        completeAsSystemPluginIfAvailable()
        startKeepAliveAudio()
        windowController = HUDGlobalWindowController(renderView: renderer)
        windowController?.show()

        roomClient = HUDRoomClient { [weak renderer] frame in
            DispatchQueue.main.async {
                renderer?.apply(frame: frame)
            }
        }
        receiver = HUDStateReceiver(url: stateURL) { [weak self, weak renderer] envelope in
            guard let self else { return }
            renderer?.apply(envelope: envelope)
            if !envelope.room.isEmpty, envelope.enabled {
                self.roomClient?.connect(room: envelope.room)
            }
            if !envelope.enabled {
                self.windowController?.hide()
                self.roomClient?.stop()
                self.receiver?.stop()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { exit(0) }
            } else {
                self.windowController?.show()
            }
        }
        receiver?.start()
        return true
    }

    private func argument(after flag: String) -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: flag) else { return nil }
        let next = index + 1
        return CommandLine.arguments.indices.contains(next) ? CommandLine.arguments[next] : nil
    }

    private func completeAsSystemPluginIfAvailable() {
        let app = UIApplication.shared
        let accessibilityInit = Selector(("_accessibilityInit"))
        if app.responds(to: accessibilityInit) {
            app.perform(accessibilityInit)
        }
        let pluginRun = Selector(("__completeAndRunAsPlugin"))
        if app.responds(to: pluginRun) {
            app.perform(pluginRun)
        }
    }

    private func startKeepAliveAudio() {
        do {
            let audio = AVAudioSession.sharedInstance()
            try audio.setCategory(.playback, options: [.mixWithOthers])
            try audio.setActive(true)
            let engine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            let format = AVAudioFormat(standardFormatWithSampleRate: 8_000, channels: 1)
            guard let format, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8_000) else { return }
            buffer.frameLength = 8_000
            if let channel = buffer.floatChannelData?.pointee {
                channel.initialize(repeating: 0, count: Int(buffer.frameLength))
            }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            node.volume = 0
            node.scheduleBuffer(buffer, at: nil, options: [.loops])
            try engine.start()
            node.play()
            keepAliveEngine = engine
            keepAliveNode = node
        } catch {
            // Background audio is an extra lifecycle guard; rendering still
            // works on systems that reject the session category.
        }
    }
}

final class HUDStateReceiver {
    private let url: URL
    private let applyEnvelope: (HUDEnvelope) -> Void
    private var timer: Timer?
    private var lastUpdatedAt: TimeInterval = 0

    init(url: URL, apply: @escaping (HUDEnvelope) -> Void) {
        self.url = url
        self.applyEnvelope = apply
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let envelope = HUDTransport.read(from: self.url), envelope.updatedAt > self.lastUpdatedAt else { return }
            self.lastUpdatedAt = envelope.updatedAt
            self.applyEnvelope(envelope)
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }
}

final class HUDRoomClient: NSObject, URLSessionWebSocketDelegate {
    private let onFrame: (BattleFrame) -> Void
    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var desiredRoom = ""
    private var reconnectWorkItem: DispatchWorkItem?

    init(onFrame: @escaping (BattleFrame) -> Void) {
        self.onFrame = onFrame
    }

    func connect(room: String) {
        let normalized = room.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return }
        guard normalized != desiredRoom || task == nil else { return }
        desiredRoom = normalized
        reconnectWorkItem?.cancel()
        closeCurrentConnection()
        openConnection()
    }

    private func openConnection() {
        guard !desiredRoom.isEmpty, task == nil else { return }
        guard let url = URL(string: "ws://king.weilua.top:8888/ws") else { return }
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        guard let session else { return }
        task = session.webSocketTask(with: url)
        task?.resume()
        receive()
    }

    func stop() {
        desiredRoom = ""
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        closeCurrentConnection()
    }

    private func closeCurrentConnection() {
        let current = task
        task = nil
        current?.cancel(with: .goingAway, reason: nil)
        session?.invalidateAndCancel()
        session = nil
    }

    private func scheduleReconnect() {
        guard !desiredRoom.isEmpty, reconnectWorkItem == nil else { return }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.reconnectWorkItem = nil
            self.openConnection()
        }
        reconnectWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: work)
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(.string(let text)):
                if text.hasPrefix("gameData##"), let frame = BattleFrameParser.parse(String(text.dropFirst(10))) {
                    self.onFrame(frame)
                }
                self.receive()
            case .success(.data): self.receive()
            case .failure:
                self.closeCurrentConnection()
                self.scheduleReconnect()
            @unknown default: self.receive()
            }
        }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        webSocketTask.send(.string("subscribe[==]" + desiredRoom)) { [weak self] error in
            if error != nil {
                self?.closeCurrentConnection()
                self?.scheduleReconnect()
            }
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        guard task === webSocketTask else { return }
        closeCurrentConnection()
        scheduleReconnect()
    }
}

final class HUDGlobalWindowController {
    private let renderView: UIView
    private var window: UIWindow?

    init(renderView: UIView) {
        self.renderView = renderView
    }

    func show() {
        if let window {
            window.isHidden = false
            return
        }
        let host = UIViewController()
        host.view = renderView
        host.view.backgroundColor = .clear
        let window = HUDSystemWindow(frame: UIScreen.main.bounds)
        window.rootViewController = host
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 100)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isUserInteractionEnabled = false
        window.isHidden = false
        window.isHidden = false
        hai_register_global_window(window)
        self.window = window
    }

    func hide() {
        window?.isHidden = true
        window = nil
    }
}
