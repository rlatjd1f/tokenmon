import SwiftUI
import TokenmonDomain
import TokenmonPersistence

/// Stats tab content: dex completion donut, rarity distribution, field distribution, 7-day trend.
struct TokenmonStatsTab: View {
    @ObservedObject var model: TokenmonMenuModel
    let contentWidth: CGFloat

    private var totalSpecies: Int { model.dexEntries.count }
    private var seenCount: Int { model.dexEntries.filter { $0.status != .unknown }.count }
    private var capturedCount: Int { model.dexEntries.filter { $0.status == .captured }.count }

    private var rarityCounts: [RarityTier: Int] {
        var result: [RarityTier: Int] = [:]
        for entry in model.dexEntries where entry.status == .captured {
            result[entry.rarity, default: 0] += 1
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            section(title: TokenmonL10n.string("stats.dex_progress")) {
                DexCompletionDonut(
                    seenCount: seenCount,
                    capturedCount: capturedCount,
                    totalCount: totalSpecies
                )
                .frame(maxWidth: .infinity)
            }

            section(title: TokenmonL10n.string("stats.rarity")) {
                RarityStackedBar(counts: rarityCounts)
            }

            section(title: TokenmonL10n.string("stats.field_activity")) {
                FieldDistributionBars(counts: model.fieldDistribution)
                    .frame(maxWidth: .infinity)
            }

            section(title: TokenmonL10n.string("stats.last_7_days")) {
                DailyTrendBars(buckets: model.dailyTrend)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(width: contentWidth, alignment: .topLeading)
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            content()
        }
    }
}
