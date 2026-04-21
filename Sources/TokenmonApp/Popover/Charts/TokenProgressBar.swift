import SwiftUI

/// Horizontal progress bar showing abstract field steps toward the next encounter.
/// The underlying accumulator is token-derived, but the Now surface uses steps
/// so gameplay progress does not look like raw dashboard token accounting.
struct TokenProgressBar: View {
    let currentTokens: Int64
    let totalTokens: Int64
    let segmentCount: Int

    @State private var isInfoPresented = false
    private let totalSteps = 100

    private var fraction: Double {
        guard totalTokens > 0 else { return 0 }
        return min(1.0, max(0.0, Double(currentTokens) / Double(totalTokens)))
    }

    private var currentSteps: Int {
        min(totalSteps, max(0, Int((fraction * Double(totalSteps)).rounded(.down))))
    }

    private var remainingSteps: Int {
        max(0, totalSteps - currentSteps)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(TokenmonL10n.format("progress.steps.remaining", remainingSteps))
                    .font(.subheadline.weight(.semibold))
                Button {
                    isInfoPresented.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help(TokenmonL10n.string("now.progress.live_only_note"))
                .popover(isPresented: $isInfoPresented, arrowEdge: .top) {
                    Text(TokenmonL10n.string("now.progress.live_only_note"))
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(width: 280, alignment: .leading)
                        .padding(14)
                }
                Spacer()
                Text(TokenmonL10n.string("progress.until_next_encounter"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.18))

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.green, Color.cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * fraction))
                        .animation(.easeOut(duration: 0.2), value: fraction)

                    HStack(spacing: 0) {
                        ForEach(1..<max(segmentCount, 2), id: \.self) { _ in
                            Spacer()
                            Rectangle()
                                .fill(Color.white.opacity(0.35))
                                .frame(width: 1)
                        }
                        Spacer()
                    }
                }
            }
            .frame(height: 12)
        }
    }
}

#if XCODE
#Preview("TokenProgressBar — partway") {
    TokenProgressBar(currentTokens: 3_200_000, totalTokens: 6_100_000, segmentCount: 10)
        .padding()
        .frame(width: 300)
}

#Preview("TokenProgressBar — empty") {
    TokenProgressBar(currentTokens: 0, totalTokens: 5_800_000, segmentCount: 10)
        .padding()
        .frame(width: 300)
}

#Preview("TokenProgressBar — full") {
    TokenProgressBar(currentTokens: 6_200_000, totalTokens: 6_200_000, segmentCount: 10)
        .padding()
        .frame(width: 300)
}
#endif
