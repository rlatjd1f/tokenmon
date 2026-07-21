import CoreGraphics
import Testing
@testable import TokenmonApp

struct TokenmonFloatingPanelTests {
    @Test
    func missingOriginUsesTopRightInset() {
        let visibleFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let origin = TokenmonFloatingPanelFrameResolver.constrainedOrigin(
            requestedOrigin: nil,
            panelSize: CGSize(width: 360, height: 520),
            visibleFrames: [visibleFrame],
            fallbackVisibleFrame: visibleFrame
        )

        #expect(origin == CGPoint(x: 1060, y: 360))
    }

    @Test
    func offscreenOriginIsConstrainedToVisibleFrame() {
        let visibleFrame = CGRect(x: 0, y: 40, width: 1200, height: 760)
        let origin = TokenmonFloatingPanelFrameResolver.constrainedOrigin(
            requestedOrigin: CGPoint(x: 4000, y: -2000),
            panelSize: CGSize(width: 360, height: 520),
            visibleFrames: [visibleFrame],
            fallbackVisibleFrame: visibleFrame
        )

        #expect(origin == CGPoint(x: 840, y: 40))
    }

    @Test
    func originOnSecondaryDisplayStaysOnThatDisplay() {
        let primary = CGRect(x: 0, y: 0, width: 1200, height: 800)
        let secondary = CGRect(x: 1200, y: 0, width: 1000, height: 700)
        let origin = TokenmonFloatingPanelFrameResolver.constrainedOrigin(
            requestedOrigin: CGPoint(x: 1500, y: 100),
            panelSize: CGSize(width: 360, height: 520),
            visibleFrames: [primary, secondary],
            fallbackVisibleFrame: primary
        )

        #expect(origin == CGPoint(x: 1500, y: 100))
    }
}
