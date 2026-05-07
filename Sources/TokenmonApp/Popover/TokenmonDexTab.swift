import SwiftUI
import TokenmonPersistence

/// Dex tab content: grouped rarity grid inside the popover with a single
/// handoff into the full Dex browser for deeper browsing and species details.
struct TokenmonDexTab: View {
    @ObservedObject var model: TokenmonMenuModel
    let contentWidth: CGFloat
    let onOpenFullDex: () -> Void
    let onSelectSpecies: (DexEntrySummary) -> Void

    private var progress: TokenmonDexCollectionProgress {
        TokenmonDexPresentation.progress(for: model.dexEntries)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TokenmonDexCompletionStrip(progress: progress, layout: .compactGrid)

            if model.dexEntries.isEmpty {
                ContentUnavailableView(
                    TokenmonL10n.string("dex.tab.unavailable_title"),
                    systemImage: "books.vertical",
                    description: Text(TokenmonL10n.string("dex.tab.unavailable_description"))
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                DexPreviewGrid(model: model, entries: model.dexEntries, onSelect: onSelectSpecies)
            }

            Button(action: onOpenFullDex) {
                Label(TokenmonL10n.string("dex.tab.open_full"), systemImage: "books.vertical.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 10)
        .frame(width: contentWidth, alignment: .topLeading)
    }
}
