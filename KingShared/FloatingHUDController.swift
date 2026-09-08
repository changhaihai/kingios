import SwiftUI
import UIKit

@MainActor
final class FloatingHUDController: NSObject, ObservableObject {
    @Published private(set) var isRunning = false
    private var window: TRHudMainWindow?

    func start(state: AppState) {
        guard window == nil else { return }
        let hud = TRHudMainWindow(frame: UIScreen.main.bounds)
        hud.backgroundColor = .clear
        hud.isOpaque = false
        hud.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.alert.rawValue + 1)
        if let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first {
            hud.windowScene = scene
        }
        let host = UIHostingController(rootView: FloatingHUDView().environmentObject(state))
        host.view.backgroundColor = .clear
        host.view.isOpaque = false
        hud.rootViewController = host
        window = hud
        hud.isHidden = false
        isRunning = true
    }

    func stop() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
        isRunning = false
    }
}

private struct FloatingHUDView: View {
    @EnvironmentObject private var state: AppState
    var body: some View {
        ZStack(alignment: .top) {
            MapHUDView(frame: state.frame, settings: state.settings)
            TopInfoHUDView(enemies: state.frame.heroes.filter { !$0.ownTeam }, settings: state.settings).padding(.top, 20)
        }
        .background(Color.clear)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}
