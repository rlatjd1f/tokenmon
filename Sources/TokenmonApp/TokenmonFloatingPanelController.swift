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
    private let defaultPanelSize = NSSize(
        width: TokenmonPopoverContainer.width,
        height: TokenmonPopoverContainer.height
    )
    private let onMove: (CGPoint) -> Void
    private let onResize: (CGSize) -> Void
    private let panel: NSPanel
    private var shouldPersistMoves = true
    private var shouldPersistResizes = true

    init(
        rootView: AnyView,
        alwaysOnTop: Bool,
        onMove: @escaping (CGPoint) -> Void,
        onResize: @escaping (CGSize) -> Void
    ) {
        self.onMove = onMove
        self.onResize = onResize
        panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: defaultPanelSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
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
        panel.contentMinSize = NSSize(width: defaultPanelSize.width, height: 320)
        panel.contentMaxSize = NSSize(width: defaultPanelSize.width, height: .greatestFiniteMagnitude)
        panel.setContentSize(defaultPanelSize)
        TokenmonAppAppearanceController.syncHostWindow(panel)
    }

    var isVisible: Bool { panel.isVisible }

    func updateRootView(_ rootView: AnyView) {
        (panel.contentViewController as? NSHostingController<AnyView>)?.rootView = rootView
    }

    func update(alwaysOnTop: Bool) {
        panel.level = alwaysOnTop ? .floating : .normal
    }

    func show(savedOrigin: CGPoint?, savedHeight: CGFloat?) {
        if let savedHeight {
            shouldPersistResizes = false
            panel.setContentSize(NSSize(width: defaultPanelSize.width, height: savedHeight))
            shouldPersistResizes = true
        }
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
            panelSize: panel.frame.size,
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

    func windowDidResize(_ notification: Notification) {
        guard shouldPersistResizes, panel.inLiveResize == false else { return }
        persistCurrentSize()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        guard shouldPersistResizes else { return }
        persistCurrentSize()
    }

    private func persistCurrentSize() {
        onResize(panel.contentView?.bounds.size ?? panel.contentLayoutRect.size)
    }

}
