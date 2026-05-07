import Foundation
import TokenmonDomain

public struct CodexTranscriptBackfillAdapterConfig: Sendable {
    public let sessionIDFallback: String?
    public let nowProvider: @Sendable () -> String
    public let sourceMode: String
    public let rawReferenceKind: String
    public let sessionOriginHint: ProviderSessionOriginHint

    public init(
        sessionIDFallback: String? = nil,
        sourceMode: String = "codex_transcript_backfill",
        rawReferenceKind: String = "transcript_backfill",
        sessionOriginHint: ProviderSessionOriginHint = .unknown,
        nowProvider: @escaping @Sendable () -> String = {
            ISO8601DateFormatter().string(from: Date())
        }
    ) {
        self.sessionIDFallback = sessionIDFallback
        self.sourceMode = sourceMode
        self.rawReferenceKind = rawReferenceKind
        self.sessionOriginHint = sessionOriginHint
        self.nowProvider = nowProvider
    }
}

public struct CodexTranscriptBackfillImportResult: Sendable {
    public let sessionID: String
    public let events: [ProviderUsageSampleEvent]
}

public struct CodexTranscriptBackfillDeltaResult: Sendable {
    public let sessionID: String?
    public let events: [ProviderUsageSampleEvent]
    public let lastOffset: Int64
    public let lastLineNumber: Int
    public let lastEventFingerprint: String?
    public let encounteredTokenCount: Bool
}

public struct CodexTranscriptSessionMetadata: Sendable {
    public let sessionID: String?
    public let workspaceDir: String?
    public let modelSlug: String?
    public let lastOffset: Int64
    public let lastLineNumber: Int
}

public enum CodexTranscriptBackfillAdapterError: Error, LocalizedError {
    case missingSessionID
    case malformedLine(lineNumber: Int)
    case invalidTokenUsage(lineNumber: Int)
    case noUsageSamplesFound

    public var errorDescription: String? {
        switch self {
        case .missingSessionID:
            return "codex transcript backfill requires a session id from the transcript or hook payload"
        case .malformedLine(let lineNumber):
            return "codex transcript line \(lineNumber) is not valid JSON"
        case .invalidTokenUsage(let lineNumber):
            return "codex transcript line \(lineNumber) has invalid token_count payload"
        case .noUsageSamplesFound:
            return "codex transcript does not contain any recoverable token_count events"
        }
    }
}

public enum CodexTranscriptBackfillAdapter {
    public static func scanTranscriptMetadata(
        from transcriptPath: String,
        config: CodexTranscriptBackfillAdapterConfig = CodexTranscriptBackfillAdapterConfig()
    ) throws -> CodexTranscriptSessionMetadata {
        var sessionID = config.sessionIDFallback
        var workspaceDir: String?
        var modelSlug: String?
        var lastOffset: Int64 = 0
        var lastLineNumber = 0

        try ProviderInboxReader.readLines(from: transcriptPath, startingAt: 0) { line in
            let lineNumber = lastLineNumber + 1
            let trimmed = line.rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                if line.newlineTerminated {
                    lastOffset = line.nextOffset
                    lastLineNumber = lineNumber
                }
                return
            }

            if line.newlineTerminated == false {
                return
            }

            guard let jsonObject = try jsonObject(from: trimmed) else {
                throw CodexTranscriptBackfillAdapterError.malformedLine(lineNumber: lineNumber)
            }

            if jsonObject["type"] as? String == "session_meta",
               let payload = dictionaryValue(jsonObject["payload"]) {
                if let id = stringValue(payload["id"]) {
                    sessionID = id
                }
                workspaceDir = stringValue(payload["cwd"]) ?? workspaceDir
                modelSlug = stringValue(payload["model"]) ?? modelSlug
            }

            lastOffset = line.nextOffset
            lastLineNumber = lineNumber
        }

        return CodexTranscriptSessionMetadata(
            sessionID: sessionID,
            workspaceDir: workspaceDir,
            modelSlug: modelSlug,
            lastOffset: lastOffset,
            lastLineNumber: lastLineNumber
        )
    }

    public static func importTranscript(
        from transcriptPath: String,
        config: CodexTranscriptBackfillAdapterConfig = CodexTranscriptBackfillAdapterConfig()
    ) throws -> CodexTranscriptBackfillImportResult {
        let deltaResult = try scanTranscriptDelta(
            from: transcriptPath,
            startingAt: 0,
            startingLineNumber: 0,
            config: config
        )

        guard let resolvedSessionID = deltaResult.sessionID, resolvedSessionID.isEmpty == false else {
            throw CodexTranscriptBackfillAdapterError.missingSessionID
        }
        guard deltaResult.events.isEmpty == false else {
            throw CodexTranscriptBackfillAdapterError.noUsageSamplesFound
        }

        return CodexTranscriptBackfillImportResult(
            sessionID: resolvedSessionID,
            events: deltaResult.events
        )
    }

    public static func scanTranscriptDelta(
        from transcriptPath: String,
        startingAt offset: Int64,
        startingLineNumber: Int,
        config: CodexTranscriptBackfillAdapterConfig = CodexTranscriptBackfillAdapterConfig()
    ) throws -> CodexTranscriptBackfillDeltaResult {
        var sessionID = config.sessionIDFallback
        var workspaceDir: String?
        var modelSlug: String?
        var events: [ProviderUsageSampleEvent] = []
        var lastOffset = offset
        var lastLineNumber = startingLineNumber
        var lastEventFingerprint: String?
        var encounteredTokenCount = false

        try ProviderInboxReader.readLines(from: transcriptPath, startingAt: offset) { line in
            let lineNumber = lastLineNumber + 1
            let trimmed = line.rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                if line.newlineTerminated {
                    lastOffset = line.nextOffset
                    lastLineNumber = lineNumber
                }
                return
            }

            if line.newlineTerminated == false {
                return
            }

            guard let jsonObject = try jsonObject(from: trimmed) else {
                throw CodexTranscriptBackfillAdapterError.malformedLine(lineNumber: lineNumber)
            }

            if let payload = dictionaryValue(jsonObject["payload"]) {
                if jsonObject["type"] as? String == "session_meta" {
                    if let id = stringValue(payload["id"]) {
                        sessionID = id
                    }
                    workspaceDir = stringValue(payload["cwd"]) ?? workspaceDir
                    modelSlug = stringValue(payload["model"]) ?? modelSlug
                    lastOffset = line.nextOffset
                    lastLineNumber = lineNumber
                    return
                }

                guard jsonObject["type"] as? String == "event_msg",
                      payload["type"] as? String == "token_count" else {
                    lastOffset = line.nextOffset
                    lastLineNumber = lineNumber
                    return
                }

                encounteredTokenCount = true

                guard let info = dictionaryValue(payload["info"]),
                      let totalUsage = dictionaryValue(info["total_token_usage"]) else {
                    lastOffset = line.nextOffset
                    lastLineNumber = lineNumber
                    return
                }

                guard let inputTokens = int64Value(totalUsage["input_tokens"]),
                      let cachedInputTokens = int64Value(totalUsage["cached_input_tokens"]),
                      let outputTokens = int64Value(totalUsage["output_tokens"]),
                      inputTokens >= 0,
                      cachedInputTokens >= 0,
                      outputTokens >= 0,
                      (int64Value(totalUsage["total_tokens"]) ?? 0) >= 0 else {
                    throw CodexTranscriptBackfillAdapterError.invalidTokenUsage(lineNumber: lineNumber)
                }

                guard let resolvedSessionID = sessionID, resolvedSessionID.isEmpty == false else {
                    throw CodexTranscriptBackfillAdapterError.missingSessionID
                }

                let lastUsage = dictionaryValue(info["last_token_usage"])
                let currentInputTokens = lastUsage.flatMap { int64Value($0["input_tokens"]) }
                let currentOutputTokens = lastUsage.flatMap { int64Value($0["output_tokens"]) }
                let observedAt = stringValue(jsonObject["timestamp"]) ?? config.nowProvider()
                let accounting = ProviderTokenAccounting.codex(
                    totalInputTokens: inputTokens,
                    totalOutputTokens: outputTokens,
                    totalCachedInputTokens: cachedInputTokens,
                    providerTotalTokens: int64Value(totalUsage["total_tokens"]),
                    currentInputTokens: currentInputTokens,
                    currentOutputTokens: currentOutputTokens
                )

                let event = ProviderUsageSampleEvent(
                    eventType: "provider_usage_sample",
                    provider: .codex,
                    sourceMode: config.sourceMode,
                    providerSessionID: resolvedSessionID,
                    observedAt: observedAt,
                    workspaceDir: workspaceDir,
                    modelSlug: modelSlug,
                    transcriptPath: transcriptPath,
                    totalInputTokens: accounting.totalInputTokens,
                    totalOutputTokens: accounting.totalOutputTokens,
                    totalCachedInputTokens: accounting.totalCachedInputTokens,
                    normalizedTotalTokens: accounting.normalizedTotalTokens,
                    providerEventFingerprint: "codex:\(resolvedSessionID):\(inputTokens):\(cachedInputTokens):\(outputTokens)",
                    rawReference: ProviderRawReference(
                        kind: config.rawReferenceKind,
                        offset: String(lineNumber),
                        eventName: "token_count"
                    ),
                    currentInputTokens: accounting.currentInputTokens,
                    currentOutputTokens: accounting.currentOutputTokens,
                    sessionOriginHint: config.sessionOriginHint
                )
                events.append(event)
                lastEventFingerprint = event.providerEventFingerprint
            }

            lastOffset = line.nextOffset
            lastLineNumber = lineNumber
        }

        return CodexTranscriptBackfillDeltaResult(
            sessionID: sessionID,
            events: events,
            lastOffset: lastOffset,
            lastLineNumber: lastLineNumber,
            lastEventFingerprint: lastEventFingerprint,
            encounteredTokenCount: encounteredTokenCount
        )
    }

    private static func jsonObject(from rawLine: String) throws -> [String: Any]? {
        let data = Data(rawLine.utf8)
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any]
    }

    private static func dictionaryValue(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func stringValue(_ value: Any?) -> String? {
        if let string = value as? String, string.isEmpty == false {
            return string
        }
        return nil
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let string = value as? String, let parsed = Int64(string) {
            return parsed
        }
        return nil
    }
}
