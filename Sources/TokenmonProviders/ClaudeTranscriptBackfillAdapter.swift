import Foundation
import TokenmonDomain

public struct ClaudeTranscriptBackfillAdapterConfig: Sendable {
    public let sessionIDFallback: String?
    public let sourceMode: String
    public let rawReferenceKind: String
    public let sessionOriginHint: ProviderSessionOriginHint
    public let nowProvider: @Sendable () -> String

    public init(
        sessionIDFallback: String? = nil,
        sourceMode: String = "claude_transcript_backfill",
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

public struct ClaudeTranscriptBackfillImportResult: Sendable {
    public let sessionID: String
    public let events: [ProviderUsageSampleEvent]
    public let collapsedDuplicateMessages: Int
}

public enum ClaudeTranscriptBackfillAdapterError: Error, LocalizedError {
    case missingSessionID
    case conflictingSessionID(expected: String, found: String, lineNumber: Int)
    case malformedLine(lineNumber: Int)
    case invalidUsageTokens(lineNumber: Int)
    case noUsageSamplesFound

    public var errorDescription: String? {
        switch self {
        case .missingSessionID:
            return "claude transcript backfill requires a session id from the transcript or --session-id"
        case .conflictingSessionID(let expected, let found, let lineNumber):
            return "claude transcript line \(lineNumber) has conflicting session id \(found); expected \(expected)"
        case .malformedLine(let lineNumber):
            return "claude transcript line \(lineNumber) is not valid JSON"
        case .invalidUsageTokens(let lineNumber):
            return "claude transcript line \(lineNumber) has invalid usage tokens"
        case .noUsageSamplesFound:
            return "claude transcript does not contain any recoverable usage-bearing assistant messages"
        }
    }
}

private struct ClaudeTranscriptAggregatedStep {
    var firstLineNumber: Int
    var observedAt: String?
    var workspaceDir: String?
    var modelSlug: String?
    var inputTokens: Int64
    var outputTokens: Int64
    var cachedInputTokens: Int64
}

public enum ClaudeTranscriptBackfillAdapter {
    public static func importTranscript(
        from transcriptPath: String,
        config: ClaudeTranscriptBackfillAdapterConfig = ClaudeTranscriptBackfillAdapterConfig()
    ) throws -> ClaudeTranscriptBackfillImportResult {
        let readResult = try ProviderInboxReader.read(from: transcriptPath)

        var resolvedSessionID = config.sessionIDFallback
        var stepsByMessageID: [String: ClaudeTranscriptAggregatedStep] = [:]
        var messageOrder: [String] = []
        var collapsedDuplicateMessages = 0

        for (index, line) in readResult.lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                continue
            }

            if line.newlineTerminated == false {
                // Ignore an in-flight partial trailing line during recovery scans.
                continue
            }

            guard let jsonObject = try jsonObject(from: trimmed) else {
                throw ClaudeTranscriptBackfillAdapterError.malformedLine(lineNumber: lineNumber)
            }

            if let lineSessionID = extractSessionID(from: jsonObject) {
                if let resolvedSessionID, resolvedSessionID != lineSessionID {
                    throw ClaudeTranscriptBackfillAdapterError.conflictingSessionID(
                        expected: resolvedSessionID,
                        found: lineSessionID,
                        lineNumber: lineNumber
                    )
                }
                resolvedSessionID = lineSessionID
            }

            guard let usage = extractUsage(from: jsonObject),
                  let messageID = extractMessageID(from: jsonObject) else {
                continue
            }

            guard usage.inputTokens >= 0,
                  usage.outputTokens >= 0,
                  usage.cachedInputTokens >= 0 else {
                throw ClaudeTranscriptBackfillAdapterError.invalidUsageTokens(lineNumber: lineNumber)
            }

            let observedAt = extractObservedAt(from: jsonObject) ?? config.nowProvider()
            let workspaceDir = extractWorkspaceDir(from: jsonObject)
            let modelSlug = extractModelSlug(from: jsonObject)

            if var existing = stepsByMessageID[messageID] {
                collapsedDuplicateMessages += 1
                existing.observedAt = observedAt
                existing.workspaceDir = workspaceDir ?? existing.workspaceDir
                existing.modelSlug = modelSlug ?? existing.modelSlug
                existing.inputTokens = max(existing.inputTokens, usage.inputTokens)
                existing.outputTokens = max(existing.outputTokens, usage.outputTokens)
                existing.cachedInputTokens = max(existing.cachedInputTokens, usage.cachedInputTokens)
                stepsByMessageID[messageID] = existing
            } else {
                messageOrder.append(messageID)
                stepsByMessageID[messageID] = ClaudeTranscriptAggregatedStep(
                    firstLineNumber: lineNumber,
                    observedAt: observedAt,
                    workspaceDir: workspaceDir,
                    modelSlug: modelSlug,
                    inputTokens: usage.inputTokens,
                    outputTokens: usage.outputTokens,
                    cachedInputTokens: usage.cachedInputTokens
                )
            }
        }

        guard let sessionID = resolvedSessionID, sessionID.isEmpty == false else {
            throw ClaudeTranscriptBackfillAdapterError.missingSessionID
        }

        let orderedSteps = messageOrder.compactMap { messageID -> ClaudeTranscriptAggregatedStep? in
            stepsByMessageID[messageID]
        }
        guard orderedSteps.isEmpty == false else {
            throw ClaudeTranscriptBackfillAdapterError.noUsageSamplesFound
        }

        var cumulativeInputTokens: Int64 = 0
        var cumulativeOutputTokens: Int64 = 0
        var cumulativeCachedInputTokens: Int64 = 0

        let events = orderedSteps.map { step in
            cumulativeInputTokens += step.inputTokens
            cumulativeOutputTokens += step.outputTokens
            cumulativeCachedInputTokens += step.cachedInputTokens
            let accounting = ProviderTokenAccounting.claudeTranscript(
                totalInputTokens: cumulativeInputTokens,
                totalOutputTokens: cumulativeOutputTokens,
                totalCachedInputTokens: cumulativeCachedInputTokens,
                currentInputTokens: step.inputTokens,
                currentOutputTokens: step.outputTokens
            )

            return ProviderUsageSampleEvent(
                eventType: "provider_usage_sample",
                provider: .claude,
                sourceMode: config.sourceMode,
                providerSessionID: sessionID,
                observedAt: step.observedAt ?? config.nowProvider(),
                workspaceDir: step.workspaceDir,
                modelSlug: step.modelSlug,
                transcriptPath: transcriptPath,
                totalInputTokens: accounting.totalInputTokens,
                totalOutputTokens: accounting.totalOutputTokens,
                totalCachedInputTokens: accounting.totalCachedInputTokens,
                normalizedTotalTokens: accounting.normalizedTotalTokens,
                providerEventFingerprint: "claude:\(sessionID):\(cumulativeInputTokens):\(cumulativeOutputTokens)",
                rawReference: ProviderRawReference(
                    kind: config.rawReferenceKind,
                    offset: String(step.firstLineNumber),
                    eventName: "assistant"
                ),
                currentInputTokens: accounting.currentInputTokens,
                currentOutputTokens: accounting.currentOutputTokens,
                sessionOriginHint: config.sessionOriginHint
            )
        }

        return ClaudeTranscriptBackfillImportResult(
            sessionID: sessionID,
            events: events,
            collapsedDuplicateMessages: collapsedDuplicateMessages
        )
    }

    private static func jsonObject(from rawLine: String) throws -> [String: Any]? {
        let data = Data(rawLine.utf8)
        let value = try JSONSerialization.jsonObject(with: data)
        return value as? [String: Any]
    }

    private static func extractSessionID(from jsonObject: [String: Any]) -> String? {
        stringValue(jsonObject["session_id"])
            ?? stringValue(jsonObject["sessionId"])
    }

    private static func extractMessageID(from jsonObject: [String: Any]) -> String? {
        if let message = dictionaryValue(jsonObject["message"]) {
            return stringValue(message["id"])
                ?? stringValue(message["message_id"])
        }

        return stringValue(jsonObject["message_id"])
            ?? stringValue(jsonObject["id"])
    }

    private static func extractObservedAt(from jsonObject: [String: Any]) -> String? {
        if let message = dictionaryValue(jsonObject["message"]) {
            return stringValue(message["timestamp"])
                ?? stringValue(message["created_at"])
        }

        return stringValue(jsonObject["timestamp"])
            ?? stringValue(jsonObject["created_at"])
    }

    private static func extractWorkspaceDir(from jsonObject: [String: Any]) -> String? {
        if let workspace = dictionaryValue(jsonObject["workspace"]) {
            return stringValue(workspace["current_dir"])
        }

        return stringValue(jsonObject["cwd"])
            ?? stringValue(jsonObject["current_dir"])
    }

    private static func extractModelSlug(from jsonObject: [String: Any]) -> String? {
        if let message = dictionaryValue(jsonObject["message"]) {
            if let model = dictionaryValue(message["model"]) {
                return stringValue(model["id"]) ?? stringValue(model["display_name"])
            }
            if let modelSlug = stringValue(message["model"]) {
                return modelSlug
            }
        }

        if let model = dictionaryValue(jsonObject["model"]) {
            return stringValue(model["id"]) ?? stringValue(model["display_name"])
        }

        return stringValue(jsonObject["model"])
    }

    private static func extractUsage(from jsonObject: [String: Any]) -> (inputTokens: Int64, outputTokens: Int64, cachedInputTokens: Int64)? {
        let usageObject: [String: Any]?
        if let message = dictionaryValue(jsonObject["message"]),
           let nestedUsage = dictionaryValue(message["usage"]) {
            usageObject = nestedUsage
        } else {
            usageObject = dictionaryValue(jsonObject["usage"])
        }

        guard let usageObject else {
            return nil
        }

        guard let inputTokens = int64Value(usageObject["input_tokens"]),
              let outputTokens = int64Value(usageObject["output_tokens"]) else {
            return nil
        }

        let cacheCreation = int64Value(usageObject["cache_creation_input_tokens"]) ?? 0
        let cacheRead = int64Value(usageObject["cache_read_input_tokens"]) ?? 0
        return (
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cachedInputTokens: cacheCreation + cacheRead
        )
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
