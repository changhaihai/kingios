import AVFoundation
import SwiftUI
import UIKit

struct PiPHostView: UIViewRepresentable {
    let manager: PiPManager

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .clear
        manager.displayLayer.frame = view.bounds
        view.layer.addSublayer(manager.displayLayer)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        manager.displayLayer.frame = view.bounds
    }
}
