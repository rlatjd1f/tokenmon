import SwiftUI

let tokenmonCollectionSidebarWidth: CGFloat = 220
let tokenmonCollectionMinimumWidth: CGFloat = 1_000
let tokenmonCollectionIdealWidth: CGFloat = 1_120
let tokenmonCollectionMinimumHeight: CGFloat = 640
let tokenmonCollectionIdealHeight: CGFloat = 720

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

    var systemImage: String {
        switch self {
        case .dex:
            return "books.vertical.fill"
        case .rewards:
            return "shippingbox.fill"
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
        content
        .frame(
            minWidth: tokenmonCollectionMinimumWidth,
            idealWidth: tokenmonCollectionIdealWidth,
            maxWidth: .infinity,
            minHeight: tokenmonCollectionMinimumHeight,
            idealHeight: tokenmonCollectionIdealHeight,
            maxHeight: .infinity
        )
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: navigation.selectedSection) { _, section in
            noteSectionOpened(section)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch navigation.selectedSection {
        case .dex:
            TokenmonDexPanel(model: model, collectionNavigation: navigation)
        case .rewards:
            TokenmonRewardArchivePanel(model: model, collectionNavigation: navigation)
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

struct TokenmonCollectionSidebarHeader: View {
    @ObservedObject var navigation: TokenmonCollectionNavigationState

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(TokenmonCollectionSection.allCases, id: \.self) { section in
                Button {
                    navigation.show(section)
                } label: {
                    TokenmonCollectionSidebarRow(
                        title: section.title,
                        systemImage: section.systemImage
                    )
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(section == navigation.selectedSection ? Color.accentColor.opacity(0.16) : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TokenmonCollectionSidebarGroupTitle: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.top, 4)
    }
}

struct TokenmonCollectionSidebarRow: View {
    let title: String
    let systemImage: String
    var countText: String?

    var body: some View {
        HStack {
            Label {
                Text(title)
                    .lineLimit(1)
            } icon: {
                Image(systemName: systemImage)
            }
            .layoutPriority(1)

            Spacer(minLength: 4)

            if let countText {
                Text(countText)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
