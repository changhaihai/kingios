import UIKit

struct MapViewport {
    let scale: Float
    let width: Float
    let height: Float

    func mapX(_ x: Float) -> Float { return x * scale }
    func mapY(_ y: Float) -> Float { return y * scale }

    func clampX(_ x: Float, margin: Float = 0) -> Float {
        return min(max(x, margin), max(width - margin, margin))
    }

    func clampY(_ y: Float, margin: Float = 0) -> Float {
        return min(max(y, margin), max(height - margin, margin))
    }
}

enum MapViewportCalculator {
    static let referenceWidth: Float = 2400
    static let referenceHeight: Float = 1080

    static func contain(width: Int, height: Int) -> MapViewport {
        let safeWidth = Float(max(width, 1))
        let safeHeight = Float(max(height, 1))
        return MapViewport(
            scale: min(safeWidth / referenceWidth, safeHeight / referenceHeight),
            width: safeWidth,
            height: safeHeight
        )
    }
}

/// 1:1 port of the Android MapOverlayView renderer (minions, resources,
/// towers, hero avatars + HP bars, AI dots, recall arcs, 2400x1080 space).
final class MapOverlayView: UIView {
    private var frameData: BattleFrame?
    private var settings = DisplaySettings()
    private var detached = false
    private var recallTimer: Timer?

    private let avatarCache = NSCache<NSString, UIImage>()
    private var avatarLoading = Set<String>()
    private let loadingLock = NSLock()
    private let avatarQueue = DispatchQueue(label: "map-avatar", qos: .utility, attributes: .concurrent)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func submit(_ next: BattleFrame) {
        guard !detached else { return }
        frameData = next
        setNeedsDisplay()
        updateRecallTimer(next)
    }

    func updateSettings(_ next: DisplaySettings) {
        guard !detached else { return }
        settings = next
        setNeedsDisplay()
    }

    func reattach() {
        detached = false
        avatarLoading.removeAll()
        setNeedsDisplay()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        detached = window == nil
        if !detached { setNeedsDisplay() }
    }

    private func updateRecallTimer(_ next: BattleFrame) {
        let hasRecall = next.heroes.contains { $0.returning }
        if hasRecall {
            if recallTimer == nil {
                let timer = Timer(timeInterval: 0.032, repeats: true) { [weak self] _ in
                    self?.setNeedsDisplay()
                }
                RunLoop.main.add(timer, forMode: .common)
                recallTimer = timer
            }
        } else {
            recallTimer?.invalidate()
            recallTimer = nil
        }
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        guard let value = frameData else { return }

        let config = settings
        let viewport = MapViewportCalculator.contain(width: Int(bounds.width), height: Int(bounds.height))
        let mapFactor = min(max(1 + config.mapSpacing / 100, 0.5), 2)

        func map(_ v: Float) -> Float { return (v - 170) * mapFactor + 170 }
        func px(_ x: Float) -> CGFloat { return CGFloat(viewport.mapX(map(x) + config.offsetX)) }
        func py(_ y: Float) -> CGFloat { return CGFloat(viewport.mapY(map(y) + config.offsetY)) }
        func rpx(_ x: Float) -> CGFloat { return CGFloat(viewport.mapX(map(x) + config.offsetX + config.resourceOffsetX)) }
        func rpy(_ y: Float) -> CGFloat { return CGFloat(viewport.mapY(map(y) + config.offsetY + config.resourceOffsetY)) }
        func mpx(_ x: Float) -> CGFloat { return CGFloat(viewport.mapX(map(x) + config.offsetX + config.minionOffsetX)) }
        func mpy(_ y: Float) -> CGFloat { return CGFloat(viewport.mapY(map(y) + config.offsetY + config.minionOffsetY)) }

        let scale = CGFloat(viewport.scale)
        let alpha = CGFloat(config.opacity)
        let blue = UIColor(red: 37/255.0, green: 141/255.0, blue: 242/255.0, alpha: 1)
        let red = UIColor(red: 224/255.0, green: 72/255.0, blue: 72/255.0, alpha: 1)
        let gold = UIColor(red: 240/255.0, green: 188/255.0, blue: 85/255.0, alpha: 1)

        func color(_ isBlue: Bool) -> UIColor { return isBlue ? blue : red }

        if config.minions {
            for unit in value.minions {
                ctx.setFillColor(color(unit.blue).withAlphaComponent(alpha).cgColor)
                ctx.fillEllipse(in: CGRect(x: mpx(unit.x) - 4 * scale, y: mpy(unit.y) - 4 * scale, width: 8 * scale, height: 8 * scale))
            }
        }

        if config.resources {
            let readySet: Set<Int> = [0, 60, 70, 90, 120, 240]
            for item in value.resources {
                let rx = rpx(item.x)
                let ry = rpy(item.y)
                if readySet.contains(item.cooldown) {
                    ctx.setFillColor(gold.withAlphaComponent(alpha).cgColor)
                    ctx.fillEllipse(in: CGRect(x: rx - 5 * scale, y: ry - 5 * scale, width: 10 * scale, height: 10 * scale))
                } else {
                    let text = "\(item.cooldown)s" as NSString
                    let font = UIFont.boldSystemFont(ofSize: 18 * scale)
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: font,
                        .foregroundColor: gold.withAlphaComponent(alpha)
                    ]
                    let size = text.size(withAttributes: attrs)
                    text.draw(at: CGPoint(x: rx - size.width / 2, y: ry - 12 * scale - size.height / 2), withAttributes: attrs)
                }
            }
        }

        if config.towers {
            for tower in value.towers {
                let x = px(tower.x)
                let y = py(tower.y)
                let w = 14 * scale
                let h = 16 * scale
                let rect = CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 3 * scale).cgPath
                ctx.setFillColor(UIColor(red: 14/255.0, green: 23/255.0, blue: 29/255.0, alpha: alpha).cgColor)
                ctx.addPath(path)
                ctx.fillPath()
                ctx.setStrokeColor(color(tower.blue).withAlphaComponent(alpha).cgColor)
                ctx.setLineWidth(2 * scale)
                ctx.addPath(path)
                ctx.strokePath()
                let ratio = CGFloat(min(max(tower.hp / tower.maxHp, 0), 1))
                ctx.setFillColor(color(tower.blue).withAlphaComponent(alpha).cgColor)
                ctx.fill(CGRect(x: x - w / 2 + 2 * scale, y: y + h / 2 - 4 * scale, width: (w - 4 * scale) * ratio, height: 2 * scale))
            }
        }

        var heroes = value.heroes
        if config.hideOwnTeam {
            heroes = heroes.filter { !$0.ownTeam }
        }
        for hero in heroes {
            let avatarScale = CGFloat(config.avatarScale)
            let diameter = 40 * avatarScale * scale
            let radius = diameter / 2
            let barHeight = 7 * avatarScale * scale
            let topSpace = 6 * avatarScale * scale
            let xF = viewport.clampX(Float(px(hero.x)) + Float(radius), margin: Float(radius))
            let yMargin = Float(radius) + Float(topSpace)
            let yCap = max(Float(bounds.height) - Float(radius) - Float(barHeight), yMargin)
            let yF = min(viewport.clampY(Float(py(hero.y)) + Float(radius), margin: yMargin), yCap)
            let x = CGFloat(xF)
            let y = CGFloat(yF)
            let accent = color(hero.blue)

            if config.heroes {
                ctx.setFillColor(UIColor(red: 20/255.0, green: 28/255.0, blue: 34/255.0, alpha: alpha).cgColor)
                ctx.fillEllipse(in: CGRect(x: x - radius, y: y - radius, width: diameter, height: diameter))
                drawAvatar(ctx: ctx, id: hero.id, x: x, y: y, radius: radius, alpha: alpha)
                ctx.setStrokeColor(accent.withAlphaComponent(alpha).cgColor)
                ctx.setLineWidth(3 * avatarScale * scale)
                ctx.strokeEllipse(in: CGRect(x: x - radius, y: y - radius, width: diameter, height: diameter))

                let barTop = y + radius
                let barHalf = radius
                ctx.setFillColor(UIColor(white: 1, alpha: alpha / 2).cgColor)
                ctx.fill(CGRect(x: x - barHalf, y: barTop, width: barHalf * 2, height: barHeight))
                ctx.setFillColor(accent.withAlphaComponent(alpha).cgColor)
                ctx.fill(CGRect(x: x - barHalf, y: barTop, width: barHalf * 2 * CGFloat(hero.hp / 100), height: barHeight))

                if hero.ai {
                    ctx.setFillColor(gold.withAlphaComponent(alpha).cgColor)
                    ctx.fillEllipse(in: CGRect(
                        x: x - 4 * avatarScale * scale,
                        y: y - radius - 10 * avatarScale * scale,
                        width: 8 * avatarScale * scale,
                        height: 8 * avatarScale * scale
                    ))
                }
                if hero.returning {
                    drawRecall(ctx: ctx, x: x, y: y, radius: radius + 5 * avatarScale * scale, strokeWidth: 3 * avatarScale * scale, color: accent, alpha: alpha)
                }
            }
        }
    }

    private func drawAvatar(ctx: CGContext, id: String, x: CGFloat, y: CGFloat, radius: CGFloat, alpha: CGFloat) {
        if let bitmap = avatarCache.object(forKey: id as NSString) {
            ctx.saveGState()
            let clipRadius = max(radius - 2, 1)
            ctx.addEllipse(in: CGRect(x: x - clipRadius, y: y - clipRadius, width: clipRadius * 2, height: clipRadius * 2))
            ctx.clip()
            if let cg = bitmap.cgImage {
                let side = min(cg.width, cg.height)
                let src = CGRect(x: (cg.width - side) / 2, y: (cg.height - side) / 2, width: side, height: side)
                if let cropped = cg.cropping(to: src) {
                    ctx.draw(cropped, in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                }
            }
            ctx.restoreGState()
        } else {
            requestAvatar(id: id)
            drawFallbackText(id: id, x: x, y: y, radius: radius, alpha: alpha)
        }
    }

    private func drawFallbackText(id: String, x: CGFloat, y: CGFloat, radius: CGFloat, alpha: CGFloat) {
        let font = UIFont.boldSystemFont(ofSize: 14 * (radius / 16))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(alpha)
        ]
        let text = id as NSString
        let size = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: x - size.width / 2, y: y + font.pointSize * 0.35 - size.height / 2), withAttributes: attrs)
    }

    private func drawRecall(ctx: CGContext, x: CGFloat, y: CGFloat, radius: CGFloat, strokeWidth: CGFloat, color: UIColor, alpha: CGFloat) {
        let cycle = CACurrentMediaTime().truncatingRemainder(dividingBy: 1.6) / 1.6
        let start = CGFloat(cycle) * CGFloat.pi * 2
        ctx.setStrokeColor(color.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.addArc(center: CGPoint(x: x, y: y), radius: radius, startAngle: start, endAngle: start + 130 * .pi / 180, clockwise: false)
        ctx.strokePath()
        ctx.addArc(center: CGPoint(x: x, y: y), radius: radius, startAngle: start + .pi, endAngle: start + .pi + 130 * .pi / 180, clockwise: false)
        ctx.strokePath()
    }

    private func requestAvatar(id: String) {
        guard !id.isEmpty else { return }
        loadingLock.lock()
        if avatarLoading.contains(id) {
            loadingLock.unlock()
            return
        }
        avatarLoading.insert(id)
        loadingLock.unlock()

        avatarQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                self.loadingLock.lock()
                self.avatarLoading.remove(id)
                self.loadingLock.unlock()
                DispatchQueue.main.async {
                    if !self.detached { self.setNeedsDisplay() }
                }
            }
            if self.detached { return }
            guard let url = URL(string: "https://game.gtimg.cn/images/yxzj/img201606/heroimg/\(id)/\(id).jpg") else { return }
            var image: UIImage?
            let sem = DispatchSemaphore(value: 0)
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 7)
            URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data = data { image = UIImage(data: data) }
                sem.signal()
            }.resume()
            sem.wait()
            guard var img = image, !self.detached else { return }
            let maxSide: CGFloat = 160
            if img.size.width > maxSide || img.size.height > maxSide {
                let ratio = maxSide / max(img.size.width, img.size.height)
                let newSize = CGSize(width: img.size.width * ratio, height: img.size.height * ratio)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1)
                img.draw(in: CGRect(origin: .zero, size: newSize))
                let scaled = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                if let scaled = scaled { img = scaled }
            }
            self.avatarCache.setObject(img, forKey: id as NSString)
        }
    }
}
