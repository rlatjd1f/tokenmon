import AppKit
import SwiftUI

struct TokenmonFloatingPanelFrameResolver {
    static func constrainedOrigin(
        requestedOrigin: CGPoint?,
        panelSize: CGSize,
        visibleFrames: [CGRect],
        fallbackVisibleFrame: CGRect
    ) -> CGPoint {
        let targetFrame = requestedOrigin.flatMap { origin in
            visibleFrames.first { $0.intersects(CGRect(origin: origin, size: panelSize)) }
        } ?? fallbackVisibleFrame

        let defaultOrigin = CGPoint(
            x: targetFrame.maxX - panelSize.width - 20,
            y: targetFrame.maxY - panelSize.height - 20
        )
        let origin = requestedOrigin ?? defaultOrigin
        return CGPoint(
            x: min(max(origin.x, targetFrame.minX), max(targetFrame.minX, targetFrame.maxX - panelSize.width)),
            y: min(max(origin.y, targetFrame.minY), max(targetFrame.minY, targetFrame.maxY - panelSize.height))
        )
    }
}

@MainActor
final class TokenmonFloatingPanelController: NSObject, NSWindowDelegate {
    private let panelSize = NSSize(
        width: TokenmonPopoverContainer.width,
        height: TokenmonPopoverContainer.height
    )
    private let onMove: (CGPoint) -> Void
    private let onAlwaysOnTopChange: (Bool) -> Void
    private let panel: NSPanel
    private let pinButton = NSButton()
    private var alwaysOnTop: Bool
    private var shouldPersistMoves = true

    init(
        rootView: AnyView,
        alwaysOnTop: Bool,
        onMove: @escaping (CGPoint) -> Void,
        onAlwaysOnTopChange: @escaping (Bool) -> Void
    ) {
        self.onMove = onMove
        self.onAlwaysOnTopChange = onAlwaysOnTopChange
        self.alwaysOnTop = alwaysOnTop
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.delegate = self
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.level = alwaysOnTop ? .floating : .normal
        panel.contentViewController = NSHostingController(rootView: rootView)
        panel.contentMinSize = panelSize
        panel.contentMaxSize = panelSize
        panel.setContentSize(panelSize)
        configurePinButton()
        updatePinAppearance()
        TokenmonAppAppearanceController.syncHostWindow(panel)
    }

    var isVisible: Bool { panel.isVisible }

    func updateRootView(_ rootView: AnyView) {
        (panel.contentViewController as? NSHostingController<AnyView>)?.rootView = rootView
    }

    func update(alwaysOnTop: Bool) {
        self.alwaysOnTop = alwaysOnTop
        panel.level = alwaysOnTop ? .floating : .normal
        updatePinAppearance()
    }

    func show(savedOrigin: CGPoint?) {
        position(savedOrigin: savedOrigin)
        panel.orderFrontRegardless()
    }

    func close() {
        panel.orderOut(nil)
    }

    func reposition(savedOrigin: CGPoint?) {
        position(savedOrigin: savedOrigin)
    }

    private func position(savedOrigin: CGPoint?) {
        guard let fallbackScreen = panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }
        let origin = TokenmonFloatingPanelFrameResolver.constrainedOrigin(
            requestedOrigin: savedOrigin,
            panelSize: panelSize,
            visibleFrames: NSScreen.screens.map(\.visibleFrame),
            fallbackVisibleFrame: fallbackScreen.visibleFrame
        )
        shouldPersistMoves = false
        panel.setFrameOrigin(origin)
        shouldPersistMoves = true
    }

    func windowDidMove(_ notification: Notification) {
        guard shouldPersistMoves else { return }
        onMove(panel.frame.origin)
    }

    private func configurePinButton() {
        pinButton.target = self
        pinButton.action = #selector(toggleAlwaysOnTop)
        pinButton.isBordered = false
        pinButton.imagePosition = .imageOnly
        pinButton.toolTip = TokenmonL10n.string("floating_panel.pin.tooltip")
        pinButton.setAccessibilityLabel(TokenmonL10n.string("floating_panel.pin.tooltip"))
        pinButton.frame = NSRect(x: 0, y: 0, width: 30, height: 24)

        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .right
        accessory.view = pinButton
        panel.addTitlebarAccessoryViewController(accessory)
    }

    private func updatePinAppearance() {
        let symbolName = alwaysOnTop ? "pin.fill" : "pin"
        pinButton.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: TokenmonL10n.string("floating_panel.pin.tooltip")
        )
        pinButton.contentTintColor = alwaysOnTop ? .controlAccentColor : .secondaryLabelColor
        pinButton.state = alwaysOnTop ? .on : .off
    }

    @objc private func toggleAlwaysOnTop() {
        let newValue = !alwaysOnTop
        update(alwaysOnTop: newValue)
        onAlwaysOnTopChange(newValue)
    }
}
