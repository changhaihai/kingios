import Foundation

struct Hero: Identifiable, Equatable {
    let id: String
    let x: Float
    let y: Float
    let hp: Float
    let blue: Bool
    let ownTeam: Bool
    let ultimateCooldown: Float
    let skillCooldown: Float
    let returning: Bool
    let ai: Bool
}

struct Resource: Identifiable, Equatable {
    let id = UUID()
    let x: Float
    let y: Float
    let cooldown: Int
}

struct Minion: Identifiable, Equatable {
    let id = UUID()
    let x: Float
    let y: Float
    let blue: Bool
}

struct Tower: Identifiable, Equatable {
    let id = UUID()
    let x: Float
    let y: Float
    let hp: Float
    let maxHp: Float
    let blue: Bool
}

struct BattleFrame: Equatable {
    var heroes: [Hero] = []
    var resources: [Resource] = []
    var minions: [Minion] = []
    var towers: [Tower] = []
}

enum BattleFrameParser {
    static func parse(_ raw: String) -> BattleFrame? {
        guard !raw.isEmpty, raw.utf8.count <= 256 * 1024 else { return nil }
        var normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.hasPrefix("##") { normalized.removeFirst(2) }
        let sections = normalized.components(separatedBy: "---")
        guard sections.count >= 3 else { return nil }
        let heroRows = records(sections[0])
        let foe = heroRows.compactMap { $0.count > 9 ? $0[9].trimmingCharacters(in: .whitespaces) : nil }
            .first { !$0.isEmpty }
        let heroes = heroRows.prefix(20).compactMap { row -> Hero? in
            guard row.count >= 9 else { return nil }
            let id = row[0].trimmingCharacters(in: .whitespaces)
            guard !id.isEmpty else { return nil }
            let enemy = same(row[8], row.count > 9 ? row[9] : foe)
            return Hero(id: id, x: number(row, 5), y: number(row, 6), hp: min(max(number(row, 7), 0), 100),
                        blue: !enemy, ownTeam: !enemy, ultimateCooldown: max(number(row, 3), 0),
                        skillCooldown: max(number(row, 4), 0), returning: row.count > 10 && row[10].trimmed == "1",
                        ai: row.count > 13 && row[13].trimmed == "1")
        }
        let resources = records(sections.count > 1 ? sections[1] : "").prefix(128).compactMap { row -> Resource? in
            guard row.count >= 5 else { return nil }
            return Resource(x: number(row, 3), y: number(row, 4), cooldown: max(Int(number(row, 1)), 0))
        }
        let minions = records(sections.count > 2 ? sections[2] : "").prefix(256).compactMap { row -> Minion? in
            guard row.count >= 3 else { return nil }
            return Minion(x: number(row, 0), y: number(row, 1), blue: !same(row[2], foe))
        }
        let towers = records(sections.count > 3 ? sections[3] : "").prefix(32).compactMap { row -> Tower? in
            guard row.count >= 7, Int(number(row, 0)) >= 1690, Int(number(row, 0)) <= 1699,
                  row[6].trimmed == "1", number(row, 1) > 0, number(row, 2) > 0,
                  (1...2).contains(Int(number(row, 5))) else { return nil }
            return Tower(x: number(row, 3), y: number(row, 4), hp: number(row, 1), maxHp: number(row, 2), blue: Int(number(row, 5)) == 1)
        }
        return BattleFrame(heroes: heroes, resources: resources, minions: minions, towers: towers)
    }

    private static func records(_ section: String) -> [[String]] {
        section.split(separator: "==", omittingEmptySubsequences: true).prefix(256).map { part in
            part.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        }
    }
    private static func number(_ row: [String], _ index: Int) -> Float { Float(row.indices.contains(index) ? row[index].trimmed : "") ?? 0 }
    private static func same(_ left: String?, _ right: String?) -> Bool {
        guard let a = left?.trimmed, let b = right?.trimmed, !a.isEmpty, !b.isEmpty else { return false }
        return Int64(a) != nil && Int64(b) != nil ? Int64(a) == Int64(b) : a == b
    }
}

struct DisplaySettings: Equatable {
    var heroes = true
    var resources = true
    var minions = true
    var towers = true
    var topInfo = true
    var hideOwnTeam = false
    var opacity: Double = 1
    var avatarScale: Double = 1
    var offsetX: Double = 0
    var offsetY: Double = 0
    var mapSpacing: Double = 0
    var resourceOffsetX: Double = 0
    var resourceOffsetY: Double = 0
    var minionOffsetX: Double = 0
    var minionOffsetY: Double = 0
    var topX: Double = 0
    var topY: Double = 0
    var topSize: Double = 1
    var topOpacity: Double = 1
    var secureOverlay = false
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
