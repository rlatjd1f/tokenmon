import Foundation
import TokenmonDomain

/// Maintains per-session running token totals so each Gemini event can be
/// emitted with monotonic cumulative values that the existing ingest
/// validator and exploration accumulator already understand. The tracker
/// must be seeded from `latestGeminiSessionTotals` on receiver startup so
/// a process restart does not produce a downward jump.
public final class GeminiCumulativeTracker {
    private var totals: [String: GeminiSessionRunningTotals]

    public init(seed: [String: GeminiSessionRunningTotals]) {
        self.totals = seed
    }

    public func recordEvent(
        sessionID: String,
        inputTokens: Int64,
        outputTokens: Int64,
        cachedContentTokens: Int64,
        totalTokens: Int64
    ) -> GeminiSessionRunningTotals {
        let previous = totals[sessionID] ?? GeminiSessionRunningTotals(
            totalInputTokens: 0,
            totalOutputTokens: 0,
            totalCachedInputTokens: 0,
            normalizedTotalTokens: 0
        )
        let updated = GeminiSessionRunningTotals(
            totalInputTokens: previous.totalInputTokens + max(0, inputTokens),
            totalOutputTokens: previous.totalOutputTokens + max(0, outputTokens),
            totalCachedInputTokens: previous.totalCachedInputTokens + max(0, cachedContentTokens),
            normalizedTotalTokens: previous.normalizedTotalTokens + max(0, totalTokens)
        )
        totals[sessionID] = updated
        return updated
    }
}
