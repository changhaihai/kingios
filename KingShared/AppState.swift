import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var room = UserDefaults.standard.string(forKey: "room") ?? ""
    @Published var status = "未连接"
    @Published var frame = BattleFrame()
    @Published var settings = DisplaySettings()
    @Published var connected = false
    @Published var lastFrameAt: Date?
    @Published var startupMessage = "启动配置已完成"
    let pip = PiPManager()

    let socket = RoomWebSocket()

    init() {
        socket.onState = { [weak self] message in
            Task { @MainActor in
                self?.status = message
                self?.connected = message == "已连接"
            }
        }
        socket.onFrame = { [weak self] raw in
            guard let parsed = BattleFrameParser.parse(raw) else { return }
            Task { @MainActor in
                self?.frame = parsed
                self?.lastFrameAt = Date()
                self?.pip.update(frame: parsed, settings: self?.settings ?? DisplaySettings())
            }
        }
    }

    func connect() {
        let value = room.trimmed
        guard !value.isEmpty else { status = "请输入房间号"; return }
        room = value
        UserDefaults.standard.set(value, forKey: "room")
        socket.connect(room: value)
    }

    func stop() {
        socket.stop()
        connected = false
        status = "绘制已关闭"
    }

    func saveSettings() {
        let d = settings
        let values: [String: Any] = [
            "heroes": d.heroes, "resources": d.resources, "minions": d.minions, "towers": d.towers,
            "topInfo": d.topInfo, "hideOwnTeam": d.hideOwnTeam, "opacity": d.opacity, "avatarScale": d.avatarScale,
            "offsetX": d.offsetX, "offsetY": d.offsetY, "mapSpacing": d.mapSpacing,
            "resourceOffsetX": d.resourceOffsetX, "resourceOffsetY": d.resourceOffsetY,
            "minionOffsetX": d.minionOffsetX, "minionOffsetY": d.minionOffsetY,
            "topX": d.topX, "topY": d.topY, "topSize": d.topSize, "topOpacity": d.topOpacity,
            "secureOverlay": d.secureOverlay
        ]
        values.forEach { UserDefaults.standard.set($0.value, forKey: $0.key) }
        pip.update(frame: frame, settings: settings)
    }
}
