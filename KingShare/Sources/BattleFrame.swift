import Foundation

struct Hero {
    let id: String
    let x: Float
    let y: Float
    let hp: Float
    let blue: Bool
    let ownTeam: Bool
    let ultimateCooldown: Float
    let skillCooldown: Float
    let ultimateSkillId: Int
    let summonerSkillId: Int
    let returning: Bool
    let ai: Bool
}

struct Resource {
    let x: Float
    let y: Float
    let cooldown: Int
}

struct Minion {
    let x: Float
    let y: Float
    let blue: Bool
}

struct Tower {
    let x: Float
    let y: Float
    let hp: Float
    let maxHp: Float
    let blue: Bool
}

struct BattleFrame {
    let heroes: [Hero]
    let resources: [Resource]
    let minions: [Minion]
    let towers: [Tower]
}

/// 1:1 port of the Android BattleFrameParser (same section/row/field layout).
enum BattleFrameParser {
    static func parse(_ raw: String) -> BattleFrame? {
        if raw.isEmpty || raw.count > 256 * 1024 { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = trimmed.hasPrefix("##") ? String(trimmed.dropFirst(2)) : trimmed
        let sections = body.components(separatedBy: "---")
        if sections.count < 3 { return nil }

        let heroRows = records(sections[0])
        var foe: String = ""
        for row in heroRows {
            if row.count > 9 && !row[9].isEmpty {
                foe = row[9]
                break
            }
        }

        let heroes: [Hero] = heroRows.prefix(20).compactMap { row in
            let id = row.count > 0 ? row[0].trimmingCharacters(in: .whitespaces) : ""
            if id.isEmpty || row.count < 9 { return nil }
            let right = row.count > 9 ? row[9] : foe
            let enemyTeam = same(row[8], right)
            return Hero(
                id: id,
                x: number(row, 5),
                y: number(row, 6),
                hp: min(max(number(row, 7), 0), 100),
                blue: !enemyTeam,
                ownTeam: !enemyTeam,
                ultimateCooldown: max(number(row, 3), 0),
                skillCooldown: max(number(row, 4), 0),
                ultimateSkillId: max(Int(number(row, 12)), 0),
                summonerSkillId: max(Int(number(row, 11)), 0),
                returning: (row.count > 10 ? row[10] : "").trimmingCharacters(in: .whitespaces) == "1",
                ai: (row.count > 13 ? row[13] : "").trimmingCharacters(in: .whitespaces) == "1"
            )
        }

        let resources: [Resource] = records(sections.count > 1 ? sections[1] : "").prefix(128).compactMap { row in
            if row.count < 5 { return nil }
            return Resource(x: number(row, 3), y: number(row, 4), cooldown: max(Int(number(row, 1)), 0))
        }

        let minions: [Minion] = records(sections.count > 2 ? sections[2] : "").prefix(256).compactMap { row in
            if row.count < 3 { return nil }
            return Minion(x: number(row, 0), y: number(row, 1), blue: !same(row[2], foe))
        }

        let towers: [Tower] = records(sections.count > 3 ? sections[3] : "").prefix(32).compactMap { row in
            let id = Int(number(row, 0))
            let hp = number(row, 1)
            let maxHp = number(row, 2)
            let camp = Int(number(row, 5))
            if row.count < 7 || row[6].trimmingCharacters(in: .whitespaces) != "1"
                || id < 1690 || id > 1699 || hp <= 0 || maxHp <= 0 || camp < 1 || camp > 2 {
                return nil
            }
            return Tower(x: number(row, 3), y: number(row, 4), hp: hp, maxHp: maxHp, blue: camp == 1)
        }

        return BattleFrame(heroes: heroes, resources: resources, minions: minions, towers: towers)
    }

    private static func records(_ section: String) -> [[String]] {
        return section.components(separatedBy: "==").filter { !$0.isEmpty }.prefix(256).map {
            $0.components(separatedBy: ",")
        }
    }

    private static func number(_ row: [String], _ index: Int) -> Float {
        guard row.count > index else { return 0 }
        return Float(row[index].trimmingCharacters(in: .whitespaces)) ?? 0
    }

    private static func same(_ left: String, _ right: String) -> Bool {
        let a = left.trimmingCharacters(in: .whitespaces)
        let b = right.trimmingCharacters(in: .whitespaces)
        if a.isEmpty || b.isEmpty { return false }
        if let la = Int64(a) { return la == Int64(b) }
        return a == b
    }
}
