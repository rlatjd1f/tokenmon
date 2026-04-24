import AppKit
import SwiftUI

@main
struct TokenmonAppMain: App {
    @NSApplicationDelegateAdaptor(TokenmonAppDelegate.self) private var appDelegate

    init() {
        runAndExitIfRequested {
            try TokenmonAutomationCommand.runIfRequested(arguments: CommandLine.arguments)
        }
        runAndExitIfRequested {
            try TokenmonReadmeScreenshotRenderer.runIfRequested(arguments: CommandLine.arguments)
        }
        runAndExitIfRequested {
            try TokenmonActualPopoverScreenshotRenderer.runIfRequested(arguments: CommandLine.arguments)
        }
        runAndExitIfRequested {
            try TokenmonRewardArchiveScreenshotRenderer.runIfRequested(arguments: CommandLine.arguments)
        }
        runAndExitIfRequested {
            try TokenmonAppSmokeTest.runIfRequested(arguments: CommandLine.arguments)
        }
        runAndExitIfRequested {
            try TokenmonStatusStripScreenshotRenderer.runIfRequested(arguments: CommandLine.arguments)
        }
        runAndExitIfRequested {
            try TokenmonFieldPreviewSheetRenderer.runIfRequested(arguments: CommandLine.arguments)
        }
    }

    var body: some Scene {
        Settings {
            TokenmonSettingsPanel(
                model: TokenmonAppController.shared.menuModel,
                appUpdater: TokenmonAppController.shared.appUpdater,
                onOpenWelcomeGuide: {
                    TokenmonAppController.shared.showOnboardingWindow(entrypoint: "settings_scene")
                }
            )
        }
        .defaultSize(width: 760, height: 560)
    }
}

private func runAndExitIfRequested(_ action: () throws -> String?) {
    do {
        if let output = try action() {
            if output.isEmpty == false {
                print(output)
            }
            exit(0)
        }
    } catch {
        fputs("TokenmonApp bootstrap error: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

final class TokenmonAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = notification
        NSApp.setActivationPolicy(.accessory)
        TokenmonAppController.shared.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        _ = notification
        TokenmonAppController.shared.stop()
    }
}
