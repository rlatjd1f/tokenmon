import SwiftUI
import TokenmonDomain
import TokenmonPersistence

/// Scrollable browser of every Dex species grouped by rarity, highest first.
/// Captured / seen entries show their portrait, while unknown entries keep the
/// mystery silhouette and "???" label.
struct DexPreviewGrid: View {
    @ObservedObject var model: TokenmonMenuModel
    let entries: [DexEntrySummary]
    let onSelect: (DexEntrySummary) -> Void

    @State private var partyToast: PartyToast?

    private static let columns: [GridItem] = Array(
        repeating: GridItem(.flexible(), spacing: 8),
        count: 4
    )

    private static let rarityOrder: [RarityTier] = [.legendary, .epic, .rare, .uncommon, .common]

    private struct RarityGroup: Identifiable {
        let rarity: RarityTier
        let entries: [DexEntrySummary]
        var id: String { rarity.rawValue }
    }

    private var groups: [RarityGroup] {
        var grouped: [RarityTier: [DexEntrySummary]] = [:]
        for entry in entries {
            grouped[entry.rarity, default: []].append(entry)
        }

        return Self.rarityOrder.compactMap { rarity in
            guard let items = grouped[rarity], items.isEmpty == false else {
                return nil
            }

            let sorted = items.sorted { lhs, rhs in
                let lhsRank = statusRank(lhs.status)
                let rhsRank = statusRank(rhs.status)
                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            return RarityGroup(rarity: rarity, entries: sorted)
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            LazyVStack(alignment: .leading, spacing: 14) {
                ForEach(groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        rarityHeader(group)
                        LazyVGrid(columns: Self.columns, spacing: 10) {
                            ForEach(group.entries, id: \.speciesID) { entry in
                                slotView(for: entry)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: .infinity)
        .partyToast($partyToast)
    }

    private func statusRank(_ status: DexEntryStatus) -> Int {
        switch status {
        case .captured:
            return 0
        case .seenUncaptured:
            return 1
        case .unknown:
            return 2
        }
    }

    private func rarityColor(_ rarity: RarityTier) -> Color {
        switch rarity {
        case .common:
            return .gray
        case .uncommon:
            return .green
        case .rare:
            return .blue
        case .epic:
            return .purple
        case .legendary:
            return .yellow
        }
    }

    @ViewBuilder
    private func rarityHeader(_ group: RarityGroup) -> some View {
        let color = rarityColor(group.rarity)
        let capturedCount = group.entries.filter { $0.status == .captured }.count

        HStack(spacing: 8) {
            Text(group.rarity.displayName.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.8)
                .foregroundStyle(color)

            Rectangle()
                .fill(color.opacity(0.35))
                .frame(height: 1)

            Text("\(capturedCount)/\(group.entries.count)")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func slotView(for entry: DexEntrySummary) -> some View {
        Button {
            onSelect(entry)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    TokenmonDexSpritePreview(
                        status: entry.status,
                        revealStage: TokenmonDexPresentation.revealStage(for: entry),
                        field: entry.field,
                        rarity: entry.rarity,
                        assetKey: entry.assetKey,
                        cardSize: 56,
                        spriteSize: 38
                    )

                    if model.nowCampLeadSpeciesID == entry.speciesID {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(.yellow)
                            .padding(4)
                            .background(Circle().fill(Color(nsColor: .controlBackgroundColor).opacity(0.86)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .offset(x: -4, y: -4)
                            .accessibilityHidden(true)
                    }

                    if entry.status == .captured, entry.affinityLevel >= 2 {
                        TokenmonAffinityBadge(level: entry.affinityLevel, compact: true, emphasized: true)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .offset(x: 4, y: 4)
                    }
                }

                Text(TokenmonDexPresentation.visibleSpeciesName(for: entry))
                    .font(.caption2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
                    .foregroundStyle(entry.status == .unknown ? .secondary : .primary)
            }
            .help(tooltip(for: entry))
        }
        .buttonStyle(.plain)
        .partyMembershipBorder(
            isMember: model.partySpeciesIDs.contains(entry.speciesID),
            cornerRadius: 14,
            lineWidth: 2
        )
        .accessibilityLabel(accessibilityLabel(for: entry))
        .contextMenu {
            let isMember = model.partySpeciesIDs.contains(entry.speciesID)
            let isCaptured = entry.status == .captured

            if isMember {
                Button {
                    model.setNowCampLead(entry.speciesID)
                } label: {
                    Label(TokenmonL10n.string("dex.context_menu.set_lead"), systemImage: "crown.fill")
                }

                Button {
                    _ = model.removeSpeciesFromParty(entry.speciesID)
                } label: {
                    Label(TokenmonL10n.string("dex.context_menu.remove_from_party"), systemImage: "bag.badge.minus")
                }
            } else {
                Button {
                    let outcome = model.addSpeciesToParty(entry.speciesID)
                    if outcome == .partyFull {
                        partyToast = PartyToast(message: TokenmonL10n.string("party.full.toast"))
                    }
                } label: {
                    Label(TokenmonL10n.string("dex.context_menu.add_to_party"), systemImage: "bag.badge.plus")
                }
                .disabled(isCaptured == false)
                .help(isCaptured ? "" : TokenmonL10n.string("dex.context_menu.add_to_party.disabled_help"))
            }
        }
    }

    private func accessibilityLabel(for entry: DexEntrySummary) -> String {
        let baseLabel = TokenmonDexPresentation.visibleSpeciesName(for: entry)
        var parts = [baseLabel]
        if entry.status == .captured {
            let level = TokenmonDexPresentation.affinityLevelNumber(for: entry)
            parts.append(TokenmonDexPresentation.affinityLevelLabel(level: level))
            parts.append(TokenmonDexPresentation.affinityRaidBonusShortLabel(level: level))
        }
        if model.partySpeciesIDs.contains(entry.speciesID) {
            parts.append(TokenmonL10n.string("dex.card.accessibility.party_suffix"))
        }
        return parts.joined(separator: ", ")
    }

    private func tooltip(for entry: DexEntrySummary) -> String {
        if entry.status == .unknown {
            return TokenmonL10n.format("dex.preview.tooltip.unknown", entry.field.displayName, entry.rarity.displayName)
        }

        let date = entry.lastCapturedAt ?? entry.lastSeenAt ?? ""
        let displayName = TokenmonDexPresentation.visibleSpeciesName(for: entry, style: .sentence)
        var tooltip = TokenmonL10n.format("dex.preview.tooltip.known", displayName, entry.rarity.displayName, entry.field.displayName, date)
        if entry.status == .captured {
            let level = TokenmonDexPresentation.affinityLevelNumber(for: entry)
            tooltip += " · \(TokenmonDexPresentation.affinityLevelLabel(level: level)) · \(TokenmonDexPresentation.affinityRaidBonusShortLabel(level: level))"
        }
        return tooltip
    }
}
