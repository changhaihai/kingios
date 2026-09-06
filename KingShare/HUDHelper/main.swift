import UIKit
import Foundation

@_silgen_name("hai_prepare_hud_plugin")
private func hai_prepare_hud_plugin()

// TrollSpeed-compatible entry point. The helper is initialized as a HUD
// application singleton before UIApplicationMain creates any windows.
let isHUDMode = CommandLine.arguments.contains("--state")
if isHUDMode {
    hai_prepare_hud_plugin()
}
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    isHUDMode ? "HUDMainApplication" : nil,
    NSStringFromClass(HUDHelperAppDelegate.self)
)
