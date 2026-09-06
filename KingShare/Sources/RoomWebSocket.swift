import Foundation

/// 1:1 port of the Android RoomWebSocket:
/// - ws://king.weilua.top:8888/ws
/// - subscribe[==]<room> on connect, ping##<ts> every 2s
/// - gameData## payloads throttled to 33ms, exponential reconnect backoff 0.5s -> 8s
/// - probe(): subscribeHome -> homeData## directory lookup, 4s deadline
final class RoomWebSocket {
    static let host = "king.weilua.top"
    static let port = 8888
    static let wsURL = URL(string: "ws://\(host):\(port)/ws")!

    private let room: String
    private let onState: (String) -> Void
    private let onFrame: (String) -> Void

    private var session: URLSession?
    private var task: URLSessionWebSocketTask?
    private var pingSource: DispatchSourceTimer?
    private var endHandler: ((Bool) -> Void)?
    private var stopped = false
    private var lastFrameAt: TimeInterval = 0
    private let queue = DispatchQueue(label: "room-websocket", qos: .utility)

    init(room: String, onState: @escaping (String) -> Void, onFrame: @escaping (String) -> Void) {
        self.room = room
        self.onState = onState
        self.onFrame = onFrame
    }

    func start() {
        stopped = false
        queue.async { [weak self] in
            self?.runLoop()
        }
    }

    func stop() {
        stopped = true
        stopPing()
        task?.cancel(with: .goingAway, reason: nil)
        endHandler?(true)
        endHandler = nil
    }

    private func runLoop() {
        var delay: TimeInterval = 0.5
        while !stopped {
            let ok = connectOnce()
            if stopped { break }
            if !ok { onState("连接失败，正在重试") }
            Thread.sleep(forTimeInterval: delay)
            delay = ok ? 0.5 : min(delay * 2, 8)
        }
    }

    /// Blocks the queue thread until the session ends; returns false on network error.
    private func connectOnce() -> Bool {
        onState("正在连接")
        let sem = DispatchSemaphore(value: 0)
        var ok = false
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 60
        let s = URLSession(configuration: config)
        let t = s.webSocketTask(with: Self.wsURL)
        session = s
        task = t
        endHandler = { fine in
            ok = fine
            sem.signal()
        }
        t.resume()
        t.send(.string("subscribe[==]\(room)")) { [weak self] error in
            if error != nil { self?.finish(false) }
        }
        onState("已连接")
        startPing()
        receiveLoop()
        sem.wait()
        stopPing()
        task = nil
        session = nil
        return ok
    }

    private func receiveLoop() {
        guard let t = task else {
            finish(false)
            return
        }
        t.receive { [weak self] result in
            guard let self = self, !self.stopped else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleText(text)
                    self.receiveLoop()
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleText(text)
                    }
                    self.receiveLoop()
                @unknown default:
                    self.receiveLoop()
                }
            case .failure:
                self.finish(false)
            }
        }
    }

    private func handleText(_ text: String) {
        if !text.hasPrefix("gameData##") { return }
        let now = Date().timeIntervalSince1970 * 1000
        if now - lastFrameAt < 33 { return }
        lastFrameAt = now
        onFrame(String(text.dropFirst("gameData##".count)))
    }

    private func startPing() {
        stopPing()
        let src = DispatchSource.makeTimerSource(queue: queue)
        src.schedule(deadline: .now() + 2, repeating: 2)
        src.setEventHandler { [weak self] in
            guard let self = self, !self.stopped else { return }
            let ts = Int64(Date().timeIntervalSince1970 * 1000)
            self.task?.send(.string("ping##\(ts)")) { _ in }
        }
        src.resume()
        pingSource = src
    }

    private func stopPing() {
        pingSource?.cancel()
        pingSource = nil
    }

    private func finish(_ ok: Bool) {
        stopPing()
        task?.cancel(with: .goingAway, reason: nil)
        endHandler?(ok)
        endHandler = nil
    }

    /// Checks whether a room exists in the live directory (subscribeHome).
    static func probe(room: String, callback: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result = Probe(room: room).run()
            DispatchQueue.main.async { callback(result) }
        }
    }

    private final class Probe {
        let room: String

        init(room: String) {
            self.room = room
        }

        func run() -> Bool {
            let sem = DispatchSemaphore(value: 0)
            var found = false
            var finished = false
            let deadline = Date().addingTimeInterval(4)
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 3
            let session = URLSession(configuration: config)
            let task = session.webSocketTask(with: RoomWebSocket.wsURL)

            func finish(_ value: Bool) {
                if finished { return }
                finished = true
                found = value
                task.cancel(with: .goingAway, reason: nil)
                sem.signal()
            }

            func receive() {
                if finished { return }
                if Date() > deadline {
                    finish(false)
                    return
                }
                task.receive { result in
                    if finished { return }
                    switch result {
                    case .success(let message):
                        switch message {
                        case .string(let text):
                            if text.hasPrefix("homeData##") {
                                let body = String(text.dropFirst("homeData##".count))
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                let containsRoom = !body.isEmpty && body.components(separatedBy: ",").contains { entry in
                                    return entry.components(separatedBy: "[==]").first?
                                        .trimmingCharacters(in: .whitespaces) == self.room
                                }
                                finish(containsRoom)
                            } else {
                                receive()
                            }
                        case .data:
                            receive()
                        @unknown default:
                            receive()
                        }
                    case .failure:
                        finish(false)
                    }
                }
            }

            task.resume()
            task.send(.string("subscribeHome")) { error in
                if error != nil { finish(false) }
            }
            receive()
            sem.wait()
            return found
        }
    }
}
