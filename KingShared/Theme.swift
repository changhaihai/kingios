import SwiftUI

enum KingTheme {
    static let page = Color(red: 7/255, green: 16/255, blue: 22/255)
    static let card = Color(red: 16/255, green: 29/255, blue: 39/255)
    static let header = Color(red: 13/255, green: 25/255, blue: 33/255)
    static let field = Color(red: 11/255, green: 21/255, blue: 29/255)
    static let border = Color(red: 42/255, green: 59/255, blue: 71/255)
    static let borderLight = Color(red: 64/255, green: 85/255, blue: 99/255)
    static let primary = Color(red: 242/255, green: 247/255, blue: 250/255)
    static let secondary = Color(red: 145/255, green: 165/255, blue: 176/255)
    static let muted = Color(red: 111/255, green: 135/255, blue: 148/255)
    static let gold = Color(red: 240/255, green: 188/255, blue: 85/255)
    static let green = Color(red: 69/255, green: 220/255, blue: 156/255)
    static let red = Color(red: 255/255, green: 102/255, blue: 112/255)
    static let blue = Color(red: 53/255, green: 163/255, blue: 255/255)
}

struct BrandMark: View {
    var body: some View {
        Text("王").font(.system(size: 16, weight: .bold)).foregroundStyle(KingTheme.gold)
            .frame(width: 34, height: 34).background(Color(red: 29/255, green: 26/255, blue: 19/255))
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(red: 114/255, green: 91/255, blue: 45/255)))
            .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct KingCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .background(KingTheme.card).overlay(RoundedRectangle(cornerRadius: 10).stroke(KingTheme.border))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct KingButtonStyle: ButtonStyle {
    var primary = false
    var destructive = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 13, weight: .semibold)).foregroundStyle(primary ? Color.black : destructive ? KingTheme.red : KingTheme.primary)
            .frame(maxWidth: .infinity).frame(height: 42)
            .background(primary ? KingTheme.gold : KingTheme.card)
            .overlay(RoundedRectangle(cornerRadius: 7).stroke(primary ? Color.clear : destructive ? KingTheme.red.opacity(0.6) : KingTheme.borderLight))
            .clipShape(RoundedRectangle(cornerRadius: 7)).opacity(configuration.isPressed ? 0.72 : 1)
    }
}
