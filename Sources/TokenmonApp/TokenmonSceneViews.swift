import AppKit
import SwiftUI
import TokenmonDomain
import TokenmonPersistence

enum TokenmonSceneState: String, Equatable {
    case loading
    case idle
    case exploring
    case rustle
    case alert
    case spawn
    case resolveSuccess
    case resolveEscape
    case settle
    case unavailable
}

enum TokenmonFieldState: String, Equatable {
    case calm
    case exploring
    case rustle
    case settle
    case unavailable
}

enum TokenmonSceneFieldKind: String, Equatable {
    case grassland
    case ice
    case coast
    case sky
    case unavailable

    init(fieldType: FieldType) {
        switch fieldType {
        case .grassland:
            self = .grassland
        case .ice:
            self = .ice
        case .coast:
            self = .coast
        case .sky:
            self = .sky
        }
    }
}

enum TokenmonEffectState: String, Equatable {
    case none
    case alert
    case captureSnap
    case escapeDash
}

enum TokenmonWildState: String, Equatable {
    case hidden
    case roaming
    case spawning
    case visible
    case captured
    case escaped
}

struct TokenmonSceneContext: Equatable {
    let sceneState: TokenmonSceneState
    let fieldKind: TokenmonSceneFieldKind
    let fieldState: TokenmonFieldState
    let effectState: TokenmonEffectState
    let wildState: TokenmonWildState
    let wildAssetKey: String?
    let showsFieldBackplate: Bool

    init(
        sceneState: TokenmonSceneState,
        fieldKind: TokenmonSceneFieldKind,
        fieldState: TokenmonFieldState,
        effectState: TokenmonEffectState,
        wildState: TokenmonWildState,
        wildAssetKey: String? = nil,
        showsFieldBackplate: Bool = true
    ) {
        self.sceneState = sceneState
        self.fieldKind = fieldKind
        self.fieldState = fieldState
        self.effectState = effectState
        self.wildState = wildState
        self.wildAssetKey = wildAssetKey
        self.showsFieldBackplate = showsFieldBackplate
    }
}

enum TokenmonSceneOutcomeCallout {
    case gotcha
    case missed

    init?(sceneState: TokenmonSceneState) {
        switch sceneState {
        case .resolveSuccess:
            self = .gotcha
        case .resolveEscape:
            self = .missed
        default:
            return nil
        }
    }

    var title: String {
        switch self {
        case .gotcha:
            return "Gotcha!"
        case .missed:
            return "Missed!"
        }
    }

    var badgeWord: String {
        switch self {
        case .gotcha:
            return "GOTCHA!"
        case .missed:
            return "MISSED!"
        }
    }

    var topFillColor: Color {
        switch self {
        case .gotcha:
            return Color(red: 0.67, green: 0.90, blue: 0.28)
        case .missed:
            return Color(red: 0.78, green: 0.63, blue: 0.52)
        }
    }

    var bottomFillColor: Color {
        switch self {
        case .gotcha:
            return Color(red: 0.24, green: 0.65, blue: 0.20)
        case .missed:
            return Color(red: 0.43, green: 0.35, blue: 0.32)
        }
    }

    var outlineColor: Color {
        switch self {
        case .gotcha:
            return Color(red: 0.93, green: 1.00, blue: 0.78)
        case .missed:
            return Color(red: 0.99, green: 0.79, blue: 0.61)
        }
    }

    var shadowColor: Color {
        switch self {
        case .gotcha:
            return Color(red: 0.10, green: 0.22, blue: 0.12).opacity(0.42)
        case .missed:
            return Color.black.opacity(0.34)
        }
    }
}

struct TokenmonSceneOutcomeBadge: View {
    let callout: TokenmonSceneOutcomeCallout
    let fieldKind: TokenmonSceneFieldKind

    private var badgeWidth: Int {
        max(29, TokenmonPixelArt.pixelWordWidth(callout.badgeWord) + 4)
    }

    private var plateWidth: Int {
        badgeWidth + 4
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelSprite(
                dots: TokenmonPixelArt.pixelBadgeShape(
                    width: plateWidth,
                    height: 11,
                    fillTop: plateTopColor,
                    fillBottom: plateBottomColor,
                    outline: plateOutlineColor
                ),
                pixelSize: 1
            )

            PixelSprite(
                dots: TokenmonPixelArt.pixelBadgeShape(
                    width: badgeWidth,
                    height: 9,
                    fillTop: callout.shadowColor,
                    fillBottom: callout.shadowColor,
                    outline: callout.shadowColor
                ),
                pixelSize: 1
            )
            .offset(x: 1, y: 1)

            PixelSprite(
                dots: TokenmonPixelArt.pixelBadgeShape(
                    width: badgeWidth,
                    height: 9,
                    fillTop: callout.topFillColor,
                    fillBottom: callout.bottomFillColor,
                    outline: callout.outlineColor
                ),
                pixelSize: 1
            )

            PixelSprite(
                dots: TokenmonPixelArt.pixelWord(callout.badgeWord, color: .white),
                pixelSize: 1
            )
            .offset(x: 4, y: 3)
        }
        .frame(width: CGFloat(plateWidth + 1), height: 11, alignment: .topLeading)
        .fixedSize()
    }

    private var plateTopColor: Color {
        switch fieldKind {
        case .grassland:
            return Color(red: 0.89, green: 0.96, blue: 0.80)
        case .ice:
            return Color(red: 0.90, green: 0.97, blue: 1.00)
        case .coast:
            return Color(red: 0.88, green: 0.95, blue: 1.00)
        case .sky:
            return Color(red: 0.94, green: 0.97, blue: 1.00)
        case .unavailable:
            return Color(red: 0.88, green: 0.88, blue: 0.90)
        }
    }

    private var plateBottomColor: Color {
        switch fieldKind {
        case .grassland:
            return Color(red: 0.72, green: 0.86, blue: 0.60)
        case .ice:
            return Color(red: 0.72, green: 0.85, blue: 0.96)
        case .coast:
            return Color(red: 0.68, green: 0.82, blue: 0.93)
        case .sky:
            return Color(red: 0.78, green: 0.86, blue: 0.97)
        case .unavailable:
            return Color(red: 0.72, green: 0.72, blue: 0.75)
        }
    }

    private var plateOutlineColor: Color {
        switch fieldKind {
        case .grassland:
            return Color(red: 0.50, green: 0.66, blue: 0.39)
        case .ice:
            return Color(red: 0.47, green: 0.67, blue: 0.82)
        case .coast:
            return Color(red: 0.38, green: 0.58, blue: 0.74)
        case .sky:
            return Color(red: 0.52, green: 0.67, blue: 0.86)
        case .unavailable:
            return Color(red: 0.52, green: 0.52, blue: 0.56)
        }
    }
}

enum TokenmonSceneContextBuilder {
    private static let recentEncounterHighlightTokenWindow: Int64 = 400
    private static let imminentEncounterTokenWindow: Int64 = 200
    private static let nearEncounterTokenWindow: Int64 = 600
    private static let liveActivityPulseWindow: TimeInterval = 3

    static func context(
        summary: CurrentRunSummary?,
        latestEncounter: RecentEncounterSummary?,
        loadError: String?,
        liveActivityUntil: Date? = nil,
        now: Date = Date()
    ) -> TokenmonSceneContext {
        if let summary {
            return context(
                summary: summary,
                latestEncounter: latestEncounter,
                liveActivityUntil: liveActivityUntil,
                now: now
            )
        }

        if loadError != nil {
            return TokenmonSceneContext(
                sceneState: .unavailable,
                fieldKind: .unavailable,
                fieldState: .unavailable,
                effectState: .none,
                wildState: .hidden
            )
        }

        if hasLiveActivityPulse(liveActivityUntil: liveActivityUntil, now: now) {
            return TokenmonSceneContext(
                sceneState: .exploring,
                fieldKind: resolvedFieldKind(latestEncounterField: latestEncounter?.field),
                fieldState: .exploring,
                effectState: .none,
                wildState: .hidden
            )
        }

        return TokenmonSceneContext(
            sceneState: .loading,
            fieldKind: resolvedFieldKind(latestEncounterField: latestEncounter?.field),
            fieldState: .calm,
            effectState: .none,
            wildState: .hidden
        )
    }

    static func restingContext(
        summary: CurrentRunSummary?,
        latestEncounterField: FieldType? = nil,
        loadError: String?,
        liveActivityUntil: Date? = nil,
        now: Date = Date()
    ) -> TokenmonSceneContext {
        guard let summary else {
            if loadError != nil {
                return TokenmonSceneContext(
                    sceneState: .unavailable,
                    fieldKind: .unavailable,
                    fieldState: .unavailable,
                    effectState: .none,
                    wildState: .hidden
                )
            }

            if hasLiveActivityPulse(liveActivityUntil: liveActivityUntil, now: now) {
                return TokenmonSceneContext(
                    sceneState: .exploring,
                    fieldKind: resolvedFieldKind(latestEncounterField: latestEncounterField),
                    fieldState: .exploring,
                    effectState: .none,
                    wildState: .hidden
                )
            }

            return TokenmonSceneContext(
                sceneState: .loading,
                fieldKind: resolvedFieldKind(latestEncounterField: latestEncounterField),
                fieldState: .calm,
                effectState: .none,
                wildState: .hidden
            )
        }

        if summary.totalNormalizedTokens == 0 {
            if hasLiveActivityPulse(liveActivityUntil: liveActivityUntil, now: now) {
                return TokenmonSceneContext(
                    sceneState: .exploring,
                    fieldKind: resolvedFieldKind(latestEncounterField: latestEncounterField),
                    fieldState: .exploring,
                    effectState: .none,
                    wildState: .hidden
                )
            }
            return TokenmonSceneContext(
                sceneState: .idle,
                fieldKind: resolvedFieldKind(latestEncounterField: latestEncounterField),
                fieldState: .calm,
                effectState: .none,
                wildState: .hidden
            )
        }
        if summary.tokensUntilNextEncounter <= imminentEncounterTokenWindow {
            return TokenmonSceneContext(
                sceneState: .alert,
                fieldKind: resolvedFieldKind(latestEncounterField: latestEncounterField),
                fieldState: .rustle,
                effectState: .alert,
                wildState: .hidden
            )
        }
        if summary.tokensUntilNextEncounter <= nearEncounterTokenWindow {
            return TokenmonSceneContext(
                sceneState: .rustle,
                fieldKind: resolvedFieldKind(latestEncounterField: latestEncounterField),
                fieldState: .rustle,
                effectState: .none,
                wildState: .hidden
            )
        }
        return TokenmonSceneContext(
            sceneState: .exploring,
            fieldKind: resolvedFieldKind(latestEncounterField: latestEncounterField),
            fieldState: .exploring,
            effectState: .none,
            wildState: .hidden
        )
    }

    static func context(
        summary: CurrentRunSummary,
        latestEncounter: RecentEncounterSummary?,
        liveActivityUntil: Date? = nil,
        now: Date = Date()
    ) -> TokenmonSceneContext {
        if let latestEncounter, summary.tokensSinceLastEncounter <= recentEncounterHighlightTokenWindow {
            return latestEncounter.outcome == .captured
                ? TokenmonSceneContext(
                    sceneState: .resolveSuccess,
                    fieldKind: .init(fieldType: latestEncounter.field),
                    fieldState: .settle,
                    effectState: .captureSnap,
                    wildState: .captured,
                    wildAssetKey: latestEncounter.assetKey
                )
                : TokenmonSceneContext(
                    sceneState: .resolveEscape,
                    fieldKind: .init(fieldType: latestEncounter.field),
                    fieldState: .settle,
                    effectState: .escapeDash,
                    wildState: .escaped,
                    wildAssetKey: latestEncounter.assetKey
                )
        }
        return restingContext(
            summary: summary,
            latestEncounterField: latestEncounter?.field,
            loadError: nil,
            liveActivityUntil: liveActivityUntil,
            now: now
        )
    }

    private static func hasLiveActivityPulse(liveActivityUntil: Date?, now: Date) -> Bool {
        guard let liveActivityUntil else {
            return false
        }
        return now <= liveActivityUntil.addingTimeInterval(liveActivityPulseWindow)
    }

    private static func resolvedFieldKind(latestEncounterField: FieldType?) -> TokenmonSceneFieldKind {
        guard let latestEncounterField else {
            return .grassland
        }
        return TokenmonSceneFieldKind(fieldType: latestEncounterField)
    }
}

enum TokenmonSceneTiming {
    static func interval(for state: TokenmonSceneState) -> Double {
        switch state {
        case .loading:
            return 0.24
        case .idle:
            return 0.52
        case .exploring:
            return 0.32
        case .rustle:
            return 0.24
        case .alert:
            return 0.16
        case .spawn:
            return 0.14
        case .resolveSuccess, .resolveEscape:
            return 0.2
        case .settle:
            return 0.28
        case .unavailable:
            return 0.7
        }
    }

    static func tickMultiplier(for state: TokenmonSceneState) -> Double {
        switch state {
        case .loading:
            return 4
        case .idle:
            return 2
        case .exploring:
            return 3
        case .rustle:
            return 4
        case .alert:
            return 6
        case .spawn:
            return 7
        case .resolveSuccess, .resolveEscape:
            return 5
        case .settle:
            return 3
        case .unavailable:
            return 1.5
        }
    }

    static func tick(for context: TokenmonSceneContext, at date: Date) -> Int {
        Int(date.timeIntervalSinceReferenceDate * tickMultiplier(for: context.sceneState))
    }

    static func statusItemTick(for context: TokenmonSceneContext, at date: Date) -> Int {
        switch context.sceneState {
        case .idle, .loading, .exploring, .unavailable:
            return 0
        case .rustle, .alert, .spawn, .resolveSuccess, .resolveEscape, .settle:
            return tick(for: context, at: date)
        }
    }
}

struct TokenmonDummyScene: View {
    let context: TokenmonSceneContext

    var body: some View {
        TimelineView(.animation(minimumInterval: TokenmonSceneTiming.interval(for: context.sceneState), paused: false)) { timeline in
            TokenmonSceneCanvas(
                context: context,
                tick: TokenmonSceneTiming.tick(for: context, at: timeline.date)
            )
        }
    }
}

struct TokenmonSceneCanvas: View {
    let context: TokenmonSceneContext
    let tick: Int
    let layout: TokenmonSceneLayout

    init(
        context: TokenmonSceneContext,
        tick: Int,
        layout: TokenmonSceneLayout = .statusStrip
    ) {
        self.context = context
        self.tick = tick
        self.layout = layout
    }

    var body: some View {
        let fieldSpec = context.fieldKind.visualSpec
        let fieldScale = layout.fieldScale
        let effectScale = layout.effectScale
        let effectRect = fieldSpec.effectRect(in: layout)
        let outcomeCallout = TokenmonSceneOutcomeCallout(sceneState: context.sceneState)
        ZStack(alignment: .topLeading) {
            TokenmonFieldLayer(
                kind: context.fieldKind,
                sceneState: context.sceneState,
                state: context.fieldState,
                tick: tick,
                showsBackplate: context.showsFieldBackplate
            )
                .scaleEffect(fieldScale, anchor: .topLeading)
                .frame(
                    width: layout.fieldFrame.width,
                    height: layout.fieldFrame.height,
                    alignment: .topLeading
                )
                .offset(
                    x: layout.fieldFrame.minX,
                    y: layout.fieldFrame.minY
                )

            if outcomeCallout == nil {
                TokenmonSceneEffect(state: context.effectState, tick: tick)
                    .scaleEffect(effectScale, anchor: .topLeading)
                    .frame(
                        width: layout.effectFrame.width,
                        height: layout.effectFrame.height,
                        alignment: .topLeading
                    )
                    .offset(
                        x: effectRect.minX,
                        y: effectRect.minY
                    )
            }

            if let callout = outcomeCallout {
                let bannerWidth = CGFloat(max(29, TokenmonPixelArt.pixelWordWidth(callout.badgeWord) + 4) + 5)
                let bannerHeight: CGFloat = 11

                TokenmonSceneOutcomeBadge(callout: callout, fieldKind: context.fieldKind)
                    .offset(
                        x: max(0, (layout.canvasSize.width - bannerWidth) / 2),
                        y: max(0, (layout.canvasSize.height - bannerHeight) / 2)
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(
            width: layout.canvasSize.width,
            height: layout.canvasSize.height,
            alignment: .topLeading
        )
        .accessibilityLabel(
            "Tokenmon scene \(context.sceneState.rawValue), field \(context.fieldKind.rawValue), motion \(context.fieldState.rawValue), effect \(context.effectState.rawValue), wild \(context.wildState.rawValue)"
        )
    }
}

struct TokenmonFieldLayer: View {
    let kind: TokenmonSceneFieldKind
    let sceneState: TokenmonSceneState
    let state: TokenmonFieldState
    let tick: Int
    let showsBackplate: Bool

    var body: some View {
        TokenmonHabitatField(
            spec: kind.visualSpec,
            sceneState: sceneState,
            state: state,
            tick: tick,
            showsBackplate: showsBackplate
        )
    }
}

struct TokenmonSceneLayout: Equatable, Sendable {
    let canvasSize: CGSize
    let safeRect: CGRect
    let fieldFrame: CGRect
    let wildFrame: CGRect
    let effectFrame: CGRect
    let previewScale: CGFloat

    var previewSize: CGSize {
        CGSize(
            width: canvasSize.width * previewScale,
            height: canvasSize.height * previewScale
        )
    }

    var fieldScale: CGFloat {
        min(fieldFrame.width / 32, fieldFrame.height / 16)
    }

    var fieldPatchRect: CGRect {
        CGRect(
            x: fieldFrame.minX,
            y: fieldFrame.minY,
            width: 32 * fieldScale,
            height: 16 * fieldScale
        )
    }

    var effectScale: CGFloat {
        min(effectFrame.width / 16, effectFrame.height / 16)
    }

    static var statusStrip: TokenmonSceneLayout {
        statusStrip(forThickness: NSStatusBar.system.thickness)
    }

    static func statusStrip(forThickness thickness: CGFloat) -> TokenmonSceneLayout {
        let normalizedHeight = max(18, round(thickness))
        let canvasHeight = normalizedHeight
        let canvasWidth = max(round(normalizedHeight * 2.0), normalizedHeight)
        let effectSize: CGFloat = 16
        let wildSize = max(16, round(normalizedHeight * 0.73))
        let wildOriginX = max(0, canvasWidth - wildSize)
        let wildOriginY = max(0, round((canvasHeight - wildSize) / 2))

        return TokenmonSceneLayout(
            canvasSize: CGSize(width: canvasWidth, height: canvasHeight),
            safeRect: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight),
            fieldFrame: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight),
            wildFrame: CGRect(x: wildOriginX, y: wildOriginY, width: wildSize, height: wildSize),
            effectFrame: CGRect(x: 0, y: 0, width: effectSize, height: effectSize),
            previewScale: 3
        )
    }
}

struct TokenmonGrassField: View {
    let state: TokenmonFieldState
    let tick: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelSprite(
                dots: TokenmonPixelArt.meadowBackHill(color: Color(red: 0.16, green: 0.39, blue: 0.24)),
                pixelSize: 1
            )
            .offset(x: 0, y: 9)

            PixelSprite(
                dots: TokenmonPixelArt.meadowTopHill(color: Color(red: 0.31, green: 0.62, blue: 0.39)),
                pixelSize: 1
            )
            .offset(x: 3, y: 8)

            PixelSprite(
                dots: TokenmonPixelArt.meadowFrontShade(color: Color(red: 0.10, green: 0.30, blue: 0.19)),
                pixelSize: 1
            )
            .offset(x: 0, y: 11)

            PixelSprite(
                dots: TokenmonPixelArt.meadowGrassBand(color: Color(red: 0.56, green: 0.83, blue: 0.55)),
                pixelSize: 1
            )
            .offset(x: grassBandOffset, y: 6 + grassBandLift)

            PixelSprite(
                dots: TokenmonPixelArt.cloverSprig(color: Color(red: 0.71, green: 0.91, blue: 0.63)),
                pixelSize: 1
            )
            .offset(x: 4, y: 9 + cloverLift)

            PixelSprite(
                dots: TokenmonPixelArt.wildflowerDots(color: Color(red: 0.98, green: 0.92, blue: 0.58)),
                pixelSize: 1
            )
            .offset(x: 14, y: 9 + flowerLift)

            PixelSprite(
                dots: TokenmonPixelArt.mossStone(color: Color(red: 0.38, green: 0.33, blue: 0.24)),
                pixelSize: 1
            )
            .offset(x: 25, y: 11)

            if state != .calm {
                PixelSprite(
                    dots: TokenmonPixelArt.pollenTrail(color: Color(red: 0.97, green: 0.93, blue: 0.68)),
                    pixelSize: 1
                )
                .offset(x: 19 + pollenOffset, y: 4 + pollenLift)
                .opacity(pollenOpacity)
            }
        }
        .frame(width: 32, height: 16, alignment: .topLeading)
        .clipped()
    }

    private var grassBandOffset: CGFloat {
        switch state {
        case .calm, .unavailable:
            return 0
        case .exploring:
            return CGFloat((tick % 3) - 1)
        case .rustle:
            return CGFloat((((tick % 4) - 2)))
        case .settle:
            return CGFloat(tick % 2)
        }
    }

    private var grassBandLift: CGFloat {
        switch state {
        case .calm, .unavailable:
            return 0
        case .exploring:
            return CGFloat(tick % 2)
        case .rustle:
            return CGFloat((tick % 3) - 1)
        case .settle:
            return 0
        }
    }

    private var cloverLift: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 2) - 1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var flowerLift: CGFloat {
        state == .rustle ? CGFloat((tick % 3) - 1) : 0
    }

    private var pollenOffset: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 4) - 2)
        case .exploring:
            return CGFloat((tick % 3) - 1)
        default:
            return 0
        }
    }

    private var pollenLift: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 3) - 1)
        case .exploring:
            return CGFloat((tick % 2) * -1)
        default:
            return 0
        }
    }

    private var pollenOpacity: Double {
        switch state {
        case .rustle:
            return 0.85
        case .exploring:
            return 0.52
        default:
            return 0
        }
    }
}

struct TokenmonSkyField: View {
    let state: TokenmonFieldState
    let tick: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelSprite(
                dots: TokenmonPixelArt.skyMainCloudShadow(color: Color(red: 0.55, green: 0.72, blue: 0.90)),
                pixelSize: 1
            )
            .offset(x: 5 + mainCloudOffset, y: 9 + mainCloudLift)
            .opacity(mainCloudOpacity)

            PixelSprite(
                dots: TokenmonPixelArt.skyMainCloud(color: Color(red: 0.95, green: 0.98, blue: 1.0)),
                pixelSize: 1
            )
            .offset(x: 4 + mainCloudOffset, y: 5 + mainCloudLift)
            .opacity(mainCloudOpacity)

            PixelSprite(
                dots: TokenmonPixelArt.skySmallCloudShadow(color: Color(red: 0.58, green: 0.75, blue: 0.92)),
                pixelSize: 1
            )
            .offset(x: 20 + smallCloudOffset, y: 5 + smallCloudLift)
            .opacity(smallCloudOpacity)

            PixelSprite(
                dots: TokenmonPixelArt.skySmallCloud(color: Color(red: 0.94, green: 0.98, blue: 1.0)),
                pixelSize: 1
            )
            .offset(x: 20 + smallCloudOffset, y: 3 + smallCloudLift)
            .opacity(smallCloudOpacity)
        }
        .frame(width: 32, height: 16, alignment: .topLeading)
        .clipped()
    }

    private var mainCloudOffset: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 4) - 2)
        case .exploring:
            return CGFloat(tick % 2)
        case .settle:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var mainCloudLift: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 3) - 1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var mainCloudOpacity: Double {
        switch state {
        case .calm:
            return 0.88
        case .exploring:
            return 0.96
        case .rustle:
            return 1
        case .settle:
            return 0.84
        case .unavailable:
            return 0.36
        }
    }

    private var smallCloudOffset: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 3) - 1)
        case .exploring:
            return CGFloat(tick % 2)
        case .settle:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var smallCloudLift: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 2) - 1)
        case .exploring:
            return CGFloat((tick % 2) - 1)
        default:
            return 0
        }
    }

    private var smallCloudOpacity: Double {
        switch state {
        case .calm:
            return 0.74
        case .exploring:
            return 0.84
        case .rustle:
            return 0.90
        case .settle:
            return 0.66
        case .unavailable:
            return 0.28
        }
    }
}

struct TokenmonCoastField: View {
    let state: TokenmonFieldState
    let tick: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelSprite(
                dots: TokenmonPixelArt.sandShelf(color: Color(red: 0.84, green: 0.74, blue: 0.52)),
                pixelSize: 1
            )
            .offset(x: 0, y: 11)

            PixelSprite(
                dots: TokenmonPixelArt.tideShadow(color: Color(red: 0.10, green: 0.34, blue: 0.53)),
                pixelSize: 1
            )
            .offset(x: 0 + tideOffset, y: 10 + tideLift)

            PixelSprite(
                dots: TokenmonPixelArt.tideBody(color: Color(red: 0.16, green: 0.48, blue: 0.71)),
                pixelSize: 1
            )
            .offset(x: tideOffset, y: 8 + tideLift)

            PixelSprite(
                dots: TokenmonPixelArt.tideHighlight(color: Color(red: 0.40, green: 0.78, blue: 0.93)),
                pixelSize: 1
            )
            .offset(x: 6 + tideHighlightOffset, y: 7 + tideHighlightLift)

            PixelSprite(
                dots: TokenmonPixelArt.foamCrest(color: foamColor),
                pixelSize: 1
            )
            .offset(x: 15, y: 6 + foamHeight)
            .opacity(foamOpacity)

            PixelSprite(
                dots: TokenmonPixelArt.shoreRock(color: Color(red: 0.39, green: 0.36, blue: 0.34)),
                pixelSize: 1
            )
            .offset(x: 24, y: 11)

            PixelSprite(
                dots: TokenmonPixelArt.shell(color: Color(red: 0.99, green: 0.88, blue: 0.85)),
                pixelSize: 1
            )
            .offset(x: 4, y: 12 + shellLift)
            .opacity(shellOpacity)

            if state != .calm {
                PixelSprite(
                    dots: TokenmonPixelArt.seaSpray(color: Color.white.opacity(0.95)),
                    pixelSize: 1
                )
                .offset(x: 23 + sprayOffset, y: 4 + sprayLift)
                .opacity(sprayOpacity)
            }
        }
        .frame(width: 32, height: 16, alignment: .topLeading)
        .clipped()
    }

    private var foamColor: Color {
        state == .unavailable ? .gray.opacity(0.45) : .white.opacity(0.92)
    }

    private var foamOpacity: Double {
        switch state {
        case .calm, .unavailable:
            return 0.45
        case .exploring:
            return 0.7
        case .rustle:
            return 0.95
        case .settle:
            return 0.55
        }
    }

    private var foamHeight: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 3) - 1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var tideOffset: CGFloat {
        switch state {
        case .calm, .unavailable:
            return 0
        case .exploring:
            return CGFloat((tick % 3) - 1)
        case .rustle:
            return CGFloat((tick % 4) - 2)
        case .settle:
            return CGFloat(tick % 2)
        }
    }

    private var tideLift: CGFloat {
        switch state {
        case .calm, .unavailable:
            return 0
        case .exploring:
            return CGFloat(tick % 2)
        case .rustle:
            return CGFloat((tick % 3) - 1)
        case .settle:
            return 0
        }
    }

    private var tideHighlightOffset: CGFloat {
        switch state {
        case .rustle:
            return CGFloat(((tick + 1) % 4) - 2)
        case .exploring:
            return CGFloat(((tick + 1) % 3) - 1)
        default:
            return 0
        }
    }

    private var tideHighlightLift: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 2) - 1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var shellLift: CGFloat {
        state == .rustle ? CGFloat((tick % 2) - 1) : 0
    }

    private var shellOpacity: Double {
        state == .unavailable ? 0.35 : 0.72
    }

    private var sprayOffset: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 3) - 1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var sprayLift: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 2) * -1)
        case .exploring:
            return CGFloat((tick % 2) - 1)
        default:
            return 0
        }
    }

    private var sprayOpacity: Double {
        switch state {
        case .rustle:
            return 0.82
        case .exploring:
            return 0.55
        default:
            return 0
        }
    }
}

struct TokenmonIceField: View {
    let state: TokenmonFieldState
    let tick: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelSprite(
                dots: TokenmonPixelArt.caveBackdrop(color: Color(red: 0.42, green: 0.35, blue: 0.30)),
                pixelSize: 1
            )
            .offset(x: 2, y: 3)

            PixelSprite(
                dots: TokenmonPixelArt.caveCeilingStalactites(color: Color(red: 0.33, green: 0.26, blue: 0.21)),
                pixelSize: 1
            )
            .offset(x: 0, y: 0 + ceilingLift)

            PixelSprite(
                dots: TokenmonPixelArt.caveFloorStalagmites(color: Color(red: 0.34, green: 0.27, blue: 0.22)),
                pixelSize: 1
            )
            .offset(x: 0, y: 11 + floorLift)

            PixelSprite(
                dots: TokenmonPixelArt.caveOpening(color: Color(red: 0.25, green: 0.20, blue: 0.17)),
                pixelSize: 1
            )
            .offset(x: 8, y: 4)
            .opacity(openingOpacity)

            PixelSprite(
                dots: TokenmonPixelArt.caveSideRock(color: Color(red: 0.30, green: 0.24, blue: 0.20)),
                pixelSize: 1
            )
            .offset(x: 1 + sideRockOffset, y: 5)

            PixelSprite(
                dots: TokenmonPixelArt.caveSideRock(color: Color(red: 0.30, green: 0.24, blue: 0.20)),
                pixelSize: 1
            )
            .offset(x: 26 + sideRockOffset, y: 5)

            PixelSprite(
                dots: TokenmonPixelArt.cavePebbleTrail(color: Color(red: 0.58, green: 0.49, blue: 0.43)),
                pixelSize: 1
            )
            .offset(x: 6 + pebbleOffset, y: 12 + pebbleLift)
            .opacity(pebbleOpacity)
        }
        .frame(width: 32, height: 16, alignment: .topLeading)
        .clipped()
    }

    private var ceilingLift: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 2) * -1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var floorLift: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 2) - 1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var openingOpacity: Double {
        switch state {
        case .calm:
            return 0.82
        case .exploring:
            return 0.90
        case .rustle:
            return 1
        case .settle:
            return 0.76
        case .unavailable:
            return 0.32
        }
    }

    private var sideRockOffset: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 2) - 1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var pebbleLift: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 2) * -1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var pebbleOffset: CGFloat {
        switch state {
        case .rustle:
            return CGFloat((tick % 2) - 1)
        case .exploring:
            return CGFloat(tick % 2)
        default:
            return 0
        }
    }

    private var pebbleOpacity: Double {
        switch state {
        case .unavailable:
            return 0.25
        case .rustle:
            return 0.85
        default:
            return 0.6
        }
    }
}

struct TokenmonUnavailableField: View {
    let state: TokenmonFieldState
    let tick: Int

    var body: some View {
        ZStack(alignment: .topLeading) {
            PixelSprite(
                dots: TokenmonPixelArt.oreVein(color: .gray.opacity(0.48)),
                pixelSize: 1
            )
            .offset(x: 2, y: 8)

            PixelSprite(
                dots: TokenmonPixelArt.windRibbon(color: .gray.opacity(0.32)),
                pixelSize: 1
            )
            .offset(x: 12 + CGFloat(tick % 2), y: 3)
        }
        .frame(width: 32, height: 16, alignment: .topLeading)
        .opacity(state == .unavailable ? 1 : 0.6)
        .clipped()
    }
}

private extension TokenmonEffectState {
    var spriteVariant: TokenmonEffectSpriteVariant? {
        switch self {
        case .none:
            return nil
        case .alert:
            return .alert16
        case .captureSnap:
            return .captureSnap16
        case .escapeDash:
            return .escapeDash16
        }
    }
}

struct TokenmonSceneEffect: View {
    let state: TokenmonEffectState
    let tick: Int

    var body: some View {
        ZStack {
            if let variant = state.spriteVariant {
                effectShadow(variant: variant)
                TokenmonEffectSpriteImage(variant: variant)
            }
        }
        .frame(width: 16, height: 16, alignment: .topLeading)
        .scaleEffect(effectScale)
        .offset(x: xOffset, y: yOffset)
        .opacity(opacity)
    }

    @ViewBuilder
    private func effectShadow(variant: TokenmonEffectSpriteVariant) -> some View {
        Color.black
            .opacity(shadowOpacity)
            .mask(TokenmonEffectSpriteImage(variant: variant))
            .offset(x: shadowOffset.width, y: shadowOffset.height)
    }
    
    private var effectScale: CGFloat {
        switch state {
        case .none:
            return 1
        case .alert:
            return [0.88, 1.06, 0.98, 1.06][tick % 4]
        case .captureSnap:
            return [1.0, 1.10, 1.18, 1.10][tick % 4]
        case .escapeDash:
            return [1.12, 1.20, 1.14, 1.08][tick % 4]
        }
    }

    private var xOffset: CGFloat {
        switch state {
        case .none:
            return 0
        case .alert:
            return [0, 0, 1, 0][tick % 4]
        case .captureSnap:
            return [0, -1, 0, 1][tick % 4]
        case .escapeDash:
            return [0, 2, 4, 5][tick % 4]
        }
    }

    private var yOffset: CGFloat {
        switch state {
        case .none:
            return 0
        case .alert:
            return [-2, -1, -2, -1][tick % 4]
        case .captureSnap:
            return [0, -1, -2, -1][tick % 4]
        case .escapeDash:
            return [0, -1, 0, 1][tick % 4]
        }
    }

    private var opacity: Double {
        switch state {
        case .none:
            return 0
        case .alert:
            return [0.90, 1.0, 0.96, 1.0][tick % 4]
        case .captureSnap:
            return [0.98, 1.0, 0.96, 0.92][tick % 4]
        case .escapeDash:
            return [1.0, 0.98, 0.94, 0.90][tick % 4]
        }
    }

    private var shadowOffset: CGSize {
        switch state {
        case .none:
            return .zero
        case .alert:
            return CGSize(width: 1, height: 1)
        case .captureSnap:
            return CGSize(width: 1, height: 1)
        case .escapeDash:
            return CGSize(width: 1, height: 1)
        }
    }

    private var shadowOpacity: Double {
        switch state {
        case .none:
            return 0
        case .alert:
            return 0.26
        case .captureSnap:
            return 0.32
        case .escapeDash:
            return 0.22
        }
    }
}

struct PixelDot: Identifiable {
    let x: Int
    let y: Int
    let color: Color

    var id: String {
        "\(x)-\(y)"
    }
}

struct PixelSprite: View {
    let dots: [PixelDot]
    let pixelSize: CGFloat

    var body: some View {
        let maxX = (dots.map(\.x).max() ?? 0) + 1
        let maxY = (dots.map(\.y).max() ?? 0) + 1

        ZStack(alignment: .topLeading) {
            ForEach(dots) { dot in
                Rectangle()
                    .fill(dot.color)
                    .frame(width: pixelSize, height: pixelSize)
                    .offset(x: CGFloat(dot.x) * pixelSize, y: CGFloat(dot.y) * pixelSize)
            }
        }
        .frame(width: CGFloat(maxX) * pixelSize, height: CGFloat(maxY) * pixelSize, alignment: .topLeading)
    }
}

enum TokenmonPixelArt {
    private static let tinyGrassRows = [
        ".XX...",
        "XddX..",
        "XdmmX.",
        "XmmmdX",
        "XllmXX",
        ".XXXX.",
    ]

    private static let referenceGrassBaseRows = [
        "....................",
        "....................",
        "....................",
        "....................",
        "..XX............XX..",
        ".XllXX........XXllX.",
        "XlllmmXXXXXXXXmmlllX",
        "XllmmmmmmmmmmmmmmllX",
        ".XlmmmmmmmmmmmmmmX..",
        "..XXXXXXXXXXXXXXXX..",
    ]

    private static let referenceGrassBladeRows = [
        ".......XX......XX...",
        "......XddX....XddX..",
        "..XX..XdmmX..XdmmdX.",
        ".XddX.XdmmmXXdmmmdX.",
        "XmmmdXXdmmmmddmmmdX.",
        ".XmmmmdmmmmmmmmmdX..",
    ]

    private static let grassClumpRows = [
        "......XX..........",
        ".....XddX....XX...",
        "....XdmmdX..XdmX..",
        "..XXdmmmmdX.XmmdX.",
        ".XdmddmmmmdXXmmmdX",
        "XdmmdmmmmmmdmmmmdX",
        "XmmmmdmmmmmmmmdmmX",
        "XlmmmmdmmmmXXmmmdX",
        "XllmmmmmmmmddmmmdX",
        ".XlllmmmmmmmmmmmX.",
        "..XllllmmmmmmmXX..",
        "...XXXXXXXXXXXX...",
    ]

    private static func spriteDots(
        rows: [String],
        matching characters: Set<Character>,
        color: Color
    ) -> [PixelDot] {
        var dots: [PixelDot] = []
        for (y, row) in rows.enumerated() {
            for (x, char) in row.enumerated() where characters.contains(char) {
                dots.append(PixelDot(x: x, y: y, color: color))
            }
        }
        return dots
    }

    static func referenceGrassBaseOutline(color: Color) -> [PixelDot] {
        spriteDots(rows: referenceGrassBaseRows, matching: ["X"], color: color)
    }

    static func referenceGrassBaseDark(color: Color) -> [PixelDot] {
        spriteDots(rows: referenceGrassBaseRows, matching: ["m"], color: color)
    }

    static func referenceGrassBaseLight(color: Color) -> [PixelDot] {
        spriteDots(rows: referenceGrassBaseRows, matching: ["l"], color: color)
    }

    static func referenceGrassBladeOutline(color: Color) -> [PixelDot] {
        spriteDots(rows: referenceGrassBladeRows, matching: ["X"], color: color)
    }

    static func referenceGrassBladeDark(color: Color) -> [PixelDot] {
        spriteDots(rows: referenceGrassBladeRows, matching: ["d"], color: color)
    }

    static func referenceGrassBladeMain(color: Color) -> [PixelDot] {
        spriteDots(rows: referenceGrassBladeRows, matching: ["m"], color: color)
    }

    static func referenceGrassBladeLight(color: Color) -> [PixelDot] {
        spriteDots(rows: referenceGrassBladeRows, matching: ["l"], color: color)
    }

    static func tinyGrassOutline(color: Color) -> [PixelDot] {
        spriteDots(rows: tinyGrassRows, matching: ["X"], color: color)
    }

    static func tinyGrassDark(color: Color) -> [PixelDot] {
        spriteDots(rows: tinyGrassRows, matching: ["d"], color: color)
    }

    static func tinyGrassMain(color: Color) -> [PixelDot] {
        spriteDots(rows: tinyGrassRows, matching: ["m"], color: color)
    }

    static func tinyGrassLight(color: Color) -> [PixelDot] {
        spriteDots(rows: tinyGrassRows, matching: ["l"], color: color)
    }

    static func simpleGrassBase(color: Color) -> [PixelDot] {
        spriteDots(rows: grassClumpRows, matching: ["X"], color: color)
    }

    static func simpleGrassShadow(color: Color) -> [PixelDot] {
        spriteDots(rows: grassClumpRows, matching: ["d"], color: color)
    }

    static func simpleGrassTuft(color: Color) -> [PixelDot] {
        spriteDots(rows: grassClumpRows, matching: ["m"], color: color)
    }

    static func simpleGrassHighlight(color: Color) -> [PixelDot] {
        spriteDots(rows: grassClumpRows, matching: ["l"], color: color)
    }

    static func smallGrassTuft(color: Color) -> [PixelDot] {
        spriteDots(
            rows: [
                ".XmX..",
                "XmmmX.",
                ".XmmX.",
                "..XX..",
            ],
            matching: ["X", "m"],
            color: color
        )
    }

    static func simpleCloudShelf(color: Color) -> [PixelDot] {
        let points = [
            (7, 0), (8, 0), (9, 0),
            (4, 1), (5, 1), (6, 1), (7, 1), (8, 1), (9, 1), (10, 1), (11, 1), (12, 1),
            (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2), (9, 2), (10, 2), (11, 2), (12, 2), (13, 2), (14, 2),
            (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (8, 3), (9, 3), (10, 3), (11, 3), (12, 3), (13, 3), (14, 3), (15, 3),
            (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4), (9, 4), (10, 4), (11, 4), (12, 4), (13, 4), (14, 4),
            (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5), (11, 5),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleCloudShade(color: Color) -> [PixelDot] {
        let points = [
            (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4), (9, 4),
            (10, 4), (11, 4), (12, 4), (13, 4),
            (5, 5), (6, 5), (7, 5), (8, 5), (9, 5), (10, 5),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleSmallCloud(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (2, 0), (3, 0),
            (0, 1), (1, 1), (2, 1), (3, 1), (4, 1), (5, 1),
            (1, 2), (2, 2), (3, 2), (4, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleWaveBase(color: Color) -> [PixelDot] {
        let points = [
            (0, 4), (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4),
            (9, 4), (10, 4), (11, 4), (12, 4), (13, 4), (14, 4), (15, 4), (16, 4),
            (17, 4), (18, 4), (19, 4), (20, 4), (21, 4), (22, 4), (23, 4), (24, 4), (25, 4),
            (1, 5), (2, 5), (3, 5), (4, 5), (5, 5), (6, 5), (7, 5), (8, 5), (9, 5),
            (10, 5), (11, 5), (12, 5), (13, 5), (14, 5), (15, 5), (16, 5), (17, 5),
            (18, 5), (19, 5), (20, 5), (21, 5), (22, 5), (23, 5),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleWaveBand(color: Color) -> [PixelDot] {
        let points = [
            (0, 5), (1, 4), (2, 3), (3, 2), (4, 1), (5, 1), (6, 2), (7, 3), (8, 4),
            (8, 5), (9, 4), (10, 3), (11, 2), (12, 1), (13, 1), (14, 2), (15, 3), (16, 4),
            (16, 5), (17, 4), (18, 3), (19, 2), (20, 1), (21, 1), (22, 2), (23, 3), (24, 4),
            (24, 5), (25, 4), (26, 3), (27, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleWaveHighlight(color: Color) -> [PixelDot] {
        let points = [
            (2, 3), (3, 2), (4, 2), (5, 2),
            (10, 3), (11, 2), (12, 2), (13, 2),
            (18, 3), (19, 2), (20, 2), (21, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleWaveFoam(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (3, 0), (5, 1), (7, 0), (9, 1),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleWaveEcho(color: Color) -> [PixelDot] {
        let points = [
            (0, 2), (1, 1), (2, 1), (3, 2), (4, 3),
            (5, 2), (6, 1), (7, 1), (8, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleCaveArch(color: Color) -> [PixelDot] {
        let points = [
            (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0), (8, 0), (9, 0), (10, 0),
            (11, 0), (12, 0), (13, 0), (14, 0), (15, 0), (16, 0), (17, 0), (18, 0), (19, 0), (20, 0), (21, 0), (22, 0),
            (1, 1), (2, 1), (3, 1), (4, 1), (5, 1), (19, 1), (20, 1), (21, 1), (22, 1), (23, 1),
            (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (18, 2), (19, 2), (20, 2), (21, 2), (22, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleCaveStalactites(color: Color) -> [PixelDot] {
        let points = [
            (5, 0), (6, 1), (6, 2),
            (12, 0), (13, 1), (13, 2), (13, 3),
            (18, 0), (19, 1), (19, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleCaveFloor(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (2, 0), (3, 0), (4, 0),
            (8, 0), (9, 0), (10, 0),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleCrystalCluster(color: Color) -> [PixelDot] {
        let points = [
            (1, 0),
            (0, 1), (1, 1), (2, 1),
            (1, 2), (3, 0), (3, 1), (3, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func simpleCrystalGlow(color: Color) -> [PixelDot] {
        let points = [
            (1, 3), (2, 3), (3, 3), (4, 3),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func meadowBackHill(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<32 {
            let crest: Int
            switch x {
            case 0..<6: crest = 4
            case 6..<12: crest = 3
            case 12..<20: crest = 2
            case 20..<27: crest = 3
            default: crest = 4
            }

            for y in crest..<7 {
                points.append((x, y))
            }
        }
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func meadowTopHill(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<26 {
            let crest: Int
            switch x {
            case 0..<5: crest = 3
            case 5..<12: crest = 2
            case 12..<18: crest = 1
            case 18..<23: crest = 2
            default: crest = 3
            }

            for y in crest..<6 {
                points.append((x, y))
            }
        }
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func meadowGrassBand(color: Color) -> [PixelDot] {
        let blades = [(0, 4), (2, 6), (4, 5), (6, 7), (9, 4), (11, 6), (14, 5), (17, 7), (20, 5), (23, 6), (26, 4), (29, 5)]
        var points: [(Int, Int)] = []

        for (x, height) in blades {
            for step in 0..<height {
                let y = 7 - height + step
                points.append((x, y))
                if step >= height - 2 {
                    points.append((x + 1, y))
                }
            }
        }

        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func meadowFrontShade(color: Color) -> [PixelDot] {
        let ridge = [
            3, 3, 2, 2, 3, 4, 3, 2, 2, 3, 4, 4, 3, 2, 2, 3,
            4, 4, 3, 2, 2, 3, 4, 4, 3, 2, 2, 3, 4, 3, 2, 2,
        ]
        var points: [(Int, Int)] = []

        for (x, crest) in ridge.enumerated() {
            for y in crest..<5 {
                points.append((x, y))
            }
        }

        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func cloverSprig(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (0, 1), (1, 1), (2, 1), (1, 2),
            (4, 1), (3, 2), (4, 2), (5, 2), (4, 3),
            (3, 4), (3, 5),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func wildflowerDots(color: Color) -> [PixelDot] {
        let points = [
            (0, 0), (3, 1), (6, 0), (2, 3), (7, 3),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func mossStone(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (2, 0),
            (0, 1), (1, 1), (2, 1), (3, 1),
            (1, 2), (2, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func pollenTrail(color: Color) -> [PixelDot] {
        let points = [
            (0, 2), (2, 1), (4, 0), (6, 1), (8, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func sunBurst(color: Color) -> [PixelDot] {
        let points = [
            (2, 0),
            (1, 1), (2, 1), (3, 1),
            (0, 2), (1, 2), (2, 2), (3, 2), (4, 2),
            (1, 3), (2, 3), (3, 3),
            (2, 4),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func skyMainCloud(color: Color) -> [PixelDot] {
        let points = [
            (4, 0), (5, 0),
            (2, 1), (3, 1), (4, 1), (5, 1), (6, 1), (7, 1),
            (1, 2), (2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (7, 2), (8, 2),
            (0, 3), (1, 3), (2, 3), (3, 3), (4, 3), (5, 3), (6, 3), (7, 3), (8, 3), (9, 3),
            (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4),
            (3, 5), (4, 5), (5, 5), (6, 5),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func skyMainCloudShadow(color: Color) -> [PixelDot] {
        let points = [
            (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4), (8, 4),
            (2, 5), (3, 5), (4, 5), (5, 5), (6, 5), (7, 5),
            (4, 6), (5, 6),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func skySmallCloud(color: Color) -> [PixelDot] {
        let points = [
            (2, 0),
            (1, 1), (2, 1), (3, 1),
            (0, 2), (1, 2), (2, 2), (3, 2), (4, 2),
            (1, 3), (2, 3), (3, 3),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func skySmallCloudShadow(color: Color) -> [PixelDot] {
        let points = [
            (0, 3), (1, 3), (2, 3), (3, 3), (4, 3),
            (1, 4), (2, 4), (3, 4),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func windRibbon(color: Color) -> [PixelDot] {
        let points = [
            (0, 2), (1, 2), (2, 2), (3, 1), (4, 1), (5, 1), (6, 2), (7, 2), (8, 2),
            (6, 4), (7, 4), (8, 4), (9, 3), (10, 3), (11, 3), (12, 4), (13, 4), (14, 4),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func skyCurrentBand(color: Color) -> [PixelDot] {
        let points = [
            (0, 3), (1, 3), (2, 3), (3, 2), (4, 2), (5, 2), (6, 2), (7, 3), (8, 3), (9, 3),
            (10, 4), (11, 4), (12, 4), (13, 3), (14, 3), (15, 3), (16, 2), (17, 2), (18, 2), (19, 3),
            (20, 3), (21, 3), (22, 4), (23, 4), (24, 4), (25, 3), (26, 3), (27, 3),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func skyCurrentHighlight(color: Color) -> [PixelDot] {
        let points = [
            (1, 2), (2, 2), (3, 1), (4, 1), (5, 1), (6, 1), (7, 2), (8, 2),
            (12, 3), (13, 2), (14, 2), (15, 2), (16, 1), (17, 1), (18, 1), (19, 2), (20, 2),
            (24, 3), (25, 2), (26, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func windMote(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (0, 1), (2, 1),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func snowflakeOutline(color: Color) -> [PixelDot] {
        let points = [
            (2, 0),
            (1, 1), (2, 1), (3, 1),
            (0, 2), (1, 2), (2, 2), (3, 2), (4, 2),
            (1, 3), (2, 3), (3, 3),
            (2, 4),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func snowflakeCore(color: Color) -> [PixelDot] {
        let points = [
            (2, 1),
            (1, 2), (2, 2), (3, 2),
            (2, 3),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func sandShelf(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<32 {
            let crest: Int
            switch x {
            case 0..<8: crest = 2
            case 8..<15: crest = 1
            case 15..<22: crest = 2
            case 22..<28: crest = 1
            default: crest = 2
            }

            for y in crest..<5 {
                points.append((x, y))
            }
        }
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func tideBody(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<24 {
            let crest = (x % 6 == 0 || x % 6 == 1) ? 1 : 2
            for y in crest..<6 {
                points.append((x, y))
            }
        }
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func tideShadow(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<27 {
            let crest = x < 18 ? 1 : 2
            for y in crest..<4 {
                points.append((x, y))
            }
        }
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func tideHighlight(color: Color) -> [PixelDot] {
        let points = [
            (0, 1), (1, 0), (2, 0), (3, 1), (4, 1), (5, 0), (6, 0), (7, 1), (8, 1),
            (3, 2), (4, 2), (5, 2), (6, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func foamCrest(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (3, 0), (5, 1), (7, 0), (9, 1),
            (0, 1), (2, 1), (4, 2), (6, 1), (8, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func shoreRock(color: Color) -> [PixelDot] {
        let points = [
            (2, 0), (3, 0),
            (1, 1), (2, 1), (3, 1), (4, 1),
            (0, 2), (1, 2), (2, 2), (3, 2), (4, 2),
            (1, 3), (2, 3), (3, 3),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func shell(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (0, 1), (1, 1), (2, 1), (1, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func seaSpray(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (0, 1), (2, 1), (1, 2), (3, 2),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func caveCeiling(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<32 {
            let depth: Int
            switch x {
            case 0..<5, 27..<32: depth = 2
            case 5..<10, 22..<27: depth = 3
            case 10..<22: depth = 4
            default: depth = 2
            }

            for y in 0..<depth {
                points.append((x, y))
            }
        }

        points.append(contentsOf: [(6, 4), (7, 5), (15, 4), (16, 5), (24, 4)])
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func caveBackdrop(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<24 {
            for y in 0..<8 {
                points.append((x, y))
            }
        }
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func caveCeilingStalactites(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<32 {
            points.append((x, 0))
            points.append((x, 1))
        }
        points.append(contentsOf: [
            (4, 2), (5, 2), (6, 2), (5, 3), (5, 4),
            (12, 2), (13, 2), (14, 2), (13, 3),
            (20, 2), (21, 2), (22, 2), (21, 3), (21, 4),
            (28, 2), (29, 2), (30, 2), (29, 3),
        ])
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func caveFloorStalagmites(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<32 {
            points.append((x, 3))
            points.append((x, 4))
        }
        points.append(contentsOf: [
            (6, 2), (7, 2), (8, 2), (7, 1),
            (15, 2), (16, 2), (17, 2), (16, 1),
            (24, 2), (25, 2), (26, 2), (25, 1),
        ])
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func caveOpening(color: Color) -> [PixelDot] {
        var points: [(Int, Int)] = []
        for x in 0..<15 {
            for y in 0..<6 {
                points.append((x, y))
            }
        }
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func caveSideRock(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (2, 0),
            (0, 1), (1, 1), (2, 1), (3, 1),
            (0, 2), (1, 2), (2, 2), (3, 2),
            (1, 3), (2, 3),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func cavePebbleTrail(color: Color) -> [PixelDot] {
        let points = [
            (0, 1), (2, 0), (4, 1), (6, 0), (8, 1), (10, 0), (12, 1),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func oreVein(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (4, 0),
            (0, 1), (1, 1), (2, 1), (4, 1), (5, 1),
            (2, 2), (3, 2), (4, 2),
            (1, 3), (3, 3), (5, 3),
            (2, 4), (4, 4),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func crystalCluster(color: Color) -> [PixelDot] {
        let points = [
            (3, 0),
            (2, 1), (3, 1), (4, 1),
            (1, 2), (2, 2), (3, 2), (4, 2), (5, 2),
            (2, 3), (3, 3), (4, 3),
            (0, 4), (1, 4), (2, 4), (4, 4), (5, 4), (6, 4),
            (1, 5), (2, 5), (3, 5), (4, 5), (5, 5),
            (2, 6), (3, 6), (4, 6),
            (3, 7),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func caveCrystalSpire(color: Color) -> [PixelDot] {
        let points = [
            (4, 0),
            (3, 1), (4, 1), (5, 1),
            (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
            (2, 3), (3, 3), (4, 3), (5, 3), (6, 3),
            (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4), (7, 4),
            (2, 5), (3, 5), (4, 5), (5, 5), (6, 5),
            (3, 6), (4, 6), (5, 6),
            (4, 7),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func caveCrystalShadow(color: Color) -> [PixelDot] {
        let points = [
            (3, 1), (4, 1), (5, 1),
            (2, 2), (3, 2), (4, 2), (5, 2), (6, 2),
            (2, 3), (3, 3), (4, 3), (5, 3), (6, 3),
            (1, 4), (2, 4), (3, 4), (4, 4), (5, 4), (6, 4),
            (2, 5), (3, 5), (4, 5), (5, 5), (6, 5),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func gritPebbles(color: Color) -> [PixelDot] {
        let points = [
            (0, 1), (2, 0), (4, 1), (6, 0), (7, 1),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func emberSpark(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (0, 1), (1, 1), (2, 1),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func lavaCrack(color: Color) -> [PixelDot] {
        let points = [
            (0, 1), (1, 1), (2, 0), (3, 0), (4, 1), (5, 1),
            (6, 1), (7, 0), (8, 0), (9, 1), (10, 1), (11, 2),
            (12, 2), (13, 1), (14, 1),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func alertBang(color: Color) -> [PixelDot] {
        let points = [
            (1, 0), (1, 1), (1, 2), (1, 3),
            (1, 5),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func sparkle(color: Color) -> [PixelDot] {
        let points = [
            (2, 0), (2, 1), (0, 2), (1, 2), (2, 2), (3, 2), (4, 2), (2, 3), (2, 4),
        ]
        return points.map { PixelDot(x: $0.0, y: $0.1, color: color) }
    }

    static func encounterBadge() -> [PixelDot] {
        let burstColor = Color(red: 0.98, green: 0.84, blue: 0.24)
        let coreColor = Color(red: 1.0, green: 0.91, blue: 0.48)
        let burst = [
            (3, 0, burstColor), (4, 0, burstColor),
            (2, 1, burstColor), (3, 1, coreColor), (4, 1, coreColor), (5, 1, burstColor),
            (1, 2, burstColor), (2, 2, coreColor), (3, 2, coreColor), (4, 2, coreColor), (5, 2, coreColor), (6, 2, burstColor),
            (2, 3, coreColor), (3, 3, coreColor), (4, 3, coreColor), (5, 3, coreColor),
            (3, 4, burstColor), (4, 4, burstColor),
            (3, 1, Color.red), (3, 2, Color.red), (3, 3, Color.red), (3, 5, Color.red),
        ]
        return burst.map { PixelDot(x: $0.0, y: $0.1, color: $0.2) }
    }

    static func capturedBadge() -> [PixelDot] {
        let burstColor = Color(red: 0.17, green: 0.78, blue: 0.34)
        let coreColor = Color(red: 0.50, green: 0.93, blue: 0.61)
        let burst = [
            (3, 0, burstColor), (4, 0, burstColor),
            (2, 1, burstColor), (3, 1, coreColor), (4, 1, coreColor), (5, 1, burstColor),
            (1, 2, burstColor), (2, 2, coreColor), (3, 2, coreColor), (4, 2, coreColor), (5, 2, coreColor), (6, 2, burstColor),
            (2, 3, coreColor), (3, 3, coreColor), (4, 3, coreColor), (5, 3, coreColor),
            (3, 4, burstColor), (4, 4, burstColor),
            (2, 3, Color.white), (3, 4, Color.white), (4, 3, Color.white), (5, 2, Color.white),
        ]
        return burst.map { PixelDot(x: $0.0, y: $0.1, color: $0.2) }
    }

    static func escapedBadge() -> [PixelDot] {
        let burstColor = Color(red: 0.90, green: 0.36, blue: 0.22)
        let coreColor = Color(red: 0.98, green: 0.62, blue: 0.29)
        let burst = [
            (3, 0, burstColor), (4, 0, burstColor),
            (2, 1, burstColor), (3, 1, coreColor), (4, 1, coreColor), (5, 1, burstColor),
            (1, 2, burstColor), (2, 2, coreColor), (3, 2, coreColor), (4, 2, coreColor), (5, 2, coreColor), (6, 2, burstColor),
            (2, 3, coreColor), (3, 3, coreColor), (4, 3, coreColor), (5, 3, coreColor),
            (3, 4, burstColor), (4, 4, burstColor),
            (2, 2, Color.white), (3, 3, Color.white), (4, 2, Color.white), (5, 3, Color.white),
        ]
        return burst.map { PixelDot(x: $0.0, y: $0.1, color: $0.2) }
    }

    static func pixelBadgeShape(
        width: Int,
        height: Int,
        fillTop: Color,
        fillBottom: Color,
        outline: Color
    ) -> [PixelDot] {
        var dots: [PixelDot] = []

        for y in 0..<height {
            let inset = badgeInset(for: y, height: height)
            let startX = inset
            let endX = width - inset - 1

            guard startX <= endX else {
                continue
            }

            for x in startX...endX {
                let isOutline = y == 0 || y == height - 1 || x == startX || x == endX
                let color = isOutline ? outline : (y <= (height / 2) ? fillTop : fillBottom)
                dots.append(PixelDot(x: x, y: y, color: color))
            }
        }

        return dots
    }

    static func pixelWordWidth(_ word: String) -> Int {
        var width = 0
        let characters = Array(word)

        for (index, character) in characters.enumerated() {
            width += tinyGlyph(for: character).first?.count ?? 0
            if index < characters.count - 1 {
                width += 1
            }
        }

        return width
    }

    static func pixelWord(_ word: String, color: Color) -> [PixelDot] {
        var dots: [PixelDot] = []
        let characters = Array(word)
        var cursorX = 0

        for (index, character) in characters.enumerated() {
            let glyph = tinyGlyph(for: character)
            let glyphWidth = glyph.first?.count ?? 0

            for (y, row) in glyph.enumerated() {
                for (x, pixel) in row.enumerated() where pixel == "X" {
                    dots.append(PixelDot(x: cursorX + x, y: y, color: color))
                }
            }

            cursorX += glyphWidth
            if index < characters.count - 1 {
                cursorX += 1
            }
        }

        return dots
    }

    private static func badgeInset(for y: Int, height: Int) -> Int {
        switch y {
        case 0, height - 1:
            return 2
        case 1, height - 2:
            return 1
        default:
            return 0
        }
    }

    private static func tinyGlyph(for character: Character) -> [String] {
        switch character {
        case "A":
            return [".X.", "X.X", "XXX", "X.X", "X.X"]
        case "C":
            return [".XX", "X..", "X..", "X..", ".XX"]
        case "D":
            return ["XX.", "X.X", "X.X", "X.X", "XX."]
        case "E":
            return ["XXX", "X..", "XX.", "X..", "XXX"]
        case "G":
            return [".XX", "X..", "X.X", "X.X", ".XX"]
        case "H":
            return ["X.X", "X.X", "XXX", "X.X", "X.X"]
        case "I":
            return ["XXX", ".X.", ".X.", ".X.", "XXX"]
        case "M":
            return ["X.X", "XXX", "XXX", "X.X", "X.X"]
        case "O":
            return [".X.", "X.X", "X.X", "X.X", ".X."]
        case "S":
            return [".XX", "X..", ".X.", "..X", "XX."]
        case "T":
            return ["XXX", ".X.", ".X.", ".X.", ".X."]
        case "!":
            return ["X", "X", "X", ".", "X"]
        default:
            return ["XXX", "X.X", ".X.", "...", ".X."]
        }
    }
}
