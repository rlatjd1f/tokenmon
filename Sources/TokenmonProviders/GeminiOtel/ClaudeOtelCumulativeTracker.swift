import Foundation
import TokenmonDomain

public final class ClaudeOtelCumulativeTracker {
    private var totals: [String: GeminiSessionRunningTotals]

    public init(seed: [String: GeminiSessionRunningTotals]) {
        self.totals = seed
    }

    public func recordEvent(_ event: ClaudeOtelSampleEvent) -> GeminiSessionRunningTotals {
        let previous = totals[event.sessionID] ?? GeminiSessionRunningTotals(
            totalInputTokens: 0,
            totalOutputTokens: 0,
            totalCachedInputTokens: 0,
            normalizedTotalTokens: 0
        )
        let updated = GeminiSessionRunningTotals(
            totalInputTokens: previous.totalInputTokens + max(0, event.inputTokens),
            totalOutputTokens: previous.totalOutputTokens + max(0, event.outputTokens),
            totalCachedInputTokens: previous.totalCachedInputTokens + max(0, event.cachedInputTokens),
            normalizedTotalTokens: previous.normalizedTotalTokens + max(0, event.totalTokens)
        )
        totals[event.sessionID] = updated
        return updated
    }
}
