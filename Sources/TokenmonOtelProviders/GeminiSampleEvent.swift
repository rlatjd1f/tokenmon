import Foundation
import TokenmonDomain

/// Fields extracted from a single `gemini_cli.api_response` OTel log record.
/// The OTel SDK fans these out as LogRecord attributes; this type is a
/// strongly-typed snapshot the rest of the receiver consumes.
public struct GeminiSampleEvent: Equatable, Sendable {
    public let sessionID: String
    public let observedAt: Date
    public let model: String
    public let inputTokens: Int64
    public let outputTokens: Int64
    public let cachedContentTokens: Int64
    public let thoughtsTokens: Int64
    public let toolTokens: Int64
    public let totalTokens: Int64
    public let durationMs: Int64

    public init(
        sessionID: String,
        observedAt: Date,
        model: String,
        inputTokens: Int64,
        outputTokens: Int64,
        cachedContentTokens: Int64,
        thoughtsTokens: Int64,
        toolTokens: Int64,
        totalTokens: Int64,
        durationMs: Int64
    ) {
        self.sessionID = sessionID
        self.observedAt = observedAt
        self.model = model
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedContentTokens = cachedContentTokens
        self.thoughtsTokens = thoughtsTokens
        self.toolTokens = toolTokens
        self.totalTokens = totalTokens
        self.durationMs = durationMs
    }
}
