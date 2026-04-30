import SwiftUI
import TokenmonDomain
import TokenmonPersistence

private extension Color {
    init(hex: UInt32) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

let tokenmonDexSupportingWidth: CGFloat = 272
let tokenmonDexFrontCardWidth: CGFloat = tokenmonDexSupportingWidth
let tokenmonDexFrontCardMinHeight: CGFloat = 424
let tokenmonDexHeaderPillFlowHeight: CGFloat = 49

extension DexEntryStatus {
    var allowsPremiumDexDetailCardEffects: Bool {
        self == .captured
    }
}

enum TokenmonDexShimmerZone: Equatable {
    case none
    case perimeter
}

struct TokenmonDexDetailCardStyle: Equatable {
    let shellEdgeGlow: Double
    let hoverGlowBoost: Double
    let frameHighlight: Double
    let auraOpacity: Double
    let foilOpacity: Double
    let hoverEdgeSweepOpacity: Double
    let glareOpacity: Double
    let hoverGlareBoost: Double
    let shadowOpacity: Double
    let hoverShadowBoost: Double
    let frameGlossOpacity: Double
    let shellCenterProtection: Double
    let artSurfaceTop: Color
    let artSurfaceBottom: Color
    let artBackplateOpacity: Double
    let artGlareOpacity: Double
    let artGlareWidth: CGFloat
    let shimmerAllowed: Bool
    let shimmerOpacity: Double
    let shimmerDuration: Double
    let shimmerZone: TokenmonDexShimmerZone
    let pulseAllowed: Bool
    let stampSymbol: String
    let surfaceTop: Color
    let surfaceBottom: Color
    let primaryText: Color
    let secondaryText: Color
    let foilTint: Color
    let foilAccent: Color
    let holoOpacity: Double
    let holoGlareIntensity: Double
    let sparkleCount: Int
    let tiltStrength: Double

    static func make(for rarity: RarityTier) -> TokenmonDexDetailCardStyle {
        switch rarity {
        case .common:
            return TokenmonDexDetailCardStyle(
                shellEdgeGlow: 0,
                hoverGlowBoost: 0,
                frameHighlight: 0.10,
                auraOpacity: 0,
                foilOpacity: 0,
                hoverEdgeSweepOpacity: 0,
                glareOpacity: 0.0003,
                hoverGlareBoost: 0.0005,
                shadowOpacity: 0.08,
                hoverShadowBoost: 0.025,
                frameGlossOpacity: 0,
                shellCenterProtection: 0.022,
                artSurfaceTop: Color(hex: 0x2A2D35),
                artSurfaceBottom: Color(hex: 0x1B1D24),
                artBackplateOpacity: 0.04,
                artGlareOpacity: 0.0,
                artGlareWidth: 0.12,
                shimmerAllowed: false,
                shimmerOpacity: 0,
                shimmerDuration: 8.5,
                shimmerZone: .none,
                pulseAllowed: false,
                stampSymbol: "circle.fill",
                surfaceTop: Color(hex: 0x353842),
                surfaceBottom: Color(hex: 0x242731),
                primaryText: Color.white.opacity(0.95),
                secondaryText: Color.white.opacity(0.68),
                foilTint: Color.white,
                foilAccent: Color(hex: 0xB8BEC8),
                holoOpacity: 0.0092,
                holoGlareIntensity: 0.004,
                sparkleCount: 0,
                tiltStrength: 0.28
            )
        case .uncommon:
            return TokenmonDexDetailCardStyle(
                shellEdgeGlow: 0,
                hoverGlowBoost: 0,
                frameHighlight: 0.13,
                auraOpacity: 0,
                foilOpacity: 0,
                hoverEdgeSweepOpacity: 0,
                glareOpacity: 0.0005,
                hoverGlareBoost: 0.0009,
                shadowOpacity: 0.09,
                hoverShadowBoost: 0.03,
                frameGlossOpacity: 0,
                shellCenterProtection: 0.024,
                artSurfaceTop: Color(hex: 0x24322C),
                artSurfaceBottom: Color(hex: 0x18211D),
                artBackplateOpacity: 0.05,
                artGlareOpacity: 0.0,
                artGlareWidth: 0.13,
                shimmerAllowed: false,
                shimmerOpacity: 0,
                shimmerDuration: 8,
                shimmerZone: .none,
                pulseAllowed: false,
                stampSymbol: "diamond.fill",
                surfaceTop: Color(hex: 0x214239),
                surfaceBottom: Color(hex: 0x1F2E2B),
                primaryText: Color.white.opacity(0.95),
                secondaryText: Color.white.opacity(0.70),
                foilTint: Color(hex: 0xA6F4C5),
                foilAccent: Color(hex: 0x53D391),
                holoOpacity: 0.0158,
                holoGlareIntensity: 0.007,
                sparkleCount: 18,
                tiltStrength: 0.385
            )
        case .rare:
            return TokenmonDexDetailCardStyle(
                shellEdgeGlow: 0,
                hoverGlowBoost: 0,
                frameHighlight: 0.18,
                auraOpacity: 0,
                foilOpacity: 0,
                hoverEdgeSweepOpacity: 0,
                glareOpacity: 0.0008,
                hoverGlareBoost: 0.0016,
                shadowOpacity: 0.12,
                hoverShadowBoost: 0.04,
                frameGlossOpacity: 0,
                shellCenterProtection: 0.026,
                artSurfaceTop: Color(hex: 0x233047),
                artSurfaceBottom: Color(hex: 0x17202E),
                artBackplateOpacity: 0.06,
                artGlareOpacity: 0.002,
                artGlareWidth: 0.15,
                shimmerAllowed: true,
                shimmerOpacity: 0,
                shimmerDuration: 12.0,
                shimmerZone: .perimeter,
                pulseAllowed: false,
                stampSymbol: "triangle.fill",
                surfaceTop: Color(hex: 0x223A5A),
                surfaceBottom: Color(hex: 0x202A3C),
                primaryText: Color.white.opacity(0.96),
                secondaryText: Color.white.opacity(0.72),
                foilTint: Color(hex: 0x9FDBFF),
                foilAccent: Color(hex: 0x5CB7FF),
                holoOpacity: 0.025,
                holoGlareIntensity: 0.011,
                sparkleCount: 36,
                tiltStrength: 0.49
            )
        case .epic:
            return TokenmonDexDetailCardStyle(
                shellEdgeGlow: 0,
                hoverGlowBoost: 0,
                frameHighlight: 0.24,
                auraOpacity: 0,
                foilOpacity: 0,
                hoverEdgeSweepOpacity: 0,
                glareOpacity: 0.0011,
                hoverGlareBoost: 0.0021,
                shadowOpacity: 0.16,
                hoverShadowBoost: 0.06,
                frameGlossOpacity: 0,
                shellCenterProtection: 0.028,
                artSurfaceTop: Color(hex: 0x312341),
                artSurfaceBottom: Color(hex: 0x21182C),
                artBackplateOpacity: 0.08,
                artGlareOpacity: 0.0035,
                artGlareWidth: 0.17,
                shimmerAllowed: true,
                shimmerOpacity: 0,
                shimmerDuration: 7.8,
                shimmerZone: .perimeter,
                pulseAllowed: true,
                stampSymbol: "sparkles",
                surfaceTop: Color(hex: 0x402553),
                surfaceBottom: Color(hex: 0x2A1F35),
                primaryText: Color.white.opacity(0.97),
                secondaryText: Color.white.opacity(0.72),
                foilTint: Color(hex: 0xF2B2FF),
                foilAccent: Color(hex: 0xB97CFF),
                holoOpacity: 0.0344,
                holoGlareIntensity: 0.016,
                sparkleCount: 60,
                tiltStrength: 0.595
            )
        case .legendary:
            return TokenmonDexDetailCardStyle(
                shellEdgeGlow: 0,
                hoverGlowBoost: 0,
                frameHighlight: 0.30,
                auraOpacity: 0,
                foilOpacity: 0,
                hoverEdgeSweepOpacity: 0,
                glareOpacity: 0.0015,
                hoverGlareBoost: 0.00275,
                shadowOpacity: 0.19,
                hoverShadowBoost: 0.08,
                frameGlossOpacity: 0,
                shellCenterProtection: 0.032,
                artSurfaceTop: Color(hex: 0x3A2C1E),
                artSurfaceBottom: Color(hex: 0x241A12),
                artBackplateOpacity: 0.10,
                artGlareOpacity: 0.005,
                artGlareWidth: 0.18,
                shimmerAllowed: true,
                shimmerOpacity: 0,
                shimmerDuration: 6.0,
                shimmerZone: .perimeter,
                pulseAllowed: true,
                stampSymbol: "crown.fill",
                surfaceTop: Color(hex: 0x574024),
                surfaceBottom: Color(hex: 0x32271B),
                primaryText: Color.white.opacity(0.97),
                secondaryText: Color.white.opacity(0.76),
                foilTint: Color(hex: 0xFFE2A6),
                foilAccent: Color(hex: 0xFFC44D),
                holoOpacity: 0.043,
                holoGlareIntensity: 0.021,
                sparkleCount: 96,
                tiltStrength: 0.7
            )
        }
    }
}

struct TokenmonDexDetailCard: View {
    let entry: DexEntrySummary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.controlActiveState) private var controlActiveState
    @EnvironmentObject private var tuning: TokenmonDexCardTuningStore

    @State private var hoverLocation = CGPoint(x: 0.62, y: 0.20)
    @State private var cardSize = CGSize(width: tokenmonDexFrontCardWidth, height: tokenmonDexFrontCardMinHeight)
    @State private var isHovering = false

    private var style: TokenmonDexDetailCardStyle {
        TokenmonDexDetailCardStyle
            .make(for: entry.rarity)
            .applying(tuning: tuning)
    }

    var body: some View {
        let outerShell = RoundedRectangle(cornerRadius: 22, style: .continuous)
        let innerShell = RoundedRectangle(cornerRadius: 17, style: .continuous)

        ZStack {
            outerShell
                .fill(frameFill)

            outerShell
                .fill(frameAura)

            innerShell
                .fill(printSurface)
                .padding(7)

            innerShell
                .strokeBorder(innerBorder, lineWidth: 1.2)
                .padding(7)

            innerShell
                .overlay {
                    TokenmonDexShellFinishOverlay(
                        style: style,
                        selectionStrength: selectionEffectStrength,
                        hoverStrength: hoverEffectStrength,
                        cardSize: cardSize
                    )
                }
                .padding(7)
                .mask(
                    TokenmonDexCardPerimeterMask(
                        centerProtection: style.shellCenterProtection,
                        cardSize: cardSize
                    )
                )

            if premiumEffectsEligible {
                TokenmonDexCardMaterialUnderlay(
                    style: style,
                    rarity: entry.rarity,
                    selectionStrength: selectionEffectStrength,
                    cardSize: cardSize,
                    animateShimmer: shouldAnimateShimmer
                )
                .padding(7)
                .clipShape(innerShell)
            }

            TokenmonDexCardWatermark(
                assetKey: entry.assetKey,
                rarity: entry.rarity,
                isHovering: isHovering,
                opacityMultiplier: tuning.watermarkMultiplier
            )
            .padding(7)
            .clipShape(innerShell)

            VStack(alignment: .leading, spacing: 8) {
                TokenmonDexCardHeader(entry: entry, style: style)

                TokenmonDexCardArtFrame(
                    entry: entry,
                    style: style,
                    glareCenter: glareUnitPoint,
                    glareOpacity: currentGlareOpacity,
                    finishStrength: currentArtFinishStrength
                )

                TokenmonDexStatsSection(
                    stats: entry.stats,
                    status: entry.status,
                    rarity: entry.rarity,
                    style: style
                )

            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 12)

            if premiumEffectsEligible {
                TokenmonDexHolographicOverlay(
                    style: style,
                    rarity: entry.rarity,
                    hoverLocation: hoverLocation,
                    hoverStrength: hoverEffectStrength,
                    selectionStrength: selectionEffectStrength,
                    cardSize: cardSize,
                    sparkleOpacityMultiplier: tuning.sparkleOpacityMultiplier
                )
                .padding(7)
                .clipShape(innerShell)
            }
        }
        .overlay {
            outerShell
                .strokeBorder(
                    entry.rarity.tint.opacity(currentFrameGlowOpacity),
                    lineWidth: currentGlowLineWidth
                )
                .blur(radius: currentGlowBlurRadius)
        }
        .overlay {
            outerShell
                .strokeBorder(outerBorder, lineWidth: 1.4)
        }
        .overlay {
            if hoverEffectStrength > 0 {
                TokenmonDexEdgeCatchOverlay(
                    style: style,
                    rarity: entry.rarity,
                    hoverLocation: hoverLocation,
                    hoverStrength: hoverEffectStrength,
                    cardSize: cardSize
                )
                    .blendMode(.plusLighter)
                    .clipShape(outerShell)
            }
        }
        .shadow(
            color: entry.rarity.tint.opacity(currentPrimaryShadowOpacity),
            radius: currentPrimaryShadowRadius,
            y: currentPrimaryShadowYOffset
        )
        .shadow(
            color: Color.black.opacity(currentSecondaryShadowOpacity),
            radius: currentSecondaryShadowRadius,
            y: currentSecondaryShadowYOffset
        )
        .rotation3DEffect(
            .degrees(verticalTiltDegrees),
            axis: (x: 1, y: 0, z: 0),
            perspective: 0.6
        )
        .rotation3DEffect(
            .degrees(horizontalTiltDegrees),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.6
        )
        .offset(y: currentVerticalOffset)
        .contentShape(outerShell)
        .onContinuousHover(coordinateSpace: .local) { phase in
            guard motionEffectsAvailable else {
                isHovering = false
                hoverLocation = CGPoint(x: 0.62, y: 0.20)
                return
            }

            switch phase {
            case let .active(location):
                isHovering = true
                hoverLocation = normalizedHoverPoint(location)
            case .ended:
                isHovering = false
                hoverLocation = CGPoint(x: 0.62, y: 0.20)
            }
        }
        .animation(.easeOut(duration: 0.16), value: isHovering)
        .animation(.easeOut(duration: 0.16), value: hoverLocation)
        .animation(.easeOut(duration: 0.18), value: controlActiveState)
        .frame(width: tokenmonDexFrontCardWidth)
        .frame(minHeight: tokenmonDexFrontCardMinHeight, alignment: .top)
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        cardSize = proxy.size
                    }
                    .onChange(of: proxy.size) { _, newSize in
                        cardSize = newSize
                    }
            }
        }
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .environment(\.colorScheme, .light)
    }

    private var selectionEffectStrength: Double {
        guard premiumEffectsEligible else { return 0 }
        return controlActiveState == .inactive ? 0.45 : 1
    }

    private var premiumEffectsEligible: Bool {
        entry.status.allowsPremiumDexDetailCardEffects
    }

    private var motionEffectsAvailable: Bool {
        premiumEffectsEligible && reduceMotion == false && controlActiveState != .inactive
    }

    private var hoverEffectStrength: Double {
        motionEffectsAvailable && isHovering ? 1 : 0
    }

    private var shouldAnimateShimmer: Bool {
        motionEffectsAvailable && style.shimmerOpacity > 0
    }

    private var glareUnitPoint: UnitPoint {
        UnitPoint(x: hoverLocation.x, y: hoverLocation.y)
    }

    private var currentFrameGlowOpacity: Double {
        (style.shellEdgeGlow * selectionEffectStrength) + (style.hoverGlowBoost * hoverEffectStrength)
    }

    private var currentGlowLineWidth: CGFloat {
        CGFloat(2.8 + (selectionEffectStrength * 0.8) + (hoverEffectStrength * 1.0))
    }

    private var currentGlowBlurRadius: CGFloat {
        CGFloat(5.5 + (selectionEffectStrength * 1.4) + (hoverEffectStrength * 1.2))
    }

    private var currentGlareOpacity: Double {
        (style.glareOpacity * selectionEffectStrength) + (style.hoverGlareBoost * hoverEffectStrength)
    }

    private var currentArtFinishStrength: Double {
        selectionEffectStrength + (hoverEffectStrength * 0.10)
    }

    private var currentPrimaryShadowOpacity: Double {
        (style.shadowOpacity * selectionEffectStrength) + (style.hoverShadowBoost * hoverEffectStrength)
    }

    private var currentPrimaryShadowRadius: CGFloat {
        CGFloat(10 + (selectionEffectStrength * 3) + (hoverEffectStrength * 5))
    }

    private var currentPrimaryShadowYOffset: CGFloat {
        CGFloat(4 + (selectionEffectStrength * 2) + (hoverEffectStrength * 4))
    }

    private var currentSecondaryShadowOpacity: Double {
        0.12 + (selectionEffectStrength * 0.03) + (hoverEffectStrength * 0.05)
    }

    private var currentSecondaryShadowRadius: CGFloat {
        CGFloat(12 + (selectionEffectStrength * 2) + (hoverEffectStrength * 4))
    }

    private var currentSecondaryShadowYOffset: CGFloat {
        CGFloat(8 + (selectionEffectStrength * 2) + (hoverEffectStrength * 4))
    }

    private var currentVerticalOffset: CGFloat {
        CGFloat(-(selectionEffectStrength * 0.8) - (hoverEffectStrength * 1.4))
    }

    private var horizontalTiltDegrees: Double {
        guard hoverEffectStrength > 0 else { return 0 }
        return Double((hoverLocation.x - 0.5) * 14 * style.tiltStrength)
    }

    private var verticalTiltDegrees: Double {
        guard hoverEffectStrength > 0 else { return 0 }
        return Double((0.5 - hoverLocation.y) * 9 * style.tiltStrength)
    }

    private var frameFill: LinearGradient {
        LinearGradient(
            colors: [
                Color.black.opacity(0.72),
                entry.rarity.tint.opacity(0.28),
                entry.field.tint.opacity(0.16),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var frameAura: RadialGradient {
        let auraStrength = premiumEffectsEligible
        ? (0.55 + (selectionEffectStrength * 0.45) + (hoverEffectStrength * 0.18))
        : 0.0

        return RadialGradient(
            colors: [
                entry.rarity.tint.opacity(style.auraOpacity * auraStrength),
                .clear,
            ],
            center: .topLeading,
            startRadius: 0,
            endRadius: 180
        )
    }

    private var printSurface: LinearGradient {
        LinearGradient(
            colors: [
                style.surfaceTop,
                style.surfaceBottom,
                entry.rarity.tint.opacity(0.06 + (selectionEffectStrength * 0.02)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var innerBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.04),
                entry.rarity.tint.opacity(style.frameHighlight),
                Color.black.opacity(0.28),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var outerBorder: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(0.09),
                entry.rarity.tint.opacity(style.frameHighlight + (selectionEffectStrength * 0.04) + (hoverEffectStrength * 0.05)),
                entry.field.tint.opacity(0.12 + (selectionEffectStrength * 0.03)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func normalizedHoverPoint(_ location: CGPoint) -> CGPoint {
        let width = max(cardSize.width, 1)
        let height = max(cardSize.height, 1)
        let x = min(max(location.x / width, 0), 1)
        let y = min(max(location.y / height, 0), 1)
        return CGPoint(x: x, y: y)
    }
}

private struct TokenmonDexCardHeader: View {
    let entry: DexEntrySummary
    let style: TokenmonDexDetailCardStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: style.stampSymbol)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(entry.rarity.tint)
                    Text(entry.rarity.displayName.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(style.secondaryText)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                )

                Spacer()

                Text(String(format: "#%03d", entry.sortOrder))
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(style.secondaryText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                    )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(TokenmonDexPresentation.visibleSpeciesName(for: entry))
                    .font(.subheadline.weight(.black))
                    .lineLimit(1)
                    .foregroundStyle(style.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                TokenmonDexHeaderPillFlow(spacing: 6, rowSpacing: 5) {
                    TokenmonFieldBadge(field: entry.field, compact: true, iconOnly: true)

                    if entry.status == .captured {
                        TokenmonAffinityBadge(
                            level: max(1, entry.affinityLevel),
                            compact: true,
                            emphasized: entry.affinityLevel >= 2
                        )
                    }

                    if TokenmonDexPresentation.showsTraitTags(for: entry) {
                        ForEach(entry.stats.traits, id: \.self) { trait in
                            TokenmonDexHeaderTraitPill(trait: trait, style: style)
                        }
                    }
                }
                .frame(height: tokenmonDexHeaderPillFlowHeight, alignment: .topLeading)
                .clipped()
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                Color.black.opacity(0.12),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

private struct TokenmonDexHeaderTraitPill: View {
    let trait: String
    let style: TokenmonDexDetailCardStyle

    var body: some View {
        Text(trait)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .foregroundStyle(style.secondaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.05))
            )
    }
}

private struct TokenmonDexHeaderPillFlow: Layout {
    var spacing: CGFloat = 6
    var rowSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var measuredWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                measuredWidth = max(measuredWidth, x - spacing)
                y += rowHeight + rowSpacing
                x = 0
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        measuredWidth = max(measuredWidth, max(0, x - spacing))
        y += rowHeight
        return CGSize(width: measuredWidth, height: y)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + rowSpacing
                x = bounds.minX
                rowHeight = 0
            }

            subview.place(
                at: CGPoint(x: x, y: y),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

private struct TokenmonDexShellFinishOverlay: View {
    let style: TokenmonDexDetailCardStyle
    let selectionStrength: Double
    let hoverStrength: Double
    let cardSize: CGSize

    var body: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(style.frameGlossOpacity * 0.16 * selectionStrength),
                            style.foilTint.opacity(style.frameGlossOpacity * 0.07 * selectionStrength),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: max(cardSize.height * 0.08, 18))
                .frame(maxHeight: .infinity, alignment: .top)
                .blur(radius: 1.2)

            Ellipse()
                .fill(Color.white.opacity(style.frameGlossOpacity * 0.09 * selectionStrength))
                .frame(
                    width: max(cardSize.width * 0.18, 42),
                    height: max(cardSize.height * 0.09, 18)
                )
                .offset(
                    x: -cardSize.width * 0.34,
                    y: -cardSize.height * 0.34
                )
                .blur(radius: 7)

            Ellipse()
                .fill(style.foilAccent.opacity(style.frameGlossOpacity * (0.035 + (hoverStrength * 0.02))))
                .frame(
                    width: max(cardSize.width * 0.14, 32),
                    height: max(cardSize.height * 0.07, 16)
                )
                .offset(
                    x: cardSize.width * 0.33,
                    y: cardSize.height * 0.31
                )
                .blur(radius: 8)
        }
        .blendMode(.softLight)
        .allowsHitTesting(false)
    }
}

private struct TokenmonDexCardArtFrame: View {
    let entry: DexEntrySummary
    let style: TokenmonDexDetailCardStyle
    let glareCenter: UnitPoint
    let glareOpacity: Double
    let finishStrength: Double

    var body: some View {
        let artShell = RoundedRectangle(cornerRadius: 16, style: .continuous)

        ZStack {
            artShell
                .fill(
                    LinearGradient(
                        colors: [
                            style.artSurfaceTop,
                            style.artSurfaceBottom,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            artShell
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.01),
                            .clear,
                            Color.black.opacity(0.04),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            entry.field.tint.opacity(style.artBackplateOpacity),
                            entry.rarity.tint.opacity(style.artBackplateOpacity * 0.35),
                            .clear,
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 84
                    )
                )
                .frame(width: 146, height: 116)
                .blur(radius: 10)

            TokenmonDexHeroArt(
                status: entry.status,
                revealStage: TokenmonDexPresentation.revealStage(for: entry),
                field: entry.field,
                rarity: entry.rarity,
                assetKey: entry.assetKey,
                cardSize: 178,
                spriteSize: 132,
                showsBackground: false,
                showsBorder: false
            )
            .padding(.top, 2)

            artShell
                .fill(
                    RadialGradient(
                        colors: [
                            .clear,
                            Color.black.opacity(0.08 + (finishStrength * 0.03)),
                        ],
                        center: .center,
                        startRadius: 42,
                        endRadius: 160
                    )
                )
                .blendMode(.multiply)

            artShell
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08),
                            entry.rarity.tint.opacity(0.18),
                            Color.black.opacity(0.20),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )

            if style.artGlareOpacity > 0 {
                artShell
                    .overlay {
                        Ellipse()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(glareOpacity * style.artGlareOpacity),
                                        style.foilTint.opacity(glareOpacity * style.artGlareOpacity * 0.32),
                                        .clear,
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(artShellWidth * style.artGlareWidth, 72),
                                height: 18
                            )
                            .rotationEffect(.degrees(-18))
                            .offset(
                                x: CGFloat((glareCenter.x - 0.5) * 24),
                                y: CGFloat((glareCenter.y - 0.5) * 10) - 82
                            )
                            .blur(radius: 3)
                    }
                    .blendMode(.screen)
            }
        }
        .frame(height: 212)
        .clipShape(artShell)
    }

    private var artShellWidth: CGFloat {
        tokenmonDexFrontCardWidth - 24
    }
}

private struct TokenmonDexCardMaterialUnderlay: View {
    let style: TokenmonDexDetailCardStyle
    let rarity: RarityTier
    let selectionStrength: Double
    let cardSize: CGSize
    let animateShimmer: Bool

    var body: some View {
        ZStack {
            surfaceLightField
            distributedFoilTexture
            raritySignatureField

            if style.shimmerAllowed && animateShimmer {
                TokenmonDexAnimatedFoilOverlay(
                    style: style,
                    rarity: rarity,
                    cardSize: cardSize
                )
            }
        }
        .blendMode(.screen)
        .mask(
            TokenmonDexCardPerimeterMask(
                centerProtection: style.shellCenterProtection,
                cardSize: cardSize
            )
        )
        .allowsHitTesting(false)
    }

    private var surfaceLightField: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.08 * selectionStrength),
                            style.foilTint.opacity(0.04 * selectionStrength),
                            .clear,
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: max(cardSize.height * 0.17, 36))
                .frame(maxHeight: .infinity, alignment: .top)

            Ellipse()
                .fill(style.foilTint.opacity(0.045 * selectionStrength))
                .frame(
                    width: max(cardSize.width * 0.32, 74),
                    height: max(cardSize.height * 0.18, 38)
                )
                .offset(x: -cardSize.width * 0.30, y: -cardSize.height * 0.28)
                .blur(radius: 14)

            Ellipse()
                .fill(style.foilAccent.opacity(0.04 * selectionStrength))
                .frame(
                    width: max(cardSize.width * 0.26, 62),
                    height: max(cardSize.height * 0.14, 28)
                )
                .offset(x: cardSize.width * 0.31, y: cardSize.height * 0.30)
                .blur(radius: 16)
        }
    }

    private var distributedFoilTexture: some View {
        ZStack {
            ForEach(textureStripeSet, id: \.offsetX) { stripe in
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                stripe.tint.opacity(stripe.opacity * selectionStrength),
                                stripe.accent.opacity(stripe.opacity * selectionStrength),
                                Color.white.opacity(stripe.opacity * 0.22 * selectionStrength),
                                .clear,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: max(cardSize.width * stripe.widthFactor, 26))
                    .rotationEffect(.degrees(stripe.angle))
                    .offset(
                        x: cardSize.width * stripe.offsetX,
                        y: cardSize.height * stripe.offsetY
                    )
                    .blur(radius: stripe.blur)
            }
        }
    }

    private var raritySignatureField: some View {
        ZStack {
            edgeRim
            switch rarity {
            case .common:
                EmptyView()
            case .uncommon:
                edgeCornerCatch(color: style.foilTint, x: -0.22, y: -0.22, width: 0.56, height: 0.28, opacity: 0.10)
            case .rare:
                edgeCornerCatch(color: style.foilTint, x: -0.20, y: -0.20, width: 0.58, height: 0.30, opacity: 0.12)
                edgeCornerCatch(color: style.foilAccent, x: 0.24, y: 0.24, width: 0.44, height: 0.24, opacity: 0.08)
            case .epic:
                edgeCornerCatch(color: style.foilTint, x: -0.22, y: -0.24, width: 0.62, height: 0.34, opacity: 0.16)
                edgeCornerCatch(color: style.foilAccent, x: 0.28, y: 0.20, width: 0.48, height: 0.28, opacity: 0.12)
            case .legendary:
                edgeCornerCatch(color: style.foilTint, x: -0.24, y: -0.24, width: 0.66, height: 0.36, opacity: 0.22)
                edgeCornerCatch(color: style.foilAccent, x: 0.30, y: -0.10, width: 0.52, height: 0.30, opacity: 0.18)
                edgeCornerCatch(color: Color.white, x: 0.18, y: 0.28, width: 0.40, height: 0.22, opacity: 0.10)
            }
        }
    }

    private var edgeRim: some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    colors: rimColors,
                    center: .center
                ),
                lineWidth: rimLineWidth
            )
            .blur(radius: rarity == .legendary ? 1.4 : 0.9)
    }

    private var rimColors: [Color] {
        switch rarity {
        case .common:
            return [
                Color.white.opacity(0.05 * selectionStrength),
                style.foilTint.opacity(0.04 * selectionStrength),
                Color.white.opacity(0.05 * selectionStrength),
            ]
        case .uncommon:
            return [
                Color.white.opacity(0.06 * selectionStrength),
                style.foilTint.opacity(0.08 * selectionStrength),
                style.foilAccent.opacity(0.06 * selectionStrength),
                Color.white.opacity(0.06 * selectionStrength),
            ]
        case .rare:
            return [
                Color.white.opacity(0.06 * selectionStrength),
                style.foilTint.opacity(0.12 * selectionStrength),
                style.foilAccent.opacity(0.14 * selectionStrength),
                Color.white.opacity(0.06 * selectionStrength),
            ]
        case .epic:
            return [
                Color.white.opacity(0.08 * selectionStrength),
                style.foilTint.opacity(0.16 * selectionStrength),
                style.foilAccent.opacity(0.18 * selectionStrength),
                Color.white.opacity(0.08 * selectionStrength),
            ]
        case .legendary:
            return [
                Color.white.opacity(0.10 * selectionStrength),
                style.foilTint.opacity(0.24 * selectionStrength),
                style.foilAccent.opacity(0.28 * selectionStrength),
                Color.white.opacity(0.10 * selectionStrength),
            ]
        }
    }

    private var rimLineWidth: CGFloat {
        switch rarity {
        case .common: 1.1
        case .uncommon: 1.2
        case .rare: 1.5
        case .epic: 1.8
        case .legendary: 2.2
        }
    }

    private var textureStripeSet: [TokenmonDexFoilStripe] {
        let base: [TokenmonDexFoilStripe] = [
            .init(widthFactor: 0.12, angle: -24, offsetX: -0.42, offsetY: -0.24, opacity: 0.04, blur: 1.8, tint: style.foilTint, accent: style.foilAccent),
            .init(widthFactor: 0.10, angle: 22, offsetX: 0.40, offsetY: 0.24, opacity: 0.035, blur: 1.6, tint: style.foilAccent, accent: Color.white),
        ]

        switch rarity {
        case .common:
            return []
        case .uncommon:
            return base
        case .rare:
            return base + [
                .init(widthFactor: 0.10, angle: 30, offsetX: 0.34, offsetY: -0.20, opacity: 0.05, blur: 1.6, tint: style.foilTint, accent: style.foilAccent),
            ]
        case .epic:
            return base + [
                .init(widthFactor: 0.12, angle: 28, offsetX: 0.34, offsetY: -0.18, opacity: 0.07, blur: 1.7, tint: Color(hex: 0x93F5FF), accent: Color.white),
                .init(widthFactor: 0.10, angle: -28, offsetX: -0.32, offsetY: 0.24, opacity: 0.06, blur: 1.7, tint: style.foilAccent, accent: style.foilTint),
            ]
        case .legendary:
            return base + [
                .init(widthFactor: 0.14, angle: 28, offsetX: 0.34, offsetY: -0.18, opacity: 0.10, blur: 1.8, tint: Color.white, accent: style.foilTint),
                .init(widthFactor: 0.11, angle: -30, offsetX: -0.34, offsetY: 0.24, opacity: 0.08, blur: 1.8, tint: style.foilAccent, accent: Color.white),
                .init(widthFactor: 0.09, angle: 18, offsetX: 0.02, offsetY: -0.34, opacity: 0.06, blur: 1.4, tint: style.foilTint, accent: style.foilAccent),
            ]
        }
    }

    private func edgeCornerCatch(color: Color, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, opacity: Double) -> some View {
        Ellipse()
            .fill(color.opacity(opacity * selectionStrength))
            .frame(
                width: max(cardSize.width * width, 64),
                height: max(cardSize.height * height, 34)
            )
            .blur(radius: 16)
            .offset(
                x: cardSize.width * x,
                y: cardSize.height * y
            )
    }
}

private struct TokenmonDexCardPerimeterMask: View {
    let centerProtection: Double
    let cardSize: CGSize

    var body: some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .fill(Color.white.opacity(centerFillOpacity))
            .overlay {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.50), lineWidth: perimeterStrokeWidth)
                    .blur(radius: 2.8)
            }
            .overlay(alignment: .topLeading) {
                Ellipse()
                    .fill(Color.white.opacity(0.42))
                    .frame(
                        width: max(cardSize.width * 0.16, 36),
                        height: max(cardSize.height * 0.08, 18)
                    )
                    .offset(x: 18, y: 6)
                    .blur(radius: 6)
            }
            .overlay(alignment: .topTrailing) {
                Ellipse()
                    .fill(Color.white.opacity(0.34))
                    .frame(
                        width: max(cardSize.width * 0.12, 28),
                        height: max(cardSize.height * 0.07, 16)
                    )
                    .offset(x: -14, y: 8)
                    .blur(radius: 6)
            }
            .overlay(alignment: .bottomLeading) {
                Ellipse()
                    .fill(Color.white.opacity(0.24))
                    .frame(
                        width: max(cardSize.width * 0.12, 28),
                        height: max(cardSize.height * 0.07, 16)
                    )
                    .offset(x: 14, y: -10)
                    .blur(radius: 7)
            }
            .overlay(alignment: .bottomTrailing) {
                Ellipse()
                    .fill(Color.white.opacity(0.30))
                    .frame(
                        width: max(cardSize.width * 0.15, 34),
                        height: max(cardSize.height * 0.08, 18)
                    )
                    .offset(x: -18, y: -8)
                    .blur(radius: 7)
            }
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }

    private var centerFillOpacity: Double {
        max(0.0015, 0.010 - (centerProtection * 0.18))
    }

    private var perimeterStrokeWidth: CGFloat {
        max(min(min(cardSize.width, cardSize.height) * 0.04, 8), 5)
    }
}

private struct TokenmonDexEdgeCatchOverlay: View {
    let style: TokenmonDexDetailCardStyle
    let rarity: RarityTier
    let hoverLocation: CGPoint
    let hoverStrength: Double
    let cardSize: CGSize

    var body: some View {
        ZStack {
            edgeBeam(
                angle: -18,
                widthFactor: rarity == .legendary ? 0.26 : 0.20,
                x: (hoverLocation.x - 0.5) * 0.42,
                y: -0.30 + ((hoverLocation.y - 0.5) * 0.08),
                tint: Color.white,
                accent: style.foilTint,
                opacity: style.hoverEdgeSweepOpacity * 0.95
            )

            edgeBeam(
                angle: 24,
                widthFactor: rarity == .legendary ? 0.18 : 0.14,
                x: 0.34 + ((hoverLocation.x - 0.5) * 0.10),
                y: 0.26 + ((hoverLocation.y - 0.5) * 0.10),
                tint: style.foilAccent,
                accent: Color.white,
                opacity: style.hoverEdgeSweepOpacity * 0.58
            )
        }
        .opacity(hoverStrength)
        .mask(
            TokenmonDexCardPerimeterMask(centerProtection: 0.05, cardSize: cardSize)
        )
        .allowsHitTesting(false)
    }

    private func edgeBeam(
        angle: Double,
        widthFactor: CGFloat,
        x: CGFloat,
        y: CGFloat,
        tint: Color,
        accent: Color,
        opacity: Double
    ) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        tint.opacity(opacity * 0.58),
                        accent.opacity(opacity),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: max(cardSize.width * widthFactor, 34))
            .rotationEffect(.degrees(angle))
            .offset(
                x: cardSize.width * x,
                y: cardSize.height * y
            )
            .blur(radius: 2.6)
    }
}

private struct TokenmonDexAnimatedFoilOverlay: View {
    let style: TokenmonDexDetailCardStyle
    let rarity: RarityTier
    let cardSize: CGSize

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: false)) { context in
            let progress = shimmerProgress(at: context.date)
            let pulse = pulseProgress(at: context.date)

            ZStack {
                if style.shimmerZone == .perimeter, style.pulseAllowed {
                    pulseRing(progress: pulse)
                }

                if style.shimmerZone == .perimeter {
                    edgeSweep(
                        progress: progress,
                        widthFactor: rarity == .legendary ? 0.16 : (rarity == .epic ? 0.14 : 0.10),
                        verticalBias: -0.36,
                        opacity: style.shimmerOpacity
                    )

                    edgeSweep(
                        progress: (progress + 0.42).truncatingRemainder(dividingBy: 1),
                        widthFactor: rarity == .legendary ? 0.12 : 0.10,
                        verticalBias: 0.34,
                        opacity: style.shimmerOpacity * 0.58
                    )

                    if rarity == .legendary {
                        edgeSweep(
                            progress: (progress + 0.68).truncatingRemainder(dividingBy: 1),
                            widthFactor: 0.08,
                            verticalBias: -0.26,
                            opacity: style.shimmerOpacity * 0.36
                        )
                    }
                }
            }
            .blur(radius: rarity == .legendary ? 3.4 : (rarity == .epic ? 2.8 : 2.2))
        }
        .blendMode(.plusLighter)
        .mask(
            TokenmonDexCardPerimeterMask(centerProtection: 0.05, cardSize: cardSize)
        )
        .allowsHitTesting(false)
    }

    private func shimmerProgress(at date: Date) -> Double {
        let cycle = date.timeIntervalSinceReferenceDate / max(style.shimmerDuration, 1)
        return cycle.truncatingRemainder(dividingBy: 1)
    }

    private func pulseProgress(at date: Date) -> Double {
        let cycle = date.timeIntervalSinceReferenceDate / max(style.shimmerDuration * 0.82, 1)
        return (sin(cycle * .pi * 2) + 1) / 2
    }

    private func pulseRing(progress: Double) -> some View {
        RoundedRectangle(cornerRadius: 17, style: .continuous)
            .strokeBorder(
                AngularGradient(
                    colors: [
                        Color.white.opacity(style.shimmerOpacity * 0.10),
                        style.foilTint.opacity(style.shimmerOpacity * (0.20 + (progress * 0.14))),
                        style.foilAccent.opacity(style.shimmerOpacity * (0.34 + (progress * 0.18))),
                        Color.white.opacity(style.shimmerOpacity * 0.10),
                    ],
                    center: .center
                ),
                lineWidth: 1.0 + (progress * 0.8)
            )
            .blur(radius: 3 + (progress * 2.0))
            .opacity(0.28 + (progress * 0.18))
    }

    private func edgeSweep(progress: Double, widthFactor: CGFloat, verticalBias: CGFloat, opacity: Double) -> some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        .clear,
                        style.foilTint.opacity(opacity * 0.34),
                        style.foilAccent.opacity(opacity * 0.68),
                        Color.white.opacity(opacity * 0.22),
                        .clear,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: max(cardSize.width * widthFactor, 56))
            .rotationEffect(.degrees(-22))
            .offset(
                x: CGFloat(progress - 0.5) * max(cardSize.width * 1.35, 180),
                y: cardSize.height * verticalBias
            )
    }
}

private struct TokenmonDexCardWatermark: View {
    let assetKey: String
    let rarity: RarityTier
    let isHovering: Bool
    var opacityMultiplier: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            if let nsImage = TokenmonSpeciesSpriteLoader.image(assetKey: assetKey, variant: .portrait64) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: geo.size.width * 1.6, height: geo.size.width * 1.6)
                    .rotationEffect(.degrees(-12))
                    .offset(x: geo.size.width * 0.07, y: -geo.size.height * 0.03)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                    .opacity((isHovering ? hoverOpacity : restOpacity) * opacityMultiplier)
                    .blendMode(.screen)
            }
        }
        .allowsHitTesting(false)
    }

    private var restOpacity: Double {
        switch rarity {
        case .common: 0.042
        case .uncommon: 0.054
        case .rare: 0.066
        case .epic: 0.078
        case .legendary: 0.09
        }
    }

    private var hoverOpacity: Double {
        switch rarity {
        case .common: 0.06
        case .uncommon: 0.078
        case .rare: 0.096
        case .epic: 0.108
        case .legendary: 0.132
        }
    }
}

private struct TokenmonDexHolographicOverlay: View {
    let style: TokenmonDexDetailCardStyle
    let rarity: RarityTier
    let hoverLocation: CGPoint
    let hoverStrength: Double
    let selectionStrength: Double
    let cardSize: CGSize
    var sparkleOpacityMultiplier: Double = 1.0

    var body: some View {
        ZStack {
            rainbowLayer
            glareLayer
            if style.sparkleCount > 0 {
                sparkleLayer
            }
        }
        .allowsHitTesting(false)
    }

    private var rainbowLayer: some View {
        let effectStrength = selectionStrength * 0.4 + hoverStrength * 0.6
        let centerX = 0.4 + (hoverLocation.x - 0.5) * 0.3
        let centerY = 0.4 + (hoverLocation.y - 0.5) * 0.3
        let startAngle = (hoverLocation.x - 0.5) * 180 + (hoverLocation.y - 0.5) * 90

        return AngularGradient(
            colors: [
                Color(hex: 0xFF3C3C),
                Color(hex: 0xFF8A3C),
                Color(hex: 0xFFD53C),
                Color(hex: 0x3CFF6E),
                Color(hex: 0x3CD4FF),
                Color(hex: 0x3C6EFF),
                Color(hex: 0x8A3CFF),
                Color(hex: 0xFF3CAA),
                Color(hex: 0xFF3C3C),
            ],
            center: UnitPoint(x: centerX, y: centerY),
            startAngle: .degrees(startAngle),
            endAngle: .degrees(startAngle + 360)
        )
        .blur(radius: 18)
        .saturation(1.2)
        .blendMode(.overlay)
        .opacity(style.holoOpacity * effectStrength)
    }

    private var glareLayer: some View {
        let intensity = style.holoGlareIntensity * (selectionStrength * 0.3 + hoverStrength * 0.7)

        return RadialGradient(
            colors: [
                Color.white.opacity(intensity * 0.5),
                Color.white.opacity(intensity * 0.08),
                .clear,
            ],
            center: UnitPoint(x: hoverLocation.x, y: hoverLocation.y),
            startRadius: 0,
            endRadius: max(cardSize.width, cardSize.height) * 0.5
        )
        .blendMode(.plusLighter)
    }

    private var sparkleLayer: some View {
        let effectStrength = selectionStrength * 0.25 + hoverStrength * 0.75
        let hoverPt = CGPoint(
            x: hoverLocation.x * cardSize.width,
            y: hoverLocation.y * cardSize.height
        )
        let opacityMul = sparkleOpacityMultiplier

        return Canvas { context, size in
            guard effectStrength > 0.05 else { return }
            let maxDist = hypot(size.width, size.height) * 0.55

            for i in 0..<style.sparkleCount {
                let fx = Self.fract(sin(Double(i) * 12.9898 + 1.0) * 43758.5453)
                let fy = Self.fract(sin(Double(i) * 78.233 + 2.0) * 43758.5453)
                let seedSize = 0.8 + Self.fract(sin(Double(i) * 93.9898) * 43758.5453) * 1.8
                let pos = CGPoint(x: fx * size.width, y: fy * size.height)
                let dist = hypot(pos.x - hoverPt.x, pos.y - hoverPt.y)
                let proximity = max(0, 1 - dist / maxDist)
                let brightness = proximity * proximity * effectStrength
                guard brightness > 0.05 else { continue }

                Self.drawSparkle(
                    context: &context,
                    at: pos,
                    brightness: brightness,
                    seedSize: seedSize,
                    rarity: rarity,
                    opacityMultiplier: opacityMul
                )
            }
        }
        .blendMode(.plusLighter)
    }

    private static func drawSparkle(
        context: inout GraphicsContext,
        at pos: CGPoint,
        brightness: Double,
        seedSize: Double,
        rarity: RarityTier,
        opacityMultiplier: Double
    ) {
        let white = Color.white
        // 0.15 bakes the tuned sparkle opacity baseline; runtime tuning multiplies further.
        let m = opacityMultiplier * 0.15

        switch rarity {
        case .common:
            break

        case .uncommon:
            let r = seedSize * brightness * 1.8
            let rect = CGRect(x: pos.x - r, y: pos.y - r, width: r * 2, height: r * 2)
            context.opacity = brightness * 0.85 * m
            context.fill(Circle().path(in: rect), with: .color(white))

        case .rare:
            let ds = seedSize * brightness * 3.5
            var diamond = Path()
            diamond.move(to: CGPoint(x: pos.x, y: pos.y - ds))
            diamond.addLine(to: CGPoint(x: pos.x + ds * 0.6, y: pos.y))
            diamond.addLine(to: CGPoint(x: pos.x, y: pos.y + ds))
            diamond.addLine(to: CGPoint(x: pos.x - ds * 0.6, y: pos.y))
            diamond.closeSubpath()
            context.opacity = brightness * 0.85 * m
            context.fill(diamond, with: .color(white))
            if brightness > 0.25 {
                let cr = seedSize * brightness * 0.8
                let coreRect = CGRect(x: pos.x - cr, y: pos.y - cr, width: cr * 2, height: cr * 2)
                context.opacity = brightness * 0.5 * m
                context.fill(Circle().path(in: coreRect), with: .color(white))
            }

        case .epic:
            let cs = seedSize * brightness * 5
            let lw = max(0.5, seedSize * brightness * 0.5)
            context.opacity = brightness * 0.7 * m
            var crossH = Path()
            crossH.move(to: CGPoint(x: pos.x - cs, y: pos.y))
            crossH.addLine(to: CGPoint(x: pos.x + cs, y: pos.y))
            context.stroke(crossH, with: .color(white), lineWidth: lw)
            var crossV = Path()
            crossV.move(to: CGPoint(x: pos.x, y: pos.y - cs))
            crossV.addLine(to: CGPoint(x: pos.x, y: pos.y + cs))
            context.stroke(crossV, with: .color(white), lineWidth: lw)
            let cs2 = cs * 0.5
            context.opacity = brightness * 0.35 * m
            var diagA = Path()
            diagA.move(to: CGPoint(x: pos.x - cs2, y: pos.y - cs2))
            diagA.addLine(to: CGPoint(x: pos.x + cs2, y: pos.y + cs2))
            context.stroke(diagA, with: .color(white), lineWidth: lw * 0.7)
            var diagB = Path()
            diagB.move(to: CGPoint(x: pos.x + cs2, y: pos.y - cs2))
            diagB.addLine(to: CGPoint(x: pos.x - cs2, y: pos.y + cs2))
            context.stroke(diagB, with: .color(white), lineWidth: lw * 0.7)
            let cr = seedSize * brightness * 1.0
            let coreRect = CGRect(x: pos.x - cr, y: pos.y - cr, width: cr * 2, height: cr * 2)
            context.opacity = brightness * 0.9 * m
            context.fill(Circle().path(in: coreRect), with: .color(white))

        case .legendary:
            let rays = 6
            let rl = seedSize * brightness * 7
            let lw = max(0.4, seedSize * brightness * 0.4)
            let seedOffset = seedSize * 0.5
            context.opacity = brightness * 0.6 * m
            for j in 0..<rays {
                let ang = (Double.pi * 2 / Double(rays)) * Double(j) + seedOffset
                var ray = Path()
                ray.move(to: pos)
                ray.addLine(to: CGPoint(
                    x: pos.x + cos(ang) * rl,
                    y: pos.y + sin(ang) * rl
                ))
                context.stroke(ray, with: .color(white), lineWidth: lw)
            }
            context.opacity = brightness * 0.3 * m
            for j in 0..<rays {
                let ang = (Double.pi * 2 / Double(rays)) * Double(j) + Double.pi / Double(rays) + seedOffset
                var ray = Path()
                ray.move(to: pos)
                ray.addLine(to: CGPoint(
                    x: pos.x + cos(ang) * rl * 0.45,
                    y: pos.y + sin(ang) * rl * 0.45
                ))
                context.stroke(ray, with: .color(white), lineWidth: lw * 0.5)
            }
            let gr = seedSize * brightness * 2.5
            let glowRect = CGRect(x: pos.x - gr, y: pos.y - gr, width: gr * 2, height: gr * 2)
            context.opacity = brightness * 0.5 * m
            context.fill(Circle().path(in: glowRect), with: .color(white))
            let cr = seedSize * brightness * 1.0
            let coreRect = CGRect(x: pos.x - cr, y: pos.y - cr, width: cr * 2, height: cr * 2)
            context.opacity = brightness * 0.95 * m
            context.fill(Circle().path(in: coreRect), with: .color(white))
        }
    }

    private static func fract(_ x: Double) -> Double {
        x - floor(x)
    }
}

private struct TokenmonDexFoilStripe {
    let widthFactor: CGFloat
    let angle: Double
    let offsetX: CGFloat
    let offsetY: CGFloat
    let opacity: Double
    let blur: CGFloat
    let tint: Color
    let accent: Color
}

struct TokenmonDexProgressPanel: View {
    let entry: DexEntrySummary

    var body: some View {
        TokenmonDexSupportingPanel(
            title: TokenmonDexPresentation.progressPanelTitle(for: entry),
            accent: entry.rarity.tint
        ) {
            switch entry.status {
            case .captured, .seenUncaptured:
                ForEach(TokenmonDexPresentation.metricRows(for: entry), id: \.title) { row in
                    TokenmonMetricRow(title: row.title, value: row.value)
                }

                if let footnote = TokenmonDexPresentation.progressPanelFootnote(for: entry) {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            case .unknown:
                Text(TokenmonDexPresentation.hiddenHint(for: entry))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct TokenmonDexFieldNotesPanel: View {
    let entry: DexEntrySummary

    var body: some View {
        TokenmonDexSupportingPanel(
            title: TokenmonL10n.string("dex.field_notes.title"),
            accent: entry.field.tint,
            variant: .reverse
        ) {
            if TokenmonDexPresentation.isFlavorTextUnlocked(for: entry),
               let flavorText = entry.flavorText,
               flavorText.isEmpty == false {
                Text(flavorText)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let placeholder = TokenmonDexPresentation.fieldNotesPlaceholder(for: entry) {
                Text(placeholder)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(TokenmonL10n.string("dex.field_notes.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct TokenmonDexSupportingPanel<Content: View>: View {
    enum Variant {
        case standard
        case reverse
    }

    let title: String
    let accent: Color
    var variant: Variant = .standard
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(backgroundShape.fill(backgroundFill))
        .overlay(backgroundShape.stroke(borderColor, lineWidth: 1))
        .frame(width: tokenmonDexSupportingWidth)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var backgroundShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
    }

    private var backgroundFill: LinearGradient {
        switch variant {
        case .standard:
            return LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor),
                    accent.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .reverse:
            return LinearGradient(
                colors: [
                    accent.opacity(0.07),
                    Color(nsColor: .controlBackgroundColor),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var borderColor: Color {
        accent.opacity(variant == .reverse ? 0.18 : 0.12)
    }
}
