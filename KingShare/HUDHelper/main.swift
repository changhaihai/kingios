import UIKit
import Foundation

@_silgen_name("hai_prepare_hud_plugin")
private func hai_prepare_hud_plugin()

// TrollSpeed-compatible entry point. The helper is initialized as a HUD
// application singleton before UIApplicationMain creates any windows.
let isHUDMode = CommandLine.arguments.contains("--state")
if isHUDMode {
    hai_prepare_hud_plugin()
    // TrollSpeed does not use UIApplicationMain for the HUD process. It
    // installs the delegate on the manually-created plugin singleton and
    // keeps the process in the CoreFoundation run loop.
    let hudDelegate = HUDHelperAppDelegate()
    UIApplication.shared.delegate = hudDelegate
    let stateIndex = CommandLine.arguments.firstIndex(of: "--state")
    let statePath = stateIndex.flatMap { index in
        let next = index + 1
        return CommandLine.arguments.indices.contains(next) ? CommandLine.arguments[next] : nil
    } ?? HUDTransport.stateURL().path
    hudDelegate.startHUD(statePath: statePath)
    UIApplication.shared.perform(Selector(("__completeAndRunAsPlugin")))
    CFRunLoopRun()
    exit(0)
}
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    isHUDMode ? "HUDMainApplication" : nil,
    NSStringFromClass(HUDHelperAppDelegate.self)
)
