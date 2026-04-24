import Foundation
import TokenmonDomain
import TokenmonProviders

/// Appends one ProviderUsageSampleEvent JSON line per Gemini api_response
/// to the gemini.ndjson inbox file. The cumulative token totals are passed
/// in by the caller (the receiver maintains them per session in memory and
/// seeds them from the database on startup).
public final class GeminiOtelInboxWriter {
    private let inboxPath: String
    private let encoder: JSONEncoder
    private let timestampFormatter: ISO8601DateFormatter

    public init(inboxPath: String) {
        self.inboxPath = inboxPath
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        self.encoder = encoder
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        self.timestampFormatter = formatter
    }

    public func append(
        event: GeminiSampleEvent,
        cumulativeInputTokens: Int64,
        cumulativeOutputTokens: Int64,
        cumulativeCachedInputTokens: Int64,
        cumulativeNormalizedTotalTokens: Int64
    ) throws {
        let observedAtString = timestampFormatter.string(from: event.observedAt)
        let fingerprint = "gemini-otel:\(event.sessionID):\(observedAtString):\(event.totalTokens)"
        let accounting = ProviderTokenAccounting.gemini(
            totalInputTokens: cumulativeInputTokens,
            totalOutputTokens: cumulativeOutputTokens,
            totalCachedInputTokens: cumulativeCachedInputTokens,
            normalizedTotalTokens: cumulativeNormalizedTotalTokens,
            currentInputTokens: event.inputTokens,
            currentOutputTokens: event.outputTokens
        )

        let payload = ProviderUsageSampleEvent(
            eventType: "provider_usage_sample",
            provider: .gemini,
            sourceMode: "otel-inprocess",
            providerSessionID: event.sessionID,
            observedAt: observedAtString,
            workspaceDir: nil,
            modelSlug: event.model,
            transcriptPath: nil,
            totalInputTokens: accounting.totalInputTokens,
            totalOutputTokens: accounting.totalOutputTokens,
            totalCachedInputTokens: accounting.totalCachedInputTokens,
            normalizedTotalTokens: accounting.normalizedTotalTokens,
            providerEventFingerprint: fingerprint,
            rawReference: ProviderRawReference(
                kind: "gemini-otel",
                offset: nil,
                eventName: "gemini_cli.api_response"
            ),
            currentInputTokens: accounting.currentInputTokens,
            currentOutputTokens: accounting.currentOutputTokens
        )

        let jsonData = try encoder.encode(payload)
        var line = jsonData
        line.append(0x0A) // newline

        let directory = (inboxPath as NSString).deletingLastPathComponent
        try FileManager.default.createDirectory(
            atPath: directory,
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: inboxPath) == false {
            FileManager.default.createFile(atPath: inboxPath, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: URL(fileURLWithPath: inboxPath))
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
    }
}
