import SwiftUI
import TokenmonDomain
import TokenmonGameEngine
import TokenmonPersistence
import TokenmonProviders

/// Now tab content: status summary, step progress, latest encounter,
/// today/cumulative counters, provider indicators.
struct TokenmonNowStatusSummary: Equatable {
    let fieldTitle: String
    let fieldSystemImage: String
    let phaseTitle: String
    let phaseSystemImage: String
    let headline: String?
    let supportingLine: String?

    init(presentation: TokenmonMenuPresentation, sceneContext: TokenmonSceneContext) {
        fieldTitle = sceneContext.fieldKind.heroFieldTitle
        fieldSystemImage = sceneContext.fieldKind.heroFieldSystemImage

        switch sceneContext.sceneState {
        case .resolveSuccess:
            phaseTitle = TokenmonL10n.string("outcome.captured")
            phaseSystemImage = "checkmark.seal.fill"
            headline = nil
            supportingLine = nil
        case .resolveEscape:
            phaseTitle = TokenmonL10n.string("outcome.escaped")
            phaseSystemImage = "xmark.seal.fill"
            headline = nil
            supportingLine = nil
        case .idle where presentation.headline == TokenmonL10n.string("menu.headline.waiting"):
            phaseTitle = TokenmonL10n.string("now.phase.waiting")
            phaseSystemImage = "pause.circle.fill"
            headline = presentation.headline
            supportingLine = presentation.detail
        case .alert, .spawn:
            phaseTitle = TokenmonL10n.string("now.phase.encounter")
            phaseSystemImage = "sparkles"
            headline = presentation.headline
            supportingLine = presentation.detail
        case .loading:
            phaseTitle = TokenmonL10n.string("menu.headline.loading")
            phaseSystemImage = "hourglass"
            headline = presentation.headline
            supportingLine = presentation.detail
        default:
            phaseTitle = TokenmonL10n.string("now.phase.exploring")
            phaseSystemImage = "figure.walk"
            headline = presentation.headline
            supportingLine = presentation.detail
        }
    }
}

struct TokenmonNowTab: View {
    @ObservedObject var model: TokenmonMenuModel
    let onOpenProviderSettings: () -> Void

    private static let explorationConfig = ExplorationAccumulatorConfig()
    private static let progressSegmentCount = 10

    private var currentTokensInEncounter: Int64 {
        model.summary?.tokensSinceLastEncounter ?? 0
    }

    private var totalTokensPerEncounter: Int64 {
        model.summary?.nextEncounterThresholdTokens ?? Self.explorationConfig.minimumEncounterThresholdTokens
    }

    private var heroCompanionAssetKeys: [String] {
        switch model.runtimeSnapshot.ambientCompanionRoster {
        case .partyOverride(let assetKeys):
            return assetKeys
        case .byField(let map):
            let field = model.popoverSceneContext.fieldKind.heroFieldType
            return map[field] ?? []
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if model.shouldShowUsageAnalyticsPrompt {
                usageAnalyticsPromptCard
            }

            TokenmonNowCampHeroCard(
                model: model,
                sceneContext: model.popoverSceneContext,
                fallbackCompanionAssetKeys: heroCompanionAssetKeys
            )

            TokenProgressBar(
                currentTokens: currentTokensInEncounter,
                totalTokens: totalTokensPerEncounter,
                segmentCount: Self.progressSegmentCount
            )

            latestEncounterCard

            statsBlock

            providerActionChips

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(width: 300, alignment: .topLeading)
    }

    private var usageAnalyticsPromptCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TokenmonL10n.string("analytics.prompt.title"))
                .font(.headline)

            Text(TokenmonL10n.string("analytics.prompt.subtitle"))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button(TokenmonL10n.string("analytics.prompt.enable")) {
                    model.updateUsageAnalyticsEnabled(true)
                }
                .tokenmonAdaptiveButtonStyle()

                Button(TokenmonL10n.string("analytics.prompt.not_now")) {
                    model.dismissUsageAnalyticsPrompt()
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    @ViewBuilder
    private var latestEncounterCard: some View {
        if let encounter = model.latestEncounter {
            HStack(alignment: .center, spacing: 14) {
                TokenmonDexSpritePreview(
                    status: encounter.outcome == .captured ? .captured : .seenUncaptured,
                    revealStage: TokenmonDexPresentation.revealStage(for: encounter),
                    field: encounter.field,
                    rarity: encounter.rarity,
                    assetKey: encounter.assetKey,
                    cardSize: 80,
                    spriteSize: 56
                )
                VStack(alignment: .leading, spacing: 4) {
                    Text(TokenmonDexPresentation.visibleSpeciesName(for: encounter, style: .sentence))
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    metaRow(label: TokenmonL10n.string("now.meta.rarity"), value: encounter.rarity.displayName)
                    metaRow(label: TokenmonL10n.string("now.meta.field"), value: encounter.field.displayName)
                    metaRow(label: TokenmonL10n.string("now.meta.result"), value: encounter.outcome.displayName)
                    if encounter.outcome == .captured {
                        latestAffinityRow(for: encounter)
                    }
                }
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
        } else {
            HStack {
                Text(TokenmonL10n.string("menu.latest.no_encounters"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
    }

    @ViewBuilder
    private func latestAffinityRow(for encounter: RecentEncounterSummary) -> some View {
        let level = TokenmonDexPresentation.affinityLevelNumber(for: encounter)
        HStack(spacing: 6) {
            Text(TokenmonL10n.string("now.meta.affinity"))
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)

            TokenmonAffinityBadge(
                level: level,
                compact: true,
                emphasized: level >= 2
            )

            Label {
                Text(TokenmonDexPresentation.affinityRaidBonusValueLabel(level: level))
                    .font(.caption2.monospacedDigit().weight(.bold))
            } icon: {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 8, weight: .black))
            }
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.10))
            )
            .help(TokenmonDexPresentation.affinityRaidBonusShortLabel(level: level))

            if let affinityLine = TokenmonDexPresentation.affinityResultLine(for: encounter) {
                Text(affinityLine)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
        }
    }

    @ViewBuilder
    private func metaRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
    }

    private var statsBlock: some View {
        VStack(spacing: 0) {
            statRow(
                label: TokenmonL10n.string("tokens.counter.today"),
                metrics: [
                    StatMetric(value: model.todayActivity?.encounterCount ?? 0, caption: TokenmonL10n.string("now.stats.encounters")),
                    StatMetric(value: model.todayActivity?.captureCount ?? 0, caption: TokenmonL10n.string("now.stats.captured")),
                ]
            )

            Divider()
                .padding(.horizontal, 12)

            statRow(
                label: TokenmonL10n.string("tokens.counter.all_time"),
                metrics: [
                    StatMetric(value: Int(model.summary?.totalEncounters ?? 0), caption: TokenmonL10n.string("now.stats.enc_short")),
                    StatMetric(value: Int(model.summary?.totalCaptures ?? 0), caption: TokenmonL10n.string("now.stats.cap_short")),
                    StatMetric(value: model.summary?.seenSpeciesCount ?? 0, caption: TokenmonL10n.string("now.stats.seen")),
                ]
            )
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private struct StatMetric {
        let value: Int
        let caption: String
    }

    @ViewBuilder
    private func statRow(label: String, metrics: [StatMetric]) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(label)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)

            HStack(spacing: 0) {
                ForEach(Array(metrics.enumerated()), id: \.offset) { _, metric in
                    VStack(spacing: 1) {
                        Text(TokenmonCompactCountFormatter.string(for: metric.value))
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text(metric.caption)
                            .font(.system(size: 8, weight: .semibold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var providerActionChips: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8),
                GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8),
            ],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(ProviderCode.allCases, id: \.self) { provider in
                let health = model.providerHealthSummaries.first { $0.provider == provider }
                let onboarding = model.onboardingStatuses.first { $0.provider == provider }
                TokenmonProviderStatusChip(
                    provider: provider,
                    healthSummary: health,
                    cliInstalled: onboarding?.cliInstalled,
                    onOpenSettings: onOpenProviderSettings
                )
            }
        }
    }

}

struct TokenmonNowFieldHeroCard: View {
    let sceneContext: TokenmonSceneContext
    let companionAssetKeys: [String]
    let backgroundDate: Date?
    let animates: Bool

    init(
        sceneContext: TokenmonSceneContext,
        companionAssetKeys: [String] = [],
        backgroundDate: Date? = nil,
        animates: Bool = true
    ) {
        self.sceneContext = sceneContext
        self.companionAssetKeys = companionAssetKeys
        self.backgroundDate = backgroundDate
        self.animates = animates
    }

    var body: some View {
        TokenmonPopoverHeroSceneCard(
            context: sceneContext,
            companionAssetKeys: companionAssetKeys,
            backgroundDate: backgroundDate,
            animates: animates
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        sceneContext.fieldKind.heroFieldTitle
    }
}

private struct TokenmonNowCampHeroCard: View {
    @ObservedObject var model: TokenmonMenuModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let sceneContext: TokenmonSceneContext
    let fallbackCompanionAssetKeys: [String]

    private var nowCamp: NowCampSummary? {
        model.nowCampSummary
    }

    private var lead: NowCampLeadSummary? {
        nowCamp?.lead
    }

    private var partyMembers: [PartyMemberSummary] {
        let runtimeParty = model.raidDashboard?.partyMembers ?? []
        return runtimeParty.isEmpty ? model.partyMembers : runtimeParty
    }

    private var supportMembers: [PartyMemberSummary] {
        if let supports = nowCamp?.supports, supports.isEmpty == false {
            return supports
        }
        guard let leadID = lead?.speciesID else {
            return Array(partyMembers.prefix(2))
        }
        return Array(partyMembers.filter { $0.speciesID != leadID }.prefix(2))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            TokenmonPopoverHeroSceneCard(
                context: sceneContext,
                companionAssetKeys: lead == nil ? fallbackCompanionAssetKeys : [],
                animates: !reduceMotion
            )

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    focusPill
                    Spacer(minLength: 8)
                    leadPicker
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom, spacing: 8) {
                    leadSprite
                    supportSprites
                    Spacer(minLength: 0)
                    actionStack
                }
            }
            .padding(10)
        }
        .frame(height: 124)
        .accessibilityElement(children: .contain)
    }

    private var focusPill: some View {
        HStack(spacing: 6) {
            NowCampEffectSpriteImage(scope: .common, variant: .resonanceOrb16)
                .frame(width: 14, height: 14)
            Image(systemName: "bolt.fill")
                .font(.system(size: 10, weight: .black))
            Text("\(nowCamp?.focusEnergy ?? 0)")
                .font(.caption.weight(.bold).monospacedDigit())
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.86))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.secondary.opacity(0.18), lineWidth: 0.8)
        )
        .help(TokenmonL10n.string("now.camp.focus.help"))
    }

    private var leadPicker: some View {
        Menu {
            ForEach(partyMembers, id: \.speciesID) { member in
                Button {
                    model.setNowCampLead(member.speciesID)
                } label: {
                    Label(
                        member.displayName,
                        systemImage: member.speciesID == lead?.speciesID ? "crown.fill" : "person.crop.circle"
                    )
                }
            }
        } label: {
            Label(
                lead?.displayName ?? TokenmonL10n.string("now.camp.lead.empty"),
                systemImage: lead == nil ? "crown" : "crown.fill"
            )
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.86))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: true, vertical: false)
        .disabled(partyMembers.isEmpty)
        .help(TokenmonL10n.string("now.camp.lead_picker.help"))
    }

    @ViewBuilder
    private var leadSprite: some View {
        if let lead {
            VStack(alignment: .leading, spacing: 3) {
                ZStack(alignment: .bottomTrailing) {
                    TokenmonDexSpritePreview(
                        status: .captured,
                        revealStage: .revealed,
                        field: lead.field,
                        rarity: lead.rarity,
                        assetKey: lead.assetKey,
                        cardSize: 58,
                        spriteSize: 42,
                        showsBackground: false,
                        showsBorder: false
                    )
                    NowCampEffectSpriteImage(scope: .field(lead.field), variant: .campProp32)
                        .frame(width: 20, height: 20)
                        .offset(x: 5, y: 5)
                }
                Text(trainingLine(for: lead))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .foregroundStyle(.primary)
                    .frame(width: 104, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "crown")
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 58, height: 58)
                    .foregroundStyle(.secondary)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
                    )
                Text(TokenmonL10n.string("now.camp.no_party"))
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
                    .frame(width: 108, alignment: .leading)
            }
        }
    }

    private var supportSprites: some View {
        HStack(spacing: -8) {
            ForEach(supportMembers, id: \.speciesID) { member in
                TokenmonDexSpritePreview(
                    status: .captured,
                    revealStage: .revealed,
                    field: member.field,
                    rarity: member.rarity,
                    assetKey: member.assetKey,
                    cardSize: 38,
                    spriteSize: 27,
                    showsBackground: false,
                    showsBorder: false
                )
                .help(member.displayName)
            }
        }
    }

    private var actionStack: some View {
        VStack(alignment: .trailing, spacing: 5) {
            Button {
                model.trainNowCampLead()
            } label: {
                Label(TokenmonL10n.string("now.camp.train"), systemImage: "figure.strengthtraining.traditional")
                    .labelStyle(.iconOnly)
            }
            .disabled(canTrain == false)
            .help(TokenmonL10n.string("now.camp.train.help"))

            Button {
                model.applyNowCampCareToLead()
            } label: {
                Label(TokenmonL10n.string("now.camp.care"), systemImage: "heart.fill")
                    .labelStyle(.iconOnly)
            }
            .disabled(canCare == false)
            .help(TokenmonL10n.string("now.camp.care.help"))
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
    }

    private var canTrain: Bool {
        guard let lead, let nowCamp else { return false }
        return nowCamp.focusEnergy >= 30
            && lead.training.trainingRank.rawValue < Int(lead.affinityLevel)
    }

    private var canCare: Bool {
        guard let lead, let nowCamp else { return false }
        return nowCamp.focusEnergy >= 10
            && lead.training.careCharge == false
            && lead.training.trainingRank.rawValue < Int(lead.affinityLevel)
    }

    private func trainingLine(for lead: NowCampLeadSummary) -> String {
        let rank = lead.training.trainingRank.romanNumeral
        let resonance = lead.training.trainingResonance
        return TokenmonL10n.format(
            "now.camp.training_line",
            rank,
            lead.trainingTrait.displayName,
            Int64(resonance)
        )
    }
}

private struct TokenmonProviderStatusChip: View {
    let provider: ProviderCode
    let healthSummary: ProviderHealthSummary?
    let cliInstalled: Bool?
    let onOpenSettings: () -> Void

    private struct Presentation {
        let tint: Color
        let accessibilityState: String
    }

    var body: some View {
        let presentation = presentationModel

        Button {
            onOpenSettings()
        } label: {
            HStack(spacing: 7) {
                Circle()
                    .fill(presentation.tint)
                    .frame(width: 8, height: 8)

                Text(provider.shortName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.95)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(presentation.tint.opacity(0.28), lineWidth: 0.8)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .help(chipTooltip)
        .accessibilityLabel("\(provider.shortName) \(presentation.accessibilityState)")
    }

    private var presentationModel: Presentation {
        if provider != .cursor, let installed = cliInstalled, !installed {
            return Presentation(tint: .secondary, accessibilityState: TokenmonL10n.string("provider.status.not_installed"))
        }

        guard let healthSummary else {
            return Presentation(tint: .secondary, accessibilityState: TokenmonL10n.string("provider.status.unavailable"))
        }

        switch healthSummary.healthState {
        case "active", "connected":
            return Presentation(tint: .green, accessibilityState: TokenmonL10n.string("provider.status.connected"))
        case "missing_configuration":
            return Presentation(tint: .orange, accessibilityState: TokenmonL10n.string("provider.status.needs_setup"))
        case "degraded", "unsupported":
            return Presentation(tint: .red, accessibilityState: TokenmonL10n.string("provider.status.needs_attention"))
        default:
            return Presentation(tint: .secondary, accessibilityState: healthSummary.healthState)
        }
    }

    private var chipTooltip: String {
        guard let healthSummary else {
            return TokenmonL10n.format("provider.status.help.unavailable", provider.shortName)
        }

        return TokenmonL10n.format("provider.status.help.open_settings", healthSummary.message)
    }
}

private struct TokenmonBrandLinkChip: View {
    @Environment(\.colorScheme) private var colorScheme
    let link: TokenmonBrandLink

    var body: some View {
        Link(destination: link.destination) {
            HStack(spacing: 6) {
                icon
                Text(TokenmonL10n.string(link.compactTitleKey))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(width: link.homeChipWidth, alignment: .leading)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.secondary.opacity(0.16), lineWidth: 0.8)
            )
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .help(link.displayValue)
        .accessibilityLabel(TokenmonL10n.string(link.titleKey))
    }

    @ViewBuilder
    private var icon: some View {
        if let brandMarkImage = link.brandMarkImage(forDarkAppearance: colorScheme == .dark) {
            Image(nsImage: brandMarkImage)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
        } else {
            Image(systemName: link.compactSymbolName)
                .font(.caption.weight(.semibold))
        }
    }
}

private extension ProviderCode {
    var shortName: String {
        switch self {
        case .claude:
            return "Claude"
        case .codex:
            return "Codex"
        case .gemini:
            return "Gemini"
        case .cursor:
            return "Cursor"
        }
    }
}

enum TokenmonCompactCountFormatter {
    static func string(for value: Int) -> String {
        string(for: Int64(value))
    }

    static func string(for value: Int64) -> String {
        let absoluteValue = abs(value)

        if absoluteValue < 1_000 {
            return "\(value)"
        }

        let (divisor, suffix): (Double, String) = switch absoluteValue {
        case 1_000_000_000...:
            (1_000_000_000, "B")
        case 1_000_000...:
            (1_000_000, "M")
        default:
            (1_000, "K")
        }

        let scaled = Double(value) / divisor
        let roundedValue: Double
        let precision: Int

        if abs(scaled) < 10 {
            roundedValue = (scaled * 10).rounded() / 10
            precision = roundedValue.rounded() == roundedValue ? 0 : 1
        } else {
            roundedValue = scaled.rounded()
            precision = 0
        }

        return "\(roundedValue.formatted(.number.precision(.fractionLength(precision))))\(suffix)"
    }
}
