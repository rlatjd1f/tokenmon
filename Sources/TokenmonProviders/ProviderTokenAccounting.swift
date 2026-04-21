import Foundation

enum ProviderAccountingConfidence: String, Sendable {
    case providerReportedTotal = "provider_reported_total"
    case componentDerivedTotal = "component_derived_total"
}

enum ProviderAccountingSemantics: String, Sendable {
    case claudeStatusLineCumulativeTotals = "claude_statusline_cumulative_totals"
    case claudeTranscriptComponentTotals = "claude_transcript_component_totals"
    case codexProviderTotal = "codex_provider_total"
    case codexInputOutputFallback = "codex_input_output_fallback"
    case geminiProviderTotal = "gemini_provider_total"
    case cursorExportTotal = "cursor_export_total"
    case cursorComponentFallback = "cursor_component_fallback"
}

struct ProviderAccountingSample: Sendable {
    let totalInputTokens: Int64
    let totalOutputTokens: Int64
    let totalCachedInputTokens: Int64
    let normalizedTotalTokens: Int64
    let currentInputTokens: Int64?
    let currentOutputTokens: Int64?
    let confidence: ProviderAccountingConfidence
    let semantics: ProviderAccountingSemantics
}

enum ProviderTokenAccounting {
    static func claudeStatusLine(
        totalInputTokens: Int64,
        totalOutputTokens: Int64,
        currentInputTokens: Int64?,
        currentOutputTokens: Int64?
    ) -> ProviderAccountingSample {
        ProviderAccountingSample(
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalCachedInputTokens: 0,
            normalizedTotalTokens: totalInputTokens + totalOutputTokens,
            currentInputTokens: currentInputTokens,
            currentOutputTokens: currentOutputTokens,
            confidence: .componentDerivedTotal,
            semantics: .claudeStatusLineCumulativeTotals
        )
    }

    static func claudeTranscript(
        totalInputTokens: Int64,
        totalOutputTokens: Int64,
        totalCachedInputTokens: Int64,
        currentInputTokens: Int64?,
        currentOutputTokens: Int64?
    ) -> ProviderAccountingSample {
        ProviderAccountingSample(
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalCachedInputTokens: totalCachedInputTokens,
            normalizedTotalTokens: totalInputTokens + totalOutputTokens + totalCachedInputTokens,
            currentInputTokens: currentInputTokens,
            currentOutputTokens: currentOutputTokens,
            confidence: .componentDerivedTotal,
            semantics: .claudeTranscriptComponentTotals
        )
    }

    static func codex(
        totalInputTokens: Int64,
        totalOutputTokens: Int64,
        totalCachedInputTokens: Int64,
        providerTotalTokens: Int64?,
        currentInputTokens: Int64?,
        currentOutputTokens: Int64?
    ) -> ProviderAccountingSample {
        let normalizedTotalTokens = providerTotalTokens ?? (totalInputTokens + totalOutputTokens)
        return ProviderAccountingSample(
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalCachedInputTokens: totalCachedInputTokens,
            normalizedTotalTokens: normalizedTotalTokens,
            currentInputTokens: currentInputTokens,
            currentOutputTokens: currentOutputTokens,
            confidence: providerTotalTokens == nil ? .componentDerivedTotal : .providerReportedTotal,
            semantics: providerTotalTokens == nil ? .codexInputOutputFallback : .codexProviderTotal
        )
    }

    static func gemini(
        totalInputTokens: Int64,
        totalOutputTokens: Int64,
        totalCachedInputTokens: Int64,
        normalizedTotalTokens: Int64,
        currentInputTokens: Int64?,
        currentOutputTokens: Int64?
    ) -> ProviderAccountingSample {
        ProviderAccountingSample(
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalCachedInputTokens: totalCachedInputTokens,
            normalizedTotalTokens: normalizedTotalTokens,
            currentInputTokens: currentInputTokens,
            currentOutputTokens: currentOutputTokens,
            confidence: .providerReportedTotal,
            semantics: .geminiProviderTotal
        )
    }

    static func cursor(
        totalInputTokens: Int64,
        totalOutputTokens: Int64,
        totalCachedInputTokens: Int64,
        normalizedTotalTokens: Int64,
        currentInputTokens: Int64?,
        currentOutputTokens: Int64?,
        usedExplicitTotal: Bool
    ) -> ProviderAccountingSample {
        ProviderAccountingSample(
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            totalCachedInputTokens: totalCachedInputTokens,
            normalizedTotalTokens: normalizedTotalTokens,
            currentInputTokens: currentInputTokens,
            currentOutputTokens: currentOutputTokens,
            confidence: usedExplicitTotal ? .providerReportedTotal : .componentDerivedTotal,
            semantics: usedExplicitTotal ? .cursorExportTotal : .cursorComponentFallback
        )
    }
}
