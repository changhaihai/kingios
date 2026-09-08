import Foundation

final class RoomWebSocket: NSObject, URLSessionWebSocketDelegate {
    var onState: ((String) -> Void)?
    var onFrame: ((String) -> Void)?
    private var task: URLSessionWebSocketTask?
    private var room = ""
    private var stopped = true
    private var reconnectDelay: UInt64 = 500_000_000
    private var lastFrame = Date.distantPast

    func connect(room: String) {
        stop()
        self.room = room
        stopped = false
        reconnectDelay = 500_000_000
        open()
    }

    func stop() {
        stopped = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func open() {
        guard !stopped else { return }
        guard let url = URL(string: "ws://king.weilua.top:8888/ws") else { return }
        onState?("正在连接")
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        let socket = session.webSocketTask(with: url)
        task = socket
        socket.resume()
        receive()
    }

    private func receive() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(.string(let text)):
                self.handle(text)
                self.receive()
            case .success(.data(let data)):
                if let text = String(data: data, encoding: .utf8) { self.handle(text) }
                self.receive()
            case .failure(let error):
                self.failed(error)
            @unknown default:
                self.failed(nil)
            }
        }
    }

    private func handle(_ text: String) {
        if text.hasPrefix("gameData##") {
            let now = Date()
            guard now.timeIntervalSince(lastFrame).magnitude >= 0.033 else { return }
            lastFrame = now
            onFrame?(String(text.dropFirst("gameData##".count)))
        }
    }

    private func failed(_ error: Error?) {
        guard !stopped else { return }
        onState?("连接失败，正在重试")
        task = nil
        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, 8_000_000_000)
        DispatchQueue.global().asyncAfter(deadline: .now() + .nanoseconds(Int(delay))) { [weak self] in self?.open() }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol `protocol`: String?) {
        onState?("已连接")
        webSocketTask.send(.string("subscribe[==]\(room)")) { [weak self] _ in self?.ping() }
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        failed(nil)
    }

    private func ping() {
        guard !stopped else { return }
        task?.sendPing { [weak self] _ in
            guard let self else { return }
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { self.ping() }
        }
    }
}
