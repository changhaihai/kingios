import UIKit
import Foundation

@_silgen_name("hai_prepare_hud_plugin")
private func hai_prepare_hud_plugin()

let hudMode = CommandLine.arguments.contains("--state")
if hudMode {
    hai_prepare_hud_plugin()
    let delegate = HUDHelperAppDelegate()
    UIApplication.shared.delegate = delegate
    let index = CommandLine.arguments.firstIndex(of: "--state")
    let statePath = index.flatMap { i in
        let next = i + 1
        return CommandLine.arguments.indices.contains(next) ? CommandLine.arguments[next] : nil
    } ?? HUDTransport.stateURL().path
    delegate.startHUD(statePath: statePath)
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
