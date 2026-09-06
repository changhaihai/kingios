import Foundation

/// State exchanged between HaiIOS and the independently spawned HaiHUD process.
/// The helper intentionally receives a complete snapshot so it can continue
/// rendering after the controller app is suspended or terminated.
struct HUDSettingsSnapshot: Codable, Equatable {
    var showHeroes: Bool
    var showHeroAvatars: Bool
    var showResources: Bool
    var showMinions: Bool
    var showTowers: Bool
    var showTopInfo: Bool
    var hideOwnTeam: Bool
    var avatarScale: Double
    var mapSpacing: Double
    var mapOpacity: Double
    var topScale: Double
    var topOpacity: Double
    var offsetX: Double
    var offsetY: Double
    var resourceOffsetX: Double
    var resourceOffsetY: Double
    var minionOffsetX: Double
    var minionOffsetY: Double
    var topOffsetX: Double
    var topOffsetY: Double

    static let `default` = HUDSettingsSnapshot(
        showHeroes: true,
        showHeroAvatars: true,
        showResources: true,
        showMinions: true,
        showTowers: true,
        showTopInfo: true,
        hideOwnTeam: false,
        avatarScale: 1,
        mapSpacing: 0,
        mapOpacity: 1,
        topScale: 1,
        topOpacity: 1,
        offsetX: 0,
        offsetY: 0,
        resourceOffsetX: 0,
        resourceOffsetY: 0,
        minionOffsetX: 0,
        minionOffsetY: 0,
        topOffsetX: 0,
        topOffsetY: 0
    )

    init(showHeroes: Bool, showHeroAvatars: Bool, showResources: Bool, showMinions: Bool, showTowers: Bool, showTopInfo: Bool, hideOwnTeam: Bool, avatarScale: Double, mapSpacing: Double, mapOpacity: Double, topScale: Double, topOpacity: Double, offsetX: Double, offsetY: Double, resourceOffsetX: Double, resourceOffsetY: Double, minionOffsetX: Double, minionOffsetY: Double, topOffsetX: Double, topOffsetY: Double) {
        self.showHeroes = showHeroes
        self.showHeroAvatars = showHeroAvatars
        self.showResources = showResources
        self.showMinions = showMinions
        self.showTowers = showTowers
        self.showTopInfo = showTopInfo
        self.hideOwnTeam = hideOwnTeam
        self.avatarScale = avatarScale
        self.mapSpacing = mapSpacing
        self.mapOpacity = mapOpacity
        self.topScale = topScale
        self.topOpacity = topOpacity
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.resourceOffsetX = resourceOffsetX
        self.resourceOffsetY = resourceOffsetY
        self.minionOffsetX = minionOffsetX
        self.minionOffsetY = minionOffsetY
        self.topOffsetX = topOffsetX
        self.topOffsetY = topOffsetY
    }

    init(settings: DisplaySettings, topInfo: Bool, topScale: Float, topOpacity: Float, topX: Float, topY: Float) {
        showHeroes = settings.heroes
        showHeroAvatars = settings.heroes
        showResources = settings.resources
        showMinions = settings.minions
        showTowers = settings.towers
        showTopInfo = topInfo
        hideOwnTeam = settings.hideOwnTeam
        avatarScale = Double(settings.avatarScale)
        mapSpacing = Double(settings.mapSpacing)
        mapOpacity = Double(settings.opacity)
        self.topScale = Double(topScale)
        self.topOpacity = Double(topOpacity)
        offsetX = Double(settings.offsetX)
        offsetY = Double(settings.offsetY)
        resourceOffsetX = Double(settings.resourceOffsetX)
        resourceOffsetY = Double(settings.resourceOffsetY)
        minionOffsetX = Double(settings.minionOffsetX)
        minionOffsetY = Double(settings.minionOffsetY)
        topOffsetX = Double(topX)
        topOffsetY = Double(topY)
    }
}

struct HUDEnvelope: Codable {
    var version: Int = 1
    var enabled: Bool
    var room: String
    var frame: BattleFrame?
    var settings: HUDSettingsSnapshot
    var updatedAt: TimeInterval
}

enum HUDTransport {
    static let helperBundleName = "HaiHUD.app"
    static let stateFileName = "com.hai.ios.hud.json"
    static let controlFileName = "com.hai.ios.hud.control"

    static func stateURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(stateFileName, isDirectory: false)
    }

    static func write(_ envelope: HUDEnvelope, to url: URL = stateURL()) -> Result<Void, Error> {
        do {
            let data = try JSONEncoder().encode(envelope)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: [.atomic])
            return .success(())
        } catch {
            return .failure(error)
        }
    }

    static func read(from url: URL) -> HUDEnvelope? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(HUDEnvelope.self, from: data)
    }
}
