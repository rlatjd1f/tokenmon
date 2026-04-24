import Foundation
import TokenmonDomain
import TokenmonProviders

public final class ClaudeOtelInboxWriter {
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
        event: ClaudeOtelSampleEvent,
        cumulativeInputTokens: Int64,
        cumulativeOutputTokens: Int64,
        cumulativeCachedInputTokens: Int64,
        cumulativeNormalizedTotalTokens: Int64
    ) throws {
        let observedAtString = timestampFormatter.string(from: event.observedAt)
        let accounting = ProviderTokenAccounting.claudeOtel(
            totalInputTokens: cumulativeInputTokens,
            totalOutputTokens: cumulativeOutputTokens,
            totalCachedInputTokens: cumulativeCachedInputTokens,
            normalizedTotalTokens: cumulativeNormalizedTotalTokens,
            currentInputTokens: event.inputTokens,
            currentOutputTokens: event.outputTokens
        )
        let payload = ProviderUsageSampleEvent(
            eventType: "provider_usage_sample",
            provider: .claude,
            sourceMode: "claude_otel_api_request_live",
            providerSessionID: event.sessionID,
            observedAt: observedAtString,
            workspaceDir: nil,
            modelSlug: event.model,
            transcriptPath: nil,
            totalInputTokens: accounting.totalInputTokens,
            totalOutputTokens: accounting.totalOutputTokens,
            totalCachedInputTokens: accounting.totalCachedInputTokens,
            normalizedTotalTokens: accounting.normalizedTotalTokens,
            providerEventFingerprint: fingerprint(for: event, observedAtString: observedAtString),
            rawReference: ProviderRawReference(
                kind: "claude-otel",
                offset: nil,
                eventName: "claude_code.api_request"
            ),
            currentInputTokens: accounting.currentInputTokens,
            currentOutputTokens: accounting.currentOutputTokens,
            sessionOriginHint: .startedDuringLiveRuntime
        )

        let jsonData = try encoder.encode(payload)
        var line = jsonData
        line.append(0x0A)

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

    private func fingerprint(for event: ClaudeOtelSampleEvent, observedAtString: String) -> String {
        if let requestID = event.requestID, requestID.isEmpty == false {
            return "claude-otel:\(event.sessionID):\(requestID)"
        }

        let sequence = event.eventSequence ?? "no-sequence"
        return "claude-otel:\(event.sessionID):\(sequence):\(observedAtString):\(event.model):\(event.totalTokens)"
    }
}
