import SwiftUI

struct MapHUDView: View {
    let frame: BattleFrame
    let settings: DisplaySettings
    var showCalibration = false

    private let referenceWidth: CGFloat = 2400
    private let referenceHeight: CGFloat = 1080
    private let mapCenter: CGFloat = 170

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / referenceWidth, proxy.size.height / referenceHeight)
            ZStack {
                Canvas { context, size in draw(context: &context, size: size, scale: scale) }
                if showCalibration {
                    let mapFactor = CGFloat((1 + settings.mapSpacing / 100).clamped(to: 0.5...2))
                    let side = min(proxy.size.width, proxy.size.height, 340 * scale * mapFactor)
                    Rectangle().fill(KingTheme.green.opacity(0.12)).frame(width: side, height: side)
                        .overlay(Rectangle().stroke(KingTheme.green, lineWidth: 2))
                        .overlay(alignment: .bottomTrailing) { Image(systemName: "arrow.down.right.and.arrow.up.left").foregroundStyle(KingTheme.green).padding(8) }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.allowsHitTesting(false)
    }

    private func draw(context: inout GraphicsContext, size: CGSize, scale: CGFloat) {
        let factor = CGFloat((1 + settings.mapSpacing / 100).clamped(to: 0.5...2))
        func point(_ x: Float, _ y: Float, resource: Bool = false, minion: Bool = false) -> CGPoint {
            let dx = resource ? settings.resourceOffsetX : minion ? settings.minionOffsetX : 0
            let dy = resource ? settings.resourceOffsetY : minion ? settings.minionOffsetY : 0
            let mx = (CGFloat(x) - mapCenter) * factor + mapCenter + CGFloat(settings.offsetX) + CGFloat(dx)
            let my = (CGFloat(y) - mapCenter) * factor + mapCenter + CGFloat(settings.offsetY) + CGFloat(dy)
            return CGPoint(x: mx * scale, y: my * scale)
        }
        func color(_ blue: Bool) -> Color { blue ? KingTheme.blue : KingTheme.red }
        let opacity = settings.opacity.clamped(to: 0...1)
        if settings.minions {
            for unit in frame.minions { context.fill(Path(ellipseIn: CGRect(x: point(unit.x, unit.y, minion: true).x - 3*scale, y: point(unit.x, unit.y, minion: true).y - 3*scale, width: 6*scale, height: 6*scale)), with: .color(color(unit.blue).opacity(opacity))) }
        }
        if settings.resources {
            for item in frame.resources {
                let p = point(item.x, item.y, resource: true)
                if item.cooldown <= 0 { context.fill(Path(ellipseIn: CGRect(x: p.x-5*scale, y: p.y-5*scale, width: 10*scale, height: 10*scale)), with: .color(KingTheme.gold.opacity(opacity))) }
                else { context.draw(Text("\(item.cooldown)s").font(.system(size: max(9, 18*scale))).foregroundStyle(KingTheme.gold.opacity(opacity)), at: CGPoint(x: p.x, y: p.y-12*scale)) }
            }
        }
        if settings.towers {
            for tower in frame.towers {
                let p = point(tower.x, tower.y), w = 14*scale, h = 16*scale
                let rect = CGRect(x: p.x-w/2, y: p.y-h/2, width: w, height: h)
                context.fill(Path(roundedRect: rect, cornerRadius: 3*scale), with: .color(KingTheme.page.opacity(opacity)))
                context.stroke(Path(roundedRect: rect, cornerRadius: 3*scale), with: .color(color(tower.blue).opacity(opacity)), lineWidth: 2*scale)
                let ratio = CGFloat((tower.hp / tower.maxHp).clamped(to: 0...1))
                context.fill(Path(CGRect(x: rect.minX+2*scale, y: rect.maxY-4*scale, width: (w-4*scale)*ratio, height: 2*scale)), with: .color(color(tower.blue).opacity(opacity)))
            }
        }
        let heroes = settings.hideOwnTeam ? frame.heroes.filter { !$0.ownTeam } : frame.heroes
        guard settings.heroes else { return }
        for hero in heroes {
            let raw = point(hero.x, hero.y), diameter = 40 * CGFloat(settings.avatarScale) * scale, radius = diameter/2
            let x = raw.x.clamped(to: radius...(size.width-radius)), y = raw.y.clamped(to: radius...(size.height-radius-8*scale))
            let center = CGPoint(x: x, y: y), accent = color(hero.blue).opacity(opacity)
            context.fill(Path(ellipseIn: CGRect(x:x-radius, y:y-radius, width:diameter, height:diameter)), with: .color(KingTheme.page.opacity(opacity)))
            context.draw(Text(String(hero.id.suffix(3))).font(.system(size: max(8, radius * 0.48), weight: .bold)).foregroundStyle(.white.opacity(opacity)), at: center)
            context.stroke(Path(ellipseIn: CGRect(x:x-radius, y:y-radius, width:diameter, height:diameter)), with: .color(accent), lineWidth: max(2, 3*CGFloat(settings.avatarScale)*scale))
            let hpRect = CGRect(x:x-radius, y:y+radius, width:diameter, height:max(3, 7*CGFloat(settings.avatarScale)*scale))
            context.fill(Path(roundedRect: hpRect, cornerRadius: 2), with: .color(.white.opacity(0.25*opacity)))
            context.fill(Path(roundedRect: CGRect(x:hpRect.minX, y:hpRect.minY, width:hpRect.width*CGFloat(hero.hp/100), height:hpRect.height), cornerRadius: 2), with: .color(accent))
            if hero.ai { context.fill(Path(ellipseIn: CGRect(x:x-3*scale, y:y-radius-10*scale, width:6*scale, height:6*scale)), with: .color(KingTheme.gold.opacity(opacity))) }
            if hero.returning { context.stroke(Path(ellipseIn: CGRect(x:x-radius-5*scale, y:y-radius-5*scale, width:diameter+10*scale, height:diameter+10*scale)), with: .color(accent), lineWidth: 2*scale) }
        }
    }
}

struct TopInfoHUDView: View {
    let enemies: [Hero]
    let settings: DisplaySettings
    var body: some View {
        if settings.topInfo && !enemies.isEmpty {
            HStack(spacing: 3) {
                ForEach(enemies.prefix(5)) { hero in
                    VStack(spacing: 2) {
                        Text(String(hero.id.suffix(3))).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                            .frame(width: 38, height: 38).background(KingTheme.header).clipShape(Circle())
                            .overlay(Circle().stroke(hero.blue ? KingTheme.blue : KingTheme.red, lineWidth: 2))
                        HStack(spacing: 2) { Badge(title: "大", cooldown: hero.ultimateCooldown, color: KingTheme.gold); Badge(title: "技", cooldown: hero.skillCooldown, color: KingTheme.green) }
                    }.padding(3).background(KingTheme.page.opacity(0.86)).clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }.scaleEffect(settings.topSize).opacity(settings.topOpacity)
        }
    }
}

private struct Badge: View {
    let title: String; let cooldown: Float; let color: Color
    var body: some View {
        HStack(spacing: 1) { Text(title).font(.system(size: 8, weight: .bold)); if cooldown > 0 { Text("\(Int(ceil(cooldown)))s").font(.system(size: 7)) } else { Circle().fill(.white).frame(width: 3, height: 3) } }
            .foregroundStyle(cooldown > 0 ? KingTheme.secondary : color).padding(.horizontal, 2).frame(height: 12)
            .background(KingTheme.page).overlay(RoundedRectangle(cornerRadius: 2).stroke(cooldown > 0 ? KingTheme.muted : color, lineWidth: 0.7)).clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self { min(max(self, range.lowerBound), range.upperBound) }
}
