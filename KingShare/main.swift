import UIKit
import Foundation

@_silgen_name("hai_prepare_hud_plugin")
private func hai_prepare_hud_plugin()

let hudMode = CommandLine.arguments.contains("--state")
if hudMode {
    hai_prepare_hud_plugin()
    let delegate = HUDHelperAppDelegate()
    UIApplication.shared.delegate = delegate
    // __completeAndRunAsPlugin drives didFinishLaunchingWithOptions. Do not
    // start the HUD manually here or invoke the plugin entry recursively.
    UIApplication.shared.perform(Selector(("__completeAndRunAsPlugin")))
    CFRunLoopRun()
    exit(0)
}

UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)
