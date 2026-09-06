import Foundation
import UIKit
import Darwin

@_silgen_name("hai_root_spawn")
private func hai_root_spawn(
    _ executable: UnsafePointer<CChar>,
    _ statePath: UnsafePointer<CChar>,
    _ pid: UnsafeMutablePointer<pid_t>
) -> Int32

/// Controller-side half of the TrollSpeed-style architecture.
///
/// The main app only writes snapshots and starts the helper. It deliberately
/// never waits for the child process, so a root-spawned helper can outlive the
/// controller app and keep its global window alive.
final class HUDProcessController: ObservableObject {
    static let shared = HUDProcessController()

    @Published private(set) var state = "未启动"
    private var childPID: pid_t = 0
    private var stateURL = HUDTransport.stateURL()
    private var room = ""
    private var lastWrite = Date.distantPast

    private init() {}

    func start(room: String, frame: BattleFrame?, settings: DisplaySettings) {
        self.room = room
        stateURL = HUDTransport.stateURL()
        write(enabled: true, frame: frame, settings: settings, force: true)
        if !isChildAlive {
            spawnHelper()
        }
    }

    func update(frame: BattleFrame?, settings: DisplaySettings, enabled: Bool) {
        write(enabled: enabled, frame: frame, settings: settings, force: false)
    }

    func stop(settings: DisplaySettings) {
        write(enabled: false, frame: nil, settings: settings, force: true)
        state = "已停止"
    }

    private func write(enabled: Bool, frame: BattleFrame?, settings: DisplaySettings, force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastWrite) >= 0.05 else { return }
        lastWrite = now
        let envelope = HUDEnvelope(
            enabled: enabled,
            room: room,
            frame: frame,
            settings: HUDSettingsSnapshot(
                settings: settings,
                topInfo: AppPrefs.shared.bool(AppPrefs.topInfoKey, true),
                topScale: AppPrefs.shared.topSizeScale(),
                topOpacity: AppPrefs.shared.topOpacity(),
                topX: AppPrefs.shared.topX(),
                topY: AppPrefs.shared.topY()
            ),
            updatedAt: now.timeIntervalSince1970
        )
        switch HUDTransport.write(envelope, to: stateURL) {
        case .success:
            if enabled { state = isChildAlive ? "HUD运行中" : "等待HUD启动" }
        case .failure(let error):
            state = "共享失败: \(error.localizedDescription)"
        }
    }

    private var isChildAlive: Bool {
        #if canImport(Darwin)
        guard childPID > 0 else { return false }
        return kill(childPID, 0) == 0
        #else
        return false
        #endif
    }

    private func spawnHelper() {
        // TrollSpeed spawns the same signed executable in HUD mode. This is
        // what lets TrollStore's root-persona launch survive app switching.
        guard let executableURL = Bundle.main.executableURL else {
            state = "主程序路径无效"
            return
        }
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            state = "HUD 可执行文件无效"
            return
        }

        var pid: pid_t = 0
        let result = executableURL.path.withCString { executable in
            stateURL.path.withCString { state in
                hai_root_spawn(executable, state, &pid)
            }
        }
        guard result == 0 else {
            state = "HUD 启动失败 (\(result))"
            return
        }
        // Intentionally do not synchronously wait for the child. The root-
        // spawn variant used by TrollStore owns its lifecycle independently.
        childPID = pid
        state = "HUD已启动"
    }
}
