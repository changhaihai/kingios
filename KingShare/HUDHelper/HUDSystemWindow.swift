import UIKit

/// TrollSpeed's HUDMainWindow uses these private UIWindow hooks so the
/// window is hosted by the system window server instead of a normal app scene.
/// The selectors are intentionally declared with @objc names to match UIKit's
/// private Objective-C dispatch without linking a private framework.
final class HUDSystemWindow: UIWindow {
    @objc(_isSystemWindow)
    class func hud_isSystemWindow() -> Bool { true }

    @objc(_isWindowServerHostingManaged)
    func hud_windowServerHostingManaged() -> Bool { false }

    @objc(_ignoresHitTest)
    func hud_ignoresHitTest() -> Bool { true }

    @objc(_isSecure)
    func hud_isSecure() -> Bool { true }

    @objc(_shouldCreateContextAsSecure)
    func hud_shouldCreateContextAsSecure() -> Bool { true }
}
