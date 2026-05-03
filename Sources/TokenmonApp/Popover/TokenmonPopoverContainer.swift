import SwiftUI
import TokenmonPersistence

enum TokenmonPopoverLayoutStyle: String, CaseIterable {
    case heroV2 = "hero-v2"
    case compact

    var width: CGFloat {
        switch self {
        case .heroV2:
            return 560
        case .compact:
            return 360
        }
    }

    var height: CGFloat {
        switch self {
        case .heroV2:
            return 720
        case .compact:
            return 520
        }
    }

    var contentWidth: CGFloat {
        switch self {
        case .heroV2:
            return 528
        case .compact:
            return 300
        }
    }

    var contentHeight: CGFloat {
        switch self {
        case .heroV2:
            return height - 58
        case .compact:
            return height
        }
    }

    static func fromOption(_ option: String?) -> TokenmonPopoverLayoutStyle {
        switch option?.lowercased() {
        case "compact":
            return .compact
        case "hero-v2", "herov2", "wide", nil:
            return .heroV2
        default:
            return .heroV2
        }
    }
}

struct TokenmonPopoverContainerActions {
    let openFullDex: () -> Void
    let openRewardArchive: () -> Void
    let openSettings: (TokenmonSettingsPane) -> Void
    let openDeveloperTools: (() -> Void)?
    let quit: () -> Void
    let selectSpecies: (DexEntrySummary) -> Void
}

struct TokenmonPopoverContainer: View {
    static let width: CGFloat = TokenmonPopoverLayoutStyle.heroV2.width
    static let height: CGFloat = TokenmonPopoverLayoutStyle.heroV2.height
    static let contentWidth: CGFloat = TokenmonPopoverLayoutStyle.heroV2.contentWidth
    static let compactWidth: CGFloat = TokenmonPopoverLayoutStyle.compact.width
    static let compactHeight: CGFloat = TokenmonPopoverLayoutStyle.compact.height
    static let compactContentWidth: CGFloat = TokenmonPopoverLayoutStyle.compact.contentWidth

    @ObservedObject var model: TokenmonMenuModel
    let actions: TokenmonPopoverContainerActions
    let layoutStyle: TokenmonPopoverLayoutStyle

    @State private var activeTab: TokenmonPopoverTab = .now

    init(
        model: TokenmonMenuModel,
        actions: TokenmonPopoverContainerActions,
        initialActiveTab: TokenmonPopoverTab = .now,
        layoutStyle: TokenmonPopoverLayoutStyle = .heroV2
    ) {
        self.model = model
        self.actions = actions
        self.layoutStyle = layoutStyle
        _activeTab = State(initialValue: initialActiveTab)
    }

    static func refreshSurfaceForActivation(
        activeTab: TokenmonPopoverTab,
        runtimeLoaded: Bool
    ) -> TokenmonRefreshSurface? {
        switch activeTab {
        case .now:
            return runtimeLoaded ? nil : .now
        case .raid:
            return .raid
        case .tokens:
            return .tokens
        case .stats:
            return .stats
        case .dex:
            return .dex
        }
    }

    static func analyticsSurface(for activeTab: TokenmonPopoverTab) -> TokenmonRefreshSurface {
        switch activeTab {
        case .now:
            return .now
        case .raid:
            return .raid
        case .tokens:
            return .tokens
        case .stats:
            return .stats
        case .dex:
            return .dex
        }
    }

    var body: some View {
        shell
            .frame(width: layoutStyle.width, height: layoutStyle.height)
            .onAppear {
                prewarmActiveTabIfNeeded()
            }
            .onChange(of: activeTab) { _, _ in
                prewarmActiveTabIfNeeded()
            }
            .background(hiddenKeyboardShortcuts)
    }

    @ViewBuilder
    private var shell: some View {
        switch layoutStyle {
        case .heroV2:
            VStack(spacing: 0) {
                TokenmonPopoverTopNavigation(
                    activeTab: $activeTab,
                    actions: TokenmonPopoverTopNavigationActions(
                        openSettings: { actions.openSettings(.general) },
                        quit: actions.quit,
                        openDeveloperTools: actions.openDeveloperTools
                    )
                )
                .frame(height: 57)

                Divider()

                content
                    .frame(
                        width: layoutStyle.contentWidth,
                        height: layoutStyle.contentHeight,
                        alignment: .topLeading
                    )
                    .clipped()
            }
            .background(Color(nsColor: .windowBackgroundColor))
        case .compact:
            compactShell
        }
    }

    private var compactShell: some View {
        HStack(spacing: 0) {
            content
                .frame(width: layoutStyle.contentWidth, height: layoutStyle.height, alignment: .topLeading)

            Divider()

            TokenmonPopoverSidebar(
                activeTab: $activeTab,
                actions: TokenmonPopoverSidebarActions(
                    openSettings: { actions.openSettings(.general) },
                    quit: actions.quit,
                    openDeveloperTools: actions.openDeveloperTools
                )
            )
        }
    }

    private var hiddenKeyboardShortcuts: some View {
        // Hidden hotkey buttons for ⌘1 / ⌘2 / ⌘3 / ⌘4 / ⌘5.
        HStack {
            Button(TokenmonL10n.string("popover.tab.now")) { activeTab = .now }
                .keyboardShortcut("1", modifiers: [.command])
            Button(TokenmonL10n.string("popover.tab.raid")) { activeTab = .raid }
                .keyboardShortcut("2", modifiers: [.command])
            Button(TokenmonL10n.string("popover.tab.tokens")) { activeTab = .tokens }
                .keyboardShortcut("3", modifiers: [.command])
            Button(TokenmonL10n.string("popover.tab.stats")) { activeTab = .stats }
                .keyboardShortcut("4", modifiers: [.command])
            Button(TokenmonL10n.string("window.title.dex")) { activeTab = .dex }
                .keyboardShortcut("5", modifiers: [.command])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
    }

    @ViewBuilder
    private var content: some View {
        switch activeTab {
        case .now:
            TokenmonNowTab(
                model: model,
                layoutStyle: layoutStyle,
                contentWidth: layoutStyle.contentWidth,
                onOpenProviderSettings: { actions.openSettings(.providers) },
                onOpenScout: { activeTab = .dex }
            )
        case .raid:
            TokenmonRaidTab(
                model: model,
                contentWidth: layoutStyle.contentWidth,
                onOpenRewardArchive: actions.openRewardArchive
            )
        case .stats:
            TokenmonStatsTab(model: model, contentWidth: layoutStyle.contentWidth)
        case .dex:
            TokenmonDexTab(
                model: model,
                contentWidth: layoutStyle.contentWidth,
                onOpenFullDex: actions.openFullDex,
                onSelectSpecies: actions.selectSpecies
            )
        case .tokens:
            TokenmonTokensTab(model: model, contentWidth: layoutStyle.contentWidth)
        }
    }

    private func prewarmActiveTabIfNeeded() {
        let surface = Self.analyticsSurface(for: activeTab)
        let shouldRefresh = Self.refreshSurfaceForActivation(
            activeTab: activeTab,
            runtimeLoaded: model.runtimeSnapshot.isLoaded
        ) != nil

        model.surfaceOpened(
            surface,
            entrypoint: "popover_tab",
            refresh: shouldRefresh
        )
    }
}

struct TokenmonPopoverTopNavigationActions {
    let openSettings: () -> Void
    let quit: () -> Void
    let openDeveloperTools: (() -> Void)?
}

private struct TokenmonPopoverTopNavigation: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var activeTab: TokenmonPopoverTab
    let actions: TokenmonPopoverTopNavigationActions

    var body: some View {
        HStack(spacing: 10) {
            Picker("", selection: $activeTab) {
                Text(TokenmonL10n.string("popover.tab.now")).tag(TokenmonPopoverTab.now)
                Text(TokenmonL10n.string("popover.tab.raid")).tag(TokenmonPopoverTab.raid)
                Text(TokenmonL10n.string("popover.tab.tokens")).tag(TokenmonPopoverTab.tokens)
                Text(TokenmonL10n.string("window.title.dex")).tag(TokenmonPopoverTab.dex)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)

            Menu {
                Button {
                    activeTab = .stats
                } label: {
                    Label(TokenmonL10n.string("popover.tab.stats"), systemImage: "chart.bar.fill")
                }

                Divider()

                ForEach(TokenmonBrandLink.allCases) { link in
                    Link(destination: link.destination) {
                        Label(TokenmonL10n.string(link.compactTitleKey), systemImage: link.compactSymbolName)
                    }
                }

                Divider()

                Button {
                    actions.openSettings()
                } label: {
                    Label(TokenmonL10n.string("window.title.settings"), systemImage: "gearshape.fill")
                }

                if let openDeveloperTools = actions.openDeveloperTools {
                    Button {
                        openDeveloperTools()
                    } label: {
                        Label(TokenmonL10n.string("window.title.developer_tools"), systemImage: "wrench.and.screwdriver.fill")
                    }
                }

                Button {
                    actions.quit()
                } label: {
                    Label(TokenmonL10n.string("popover.action.quit"), systemImage: "power")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .help(TokenmonL10n.string("popover.menu.more"))
        }
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor).opacity(colorScheme == .dark ? 0.96 : 0.92),
                    Color(nsColor: .windowBackgroundColor).opacity(0.90),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
