import AppKit
import SwiftUI

struct TokenmonPopoverHeroSceneCard: View {
    let context: TokenmonSceneContext
    var companionAssetKeys: [String] = []
    var backgroundDate: Date? = nil
    var animates: Bool = true

    var body: some View {
        let clipShape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        ZStack(alignment: .topLeading) {
            TokenmonPopoverHeroFieldStage(
                context: context,
                companionAssetKeys: companionAssetKeys,
                backgroundDate: backgroundDate,
                animates: animates
            )

            fieldBadge
                .padding(.leading, 10)
                .padding(.top, 8)
        }
        .clipShape(clipShape)
        .overlay(
            clipShape
                .stroke(fieldTint.opacity(0.16), lineWidth: 1)
        )
        .frame(maxWidth: .infinity)
        .frame(height: 124)
        .accessibilityLabel(companionAssetKeys.isEmpty ? "\(fieldTitle) scene preview" : "\(fieldTitle) scene preview with ambient companion")
    }

    private var fieldTitle: String {
        context.fieldKind.localizedTitle
    }

    private var fieldSystemImage: String {
        context.fieldKind.systemImage
    }

    private var fieldTint: Color {
        switch context.fieldKind {
        case .grassland:
            return Color(red: 0.23, green: 0.63, blue: 0.33)
        case .sky:
            return Color(red: 0.34, green: 0.61, blue: 0.95)
        case .coast:
            return Color(red: 0.18, green: 0.59, blue: 0.84)
        case .ice:
            return Color(red: 0.53, green: 0.79, blue: 0.98)
        case .unavailable:
            return .secondary
        }
    }

    private var fieldBadge: some View {
        Label(fieldTitle, systemImage: fieldSystemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.82))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(fieldTint.opacity(0.24), lineWidth: 0.8)
            )
    }
}

struct TokenmonPopoverHeroFieldStage: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let context: TokenmonSceneContext
    let companionAssetKeys: [String]
    let backgroundDate: Date?
    let animates: Bool
    var showsAmbientLayer: Bool = true

    var body: some View {
        GeometryReader { geometry in
            if animates {
                TimelineView(
                    .animation(
                        minimumInterval: TokenmonSceneTiming.interval(for: context.sceneState),
                        paused: accessibilityReduceMotion
                    )
                ) { timeline in
                    stageContent(
                        in: geometry,
                        date: timeline.date,
                        reduceMotion: accessibilityReduceMotion
                    )
                }
            } else {
                stageContent(
                    in: geometry,
                    date: backgroundDate ?? Date(timeIntervalSinceReferenceDate: 0),
                    reduceMotion: true
                )
            }
        }
        .padding(0)
    }

    @ViewBuilder
    private func stageContent(
        in geometry: GeometryProxy,
        date: Date,
        reduceMotion: Bool
    ) -> some View {
        let tick = TokenmonSceneTiming.tick(for: context, at: date)
        let layout = fieldLayout
        let phase = TokenmonPopoverHeroMotionModel.phase(at: date)
        let backgroundFrame = TokenmonPopoverHeroMotionModel.motionFrame(
            fieldKind: context.fieldKind,
            sceneState: context.sceneState,
            fieldState: context.fieldState,
            phase: phase,
            itemIndex: 0,
            reduceMotion: reduceMotion
        )
        let popoverBackground = TokenmonFieldSpriteLoader.popoverBackgroundImage(
            field: context.fieldKind,
            at: backgroundDate ?? date
        )

        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(layout.background)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.clear,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            if let popoverBackground {
                Image(nsImage: popoverBackground)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .scaleEffect(backgroundFrame.backgroundScale)
                    .offset(backgroundFrame.backgroundOffset)
                    .clipped()
            } else {
                fallbackFieldSprites(
                    in: geometry,
                    layout: layout,
                    phase: phase,
                    reduceMotion: reduceMotion
                )
            }

            if showsAmbientLayer {
                TokenmonPopoverAmbientFieldLayer(
                    context: context,
                    layout: layout,
                    phase: phase,
                    reduceMotion: reduceMotion,
                    showsFieldSprites: popoverBackground == nil
                )
                .allowsHitTesting(false)
            }

            if let selectedCompanionAssetKey {
                TokenmonAmbientCompanionPortrait(
                    assetKey: selectedCompanionAssetKey,
                    fieldKind: context.fieldKind,
                    sceneState: context.sceneState,
                    tick: tick,
                    sizeMultiplier: layout.companionScale,
                    motionFrame: TokenmonPopoverHeroMotionModel.motionFrame(
                        fieldKind: context.fieldKind,
                        sceneState: context.sceneState,
                        fieldState: context.fieldState,
                        phase: phase,
                        itemIndex: 2,
                        reduceMotion: reduceMotion
                    ),
                    reduceMotion: reduceMotion
                )
                .position(companionPosition(in: geometry.size, layout: layout, date: date, reduceMotion: reduceMotion))
            }
        }
    }

    @ViewBuilder
    private func fallbackFieldSprites(
        in geometry: GeometryProxy,
        layout: TokenmonPopoverFieldLayout,
        phase: Double,
        reduceMotion: Bool
    ) -> some View {
        ForEach(Array(layout.items.enumerated()), id: \.offset) { index, item in
            let frame = TokenmonPopoverHeroMotionModel.motionFrame(
                fieldKind: context.fieldKind,
                sceneState: context.sceneState,
                fieldState: context.fieldState,
                phase: phase,
                itemIndex: item.phase + index,
                reduceMotion: reduceMotion
            )
            TokenmonFieldSpriteImage(field: context.fieldKind, variant: item.variant)
                .aspectRatio(contentMode: .fit)
                .frame(width: geometry.size.width * item.widthFactor)
                .opacity(item.opacity)
                .shadow(color: Color.black.opacity(0.10), radius: 3, y: 2)
                .position(
                    x: geometry.size.width * item.center.x + frame.foregroundOffset.width,
                    y: geometry.size.height * item.center.y + frame.foregroundOffset.height
                )
        }
    }

    private var selectedCompanionAssetKey: String? {
        guard companionAssetKeys.isEmpty == false else {
            return nil
        }

        let cycle = Int(Date().timeIntervalSinceReferenceDate / 18)
        let seed = stableCompanionSeed(for: cycle)
        return companionAssetKeys[seed % companionAssetKeys.count]
    }

    private func companionPosition(
        in size: CGSize,
        layout: TokenmonPopoverFieldLayout,
        date: Date,
        reduceMotion: Bool
    ) -> CGPoint {
        let base = CGPoint(
            x: size.width * layout.companionAnchor.x,
            y: size.height * layout.companionAnchor.y
        )
        let roam = companionRoamOffset(layout: layout, date: date, reduceMotion: reduceMotion)

        return CGPoint(
            x: base.x + roam.width,
            y: base.y + roam.height
        )
    }

    private func companionRoamOffset(layout: TokenmonPopoverFieldLayout, date: Date, reduceMotion: Bool) -> CGSize {
        guard reduceMotion == false else {
            return .zero
        }

        let points = layout.companionWaypoints
        guard points.count > 1 else {
            return .zero
        }

        let raw = date.timeIntervalSinceReferenceDate / 1.8
        let segment = Int(floor(raw))
        let progress = raw - floor(raw)
        let current = points[segment % points.count]
        let next = points[(segment + 1) % points.count]
        let eased = 0.5 - (cos(progress * .pi) / 2)

        return CGSize(
            width: current.width + ((next.width - current.width) * eased),
            height: current.height + ((next.height - current.height) * eased)
        )
    }

    private func stableCompanionSeed(for cycle: Int) -> Int {
        var hash = 17
        for byte in "\(context.fieldKind.rawValue):\(cycle)".utf8 {
            hash = (hash &* 31 &+ Int(byte)) & 0x7fffffff
        }
        return hash
    }

    private var fieldLayout: TokenmonPopoverFieldLayout {
        switch context.fieldKind {
        case .grassland:
            return TokenmonPopoverFieldLayout(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.18, green: 0.29, blue: 0.19),
                        Color(red: 0.31, green: 0.43, blue: 0.28),
                        Color(red: 0.67, green: 0.82, blue: 0.58).opacity(0.35),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                items: [
                    TokenmonPopoverFieldItem(variant: .grasslandTuft, widthFactor: 0.16, center: CGPoint(x: 0.32, y: 0.78), opacity: 0.78, phase: 0),
                    TokenmonPopoverFieldItem(variant: .grasslandTuft, widthFactor: 0.22, center: CGPoint(x: 0.18, y: 0.74), opacity: 0.94, phase: 1),
                    TokenmonPopoverFieldItem(variant: .grasslandTuft, widthFactor: 0.34, center: CGPoint(x: 0.50, y: 0.68), opacity: 1.0, phase: 2),
                    TokenmonPopoverFieldItem(variant: .grasslandTuft, widthFactor: 0.24, center: CGPoint(x: 0.82, y: 0.74), opacity: 0.94, phase: 4),
                ],
                companionAnchor: CGPoint(x: 0.50, y: 0.54),
                companionWaypoints: [
                    CGSize(width: -42, height: 6),
                    CGSize(width: -20, height: -8),
                    CGSize(width: 4, height: 2),
                    CGSize(width: 30, height: -10),
                    CGSize(width: 48, height: 4),
                    CGSize(width: 16, height: 8),
                    CGSize(width: -18, height: 0),
                ],
                companionScale: 1.0
            )
        case .coast:
            return TokenmonPopoverFieldLayout(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.14, green: 0.24, blue: 0.37),
                        Color(red: 0.21, green: 0.38, blue: 0.57),
                        Color(red: 0.63, green: 0.82, blue: 0.98).opacity(0.26),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                items: [
                    TokenmonPopoverFieldItem(variant: .coastWave, widthFactor: 0.14, center: CGPoint(x: 0.34, y: 0.82), opacity: 0.72, phase: 0),
                    TokenmonPopoverFieldItem(variant: .coastWave, widthFactor: 0.18, center: CGPoint(x: 0.20, y: 0.76), opacity: 0.92, phase: 1),
                    TokenmonPopoverFieldItem(variant: .coastWave, widthFactor: 0.40, center: CGPoint(x: 0.54, y: 0.70), opacity: 1.0, phase: 2),
                    TokenmonPopoverFieldItem(variant: .coastWave, widthFactor: 0.22, center: CGPoint(x: 0.82, y: 0.76), opacity: 0.92, phase: 4),
                ],
                companionAnchor: CGPoint(x: 0.54, y: 0.52),
                companionWaypoints: [
                    CGSize(width: -48, height: 10),
                    CGSize(width: -24, height: -10),
                    CGSize(width: 6, height: -2),
                    CGSize(width: 34, height: -12),
                    CGSize(width: 52, height: 2),
                    CGSize(width: 18, height: 10),
                    CGSize(width: -16, height: 2),
                ],
                companionScale: 1.0
            )
        case .ice:
            return TokenmonPopoverFieldLayout(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.26, green: 0.33, blue: 0.45),
                        Color(red: 0.42, green: 0.56, blue: 0.72),
                        Color(red: 0.86, green: 0.95, blue: 1.0).opacity(0.28),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                items: [
                    TokenmonPopoverFieldItem(variant: .iceSnowflake, widthFactor: 0.09, center: CGPoint(x: 0.16, y: 0.42), opacity: 0.62, phase: 0),
                    TokenmonPopoverFieldItem(variant: .iceSnowflake, widthFactor: 0.10, center: CGPoint(x: 0.82, y: 0.40), opacity: 0.66, phase: 4),
                ],
                companionAnchor: CGPoint(x: 0.50, y: 0.44),
                companionWaypoints: [
                    CGSize(width: -28, height: 6),
                    CGSize(width: -10, height: -8),
                    CGSize(width: 6, height: 0),
                    CGSize(width: 24, height: -10),
                    CGSize(width: 34, height: 2),
                    CGSize(width: 8, height: 8),
                    CGSize(width: -12, height: 2),
                ],
                companionScale: 0.96
            )
        case .sky:
            return TokenmonPopoverFieldLayout(
                background: LinearGradient(
                    colors: [
                        Color(red: 0.71, green: 0.82, blue: 0.97),
                        Color(red: 0.86, green: 0.93, blue: 1.0),
                        Color.white.opacity(0.72),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                items: [
                    TokenmonPopoverFieldItem(variant: .skyCloud, widthFactor: 0.12, center: CGPoint(x: 0.20, y: 0.56), opacity: 0.90, phase: 0),
                    TokenmonPopoverFieldItem(variant: .skyCloud, widthFactor: 0.30, center: CGPoint(x: 0.50, y: 0.40), opacity: 1.0, phase: 2),
                    TokenmonPopoverFieldItem(variant: .skyCloud, widthFactor: 0.18, center: CGPoint(x: 0.80, y: 0.52), opacity: 0.92, phase: 4),
                ],
                companionAnchor: CGPoint(x: 0.52, y: 0.34),
                companionWaypoints: [
                    CGSize(width: -34, height: 6),
                    CGSize(width: -16, height: -10),
                    CGSize(width: 6, height: -18),
                    CGSize(width: 28, height: -8),
                    CGSize(width: 40, height: 2),
                    CGSize(width: 14, height: 8),
                    CGSize(width: -10, height: 0),
                ],
                companionScale: 0.95
            )
        case .unavailable:
            return TokenmonPopoverFieldLayout(
                background: LinearGradient(
                    colors: [
                        Color(nsColor: .controlBackgroundColor),
                        Color(nsColor: .windowBackgroundColor),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                items: [],
                companionAnchor: CGPoint(x: 0.50, y: 0.50),
                companionWaypoints: [.zero],
                companionScale: 0.9
            )
        }
    }
}

private struct TokenmonPopoverFieldLayout {
    let background: LinearGradient
    let items: [TokenmonPopoverFieldItem]
    let companionAnchor: CGPoint
    let companionWaypoints: [CGSize]
    let companionScale: CGFloat
}

private struct TokenmonPopoverFieldItem {
    let variant: TokenmonFieldSpriteVariant
    let widthFactor: CGFloat
    let center: CGPoint
    let opacity: Double
    let phase: Int
}

struct TokenmonPopoverHeroMotionFrame: Equatable {
    let backgroundOffset: CGSize
    let backgroundScale: CGFloat
    let foregroundOffset: CGSize
    let foregroundOpacity: Double
    let companionOffset: CGSize
    let companionScale: CGFloat
    let companionOpacity: Double
    let effectIntensity: Double
}

struct TokenmonPopoverHeroMotionModel {
    static func phase(at date: Date) -> Double {
        date.timeIntervalSinceReferenceDate
    }

    static func motionFrame(
        fieldKind: TokenmonSceneFieldKind,
        sceneState: TokenmonSceneState,
        fieldState: TokenmonFieldState,
        phase: Double,
        itemIndex: Int,
        reduceMotion: Bool
    ) -> TokenmonPopoverHeroMotionFrame {
        guard reduceMotion == false else {
            return TokenmonPopoverHeroMotionFrame(
                backgroundOffset: .zero,
                backgroundScale: 1,
                foregroundOffset: .zero,
                foregroundOpacity: 0,
                companionOffset: .zero,
                companionScale: 1,
                companionOpacity: 1,
                effectIntensity: 0
            )
        }

        let shiftedPhase = phase + (Double(itemIndex) * 0.43)
        let fieldOffset = foregroundOffset(fieldKind: fieldKind, fieldState: fieldState, phase: shiftedPhase)
        let foreground = CGSize(
            width: fieldOffset.width + stateImpulse(sceneState: sceneState, phase: shiftedPhase, itemIndex: itemIndex).width,
            height: fieldOffset.height + stateImpulse(sceneState: sceneState, phase: shiftedPhase, itemIndex: itemIndex).height
        )
        let companion = companionMotion(sceneState: sceneState, phase: shiftedPhase)

        return TokenmonPopoverHeroMotionFrame(
            backgroundOffset: backgroundOffset(fieldKind: fieldKind, sceneState: sceneState, phase: shiftedPhase),
            backgroundScale: stageScale(sceneState: sceneState, phase: phase, reduceMotion: false),
            foregroundOffset: foreground,
            foregroundOpacity: foregroundOpacity(sceneState: sceneState, fieldState: fieldState),
            companionOffset: companion.offset,
            companionScale: companion.scale,
            companionOpacity: companion.opacity,
            effectIntensity: effectIntensity(sceneState: sceneState, fieldState: fieldState)
        )
    }

    static func fieldDrift(
        fieldState: TokenmonFieldState,
        phase: Double,
        itemPhase: Int,
        reduceMotion: Bool
    ) -> CGSize {
        return motionFrame(
            fieldKind: .grassland,
            sceneState: .exploring,
            fieldState: fieldState,
            phase: phase,
            itemIndex: itemPhase,
            reduceMotion: reduceMotion
        ).foregroundOffset
    }

    static func stageScale(
        sceneState: TokenmonSceneState,
        phase: Double,
        reduceMotion: Bool
    ) -> CGFloat {
        guard reduceMotion == false else {
            return 1
        }

        switch sceneState {
        case .rustle, .alert, .spawn:
            return 1.012 + (sin(phase * 3.8) * 0.004)
        case .resolveSuccess:
            return 1.018 + (sin(phase * 4.4) * 0.006)
        case .resolveEscape:
            return 1.010 + (sin(phase * 5.2) * 0.004)
        case .loading, .exploring, .settle:
            return 1.006 + (sin(phase * 1.2) * 0.003)
        case .idle, .unavailable:
            return 1
        }
    }

    static func ambientOpacity(
        sceneState: TokenmonSceneState,
        fieldState: TokenmonFieldState,
        reduceMotion: Bool
    ) -> Double {
        guard reduceMotion == false else {
            return 0.0
        }

        return foregroundOpacity(sceneState: sceneState, fieldState: fieldState)
    }

    static func particleOffset(
        fieldKind: TokenmonSceneFieldKind,
        phase: Double,
        index: Int,
        reduceMotion: Bool
    ) -> CGSize {
        guard reduceMotion == false else {
            return .zero
        }

        let shiftedPhase = phase + Double(index)

        switch fieldKind {
        case .grassland:
            return CGSize(width: sin(shiftedPhase * 1.8) * 4, height: cos(shiftedPhase * 1.2) * 1.5)
        case .coast:
            return CGSize(width: sin(shiftedPhase * 1.6) * 7, height: cos(shiftedPhase * 2.0) * 2.0)
        case .ice:
            return CGSize(width: sin(shiftedPhase * 0.9) * 5, height: -abs(sin(shiftedPhase * 1.1) * 4))
        case .sky:
            return CGSize(width: sin(shiftedPhase * 0.7) * 8, height: cos(shiftedPhase * 0.8) * 4)
        case .unavailable:
            return .zero
        }
    }

    private static func backgroundOffset(
        fieldKind: TokenmonSceneFieldKind,
        sceneState: TokenmonSceneState,
        phase: Double
    ) -> CGSize {
        let intensity: CGFloat
        switch sceneState {
        case .rustle, .alert, .spawn, .resolveSuccess, .resolveEscape:
            intensity = 1.0
        case .loading, .exploring, .settle:
            intensity = 0.55
        case .idle, .unavailable:
            intensity = 0
        }

        switch fieldKind {
        case .grassland:
            return CGSize(width: sin(phase * 0.30) * 0.7 * intensity, height: cos(phase * 0.24) * 0.4 * intensity)
        case .coast:
            return CGSize(width: sin(phase * 0.36) * 1.3 * intensity, height: cos(phase * 0.22) * 0.5 * intensity)
        case .ice:
            return CGSize(width: sin(phase * 0.18) * 0.5 * intensity, height: cos(phase * 0.20) * 0.7 * intensity)
        case .sky:
            return CGSize(width: sin(phase * 0.26) * 1.8 * intensity, height: cos(phase * 0.18) * 0.8 * intensity)
        case .unavailable:
            return .zero
        }
    }

    private static func foregroundOffset(
        fieldKind: TokenmonSceneFieldKind,
        fieldState: TokenmonFieldState,
        phase: Double
    ) -> CGSize {
        let stateMultiplier: CGFloat
        switch fieldState {
        case .calm, .unavailable:
            stateMultiplier = 0
        case .exploring:
            stateMultiplier = 1
        case .rustle:
            stateMultiplier = 1.85
        case .settle:
            stateMultiplier = 0.55
        }

        switch fieldKind {
        case .grassland:
            return CGSize(width: sin(phase * 1.6) * 1.7 * stateMultiplier, height: cos(phase * 1.1) * 0.5 * stateMultiplier)
        case .coast:
            return CGSize(width: sin(phase * 1.1) * 6.6 * stateMultiplier, height: cos(phase * 2.0) * 1.4 * stateMultiplier)
        case .ice:
            return CGSize(width: sin(phase * 0.65) * 2.5 * stateMultiplier, height: (phase.truncatingRemainder(dividingBy: 4) - 2) * 0.9 * stateMultiplier)
        case .sky:
            return CGSize(width: sin(phase * 0.55) * 8.5 * stateMultiplier, height: cos(phase * 0.72) * 2.6 * stateMultiplier)
        case .unavailable:
            return .zero
        }
    }

    private static func stateImpulse(sceneState: TokenmonSceneState, phase: Double, itemIndex: Int) -> CGSize {
        switch sceneState {
        case .alert, .spawn:
            return CGSize(width: sin(phase * 3.2) * 1.8, height: cos(phase * 3.0) * -1.2)
        case .resolveEscape:
            return CGSize(width: 5.5 + (CGFloat(itemIndex) * 0.7), height: sin(phase * 2.0) * 1.0)
        case .resolveSuccess:
            return CGSize(width: sin(phase * 2.2) * 0.8, height: -1.6 + (cos(phase * 2.4) * 0.6))
        default:
            return .zero
        }
    }

    private static func companionMotion(sceneState: TokenmonSceneState, phase: Double) -> (offset: CGSize, scale: CGFloat, opacity: Double) {
        switch sceneState {
        case .spawn:
            return (CGSize(width: sin(phase * 4.4) * 2.8, height: -4.0 + (cos(phase * 3.8) * 1.8)), 1.06, 0.72)
        case .alert:
            return (CGSize(width: 2.6 + (sin(phase * 6.0) * 1.2), height: -3.4), 1.07, 1)
        case .resolveSuccess:
            return (CGSize(width: sin(phase * 2.8) * 1.4, height: -7.0 + (sin(phase * 4.0) * 2.2)), 1.12, 1)
        case .resolveEscape:
            return (CGSize(width: 11.0 + (sin(phase * 3.4) * 2.4), height: 3.0 + (cos(phase * 2.4) * 1.2)), 0.94, 0.72)
        case .loading, .exploring, .settle:
            return (CGSize(width: sin(phase * 1.2) * 2.8, height: cos(phase * 1.6) * 1.6), 1.0 + (sin(phase * 1.8) * 0.025), 1)
        case .rustle:
            return (CGSize(width: sin(phase * 4.6) * 2.2, height: -1.8 + (cos(phase * 3.8) * 1.0)), 1.04, 1)
        case .idle, .unavailable:
            return (.zero, 1, sceneState == .unavailable ? 0 : 1)
        }
    }

    private static func foregroundOpacity(sceneState: TokenmonSceneState, fieldState: TokenmonFieldState) -> Double {
        switch sceneState {
        case .alert, .spawn:
            return 0.36
        case .resolveSuccess:
            return 0.42
        case .resolveEscape:
            return 0.30
        default:
            switch fieldState {
            case .calm, .unavailable:
                return 0.0
            case .exploring:
                return 0.18
            case .rustle:
                return 0.34
            case .settle:
                return 0.12
            }
        }
    }

    private static func effectIntensity(sceneState: TokenmonSceneState, fieldState: TokenmonFieldState) -> Double {
        switch sceneState {
        case .alert:
            return 0.44
        case .spawn:
            return 0.54
        case .resolveSuccess:
            return 0.62
        case .resolveEscape:
            return 0.48
        default:
            switch fieldState {
            case .rustle:
                return 0.34
            case .exploring:
                return 0.16
            case .settle:
                return 0.10
            case .calm, .unavailable:
                return 0
            }
        }
    }
}

private struct TokenmonPopoverAmbientFieldLayer: View {
    let context: TokenmonSceneContext
    let layout: TokenmonPopoverFieldLayout
    let phase: Double
    let reduceMotion: Bool
    let showsFieldSprites: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if showsFieldSprites {
                    ForEach(Array(layout.items.enumerated()), id: \.offset) { index, item in
                        let frame = motionFrame(index: item.phase + index)
                        TokenmonFieldSpriteImage(field: context.fieldKind, variant: item.variant)
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width * foregroundWidthFactor(for: item))
                            .opacity(frame.foregroundOpacity * item.opacity)
                            .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
                            .position(
                                x: geometry.size.width * item.center.x + frame.foregroundOffset.width,
                                y: geometry.size.height * item.center.y + frame.foregroundOffset.height
                            )
                    }
                }

                if effectIntensity > 0 {
                    Circle()
                        .fill(effectTint.opacity(effectIntensity * effectPulseOpacity))
                        .frame(width: effectDiameter, height: effectDiameter)
                        .blur(radius: 12)
                        .position(x: geometry.size.width * 0.5, y: geometry.size.height * 0.55)
                }
            }
        }
    }

    private var effectIntensity: Double {
        motionFrame(index: 0).effectIntensity
    }

    private var effectPulseOpacity: Double {
        0.58 + (abs(sin(phase * 3.0)) * 0.22)
    }

    private var effectTint: Color {
        switch context.sceneState {
        case .resolveSuccess:
            return .green
        case .resolveEscape:
            return .orange
        case .alert, .spawn:
            return .yellow
        default:
            switch context.fieldKind {
            case .grassland:
                return .green
            case .coast:
                return .cyan
            case .ice:
                return .white
            case .sky:
                return .blue
            case .unavailable:
                return .clear
            }
        }
    }

    private var effectDiameter: CGFloat {
        switch context.sceneState {
        case .spawn, .alert:
            return 54
        case .resolveSuccess, .resolveEscape:
            return 72
        default:
            return 42
        }
    }

    private func foregroundWidthFactor(for item: TokenmonPopoverFieldItem) -> CGFloat {
        let overlayFactor = showsFieldSprites ? 0.52 : 0.44
        return max(0.08, item.widthFactor * overlayFactor)
    }

    private func motionFrame(index: Int) -> TokenmonPopoverHeroMotionFrame {
        TokenmonPopoverHeroMotionModel.motionFrame(
            fieldKind: context.fieldKind,
            sceneState: context.sceneState,
            fieldState: context.fieldState,
            phase: phase,
            itemIndex: index,
            reduceMotion: reduceMotion
        )
    }
}

private struct TokenmonAmbientCompanionPortrait: View {
    let assetKey: String
    let fieldKind: TokenmonSceneFieldKind
    let sceneState: TokenmonSceneState
    let tick: Int
    let sizeMultiplier: CGFloat
    let motionFrame: TokenmonPopoverHeroMotionFrame
    let reduceMotion: Bool

    var body: some View {
        Group {
            if isVisible {
                TokenmonHeroCompanionImage(assetKey: assetKey)
                    .frame(width: portraitSize.width, height: portraitSize.height)
            }
        }
        .scaleEffect(
            x: facingScaleX * companionScale * motionFrame.companionScale,
            y: companionScale * yStretch * motionFrame.companionScale,
            anchor: .bottom
        )
        .offset(x: xOffset + motionFrame.companionOffset.width, y: yOffset + motionFrame.companionOffset.height)
        .opacity(opacity * motionFrame.companionOpacity)
        .shadow(color: Color.black.opacity(0.12), radius: 4, y: 2)
        .allowsHitTesting(false)
        .zIndex(2)
    }

    private var isVisible: Bool {
        switch sceneState {
        case .unavailable:
            return false
        default:
            return true
        }
    }

    private var opacity: Double {
        switch sceneState {
        case .spawn:
            return 0.32
        case .resolveEscape:
            return 0.74
        default:
            return 1
        }
    }

    private var facingScaleX: CGFloat {
        guard reduceMotion == false else {
            return 1
        }

        switch sceneState {
        case .alert, .resolveEscape:
            return -1
        default:
            return 1
        }
    }

    private var portraitSize: CGSize {
        switch fieldKind {
        case .sky:
            return CGSize(width: 42 * sizeMultiplier, height: 42 * sizeMultiplier)
        case .coast:
            return CGSize(width: 50 * sizeMultiplier, height: 50 * sizeMultiplier)
        case .grassland, .ice:
            return CGSize(width: 46 * sizeMultiplier, height: 46 * sizeMultiplier)
        case .unavailable:
            return CGSize(width: 32 * sizeMultiplier, height: 32 * sizeMultiplier)
        }
    }

    private var companionScale: CGFloat {
        guard reduceMotion == false else {
            return 1
        }

        switch sceneState {
        case .resolveSuccess:
            return 1.04
        case .resolveEscape:
            return 0.98
        default:
            return 1
        }
    }

    private var yStretch: CGFloat {
        guard reduceMotion == false else {
            return 1
        }

        switch sceneState {
        case .resolveSuccess:
            return [1.0, 1.14, 0.90, 1.04][tick % 4]
        case .resolveEscape:
            return [1.0, 0.88, 0.94, 0.90][tick % 4]
        case .rustle:
            return [1.0, 1.06, 0.98, 1.04][tick % 4]
        default:
            return [1.0, 1.045, 0.985, 1.025][tick % 4]
        }
    }

    private var xOffset: CGFloat {
        guard reduceMotion == false else {
            return 0
        }

        switch sceneState {
        case .loading, .exploring, .settle:
            return [-3, -2, 0, 2, 3, 2, 0, -2][tick % 8]
        case .rustle:
            return [-2, 0, 2, 2, 0, -2][tick % 6]
        case .alert:
            return 3
        case .resolveEscape:
            return [-2, -4, -2, 1][tick % 4]
        default:
            return 0
        }
    }

    private var yOffset: CGFloat {
        guard reduceMotion == false else {
            return 0
        }

        switch sceneState {
        case .loading, .exploring, .settle:
            return [0, -2, -1, 0][tick % 4]
        case .rustle:
            return [0, -2, -1, 0][tick % 4]
        case .alert:
            return -3
        case .resolveSuccess:
            return [0, -7, -3, 0][tick % 4]
        case .resolveEscape:
            return [2, 4, 2, 0][tick % 4]
        default:
            return 0
        }
    }
}

private struct TokenmonHeroCompanionImage: View {
    let assetKey: String

    var body: some View {
        if let approvedPortrait = TokenmonSpeciesSpriteLoader.approvedPortraitImage(assetKey: assetKey) {
            Image(nsImage: approvedPortrait)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
        } else {
            TokenmonSpeciesSpriteImage(
                assetKey: assetKey,
                variants: [.portrait64, .portrait32],
                revealStage: .revealed
            )
            .scaledToFit()
        }
    }
}
