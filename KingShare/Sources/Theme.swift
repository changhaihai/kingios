import UIKit

/// king.weilua.top design system (deep navy + gold), mirrored 1:1 from the Android app.
enum Theme {
    static let pageBg = UIColor(red: 7/255.0, green: 16/255.0, blue: 22/255.0, alpha: 1)       // #071016
    static let cardBg = UIColor(red: 16/255.0, green: 29/255.0, blue: 39/255.0, alpha: 1)      // #101d27
    static let cardHeader = UIColor(red: 13/255.0, green: 25/255.0, blue: 33/255.0, alpha: 1)  // #0d1921
    static let fieldBg = UIColor(red: 11/255.0, green: 21/255.0, blue: 29/255.0, alpha: 1)     // #0b151d
    static let border = UIColor(red: 42/255.0, green: 59/255.0, blue: 71/255.0, alpha: 1)      // #2a3b47
    static let borderLight = UIColor(red: 64/255.0, green: 85/255.0, blue: 99/255.0, alpha: 1) // #405563
    static let textPrimary = UIColor(red: 242/255.0, green: 247/255.0, blue: 250/255.0, alpha: 1) // #f2f7fa
    static let textSecond = UIColor(red: 145/255.0, green: 165/255.0, blue: 176/255.0, alpha: 1)  // #91a5b0
    static let mutedText = UIColor(red: 111/255.0, green: 135/255.0, blue: 148/255.0, alpha: 1)   // #6f8794
    static let gold = UIColor(red: 240/255.0, green: 188/255.0, blue: 85/255.0, alpha: 1)         // #f0bc55
    static let green = UIColor(red: 69/255.0, green: 220/255.0, blue: 156/255.0, alpha: 1)        // #45dc9c
    static let red = UIColor(red: 255/255.0, green: 102/255.0, blue: 112/255.0, alpha: 1)         // #ff6670
    static let blue = UIColor(red: 53/255.0, green: 163/255.0, blue: 255/255.0, alpha: 1)         // #35a3ff
    static let markBg = UIColor(red: 29/255.0, green: 26/255.0, blue: 19/255.0, alpha: 1)         // #1d1a13
    static let markBorder = UIColor(red: 114/255.0, green: 91/255.0, blue: 45/255.0, alpha: 1)    // #725b2d

    static let appVersion = "1.1.6"
    static let websiteURL = "http://king.weilua.top/"
}

extension UIView {
    /// Applies the shared card look (fill + corner radius + optional 1pt border).
    func styleCard(fill: UIColor, radius: CGFloat, stroke: UIColor? = nil) {
        backgroundColor = fill
        layer.cornerRadius = radius
        if let stroke = stroke {
            layer.borderWidth = 1
            layer.borderColor = stroke.cgColor
        } else {
            layer.borderWidth = 0
            layer.borderColor = UIColor.clear.cgColor
        }
        clipsToBounds = false
    }
}
