import SwiftUI
import TokenmonPersistence

struct DexActivitySummaryCard: View {
    let summary: TokenmonDexActivitySummary

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.08))
                    .frame(width: 38, height: 38)
                Image(systemName: "text.badge.star")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.headline)
                    .font(.headline.weight(.semibold))
                Text(summary.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct DexTeaserCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.06), lineWidth: 1)
        )
    }
}

struct DexActivityFeed: View {
    let items: [TokenmonDexActivityItem]
    let onSelect: (DexEntrySummary) -> Void

    private let entriesBySpeciesID: [String: DexEntrySummary]

    init(items: [TokenmonDexActivityItem], entries: [DexEntrySummary], onSelect: @escaping (DexEntrySummary) -> Void) {
        self.items = items
        self.entriesBySpeciesID = Dictionary(uniqueKeysWithValues: entries.map { ($0.speciesID, $0) })
        self.onSelect = onSelect
    }

    var body: some View {
        if items.isEmpty {
            DexTeaserEmptyState(
                title: TokenmonL10n.string("dex.teaser.activity.empty_title"),
                subtitle: TokenmonL10n.string("dex.teaser.activity.empty_subtitle"),
                systemImage: "clock.arrow.circlepath"
            )
        } else {
            VStack(spacing: 8) {
                ForEach(items, id: \.encounterID) { item in
                    if let entry = entriesBySpeciesID[item.speciesID] {
                        Button {
                            onSelect(entry)
                        } label: {
                            DexActivityRow(item: item)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct DexActivityRow: View {
    let item: TokenmonDexActivityItem

    private var fieldLabel: String {
        item.field.displayName
    }

    var body: some View {
        HStack(spacing: 12) {
            TokenmonDexSpritePreview(
                status: item.kind == .captured ? .captured : .seenUncaptured,
                revealStage: TokenmonDexPresentation.revealStage(for: item),
                field: item.field,
                rarity: item.rarity,
                assetKey: item.assetKey,
                cardSize: 54,
                spriteSize: 36
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(TokenmonDexPresentation.visibleSpeciesName(for: item, style: .sentence))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("#\(String(format: "%03d", item.sortOrder)) · \(fieldLabel)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(item.kind.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(item.kind == .captured ? .green : .orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill((item.kind == .captured ? Color.green : Color.orange).opacity(0.12))
                )
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct DexFindsGrid: View {
    let entries: [DexEntrySummary]
    let emptyTitle: String
    let emptySubtitle: String
    let onSelect: (DexEntrySummary) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        if entries.isEmpty {
            DexTeaserEmptyState(
                title: emptyTitle,
                subtitle: emptySubtitle,
                systemImage: "sparkles.rectangle.stack"
            )
            .frame(minHeight: 98)
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(entries, id: \.speciesID) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        DexFindCard(entry: entry)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DexFindCard: View {
    let entry: DexEntrySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 4) {
                Text(String(format: "#%03d", entry.sortOrder))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: entry.status.systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(entry.status.tint)
            }

            HStack {
                Spacer(minLength: 0)
                TokenmonDexSpritePreview(
                    status: entry.status,
                    revealStage: TokenmonDexPresentation.revealStage(for: entry),
                    field: entry.field,
                    rarity: entry.rarity,
                    assetKey: entry.assetKey,
                    cardSize: 54,
                    spriteSize: 36
                )
                Spacer(minLength: 0)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(TokenmonDexPresentation.visibleSpeciesName(for: entry))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(entry.status == .captured ? TokenmonL10n.string("dex.status.captured") : TokenmonL10n.string("dex.status.seen"))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(entry.status.tint)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var cardFill: LinearGradient {
        LinearGradient(
            colors: [
                fieldTint.opacity(0.14),
                Color(nsColor: .windowBackgroundColor),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var borderColor: Color {
        entry.status.tint.opacity(0.22)
    }

    private var fieldTint: Color {
        switch entry.field {
        case .grassland:
            return Color(red: 0.27, green: 0.63, blue: 0.35)
        case .ice:
            return Color(red: 0.44, green: 0.72, blue: 0.96)
        case .coast:
            return Color(red: 0.17, green: 0.54, blue: 0.79)
        case .sky:
            return Color(red: 0.29, green: 0.54, blue: 0.88)
        }
    }
}

struct DexHiddenSlotsGrid: View {
    let entries: [DexEntrySummary]
    let onSelect: (DexEntrySummary) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        if entries.isEmpty {
            DexTeaserEmptyState(
                title: TokenmonL10n.string("dex.teaser.hidden.empty_title"),
                subtitle: TokenmonL10n.string("dex.teaser.hidden.empty_subtitle"),
                systemImage: "books.vertical"
            )
            .frame(minHeight: 110)
        } else {
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(entries, id: \.speciesID) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        DexHiddenSlotCard(entry: entry)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct DexHiddenSlotCard: View {
    let entry: DexEntrySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(String(format: "#%03d", entry.sortOrder))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: "lock.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer(minLength: 0)
                TokenmonDexSpritePreview(
                    status: entry.status,
                    revealStage: TokenmonDexPresentation.revealStage(for: entry),
                    field: entry.field,
                    rarity: entry.rarity,
                    assetKey: entry.assetKey,
                    cardSize: 54,
                    spriteSize: 36
                )
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(nsColor: .windowBackgroundColor),
                            Color.secondary.opacity(0.04),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct DexTeaserEmptyState: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
    }
}
