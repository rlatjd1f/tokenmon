import SwiftUI

enum TokenmonPopoverTab: Hashable {
    case now, raid, stats, dex, tokens
}

struct TokenmonPopoverSidebarActions {
    let openSettings: () -> Void
    let quit: () -> Void
    let openDeveloperTools: (() -> Void)?
    var toggleFloatingPanelPin: (() -> Void)? = nil
    var floatingPanelPinned = false
}

struct TokenmonPopoverSidebar: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var activeTab: TokenmonPopoverTab
    let actions: TokenmonPopoverSidebarActions

    var body: some View {
        VStack(spacing: 6) {
            tabButton(.now, systemImage: "dot.radiowaves.left.and.right", tooltip: TokenmonL10n.string("popover.tab.now"))
            tabButton(.raid, systemImage: "shield.lefthalf.filled", tooltip: TokenmonL10n.string("popover.tab.raid"))
            tabButton(.tokens, systemImage: "bolt.fill", tooltip: TokenmonL10n.string("popover.tab.tokens"))
            tabButton(.stats, systemImage: "chart.bar.fill", tooltip: TokenmonL10n.string("popover.tab.stats"))
            tabButton(.dex, systemImage: "books.vertical.fill", tooltip: TokenmonL10n.string("window.title.dex"))

            if let toggleFloatingPanelPin = actions.toggleFloatingPanelPin {
                pinButton(isPinned: actions.floatingPanelPinned, action: toggleFloatingPanelPin)
            }

            Spacer(minLength: 0)

            Divider().padding(.horizontal, 8)

            ForEach(TokenmonBrandLink.allCases) { link in
                linkButton(link: link)
            }

            actionButton(systemImage: "gearshape.fill", tooltip: TokenmonL10n.string("window.title.settings"), action: actions.openSettings)
            actionButton(systemImage: "power", tooltip: TokenmonL10n.string("popover.action.quit"), action: actions.quit)

            if let openDeveloperTools = actions.openDeveloperTools {
                actionButton(systemImage: "wrench.and.screwdriver.fill", tooltip: TokenmonL10n.string("window.title.developer_tools"), action: openDeveloperTools)
            }
        }
        .padding(.vertical, 10)
        .frame(width: 52)
        .background(Color.secondary.opacity(0.06))
    }

    private func pinButton(isPinned: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: isPinned ? "pin.fill" : "pin")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isPinned ? Color.white : Color.secondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isPinned ? Color.accentColor : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(TokenmonL10n.string("floating_panel.pin.tooltip"))
    }

    @ViewBuilder
    private func tabButton(
        _ tab: TokenmonPopoverTab,
        systemImage: String,
        tooltip: String
    ) -> some View {
        Button {
            activeTab = tab
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(activeTab == tab ? Color.white : Color.secondary)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(activeTab == tab ? Color.accentColor : Color.clear)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    @ViewBuilder
    private func actionButton(
        systemImage: String,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    @ViewBuilder
    private func linkButton(link: TokenmonBrandLink) -> some View {
        Link(destination: link.destination) {
            linkIcon(for: link)
                .frame(width: 36, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(TokenmonL10n.string(link.titleKey))
    }

    @ViewBuilder
    private func linkIcon(for link: TokenmonBrandLink) -> some View {
        if let mark = link.brandMarkImage(forDarkAppearance: colorScheme == .dark) {
            Image(nsImage: mark)
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.secondary)
        } else {
            Image(systemName: link.compactSymbolName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
    }
}
