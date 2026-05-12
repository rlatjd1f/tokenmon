import SwiftUI

enum TokenmonCollectionSection: String, CaseIterable, Hashable {
    case dex
    case rewards

    var title: String {
        switch self {
        case .dex:
            return TokenmonL10n.string("collection.section.dex")
        case .rewards:
            return TokenmonL10n.string("collection.section.rewards")
        }
    }
}

@MainActor
final class TokenmonCollectionNavigationState: ObservableObject {
    @Published var selectedSection: TokenmonCollectionSection

    init(selectedSection: TokenmonCollectionSection = .dex) {
        self.selectedSection = selectedSection
    }

    func show(_ section: TokenmonCollectionSection) {
        selectedSection = section
    }
}

struct TokenmonCollectionPanel: View {
    @ObservedObject var model: TokenmonMenuModel
    @ObservedObject var navigation: TokenmonCollectionNavigationState

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: navigation.selectedSection) { _, section in
            noteSectionOpened(section)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(TokenmonL10n.string("window.title.collection"))
                .font(.headline)

            Picker("", selection: $navigation.selectedSection) {
                ForEach(TokenmonCollectionSection.allCases, id: \.self) { section in
                    Text(section.title).tag(section)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch navigation.selectedSection {
        case .dex:
            TokenmonDexPanel(model: model)
        case .rewards:
            TokenmonRewardArchivePanel(model: model)
        }
    }

    private func noteSectionOpened(_ section: TokenmonCollectionSection) {
        switch section {
        case .dex:
            model.surfaceOpened(.dex, entrypoint: "collection_picker", emitAnalytics: false)
        case .rewards:
            model.surfaceOpened(.raid, entrypoint: "collection_picker", emitAnalytics: false)
        }
    }
}
