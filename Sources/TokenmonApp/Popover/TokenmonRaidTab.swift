import SwiftUI
import TokenmonDomain
import TokenmonGameEngine
import TokenmonPersistence

struct TokenmonRaidTab: View {
    @ObservedObject var model: TokenmonMenuModel
    let contentWidth: CGFloat
    let onOpenRewardArchive: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlightedAttackID: Int64?
    @State private var animatedAttack: TokenmonRaidAnimatedAttack?

    private var dashboard: RaidDashboardSummary? {
        model.raidDashboard
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                if let dashboard, let raid = dashboard.currentRaid {
                    TokenmonRaidBattleStage(
                        raid: raid,
                        members: dashboard.partyMembers,
                        animation: animatedAttack,
                        reduceMotion: reduceMotion
                    )
                    raidHeader(raid)
                    partySection(dashboard.partyMembers, raid: raid)
                    recentAttackSection(raid.recentAttacks)
                    rewardArchiveSection(
                        dashboard.archiveEntries,
                        onOpenRewardArchive: onOpenRewardArchive
                    )
                } else {
                    emptyState
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)
            .frame(width: contentWidth, alignment: .topLeading)
        }
        .onAppear {
            guard let attack = dashboard?.currentRaid?.recentAttacks.first else { return }
            highlightedAttackID = attack.attackID
            animatedAttack = nil
        }
        .onChange(of: dashboard?.currentRaid?.recentAttacks.first?.attackID) { _, newValue in
            guard let newValue else { return }
            let latestAttack = dashboard?.currentRaid?.recentAttacks.first
            let damage = latestAttack?.totalDamage ?? 0
            let missCount = latestAttack?.missCount ?? 0
            let criticalCount = latestAttack?.criticalCount ?? 0
            if reduceMotion {
                highlightedAttackID = newValue
                animatedAttack = TokenmonRaidAnimatedAttack(
                    attackID: newValue,
                    startedAt: Date(),
                    totalDamage: damage,
                    missCount: missCount,
                    criticalCount: criticalCount
                )
            } else {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    highlightedAttackID = newValue
                }
                animatedAttack = TokenmonRaidAnimatedAttack(
                    attackID: newValue,
                    startedAt: Date(),
                    totalDamage: damage,
                    missCount: missCount,
                    criticalCount: criticalCount
                )
            }
        }
    }

    private func raidHeader(_ raid: RaidProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(raid.raidField.tint.opacity(0.12))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.70))
                    TokenmonRaidArtImage(artKey: raid.targetArtKey)
                        .padding(5)
                        .scaleEffect(highlightedAttackID == raid.recentAttacks.first?.attackID && !reduceMotion ? 1.06 : 1.0)
                }
                .frame(width: 64, height: 64)

                VStack(alignment: .leading, spacing: 5) {
                    Text(raid.title)
                        .font(.headline)
                        .lineLimit(2)
                    Text(raid.targetName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Label(
                        TokenmonL10n.format("raid.field.type_format", raid.raidField.displayName),
                        systemImage: raid.raidField.systemImage
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(raid.raidField.tint)
                    Label(statusText(for: raid), systemImage: statusIcon(for: raid.status))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTint(for: raid.status))
                }
            }

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text(TokenmonL10n.string("raid.hp"))
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(raid.currentHP) / \(raid.maxHP)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: max(0, Double(raid.currentHP)), total: Double(raid.maxHP))
                    .progressViewStyle(.linear)
                HStack {
                    Text(TokenmonL10n.format("raid.attacks.format", raid.totalAttacks))
                    Spacer()
                    Text(TokenmonL10n.format("raid.damage.format", raid.totalDamage))
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let blessing = raid.activeBlessing {
                Label(
                    TokenmonL10n.format(
                        "raid.blessing.first_spark.format",
                        Int(blessing.damageMultiplier),
                        blessing.minimumTotalDamage
                    ),
                    systemImage: "sparkles"
                )
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.green.opacity(0.11))
                )
            }

            if let reward = raid.rewards.first {
                HStack(spacing: 8) {
                    Image(systemName: rewardIcon(for: reward.type))
                        .foregroundStyle(rewardTint(for: reward.status))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(reward.title)
                            .font(.caption.weight(.semibold))
                        Text(rewardStatusText(reward.status))
                            .font(.caption)
                            .foregroundStyle(rewardTint(for: reward.status))
                    }
                    Spacer()
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(rewardSurfaceTint(for: reward.status))
                )
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
    }

    private func partySection(_ members: [PartyMemberSummary], raid: RaidProgressSummary) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(TokenmonL10n.string("raid.party.title"))
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(TokenmonL10n.format("raid.party.power_format", raid.partyPower))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if members.isEmpty {
                Label(TokenmonL10n.string("raid.party.empty"), systemImage: "person.3.sequence")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.06)))
            } else {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(42), spacing: 6), count: 5), spacing: 7) {
                    ForEach(members, id: \.speciesID) { member in
                        TokenmonRaidPartyMemberToken(
                            member: member,
                            cardSize: 42,
                            spriteSize: 30,
                            showsRarityBadge: true,
                            fieldMatch: member.field == raid.raidField
                        )
                        .help(raidPartyMemberHelp(member, raid: raid))
                    }
                }

                Label(
                    TokenmonL10n.format(
                        "raid.party.field_match_format",
                        raid.fieldMatchCount,
                        raid.raidField.displayName,
                        fieldSynergyPercent(raid.fieldSynergyMultiplier)
                    ),
                    systemImage: raid.raidField.systemImage
                )
                .font(.caption2.weight(.semibold))
                .foregroundStyle(raid.raidField.tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(raid.raidField.tint.opacity(0.10))
                )
            }
        }
    }

    private func raidPartyMemberHelp(_ member: PartyMemberSummary, raid: RaidProgressSummary) -> String {
        let bonus = RaidDamageCalculator.captureBondBonus(affinityLevel: member.affinityLevel)
        let fieldText = member.field == raid.raidField
            ? TokenmonL10n.format("raid.party.field_match_member_help", raid.raidField.displayName)
            : TokenmonL10n.format("raid.party.field_off_member_help", member.field.displayName)
        return "\(member.displayName) · \(fieldText) · \(TokenmonDexPresentation.raidAffinityBonusLabel(affinityLevel: member.affinityLevel, bonus: bonus))"
    }

    private func fieldSynergyPercent(_ multiplier: Double) -> Int {
        max(0, Int(((multiplier - 1.0) * 100).rounded()))
    }

    private func recentAttackSection(_ attacks: [RaidAttackSummary]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(TokenmonL10n.string("raid.recent.title"))
                .font(.subheadline.weight(.semibold))

            if attacks.isEmpty {
                Text(TokenmonL10n.string("raid.recent.empty"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(attacks, id: \.attackID) { attack in
                    HStack(spacing: 8) {
                        Image(systemName: attack.totalDamage > 0 ? "sparkles" : "pause.circle")
                            .foregroundStyle(attack.totalDamage > 0 ? Color.accentColor : Color.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(TokenmonL10n.format("raid.recent.row", attack.partySize, attack.totalDamage))
                                    .font(.caption.weight(.semibold))
                                if attack.criticalCount > 0 {
                                    impactPill("CRIT", tint: .orange)
                                } else if attack.totalDamage == 0 && attack.missCount > 0 {
                                    impactPill("MISS", tint: .secondary)
                                }
                            }
                            Text(TokenmonDexPresentation.formattedTimestamp(attack.occurredAt) ?? attack.occurredAt)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(attack.attackID == highlightedAttackID ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.05))
                    )
                }
            }
        }
    }

    private func rewardArchiveSection(
        _ entries: [RaidArchiveEntrySummary],
        onOpenRewardArchive: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(TokenmonL10n.string("raid.archive.title"))
                .font(.subheadline.weight(.semibold))

            if entries.isEmpty {
                Text(TokenmonL10n.string("raid.archive.empty.description"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.06))
                    )
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(entries.prefix(4), id: \.rewardID) { entry in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 8) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(rewardSurfaceTint(for: entry.status))
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(rewardTint(for: entry.status).opacity(0.18), lineWidth: 1)
                                    TokenmonRewardArchiveArtImage(entry: entry, lockedStyle: .compact)
                                    .padding(4)
                                }
                                .frame(width: 52, height: 52)

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Spacer()
                                        Text(rewardStatusText(entry.status))
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(rewardTint(for: entry.status))
                                    }
                                    Text(entry.title)
                                        .font(.caption.weight(.semibold))
                                        .lineLimit(2)
                                    Text(entry.sourceRaidTitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .padding(9)
                        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(rewardSurfaceTint(for: entry.status).opacity(0.75))
                        )
                    }
                }

                if entries.count > 4 {
                    Text(TokenmonL10n.format("raid.archive.more_format", entries.count - 4))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button(action: onOpenRewardArchive) {
                Label(TokenmonL10n.string("raid.archive.open"), systemImage: "shippingbox.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func impactPill(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.black))
            .foregroundStyle(tint)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Capsule().fill(tint.opacity(0.14)))
    }

    private var emptyState: some View {
        ContentUnavailableView(
            TokenmonL10n.string("raid.empty.title"),
            systemImage: "shield.slash",
            description: Text(TokenmonL10n.string("raid.empty.description"))
        )
        .frame(width: contentWidth)
        .frame(minHeight: 360)
    }

    private func statusText(for raid: RaidProgressSummary) -> String {
        switch raid.status {
        case .cleared:
            return TokenmonL10n.string("raid.status.cleared")
        case .expired, .missed:
            return TokenmonL10n.string("raid.status.expired")
        case .upcoming:
            return TokenmonL10n.string("raid.status.upcoming")
        case .active:
            if raid.partyPower == 0 {
                return TokenmonL10n.string("raid.status.needs_party")
            }
            return TokenmonL10n.string("raid.status.active")
        }
    }

    private func statusIcon(for status: RaidInstanceStatus) -> String {
        switch status {
        case .cleared: return "checkmark.seal.fill"
        case .expired, .missed: return "clock.badge.xmark"
        case .upcoming: return "calendar"
        case .active: return "bolt.heart.fill"
        }
    }

    private func statusTint(for status: RaidInstanceStatus) -> Color {
        switch status {
        case .cleared: return .green
        case .expired, .missed: return .secondary
        case .upcoming: return .orange
        case .active: return .accentColor
        }
    }

    private func rewardIcon(for type: RaidRewardType?) -> String {
        switch type {
        case .trophy:
            return "trophy.fill"
        case .logoRelic:
            return "seal.fill"
        case .badge:
            return "rosette"
        case .cosmetic:
            return "sparkles"
        case .eventSpecies:
            return "pawprint.fill"
        case nil:
            return "shippingbox.fill"
        }
    }

    private func rewardTint(for status: RaidRewardArchiveStatus) -> Color {
        switch status {
        case .acquired: return .green
        case .available: return .orange
        case .missed: return .red.opacity(0.72)
        case .unknown: return .secondary.opacity(0.7)
        }
    }

    private func rewardSurfaceTint(for status: RaidRewardArchiveStatus) -> Color {
        switch status {
        case .acquired: return .green.opacity(0.09)
        case .available: return .orange.opacity(0.11)
        case .missed: return .red.opacity(0.06)
        case .unknown: return .secondary.opacity(0.06)
        }
    }

    private func rewardStatusText(_ status: RaidRewardArchiveStatus) -> String {
        switch status {
        case .unknown: return TokenmonL10n.string("raid.reward.status.unknown")
        case .available: return TokenmonL10n.string("raid.reward.status.available")
        case .acquired: return TokenmonL10n.string("raid.reward.status.acquired")
        case .missed: return TokenmonL10n.string("raid.reward.status.missed")
        }
    }
}

private struct TokenmonRaidAnimatedAttack: Equatable {
    let attackID: Int64
    let startedAt: Date
    let totalDamage: Int
    let missCount: Int
    let criticalCount: Int
}

private struct TokenmonRaidPartyMemberToken: View {
    let member: PartyMemberSummary
    let cardSize: CGFloat
    let spriteSize: CGFloat
    let showsRarityBadge: Bool
    let fieldMatch: Bool

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundFill)
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(member.rarity.tint.opacity(0.82), lineWidth: borderWidth)
            if fieldMatch {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(member.field.tint.opacity(0.92), lineWidth: 2.4)
            }

            TokenmonDexSpritePreview(
                status: .captured,
                revealStage: .revealed,
                field: member.field,
                rarity: member.rarity,
                assetKey: member.assetKey,
                cardSize: cardSize,
                spriteSize: spriteSize,
                showsBackground: false,
                showsBorder: false
            )

            if showsRarityBadge {
                Image(systemName: member.rarity.systemImage)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(Circle().fill(member.rarity.tint))
                    .overlay(Circle().stroke(Color.white.opacity(0.34), lineWidth: 0.8))
                    .offset(x: 2, y: 2)
            }

        }
        .frame(width: cardSize, height: cardSize)
        .overlay(alignment: .topLeading) {
            if fieldMatch {
                Image(systemName: member.field.systemImage)
                    .font(.system(size: 8, weight: .black))
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
                    .background(Circle().fill(member.field.tint))
                    .overlay(Circle().stroke(Color.white.opacity(0.36), lineWidth: 0.8))
                    .offset(x: -2, y: -2)
            }
        }
        .shadow(color: member.rarity.tint.opacity(0.24), radius: 4, y: 2)
        .accessibilityLabel("\(member.displayName), \(member.rarity.displayName), \(affinityAccessibilityLabel)")
    }

    private var affinityAccessibilityLabel: String {
        TokenmonDexPresentation.raidAffinityBonusLabel(
            affinityLevel: member.affinityLevel,
            bonus: RaidDamageCalculator.captureBondBonus(affinityLevel: member.affinityLevel)
        )
    }

    private var cornerRadius: CGFloat {
        max(13, cardSize * 0.28)
    }

    private var borderWidth: CGFloat {
        member.rarity == .common ? 1.2 : 2.0
    }

    private var backgroundFill: LinearGradient {
        LinearGradient(
            colors: [
                member.rarity.tint.opacity(0.24),
                member.field.tint.opacity(0.12),
                Color(nsColor: .controlBackgroundColor).opacity(0.34),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private struct TokenmonRaidBattleStage: View {
    let raid: RaidProgressSummary
    let members: [PartyMemberSummary]
    let animation: TokenmonRaidAnimatedAttack?
    let reduceMotion: Bool

    private let maxDisplayedMembers = 10

    var body: some View {
        GeometryReader { _ in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                let displayedMembers = Array(members.prefix(maxDisplayedMembers))
                let elapsed = animation.map { max(0, context.date.timeIntervalSince($0.startedAt)) } ?? 10
                let targetImpact = reduceMotion ? 0 : impactStrength(elapsed: elapsed, memberCount: displayedMembers.count)

                ZStack {
                    TokenmonRaidBattleBackdropImage(raid: raid)

                    ZStack(alignment: .topLeading) {
                        targetView(targetImpact: targetImpact, elapsed: elapsed)
                            .position(x: 150, y: 70)

                        ForEach(Array(displayedMembers.enumerated()), id: \.element.speciesID) { index, member in
                            let frame = memberFrame(index: index)
                            let local = reduceMotion ? 0 : localProgress(elapsed: elapsed, memberIndex: index)
                            let offset = reduceMotion ? .zero : attackOffset(local, from: frame)
                            let scale = 1 + (reduceMotion ? 0 : 0.12 * max(0, 1 - abs(local - 0.45) / 0.25))

                            TokenmonDexSpritePreview(
                                status: .captured,
                                revealStage: .revealed,
                                field: member.field,
                                rarity: member.rarity,
                                assetKey: member.assetKey,
                                cardSize: 36,
                                spriteSize: 30,
                                showsBackground: false,
                                showsBorder: false
                            )
                            .frame(width: frame.width, height: frame.height)
                            .position(x: frame.midX + offset.width, y: frame.midY + offset.height)
                            .scaleEffect(scale)
                            .shadow(color: .black.opacity(0.16), radius: 3, y: 2)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(raid.raidField.tint.opacity(0.16), lineWidth: 1)
        )
        .frame(height: 204)
    }

    private func memberFrame(index: Int) -> CGRect {
        let row = index / 5
        let column = index % 5
        let baseX = 43 + CGFloat(column) * 43
        let baseY = 128 + CGFloat(row) * 38
        return CGRect(x: baseX, y: baseY, width: 36, height: 36)
    }

    private func targetView(targetImpact: Double, elapsed: TimeInterval) -> some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: 104, height: 20)
                .blur(radius: 5)
                .offset(y: 42)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            raid.raidField.tint.opacity(0.22),
                            raid.raidField.tint.opacity(0.07),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 66
                    )
                )
                .frame(width: 126, height: 126)
                .blendMode(.screen)
            TokenmonRaidArtImage(artKey: raid.targetArtKey)
                .padding(13)
                .shadow(color: .black.opacity(0.24), radius: 8, y: 5)
            if targetImpact > 0.01 {
                Circle()
                    .fill(raid.raidField.tint.opacity(0.22 * targetImpact))
                    .frame(width: 104 + (targetImpact * 18), height: 104 + (targetImpact * 18))
                    .blur(radius: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(raid.raidField.tint.opacity(0.95))
                    .offset(x: -46, y: -42)
            }
            if let animation {
                damageBadge(animation, elapsed: elapsed)
            }
        }
        .frame(width: 124, height: 124)
        .scaleEffect(1 + (targetImpact * 0.04))
        .rotationEffect(.degrees(targetImpact * 2.0))
    }

    private func localProgress(elapsed: TimeInterval, memberIndex: Int) -> Double {
        let delay = Double(memberIndex) * 0.04
        let duration = 0.62
        let raw = (elapsed - delay) / duration
        return min(1, max(0, raw))
    }

    private func attackOffset(_ local: Double, from frame: CGRect) -> CGSize {
        guard local > 0, local < 1 else { return .zero }
        let progress = local < 0.5 ? easeOut(local / 0.5) : easeIn((1 - local) / 0.5)
        let target = CGPoint(x: 150, y: 86)
        let dx = (target.x - frame.midX) * CGFloat(progress) * 0.42
        let dy = (target.y - frame.midY) * CGFloat(progress) * 0.42
        let lift = -sin(local * .pi) * CGFloat(12 + ((frame.midY - 140) / 6))
        return CGSize(width: dx, height: dy + lift)
    }

    private func impactStrength(elapsed: TimeInterval, memberCount: Int) -> Double {
        guard memberCount > 0 else { return 0 }
        var strongest = 0.0
        for index in 0..<memberCount {
            let local = localProgress(elapsed: elapsed, memberIndex: index)
            let impact = max(0, 1 - abs(local - 0.5) / 0.18)
            strongest = max(strongest, impact)
        }
        return strongest
    }

    private func easeOut(_ value: Double) -> Double {
        1 - pow(1 - value, 3)
    }

    private func easeIn(_ value: Double) -> Double {
        pow(value, 3)
    }

    private func damageBadge(_ animation: TokenmonRaidAnimatedAttack, elapsed: TimeInterval) -> some View {
        let opacity: Double = {
            if elapsed < 0.12 || elapsed > 1.05 {
                return 0
            }
            if elapsed < 0.26 {
                return (elapsed - 0.12) / 0.14
            }
            if elapsed < 0.68 {
                return 1
            }
            return max(0, 1 - ((elapsed - 0.68) / 0.37))
        }()
        let lift = CGFloat(min(max(elapsed - 0.12, 0), 0.84) * 26)
        let impactScale = elapsed < 0.24 ? 1.18 - CGFloat(elapsed * 0.75) : 1.0

        return Text(damageBadgeText(for: animation))
            .font(.system(size: animation.criticalCount > 0 ? 22 : 19, weight: .black, design: .rounded))
            .foregroundStyle(damageBadgeTint(for: animation))
            .shadow(color: .black.opacity(0.72), radius: 1.5, x: 0, y: 1)
            .shadow(color: damageBadgeTint(for: animation).opacity(0.42), radius: animation.criticalCount > 0 ? 8 : 4)
            .scaleEffect(impactScale)
            .offset(x: animation.criticalCount > 0 ? 26 : 34, y: -24 - lift)
            .opacity(opacity)
    }

    private func damageBadgeText(for animation: TokenmonRaidAnimatedAttack) -> String {
        if animation.totalDamage == 0, animation.missCount > 0 {
            return "MISS"
        }
        if animation.criticalCount > 0 {
            return "CRIT -\(animation.totalDamage)"
        }
        return "-\(animation.totalDamage)"
    }

    private func damageBadgeTint(for animation: TokenmonRaidAnimatedAttack) -> Color {
        if animation.totalDamage == 0, animation.missCount > 0 {
            return .secondary
        }
        if animation.criticalCount > 0 {
            return .orange
        }
        return raid.raidField.tint
    }
}

private struct TokenmonRaidBattleBackdropImage: View {
    let raid: RaidProgressSummary

    var body: some View {
        ZStack {
            if let image = TokenmonRaidArtLoader.image(artKey: backdropArtKey) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                Color(nsColor: .controlBackgroundColor)
            }

            Color.black.opacity(0.10)
        }
    }

    private var backdropArtKey: String {
        if raid.availabilityKind == .scheduled {
            switch raid.raidField {
            case .grassland:
                return "raid_backdrop_grassland_vault"
            case .sky:
                return "raid_backdrop_sky_beacon"
            case .coast:
                return "raid_backdrop_coast_tideglass"
            case .ice:
                return "raid_backdrop_ice_aurora_archive"
            }
        }

        switch raid.targetArtKey {
        case "raid_target_token_vault_sentinel":
            return "raid_backdrop_token_vault_chamber"
        default:
            return "raid_backdrop_treasure_vault"
        }
    }
}

struct TokenmonRewardArchivePanel: View {
    private static let minimumWindowSize = CGSize(width: 820, height: 560)
    private static let idealWindowSize = CGSize(width: 1120, height: 720)

    @ObservedObject var model: TokenmonMenuModel
    let collectionNavigation: TokenmonCollectionNavigationState?
    @State private var sidebarSelection: RewardArchiveSidebarSelection = .raidAll
    @State private var selectedRewardID: String?
    @State private var selectedBadgeID: String?

    init(
        model: TokenmonMenuModel,
        collectionNavigation: TokenmonCollectionNavigationState? = nil
    ) {
        self.model = model
        self.collectionNavigation = collectionNavigation
    }

    private var entries: [RaidArchiveEntrySummary] {
        model.raidDashboard?.archiveEntries ?? []
    }

    private var badges: [AchievementBadgeSummary] {
        model.achievementBadges
    }

    private var filteredEntries: [RaidArchiveEntrySummary] {
        switch sidebarSelection {
        case .raidAll:
            return entries
        case .raidAvailable:
            return entries.filter { $0.status == .available }
        case .raidAcquired:
            return entries.filter { $0.status == .acquired }
        case .raidMissed:
            return entries.filter { $0.status == .missed }
        case .badgeAll, .badgeUnlocked, .badgeLocked:
            return []
        }
    }

    private var filteredBadges: [AchievementBadgeSummary] {
        switch sidebarSelection {
        case .badgeAll:
            return badges
        case .badgeUnlocked:
            return badges.filter(\.isUnlocked)
        case .badgeLocked:
            return badges.filter { !$0.isUnlocked }
        case .raidAll, .raidAvailable, .raidAcquired, .raidMissed:
            return []
        }
    }

    private var selectedEntry: RewardArchiveSelectedItem? {
        if sidebarSelection.isBadgeSelection {
            if let selectedBadgeID,
               let selected = filteredBadges.first(where: { $0.badgeID == selectedBadgeID }) {
                return .achievement(selected)
            }
            return filteredBadges.first.map(RewardArchiveSelectedItem.achievement)
        }
        if let selectedRewardID,
           let selected = filteredEntries.first(where: { $0.rewardID == selectedRewardID }) {
            return .raidReward(selected)
        }
        return filteredEntries.first.map(RewardArchiveSelectedItem.raidReward)
    }

    private var acquiredCount: Int {
        entries.filter { $0.status == .acquired }.count
    }

    private var availableCount: Int {
        entries.filter { $0.status == .available }.count
    }

    private var filteredSelectionIsEmpty: Bool {
        sidebarSelection.isBadgeSelection ? filteredBadges.isEmpty : filteredEntries.isEmpty
    }

    private var unlockedBadgeCount: Int {
        badges.filter(\.isUnlocked).count
    }

    var body: some View {
        HStack(spacing: 0) {
            rewardSidebar
                .frame(width: tokenmonCollectionSidebarWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .topLeading)

            Divider()

            rewardBrowser
                .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            Divider()

            TokenmonArchiveDetailPanel(selection: selectedEntry)
        }
        .frame(
            minWidth: collectionNavigation == nil ? Self.minimumWindowSize.width : nil,
            idealWidth: collectionNavigation == nil ? Self.idealWindowSize.width : nil,
            minHeight: collectionNavigation == nil ? Self.minimumWindowSize.height : nil,
            idealHeight: collectionNavigation == nil ? Self.idealWindowSize.height : nil
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            normalizeSelection()
        }
        .onChange(of: sidebarSelection) { _, _ in
            normalizeSelection()
        }
        .onChange(of: entries) { _, _ in
            normalizeSelection()
        }
        .onChange(of: badges) { _, _ in
            normalizeSelection()
        }
    }

    private var rewardSidebar: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let collectionNavigation {
                TokenmonCollectionSidebarHeader(navigation: collectionNavigation)

                Divider()
            } else {
                Text(TokenmonL10n.string("window.title.reward_archive"))
                    .font(.headline)
                    .foregroundStyle(.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                sidebarGroup(
                    title: TokenmonL10n.string("archive.group.raid_rewards"),
                    items: raidSidebarItems
                )
                sidebarGroup(
                    title: TokenmonL10n.string("archive.group.badges"),
                    items: badgeSidebarItems
                )
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func sidebarGroup(
        title: String,
        items: [(selection: RewardArchiveSidebarSelection, title: String, systemImage: String, count: Int)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            TokenmonCollectionSidebarGroupTitle(title: title)
            ForEach(items, id: \.selection) { item in
                Button {
                    sidebarSelection = item.selection
                } label: {
                    RewardArchiveSidebarRow(
                        title: item.title,
                        systemImage: item.systemImage,
                        count: item.count
                    )
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(item.selection == sidebarSelection ? Color.accentColor.opacity(0.16) : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var raidSidebarItems: [(selection: RewardArchiveSidebarSelection, title: String, systemImage: String, count: Int)] {
        [
            (
                .raidAll,
                TokenmonL10n.string("raid.archive.sidebar.all"),
                "shippingbox.fill",
                entries.count
            ),
            (
                .raidAvailable,
                TokenmonL10n.string("raid.archive.metric.available"),
                "sparkles",
                availableCount
            ),
            (
                .raidAcquired,
                TokenmonL10n.string("raid.archive.metric.acquired"),
                "checkmark.seal.fill",
                acquiredCount
            ),
            (
                .raidMissed,
                TokenmonL10n.string("raid.reward.status.missed"),
                "clock.badge.xmark",
                entries.filter { $0.status == .missed }.count
            ),
        ]
    }

    private var badgeSidebarItems: [(selection: RewardArchiveSidebarSelection, title: String, systemImage: String, count: Int)] {
        [
            (
                .badgeAll,
                TokenmonL10n.string("achievement.archive.sidebar.all"),
                "rosette",
                badges.count
            ),
            (
                .badgeUnlocked,
                TokenmonL10n.string("achievement.status.unlocked"),
                "checkmark.seal.fill",
                unlockedBadgeCount
            ),
            (
                .badgeLocked,
                TokenmonL10n.string("achievement.status.locked"),
                "lock.fill",
                badges.count - unlockedBadgeCount
            ),
        ]
    }

    private var rewardBrowser: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(sidebarSelection.title)
                    .font(.title2.weight(.semibold))
                Text(archiveSummaryText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)

            if filteredSelectionIsEmpty {
                ContentUnavailableView(
                    TokenmonL10n.string(sidebarSelection.isBadgeSelection ? "achievement.archive.empty.title" : "raid.archive.empty.title"),
                    systemImage: sidebarSelection.isBadgeSelection ? "rosette" : "shippingbox",
                    description: Text(TokenmonL10n.string(sidebarSelection.isBadgeSelection ? "achievement.archive.empty.description" : "raid.archive.empty.description"))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 170, maximum: 210), spacing: 14),
                        ],
                        spacing: 14
                    ) {
                        if sidebarSelection.isBadgeSelection {
                            ForEach(filteredBadges, id: \.badgeID) { badge in
                                Button {
                                    selectedBadgeID = badge.badgeID
                                } label: {
                                    TokenmonAchievementBadgeCard(
                                        badge: badge,
                                        isSelected: selectedBadgeID == badge.badgeID
                                    )
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .buttonStyle(.plain)
                            }
                        } else {
                            ForEach(filteredEntries, id: \.rewardID) { entry in
                                Button {
                                    selectedRewardID = entry.rewardID
                                } label: {
                                    TokenmonRewardArchiveCard(
                                        entry: entry,
                                        isSelected: selectedRewardID == entry.rewardID
                                    )
                                }
                                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 18)
                }
            }
        }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var archiveSummaryText: String {
        if sidebarSelection.isBadgeSelection {
            return [
                TokenmonL10n.format("raid.archive.summary.shown", filteredBadges.count),
                "\(unlockedBadgeCount) \(TokenmonL10n.string("achievement.status.unlocked"))",
                "\(badges.count - unlockedBadgeCount) \(TokenmonL10n.string("achievement.status.locked"))",
            ].joined(separator: " • ")
        }
        return [
            TokenmonL10n.format("raid.archive.summary.shown", filteredEntries.count),
            "\(acquiredCount) \(TokenmonL10n.string("raid.archive.metric.acquired"))",
            "\(availableCount) \(TokenmonL10n.string("raid.archive.metric.available"))",
        ].joined(separator: " • ")
    }

    private func normalizeSelection() {
        if sidebarSelection.isBadgeSelection {
            if let selectedBadgeID,
               filteredBadges.contains(where: { $0.badgeID == selectedBadgeID }) {
                return
            }
            selectedBadgeID = filteredBadges.first?.badgeID
        } else {
            if let selectedRewardID,
               filteredEntries.contains(where: { $0.rewardID == selectedRewardID }) {
                return
            }
            selectedRewardID = filteredEntries.first?.rewardID
        }
    }
}

private enum RewardArchiveSelectedItem: Equatable {
    case raidReward(RaidArchiveEntrySummary)
    case achievement(AchievementBadgeSummary)
}

private struct TokenmonRewardArchiveCard: View {
    let entry: RaidArchiveEntrySummary
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                statusPill
                Spacer()
                Image(systemName: statusIcon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.15))
                    )
            }

            HStack {
                Spacer()
                TokenmonRewardArchiveArtImage(entry: entry, lockedStyle: .card)
                .frame(width: 120, height: 120)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(entry.status == .unknown ? .secondary : .primary)
                    .lineLimit(1)
                Text(entry.sourceRaidTitle)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    TokenmonRaidSourceTargetImage(entry: entry, size: 28)
                    Text(TokenmonRaidSourceTargetDisclosure.displayName(for: entry))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(periodText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .shadow(
            color: tint.opacity(entry.status == .available ? 0.16 : 0.10),
            radius: isSelected ? 7 : 4,
            y: isSelected ? 2 : 1
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor : tint.opacity(0.35), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusPill: some View {
        Text(statusText)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.13))
            )
    }

    private var statusText: String {
        switch entry.status {
        case .unknown: return TokenmonL10n.string("raid.reward.status.unknown")
        case .available: return TokenmonL10n.string("raid.reward.status.available")
        case .acquired: return TokenmonL10n.string("raid.reward.status.acquired")
        case .missed: return TokenmonL10n.string("raid.reward.status.missed")
        }
    }

    private var tint: Color {
        switch entry.status {
        case .acquired: return .green
        case .available: return .orange
        case .missed: return .red.opacity(0.72)
        case .unknown: return .secondary.opacity(0.7)
        }
    }

    private var surfaceTint: Color {
        switch entry.status {
        case .acquired: return .green.opacity(0.10)
        case .available: return .orange.opacity(0.12)
        case .missed: return .red.opacity(0.06)
        case .unknown: return .secondary.opacity(0.06)
        }
    }

    private var statusIcon: String {
        switch entry.status {
        case .unknown: return "questionmark"
        case .available: return "sparkles"
        case .acquired: return "checkmark"
        case .missed: return "xmark"
        }
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [
                surfaceTint.opacity(1.0),
                tint.opacity(0.05),
                Color(nsColor: .controlBackgroundColor),
            ],
            startPoint: .topLeading,
            endPoint: .bottom
        )
    }

    private var periodText: String {
        RewardArchiveDateFormatter.periodText(for: entry)
    }
}

private enum RewardArchiveLockedArtStyle {
    case compact, card, detail

    var blurRadius: CGFloat {
        switch self {
        case .compact: return 2
        case .card: return 3
        case .detail: return 4
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .compact: return 14
        case .card: return 20
        case .detail: return 28
        }
    }
}

private struct TokenmonRewardArchiveArtImage: View {
    let entry: RaidArchiveEntrySummary
    let lockedStyle: RewardArchiveLockedArtStyle

    private var isRevealed: Bool {
        entry.status == .acquired
    }

    var body: some View {
        ZStack {
            TokenmonRaidArtImage(
                artKey: entry.artKey,
                saturation: isRevealed ? 1 : 0,
                brightness: isRevealed ? 0 : -0.26
            )
            .opacity(isRevealed ? 1 : 0.30)
            .blur(radius: isRevealed ? 0 : lockedStyle.blurRadius)
            .overlay {
                if !isRevealed {
                    TokenmonRaidArtImage(
                        artKey: entry.artKey,
                        saturation: 0,
                        brightness: -0.58
                    )
                    .opacity(0.38)
                    .colorMultiply(Color.black.opacity(0.92))
                }
            }

            if !isRevealed {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.18),
                                Color.black.opacity(0.42),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .allowsHitTesting(false)
                Image(systemName: entry.status == .available ? "sparkles" : "lock.fill")
                    .font(.system(size: lockedStyle.iconSize, weight: .bold))
                    .foregroundStyle(entry.status == .available ? Color.orange.opacity(0.78) : Color.secondary.opacity(0.78))
                    .padding(8)
                    .background(
                        Circle()
                            .fill(Color(nsColor: .controlBackgroundColor).opacity(0.82))
                    )
            }
        }
    }
}

private enum RewardArchiveSidebarSelection: String, Hashable {
    case raidAll, raidAvailable, raidAcquired, raidMissed
    case badgeAll, badgeUnlocked, badgeLocked

    var isBadgeSelection: Bool {
        switch self {
        case .badgeAll, .badgeUnlocked, .badgeLocked:
            return true
        case .raidAll, .raidAvailable, .raidAcquired, .raidMissed:
            return false
        }
    }

    var title: String {
        switch self {
        case .raidAll: return TokenmonL10n.string("raid.archive.sidebar.all")
        case .raidAvailable: return TokenmonL10n.string("raid.archive.metric.available")
        case .raidAcquired: return TokenmonL10n.string("raid.archive.metric.acquired")
        case .raidMissed: return TokenmonL10n.string("raid.reward.status.missed")
        case .badgeAll: return TokenmonL10n.string("achievement.archive.sidebar.all")
        case .badgeUnlocked: return TokenmonL10n.string("achievement.status.unlocked")
        case .badgeLocked: return TokenmonL10n.string("achievement.status.locked")
        }
    }
}

private struct RewardArchiveSidebarRow: View {
    let title: String
    let systemImage: String
    let count: Int

    var body: some View {
        TokenmonCollectionSidebarRow(
            title: title,
            systemImage: systemImage,
            countText: "\(count)"
        )
    }
}

private struct TokenmonAchievementBadgeCard: View {
    let badge: AchievementBadgeSummary
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(statusText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Capsule(style: .continuous).fill(tint.opacity(0.13)))
                Spacer()
                Image(systemName: badge.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 30, height: 28)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(tint.opacity(0.15))
                    )
            }

            HStack {
                Spacer()
                TokenmonBadgeArtImage(artKey: badge.artKey, isUnlocked: badge.isUnlocked)
                    .frame(width: 118, height: 118)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(TokenmonL10n.string(forKey: badge.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(badge.isUnlocked ? .primary : .secondary)
                    .lineLimit(1)
                Text(categoryText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(progressText)
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 184, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(cardBackground)
        )
        .shadow(color: tint.opacity(0.10), radius: isSelected ? 7 : 4, y: isSelected ? 2 : 1)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color.accentColor : tint.opacity(0.32), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var statusText: String {
        TokenmonL10n.string(badge.isUnlocked ? "achievement.status.unlocked" : "achievement.status.locked")
    }

    private var categoryText: String {
        TokenmonL10n.string(forKey: "achievement.category.\(badge.category.rawValue)")
    }

    private var progressText: String {
        TokenmonL10n.format("achievement.progress.format", badge.progress, badge.target)
    }

    private var tint: Color {
        badge.isUnlocked ? .green : .secondary.opacity(0.72)
    }

    private var cardBackground: LinearGradient {
        LinearGradient(
            colors: [
                tint.opacity(badge.isUnlocked ? 0.10 : 0.05),
                Color(nsColor: .controlBackgroundColor),
            ],
            startPoint: .topLeading,
            endPoint: .bottom
        )
    }
}

private struct TokenmonArchiveDetailPanel: View {
    let selection: RewardArchiveSelectedItem?

    var body: some View {
        switch selection {
        case .raidReward(let entry):
            TokenmonRewardArchiveDetail(entry: entry)
        case .achievement(let badge):
            TokenmonAchievementBadgeDetail(badge: badge)
        case nil:
            ContentUnavailableView(
                TokenmonL10n.string("raid.archive.empty.title"),
                systemImage: "shippingbox",
                description: Text(TokenmonL10n.string("raid.archive.empty.description"))
            )
            .frame(minWidth: tokenmonDexSupportingWidth + 24, maxWidth: tokenmonDexSupportingWidth + 24, maxHeight: .infinity)
        }
    }
}

private struct TokenmonAchievementBadgeDetail: View {
    let badge: AchievementBadgeSummary

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(surfaceTint)
                    TokenmonBadgeArtImage(artKey: badge.artKey, isUnlocked: badge.isUnlocked)
                        .padding(34)
                }
                .frame(maxWidth: tokenmonDexSupportingWidth, minHeight: 220, alignment: .topLeading)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(tint.opacity(0.22), lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 7) {
                    Text(TokenmonL10n.string(forKey: badge.titleKey))
                        .font(.title2.weight(.semibold))
                    Label(statusText, systemImage: badge.isUnlocked ? "checkmark.seal.fill" : "lock.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                    Text(TokenmonL10n.string(forKey: badge.descriptionKey))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                detailRow(
                    title: TokenmonL10n.string("achievement.detail.category"),
                    value: TokenmonL10n.string(forKey: "achievement.category.\(badge.category.rawValue)")
                )
                detailRow(
                    title: TokenmonL10n.string("achievement.detail.progress"),
                    value: TokenmonL10n.format("achievement.progress.format", badge.progress, badge.target)
                )
                if let unlockedAt = badge.unlockedAt {
                    detailRow(
                        title: TokenmonL10n.string("achievement.detail.unlocked_at"),
                        value: TokenmonDexPresentation.formattedTimestamp(unlockedAt) ?? unlockedAt
                    )
                }
                Spacer(minLength: 0)
            }
            .padding(22)
            .frame(maxWidth: tokenmonDexSupportingWidth, alignment: .leading)
        }
        .frame(minWidth: tokenmonDexSupportingWidth + 24, maxWidth: tokenmonDexSupportingWidth + 24, maxHeight: .infinity, alignment: .topLeading)
    }

    private var statusText: String {
        TokenmonL10n.string(badge.isUnlocked ? "achievement.status.unlocked" : "achievement.status.locked")
    }

    private var tint: Color {
        badge.isUnlocked ? .green : .secondary.opacity(0.72)
    }

    private var surfaceTint: Color {
        badge.isUnlocked ? .green.opacity(0.10) : .secondary.opacity(0.06)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
    }
}

private struct TokenmonRewardArchiveDetail: View {
    let entry: RaidArchiveEntrySummary?

    var body: some View {
        Group {
            if let entry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(detailSurfaceTint(for: entry.status))
                            TokenmonRewardArchiveArtImage(entry: entry, lockedStyle: .detail)
                            .padding(30)
                        }
                        .frame(maxWidth: tokenmonDexSupportingWidth, minHeight: 220, alignment: .topLeading)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(detailTint(for: entry.status).opacity(0.22), lineWidth: 1)
                        )

                        VStack(alignment: .leading, spacing: 7) {
                            Text(entry.title)
                                .font(.title2.weight(.semibold))
                            Label(rewardStatusText(entry.status), systemImage: rewardStatusIcon(entry.status))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(detailTint(for: entry.status))
                        }

                        detailRow(
                            title: TokenmonL10n.string("raid.archive.detail.source"),
                            value: entry.sourceRaidTitle
                        )
                        sourceRaidRow(entry)
                        detailRow(
                            title: TokenmonL10n.string("raid.archive.detail.period"),
                            value: RewardArchiveDateFormatter.periodText(for: entry)
                        )
                        if let acquiredAt = entry.acquiredAt {
                            detailRow(
                                title: TokenmonL10n.string("raid.archive.detail.acquired_at"),
                                value: TokenmonDexPresentation.formattedTimestamp(acquiredAt) ?? acquiredAt
                            )
                        }
                        if let missedAt = entry.missedAt {
                            detailRow(
                                title: TokenmonL10n.string("raid.archive.detail.missed_at"),
                                value: TokenmonDexPresentation.formattedTimestamp(missedAt) ?? missedAt
                            )
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(22)
                    .frame(maxWidth: tokenmonDexSupportingWidth, alignment: .leading)
                }
            } else {
                ContentUnavailableView(
                    TokenmonL10n.string("raid.archive.empty.title"),
                    systemImage: "shippingbox",
                    description: Text(TokenmonL10n.string("raid.archive.empty.description"))
                )
            }
        }
        .frame(minWidth: tokenmonDexSupportingWidth + 24, maxWidth: tokenmonDexSupportingWidth + 24, maxHeight: .infinity, alignment: .topLeading)
    }

    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
    }

    private func sourceRaidRow(_ entry: RaidArchiveEntrySummary) -> some View {
        HStack(spacing: 12) {
            TokenmonRaidSourceTargetImage(entry: entry, size: 62)
            VStack(alignment: .leading, spacing: 4) {
                Text(TokenmonRaidSourceTargetDisclosure.displayName(for: entry))
                    .font(.body.weight(.semibold))
                Text(sourceTargetRevealText(for: entry.status))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.secondary.opacity(0.07))
        )
    }

    private func sourceTargetRevealText(for status: RaidRewardArchiveStatus) -> String {
        switch status {
        case .available:
            return TokenmonL10n.string("raid.archive.target.revealed")
        case .acquired:
            return TokenmonL10n.string("raid.archive.target.cleared")
        case .missed:
            return TokenmonL10n.string("raid.archive.target.hidden_missed")
        case .unknown:
            return TokenmonL10n.string("raid.archive.target.hidden_future")
        }
    }

    private func rewardStatusText(_ status: RaidRewardArchiveStatus) -> String {
        switch status {
        case .unknown: return TokenmonL10n.string("raid.reward.status.unknown")
        case .available: return TokenmonL10n.string("raid.reward.status.available")
        case .acquired: return TokenmonL10n.string("raid.reward.status.acquired")
        case .missed: return TokenmonL10n.string("raid.reward.status.missed")
        }
    }

    private func rewardStatusIcon(_ status: RaidRewardArchiveStatus) -> String {
        switch status {
        case .unknown: return "questionmark.circle"
        case .available: return "sparkles"
        case .acquired: return "checkmark.seal.fill"
        case .missed: return "clock.badge.xmark"
        }
    }

    private func detailTint(for status: RaidRewardArchiveStatus) -> Color {
        switch status {
        case .acquired: return .green
        case .available: return .orange
        case .missed: return .red.opacity(0.72)
        case .unknown: return .secondary.opacity(0.7)
        }
    }

    private func detailSurfaceTint(for status: RaidRewardArchiveStatus) -> Color {
        switch status {
        case .acquired: return .green.opacity(0.10)
        case .available: return .orange.opacity(0.12)
        case .missed: return .red.opacity(0.06)
        case .unknown: return .secondary.opacity(0.06)
        }
    }
}

private struct TokenmonRaidSourceTargetImage: View {
    let entry: RaidArchiveEntrySummary
    let size: CGFloat

    private var isRevealed: Bool {
        TokenmonRaidSourceTargetDisclosure.isRevealed(entry.status)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(surfaceTint)
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .stroke(tint.opacity(0.22), lineWidth: 1)

            if isRevealed {
                TokenmonRaidArtImage(artKey: entry.sourceRaidTargetArtKey)
                    .padding(size * 0.10)
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(tint.opacity(0.72))
                Circle()
                    .strokeBorder(tint.opacity(0.20), lineWidth: 1)
                    .frame(width: size * 0.54, height: size * 0.54)
                    .blur(radius: 0.2)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        isRevealed ? entry.sourceRaidTargetName : TokenmonL10n.string("raid.archive.target.hidden_accessibility")
    }

    private var tint: Color {
        switch entry.status {
        case .acquired: return .green
        case .available: return .orange
        case .missed: return .red.opacity(0.72)
        case .unknown: return .secondary.opacity(0.7)
        }
    }

    private var surfaceTint: Color {
        switch entry.status {
        case .acquired: return .green.opacity(0.10)
        case .available: return .orange.opacity(0.12)
        case .missed: return .red.opacity(0.06)
        case .unknown: return .secondary.opacity(0.06)
        }
    }
}

private enum TokenmonRaidSourceTargetDisclosure {
    static func isRevealed(_ status: RaidRewardArchiveStatus) -> Bool {
        status == .available || status == .acquired
    }

    static func displayName(for entry: RaidArchiveEntrySummary) -> String {
        isRevealed(entry.status)
            ? entry.sourceRaidTargetName
            : TokenmonL10n.string("raid.archive.target.hidden_accessibility")
    }
}

private enum RewardArchiveDateFormatter {
    static func periodText(for entry: RaidArchiveEntrySummary) -> String {
        guard let start = entry.activeStartAt, let end = entry.activeEndAt else {
            return TokenmonL10n.string("raid.archive.period.always")
        }
        if let startDate = isoDate(start), let endDate = isoDate(end) {
            let formatter = DateIntervalFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: startDate, to: endDate)
        }
        let formattedStart = shortDate(start) ?? start
        let formattedEnd = shortDate(end) ?? end
        return TokenmonL10n.format("raid.archive.period.range", formattedStart, formattedEnd)
    }

    private static func shortDate(_ rawValue: String) -> String? {
        guard let date = isoDate(rawValue) else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private static func isoDate(_ rawValue: String) -> Date? {
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return precise.date(from: rawValue) ?? standard.date(from: rawValue)
    }
}
