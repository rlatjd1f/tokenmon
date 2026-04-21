import Foundation
import TokenmonDomain

public struct AccountUsageSampleEvent: Codable, Sendable {
    public let eventType: String
    public let provider: ProviderCode
    public let sourceMode: String
    public let observedAt: String
    public let modelSlug: String?
    public let usageKind: String
    public let inputTokens: Int64
    public let outputTokens: Int64
    public let cachedInputTokens: Int64
    public let normalizedDeltaTokens: Int64
    public let providerEventFingerprint: String
    public let rawReference: ProviderRawReference

    public init(
        eventType: String,
        provider: ProviderCode,
        sourceMode: String,
        observedAt: String,
        modelSlug: String?,
        usageKind: String,
        inputTokens: Int64,
        outputTokens: Int64,
        cachedInputTokens: Int64,
        normalizedDeltaTokens: Int64,
        providerEventFingerprint: String,
        rawReference: ProviderRawReference
    ) {
        self.eventType = eventType
        self.provider = provider
        self.sourceMode = sourceMode
        self.observedAt = observedAt
        self.modelSlug = modelSlug
        self.usageKind = usageKind
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
        self.normalizedDeltaTokens = normalizedDeltaTokens
        self.providerEventFingerprint = providerEventFingerprint
        self.rawReference = rawReference
    }

    enum CodingKeys: String, CodingKey {
        case eventType = "event_type"
        case provider
        case sourceMode = "source_mode"
        case observedAt = "observed_at"
        case modelSlug = "model_slug"
        case usageKind = "usage_kind"
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case normalizedDeltaTokens = "normalized_delta_tokens"
        case providerEventFingerprint = "provider_event_fingerprint"
        case rawReference = "raw_reference"
    }

    public func validate() throws {
        guard eventType == "account_usage_sample" else {
            throw ProviderInboxValidationError.invalidEventType(eventType)
        }
        guard !sourceMode.isEmpty else {
            throw ProviderInboxValidationError.missingField("source_mode")
        }
        guard !usageKind.isEmpty else {
            throw ProviderInboxValidationError.missingField("usage_kind")
        }
        guard !providerEventFingerprint.isEmpty else {
            throw ProviderInboxValidationError.missingField("provider_event_fingerprint")
        }
        guard inputTokens >= 0,
              outputTokens >= 0,
              cachedInputTokens >= 0,
              normalizedDeltaTokens >= 0 else {
            throw ProviderInboxValidationError.negativeTokenValue
        }
    }
}
