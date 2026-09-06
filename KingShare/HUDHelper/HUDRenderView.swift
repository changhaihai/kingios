import UIKit

final class HUDRenderView: UIView {
    private var envelope: HUDEnvelope?
    private var externalFrame: BattleFrame?
    private var imageCache: [String: UIImage] = [:]
    private var loadingIDs = Set<String>()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        isUserInteractionEnabled = false
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("HUDRenderView does not use NSCoder") }

    func apply(envelope: HUDEnvelope) {
        self.envelope = envelope
        if let frame = envelope.frame { externalFrame = frame }
        preloadImages(for: envelope.frame)
        setNeedsDisplay()
    }

    func apply(frame: BattleFrame) {
        externalFrame = frame
        preloadImages(for: frame)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(), let envelope, envelope.enabled else { return }
        let settings = envelope.settings
        guard let frame = externalFrame ?? envelope.frame else { return }
        let baseScale = min(bounds.width / 2400, bounds.height / 1080)
        let scale = baseScale
        let spacing = CGFloat((100 + settings.mapSpacing) / 100)
        func point(_ x: Float, _ y: Float) -> CGPoint {
            let mappedX = (x - 170) * Float(spacing) + 170 + Float(settings.offsetX)
            let mappedY = (y - 170) * Float(spacing) + 170 + Float(settings.offsetY)
            return CGPoint(x: CGFloat(mappedX) * scale, y: CGFloat(mappedY) * scale)
        }
        func color(_ blue: Bool) -> UIColor {
            blue ? UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 1) : UIColor(red: 0.88, green: 0.28, blue: 0.28, alpha: 1)
        }

        context.saveGState()
        context.setAlpha(CGFloat(max(0.3, min(settings.mapOpacity, 1))))
        if settings.showMinions {
            for unit in frame.minions {
                let p = point(unit.x + Float(settings.minionOffsetX), unit.y + Float(settings.minionOffsetY))
                context.setFillColor(color(unit.blue).cgColor)
                context.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
            }
        }
        if settings.showResources {
            for item in frame.resources {
                let p = point(item.x + Float(settings.resourceOffsetX), item.y + Float(settings.resourceOffsetY))
                let ready = [0, 60, 70, 90, 120, 240].contains(item.cooldown)
                if ready {
                    UIColor(red: 0.94, green: 0.74, blue: 0.33, alpha: 1).setFill()
                    context.fillEllipse(in: CGRect(x: p.x - 6, y: p.y - 6, width: 12, height: 12))
                } else {
                    let text = "\(item.cooldown)s" as NSString
                    text.draw(at: CGPoint(x: p.x - 12, y: p.y - 18), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 12),
                        .foregroundColor: UIColor(red: 0.94, green: 0.74, blue: 0.33, alpha: 1)
                    ])
                }
            }
        }
        if settings.showTowers {
            for tower in frame.towers {
                let p = point(tower.x, tower.y)
                let box = CGRect(x: p.x - 9, y: p.y - 10, width: 18, height: 20)
                context.setStrokeColor(color(tower.blue).cgColor)
                context.setLineWidth(2)
                context.stroke(box)
                context.setFillColor(color(tower.blue).cgColor)
                context.fill(CGRect(x: box.minX + 2, y: box.maxY - 5, width: (box.width - 4) * CGFloat(max(0, min(tower.hp / max(tower.maxHp, 1), 1))), height: 3))
            }
        }
        if settings.showHeroes {
            for hero in frame.heroes where !(settings.hideOwnTeam && hero.ownTeam) {
                let p = point(hero.x + 20, hero.y + 20)
                let radius = 20 * CGFloat(settings.avatarScale)
                let circle = CGRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)
                context.setFillColor(UIColor.black.withAlphaComponent(0.72).cgColor)
                context.fillEllipse(in: circle)
                context.setStrokeColor(color(hero.blue).cgColor)
                context.setLineWidth(3)
                context.strokeEllipse(in: circle)
                context.setFillColor(color(hero.blue).cgColor)
                context.fill(CGRect(x: p.x - radius, y: p.y + radius + 3, width: radius * 2 * CGFloat(max(0, min(hero.hp, 100)) / 100), height: 5))
                if settings.showHeroAvatars, let image = imageCache[hero.id], let cgImage = image.cgImage {
                    context.saveGState()
                    context.addEllipse(in: circle)
                    context.clip()
                    context.draw(cgImage, in: circle)
                    context.restoreGState()
                } else {
                    drawLabel(hero.id, in: circle, context: context)
                }
                if hero.ai {
                    context.setFillColor(UIColor(red: 0.94, green: 0.74, blue: 0.33, alpha: 1).cgColor)
                    context.fillEllipse(in: CGRect(x: p.x - 4, y: p.y - radius - 10, width: 8, height: 8))
                }
                if hero.returning {
                    context.setStrokeColor(color(hero.blue).cgColor)
                    context.setLineWidth(3)
                    context.strokeEllipse(in: CGRect(x: p.x - radius - 5, y: p.y - radius - 5, width: (radius + 5) * 2, height: (radius + 5) * 2))
                }
            }
        }
        context.restoreGState()
        if settings.showTopInfo {
            context.saveGState()
            context.setAlpha(CGFloat(max(0.3, min(settings.topOpacity, 1))))
            drawTopInfo(frame.heroes.filter { !$0.ownTeam }.prefix(5), settings: settings, context: context)
            context.restoreGState()
        }
    }

    private func drawLabel(_ id: String, in rect: CGRect, context: CGContext) {
        let text = String(id.suffix(3)) as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: max(8, rect.width * 0.24)), .foregroundColor: UIColor.white]
        let size = text.size(withAttributes: attributes)
        text.draw(at: CGPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2), withAttributes: attributes)
    }

    private func drawTopInfo<S: Sequence>(_ heroes: S, settings: HUDSettingsSnapshot, context: CGContext) where S.Element == Hero {
        var x = CGFloat(3 + settings.topOffsetX)
        let y = CGFloat(4 + settings.topOffsetY)
        for hero in heroes {
            let size = CGFloat(52 * settings.topScale)
            let box = CGRect(x: x, y: y, width: size, height: size)
            UIColor(red: 0.03, green: 0.06, blue: 0.09, alpha: 0.73).setFill()
            context.fill(box)
            context.setStrokeColor((hero.blue ? UIColor.systemBlue : UIColor.systemRed).cgColor)
            context.setLineWidth(1)
            context.stroke(box)
            let title = "大 \(hero.ultimateCooldown > 0 ? "\(Int(ceil(hero.ultimateCooldown)))s" : "OK")  技 \(hero.skillCooldown > 0 ? "\(Int(ceil(hero.skillCooldown)))s" : "OK")" as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.white]
            title.draw(at: CGPoint(x: x + 3, y: y + size - 14), withAttributes: attrs)
            x += size + 3
        }
    }

    private func preloadImages(for frame: BattleFrame?) {
        guard let frame else { return }
        for hero in frame.heroes where imageCache[hero.id] == nil && !loadingIDs.contains(hero.id) {
            loadingIDs.insert(hero.id)
            guard let url = URL(string: "https://game.gtimg.cn/images/yxzj/img201606/heroimg/\(hero.id)/\(hero.id).jpg") else { continue }
            URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
                guard let self, let data, let image = UIImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.imageCache[hero.id] = image
                    self.loadingIDs.remove(hero.id)
                    self.setNeedsDisplay()
                }
            }.resume()
        }
    }
}
