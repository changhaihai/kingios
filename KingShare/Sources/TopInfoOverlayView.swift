import UIKit

/// 1:1 port of the Android TopInfoOverlayView: compact enemy-only top strip
/// with avatars and 大/技 cooldown badges.
final class TopInfoOverlayView: UIView {
    private var enemies: [Hero] = []
    private var uiScale: CGFloat = 1

    private let avatarCache = NSCache<NSString, UIImage>()
    private var loading = Set<String>()
    private let lock = NSLock()
    private let avatarQueue = DispatchQueue(label: "top-avatar", qos: .utility, attributes: .concurrent)

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func submit(_ frame: BattleFrame) {
        enemies = Array(frame.heroes.filter { !$0.ownTeam }.prefix(5))
        setNeedsDisplay()
    }

    func clear() {
        enemies = []
        setNeedsDisplay()
    }

    func updateScale(_ scale: CGFloat) {
        uiScale = min(max(scale, 0.6), 1.8)
        setNeedsDisplay()
    }

    func reattach() {
        loading.removeAll()
        setNeedsDisplay()
    }

    private func dp(_ value: CGFloat) -> CGFloat {
        return value * uiScale
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        let list = enemies
        guard !list.isEmpty, bounds.width > 0, bounds.height > 0 else { return }

        let outer = dp(3)
        let cellWidth = dp(52)
        let gap = dp(3)
        let rowWidth = cellWidth * CGFloat(list.count) + gap * CGFloat(list.count - 1)
        let startX = max((bounds.width - rowWidth) / 2, outer)
        let avatarSize = max(min(dp(28), cellWidth - dp(6)), dp(18))
        let avatarLeftOffset = (cellWidth - avatarSize) / 2
        let badgeHeight = dp(11)
        let ultBadgeWidth = dp(24)
        let skillBadgeWidth = dp(24)
        let badgeGap = dp(2)
        let badgesWidth = ultBadgeWidth + badgeGap + skillBadgeWidth

        let gold = UIColor(red: 240/255.0, green: 188/255.0, blue: 85/255.0, alpha: 1)
        let green = UIColor(red: 69/255.0, green: 220/255.0, blue: 156/255.0, alpha: 1)

        for (index, hero) in list.enumerated() {
            let left = startX + CGFloat(index) * (cellWidth + gap)
            let avatarLeft = left + avatarLeftOffset
            let avatarTop = outer
            let teamColor = hero.blue
                ? UIColor(red: 53/255.0, green: 163/255.0, blue: 255/255.0, alpha: 1)
                : UIColor(red: 255/255.0, green: 102/255.0, blue: 112/255.0, alpha: 1)

            ctx.setFillColor(UIColor(red: 7/255.0, green: 16/255.0, blue: 22/255.0, alpha: 185/255.0).cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: left, y: 0, width: cellWidth, height: bounds.height), cornerRadius: dp(4)).cgPath)
            ctx.fillPath()

            drawAvatar(ctx: ctx, id: hero.id, left: avatarLeft, top: avatarTop, size: avatarSize, borderColor: teamColor)

            let badgesTop = avatarTop + avatarSize + dp(2)
            let badgesLeft = left + (cellWidth - badgesWidth) / 2
            drawBadge(ctx: ctx, left: badgesLeft, top: badgesTop, width: ultBadgeWidth, height: badgeHeight,
                      title: "大", cooldown: hero.ultimateCooldown, color: gold)
            drawBadge(ctx: ctx, left: badgesLeft + ultBadgeWidth + badgeGap, top: badgesTop, width: skillBadgeWidth, height: badgeHeight,
                      title: "技", cooldown: hero.skillCooldown, color: green)
        }
    }

    private func drawAvatar(ctx: CGContext, id: String, left: CGFloat, top: CGFloat, size: CGFloat, borderColor: UIColor) {
        let centerX = left + size / 2
        let centerY = top + size / 2
        let inset = dp(2)
        if let bitmap = avatarCache.object(forKey: id as NSString) {
            ctx.saveGState()
            ctx.addEllipse(in: CGRect(x: centerX - size / 2 + inset, y: centerY - size / 2 + inset, width: size - inset * 2, height: size - inset * 2))
            ctx.clip()
            if let cg = bitmap.cgImage {
                let side = min(cg.width, cg.height)
                let src = CGRect(x: (cg.width - side) / 2, y: (cg.height - side) / 2, width: side, height: side)
                if let cropped = cg.cropping(to: src) {
                    ctx.draw(cropped, in: CGRect(x: left, y: top, width: size, height: size))
                }
            }
            ctx.restoreGState()
        } else {
            ctx.setFillColor(UIColor(red: 28/255.0, green: 40/255.0, blue: 48/255.0, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: centerX - size / 2 + inset, y: centerY - size / 2 + inset, width: size - inset * 2, height: size - inset * 2))
            requestAvatar(id: id)
            let text = String(id.suffix(3)) as NSString
            let font = UIFont.boldSystemFont(ofSize: size * 0.28)
            let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
            let textSize = text.size(withAttributes: attrs)
            text.draw(at: CGPoint(x: centerX - textSize.width / 2, y: centerY + font.pointSize * 0.35 - textSize.height / 2), withAttributes: attrs)
        }
        ctx.setStrokeColor(borderColor.cgColor)
        ctx.setLineWidth(dp(2))
        let borderInset = dp(1)
        ctx.strokeEllipse(in: CGRect(x: centerX - size / 2 + borderInset, y: centerY - size / 2 + borderInset, width: size - borderInset * 2, height: size - borderInset * 2))
    }

    private func drawBadge(ctx: CGContext, left: CGFloat, top: CGFloat, width: CGFloat, height: CGFloat, title: String, cooldown: Float, color: UIColor) {
        let ready = cooldown <= 0
        ctx.setFillColor(UIColor(red: 7/255.0, green: 16/255.0, blue: 22/255.0, alpha: 232/255.0).cgColor)
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: left, y: top, width: width, height: height), cornerRadius: dp(3)).cgPath)
        ctx.fillPath()

        let borderColor = ready ? color : UIColor(red: 106/255.0, green: 123/255.0, blue: 132/255.0, alpha: 1)
        ctx.setStrokeColor(borderColor.cgColor)
        ctx.setLineWidth(dp(1))
        ctx.addPath(UIBezierPath(roundedRect: CGRect(x: left + dp(0.5), y: top + dp(0.5), width: width - dp(1), height: height - dp(1)), cornerRadius: dp(2.5)).cgPath)
        ctx.strokePath()

        let titleFont = UIFont.boldSystemFont(ofSize: title.count > 1 ? dp(5.5) : dp(7))
        let titleColor = ready ? color : UIColor(red: 183/255.0, green: 196/255.0, blue: 202/255.0, alpha: 1)
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: titleFont, .foregroundColor: titleColor]
        (title as NSString).draw(
            at: CGPoint(x: left + dp(2), y: top + height * 0.74 - titleFont.ascender),
            withAttributes: titleAttrs
        )

        if ready {
            let dotX = left + width - dp(2.5)
            let dotY = top + height / 2
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(x: dotX - dp(1.5), y: dotY - dp(1.5), width: dp(3), height: dp(3)))
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: dotX - dp(0.8), y: dotY - dp(0.8), width: dp(1.6), height: dp(1.6)))
        } else {
            let text = "\(Int(ceil(cooldown)))s" as NSString
            let font = UIFont.boldSystemFont(ofSize: dp(7))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor(red: 241/255.0, green: 245/255.0, blue: 246/255.0, alpha: 1)
            ]
            let size = text.size(withAttributes: attrs)
            text.draw(
                at: CGPoint(x: left + width - dp(1.5) - size.width, y: top + height * 0.74 - font.ascender),
                withAttributes: attrs
            )
        }
    }

    private func requestAvatar(id: String) {
        guard !id.isEmpty else { return }
        lock.lock()
        if loading.contains(id) {
            lock.unlock()
            return
        }
        loading.insert(id)
        lock.unlock()

        avatarQueue.async { [weak self] in
            guard let self = self else { return }
            defer {
                self.lock.lock()
                self.loading.remove(id)
                self.lock.unlock()
                DispatchQueue.main.async { self.setNeedsDisplay() }
            }
            guard let url = URL(string: "https://game.gtimg.cn/images/yxzj/img201606/heroimg/\(id)/\(id).jpg") else { return }
            var image: UIImage?
            let sem = DispatchSemaphore(value: 0)
            let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 7)
            URLSession.shared.dataTask(with: request) { data, _, _ in
                if let data = data { image = UIImage(data: data) }
                sem.signal()
            }.resume()
            sem.wait()
            if let image = image {
                self.avatarCache.setObject(image, forKey: id as NSString)
            }
        }
    }
}
