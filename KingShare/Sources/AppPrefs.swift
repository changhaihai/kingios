import Foundation

/// Mirrors OverlayService.DisplaySettings and the Android SharedPreferences keys exactly.
struct DisplaySettings {
    var heroes = true
    var resources = true
    var minions = true
    var towers = true
    var lines = true
    var offsetX: Float = 0
    var offsetY: Float = 0
    var opacity: Float = 1
    var avatarScale: Float = 1
    var hideOwnTeam = false
    var mapSpacing: Float = 0
    var resourceOffsetX: Float = 0
    var resourceOffsetY: Float = 0
    var minionOffsetX: Float = 0
    var minionOffsetY: Float = 0
}

final class AppPrefs {
    static let shared = AppPrefs()

    static let roomKey = "room"
    static let secureKey = "secure_overlay"
    static let topInfoKey = "top_info"

    private let d = UserDefaults.standard

    func bool(_ key: String, _ def: Bool) -> Bool {
        return d.object(forKey: key) == nil ? def : d.bool(forKey: key)
    }

    func float(_ key: String, _ def: Float) -> Float {
        return d.object(forKey: key) == nil ? def : d.float(forKey: key)
    }

    func string(_ key: String) -> String {
        return d.string(forKey: key) ?? ""
    }

    func setBool(_ key: String, _ value: Bool) { d.set(value, forKey: key) }
    func setFloat(_ key: String, _ value: Float) { d.set(value, forKey: key) }
    func setString(_ key: String, _ value: String) { d.set(value, forKey: key) }

    var room: String {
        get { return string(Self.roomKey) }
        set { setString(Self.roomKey, newValue) }
    }

    var secureOverlay: Bool {
        get { return bool(Self.secureKey, false) }
        set { setBool(Self.secureKey, newValue) }
    }

    func displaySettings() -> DisplaySettings {
        return DisplaySettings(
            heroes: bool("heroes", true),
            resources: bool("resources", true),
            minions: bool("minions", true),
            towers: bool("towers", true),
            lines: bool("lines", true),
            offsetX: float("x", 0),
            offsetY: float("y", 0),
            opacity: float("opacity", 1),
            avatarScale: float("avatar_size", 1),
            hideOwnTeam: bool("hide_own_team", false),
            mapSpacing: float("map_spacing", 0),
            resourceOffsetX: float("resource_x", 0),
            resourceOffsetY: float("resource_y", 0),
            minionOffsetX: float("minion_x", 0),
            minionOffsetY: float("minion_y", 0)
        )
    }

    func topSizeScale() -> Float {
        return min(max(float("top_size", 1), 0.6), 1.8)
    }

    func topOpacity() -> Float {
        return min(max(float("top_opacity", 1), 0.3), 1)
    }

    func topX() -> Float { return float("top_x", 0) }
    func topY() -> Float { return float("top_y", 0) }
}
