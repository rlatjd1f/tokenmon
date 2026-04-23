import Foundation

/// Fields extracted from a single Claude Code `api_request` OTel log record.
/// Claude reports request-level usage, so the receiver accumulates these into
/// monotonic session totals before writing Tokenmon inbox events.
public struct ClaudeOtelSampleEvent: Equatable, Sendable {
    public let sessionID: String
    public let observedAt: Date
    public let model: String
    public let requestID: String?
    public let eventSequence: String?
    public let inputTokens: Int64
    public let outputTokens: Int64
    public let cacheReadTokens: Int64
    public let cacheCreationTokens: Int64

    public var cachedInputTokens: Int64 {
        cacheReadTokens + cacheCreationTokens
    }

    public var totalTokens: Int64 {
        inputTokens + outputTokens + cachedInputTokens
    }

    public init(
        sessionID: String,
        observedAt: Date,
        model: String,
        requestID: String?,
        eventSequence: String?,
        inputTokens: Int64,
        outputTokens: Int64,
        cacheReadTokens: Int64,
        cacheCreationTokens: Int64
    ) {
        self.sessionID = sessionID
        self.observedAt = observedAt
        self.model = model
        self.requestID = requestID
        self.eventSequence = eventSequence
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cacheReadTokens = cacheReadTokens
        self.cacheCreationTokens = cacheCreationTokens
    }
}
