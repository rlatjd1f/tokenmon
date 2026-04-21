import Foundation
import TokenmonDomain
import TokenmonGameEngine
import TokenmonProviders

public enum TokenmonDomainEventType: String, Sendable {
    case usageSampleRecorded = "usage_sample_recorded"
    case explorationProgressUpdated = "exploration_progress_updated"
    case encounterThresholdCrossed = "encounter_threshold_crossed"
    case fieldSelected = "field_selected"
    case raritySelected = "rarity_selected"
    case speciesSelected = "species_selected"
    case encounterSpawned = "encounter_spawned"
    case captureResolved = "capture_resolved"
    case seenDexUpdated = "seen_dex_updated"
    case capturedDexUpdated = "captured_dex_updated"
    case backfillStarted = "backfill_started"
    case backfillCompleted = "backfill_completed"
}

public struct DomainEventEnvelope<Payload: Encodable & Sendable>: Sendable {
    public let eventID: String
    public let eventType: String
    public let occurredAt: String
    public let producer: String
    public let correlationID: String?
    public let causationID: String?
    public let aggregateType: String?
    public let aggregateID: String?
    public let payload: Payload

    public init(
        eventID: String = UUID().uuidString.lowercased(),
        eventType: String,
        occurredAt: String,
        producer: String,
        correlationID: String? = nil,
        causationID: String? = nil,
        aggregateType: String? = nil,
        aggregateID: String? = nil,
        payload: Payload
    ) {
        self.eventID = eventID
        self.eventType = eventType
        self.occurredAt = occurredAt
        self.producer = producer
        self.correlationID = correlationID
        self.causationID = causationID
        self.aggregateType = aggregateType
        self.aggregateID = aggregateID
        self.payload = payload
    }
}

public struct UsageSampleRecordedEventPayload: Codable, Equatable, Sendable {
    public let usageSampleID: Int64
    public let providerSessionID: String
    public let provider: String
    public let normalizedTotalTokens: Int64
    public let normalizedDeltaTokens: Int64
    public let totalInputTokens: Int64
    public let totalOutputTokens: Int64
    public let totalCachedInputTokens: Int64
    public let gameplayEligibility: String
    public let gameplayDeltaTokens: Int64
    public let gameplayBalanceBucket: String?
    public let gameplayBalanceWeight: Double?
    public let gameplayBalancePolicy: String?

    enum CodingKeys: String, CodingKey {
        case usageSampleID = "usage_sample_id"
        case providerSessionID = "provider_session_id"
        case provider
        case normalizedTotalTokens = "normalized_total_tokens"
        case normalizedDeltaTokens = "normalized_delta_tokens"
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case totalCachedInputTokens = "total_cached_input_tokens"
        case gameplayEligibility = "gameplay_eligibility"
        case gameplayDeltaTokens = "gameplay_delta_tokens"
        case gameplayBalanceBucket = "gameplay_balance_bucket"
        case gameplayBalanceWeight = "gameplay_balance_weight"
        case gameplayBalancePolicy = "gameplay_balance_policy"
    }
}

public struct ExplorationProgressUpdatedEventPayload: Codable, Equatable, Sendable {
    public let usageSampleID: Int64
    public let tokensSinceLastEncounterBefore: Int64
    public let tokensSinceLastEncounterAfter: Int64
    public let nextEncounterThresholdTokensAfter: Int64
    public let burstIntensityBand: Int

    enum CodingKeys: String, CodingKey {
        case usageSampleID = "usage_sample_id"
        case tokensSinceLastEncounterBefore = "tokens_since_last_encounter_before"
        case tokensSinceLastEncounterAfter = "tokens_since_last_encounter_after"
        case nextEncounterThresholdTokensAfter = "next_encounter_threshold_tokens_after"
        case burstIntensityBand = "burst_intensity_band"
    }
}

public struct EncounterThresholdCrossedEventPayload: Codable, Equatable, Sendable {
    public let thresholdIndexGlobal: Int64
    public let usageSampleID: Int64
    public let totalNormalizedTokensAtThreshold: Int64
    public let thresholdTokens: Int64
    public let remainingTokensAfter: Int64
    public let nextEncounterThresholdTokens: Int64
    public let burstIntensityBand: Int

    enum CodingKeys: String, CodingKey {
        case thresholdIndexGlobal = "threshold_index_global"
        case usageSampleID = "usage_sample_id"
        case totalNormalizedTokensAtThreshold = "total_normalized_tokens_at_threshold"
        case thresholdTokens = "threshold_tokens"
        case remainingTokensAfter = "remaining_tokens_after"
        case nextEncounterThresholdTokens = "next_encounter_threshold_tokens"
        case burstIntensityBand = "burst_intensity_band"
    }
}

public struct FieldSelectedEventPayload: Codable, Equatable, Sendable {
    public let encounterSeedContextID: String
    public let selectedField: String
    public let priorFieldHistorySnapshot: [String]
    public let antiRepeatApplied: Bool
    public let fieldWeightsEffective: [EncounterFieldWeight]

    enum CodingKeys: String, CodingKey {
        case encounterSeedContextID = "encounter_seed_context_id"
        case selectedField = "selected_field"
        case priorFieldHistorySnapshot = "prior_field_history_snapshot"
        case antiRepeatApplied = "anti_repeat_applied"
        case fieldWeightsEffective = "field_weights_effective"
    }
}

public struct RaritySelectedEventPayload: Codable, Equatable, Sendable {
    public let encounterSeedContextID: String
    public let selectedRarity: String
    public let rarityWeightsEffective: [EncounterRarityWeight]
    public let rngRoll: Double

    enum CodingKeys: String, CodingKey {
        case encounterSeedContextID = "encounter_seed_context_id"
        case selectedRarity = "selected_rarity"
        case rarityWeightsEffective = "rarity_weights_effective"
        case rngRoll = "rng_roll"
    }
}

public struct SpeciesSelectedEventPayload: Codable, Equatable, Sendable {
    public let encounterSeedContextID: String
    public let selectedField: String
    public let selectedRarity: String
    public let speciesID: String
    public let candidateSpeciesIDs: [String]
    public let rngRoll: Double

    enum CodingKeys: String, CodingKey {
        case encounterSeedContextID = "encounter_seed_context_id"
        case selectedField = "selected_field"
        case selectedRarity = "selected_rarity"
        case speciesID = "species_id"
        case candidateSpeciesIDs = "candidate_species_ids"
        case rngRoll = "rng_roll"
    }
}

public struct BackfillStartedEventPayload: Codable, Equatable, Sendable {
    public let provider: String
    public let sessionID: String?
    public let mode: String
    public let reason: String

    enum CodingKeys: String, CodingKey {
        case provider
        case sessionID = "session_id"
        case mode
        case reason
    }
}

public struct BackfillCompletedEventPayload: Codable, Equatable, Sendable {
    public let provider: String
    public let sessionID: String?
    public let mode: String
    public let samplesExamined: Int64
    public let samplesCreated: Int64
    public let duplicatesSkipped: Int64
    public let errorsCount: Int64

    enum CodingKeys: String, CodingKey {
        case provider
        case sessionID = "session_id"
        case mode
        case samplesExamined = "samples_examined"
        case samplesCreated = "samples_created"
        case duplicatesSkipped = "duplicates_skipped"
        case errorsCount = "errors_count"
    }
}

public struct PersistedDomainEventRecord: Equatable, Sendable {
    public let eventID: String
    public let eventType: String
    public let occurredAt: String
    public let producer: String
    public let correlationID: String?
    public let causationID: String?
    public let aggregateType: String?
    public let aggregateID: String?
    public let payloadJSON: String
    public let createdAt: String
}

enum TokenmonDomainEventRegistry {
    static let producer = "TokenmonPersistence.UsageSampleIngestionService"
    static let explorationStateAggregateID = "1"
    static let encounterProducer = "TokenmonGameEngine.EncounterGenerator"
    static let backfillProducer = "TokenmonPersistence.ClaudeTranscriptBackfillService"

    static func usageSampleEventID(_ usageSampleID: Int64) -> String {
        "\(TokenmonDomainEventType.usageSampleRecorded.rawValue):usage-sample-\(usageSampleID)"
    }

    static func explorationProgressEventID(_ usageSampleID: Int64) -> String {
        "\(TokenmonDomainEventType.explorationProgressUpdated.rawValue):usage-sample-\(usageSampleID)"
    }

    static func thresholdEventID(usageSampleID: Int64, thresholdIndex: Int64) -> String {
        "\(TokenmonDomainEventType.encounterThresholdCrossed.rawValue):usage-sample-\(usageSampleID):threshold-\(thresholdIndex)"
    }

    static func encounterEventID(_ eventType: TokenmonDomainEventType, encounterSeedContextID: String) -> String {
        "\(eventType.rawValue):\(encounterSeedContextID)"
    }

    static func usageSampleRecorded(
        usageSampleID: Int64,
        event: ProviderUsageSampleEvent,
        normalizedDeltaTokens: Int64,
        gameplayEligibility: UsageSampleGameplayEligibility,
        gameplayDeltaTokens: Int64,
        gameplayBalanceBucket: String? = nil,
        gameplayBalanceWeight: Double? = nil,
        gameplayBalancePolicy: String? = nil
    ) -> DomainEventEnvelope<UsageSampleRecordedEventPayload> {
        DomainEventEnvelope(
            eventID: usageSampleEventID(usageSampleID),
            eventType: TokenmonDomainEventType.usageSampleRecorded.rawValue,
            occurredAt: event.observedAt,
            producer: producer,
            correlationID: event.providerEventFingerprint,
            aggregateType: "provider_session",
            aggregateID: "\(event.provider.rawValue):\(event.providerSessionID)",
            payload: UsageSampleRecordedEventPayload(
                usageSampleID: usageSampleID,
                providerSessionID: event.providerSessionID,
                provider: event.provider.rawValue,
                normalizedTotalTokens: event.normalizedTotalTokens,
                normalizedDeltaTokens: normalizedDeltaTokens,
                totalInputTokens: event.totalInputTokens,
                totalOutputTokens: event.totalOutputTokens,
                totalCachedInputTokens: event.totalCachedInputTokens,
                gameplayEligibility: gameplayEligibility.rawValue,
                gameplayDeltaTokens: gameplayDeltaTokens,
                gameplayBalanceBucket: gameplayBalanceBucket,
                gameplayBalanceWeight: gameplayBalanceWeight,
                gameplayBalancePolicy: gameplayBalancePolicy
            )
        )
    }

    static func explorationProgressUpdated(
        usageSampleID: Int64,
        observedAt: String,
        correlationID: String,
        burstIntensityBand: Int,
        progress: ExplorationProgressSnapshot
    ) -> DomainEventEnvelope<ExplorationProgressUpdatedEventPayload> {
        DomainEventEnvelope(
            eventID: explorationProgressEventID(usageSampleID),
            eventType: TokenmonDomainEventType.explorationProgressUpdated.rawValue,
            occurredAt: observedAt,
            producer: producer,
            correlationID: correlationID,
            aggregateType: "exploration_state",
            aggregateID: explorationStateAggregateID,
            payload: ExplorationProgressUpdatedEventPayload(
                usageSampleID: usageSampleID,
                tokensSinceLastEncounterBefore: progress.tokensSinceLastEncounterBefore,
                tokensSinceLastEncounterAfter: progress.tokensSinceLastEncounterAfter,
                nextEncounterThresholdTokensAfter: progress.nextEncounterThresholdTokensAfter,
                burstIntensityBand: burstIntensityBand
            )
        )
    }

    static func encounterThresholdCrossed(
        usageSampleID: Int64,
        observedAt: String,
        correlationID: String,
        burstIntensityBand: Int,
        threshold: EncounterThresholdCrossedSnapshot
    ) -> DomainEventEnvelope<EncounterThresholdCrossedEventPayload> {
        DomainEventEnvelope(
            eventID: thresholdEventID(
                usageSampleID: usageSampleID,
                thresholdIndex: threshold.thresholdIndexGlobal
            ),
            eventType: TokenmonDomainEventType.encounterThresholdCrossed.rawValue,
            occurredAt: observedAt,
            producer: producer,
            correlationID: correlationID,
            aggregateType: "exploration_state",
            aggregateID: explorationStateAggregateID,
            payload: EncounterThresholdCrossedEventPayload(
                thresholdIndexGlobal: threshold.thresholdIndexGlobal,
                usageSampleID: usageSampleID,
                totalNormalizedTokensAtThreshold: threshold.totalNormalizedTokensAtThreshold,
                thresholdTokens: threshold.thresholdTokens,
                remainingTokensAfter: threshold.remainingTokensAfter,
                nextEncounterThresholdTokens: threshold.nextEncounterThresholdTokens,
                burstIntensityBand: burstIntensityBand
            )
        )
    }

    static func fieldSelected(
        generatedEncounter: GeneratedEncounter,
        correlationID: String
    ) -> DomainEventEnvelope<FieldSelectedEventPayload> {
        DomainEventEnvelope(
            eventID: encounterEventID(
                .fieldSelected,
                encounterSeedContextID: generatedEncounter.encounterSeedContextID
            ),
            eventType: TokenmonDomainEventType.fieldSelected.rawValue,
            occurredAt: generatedEncounter.occurredAt,
            producer: encounterProducer,
            correlationID: correlationID,
            causationID: thresholdEventID(
                usageSampleID: generatedEncounter.usageSampleID,
                thresholdIndex: generatedEncounter.thresholdIndexGlobal
            ),
            aggregateType: "encounter_seed_context",
            aggregateID: generatedEncounter.encounterSeedContextID,
            payload: FieldSelectedEventPayload(
                encounterSeedContextID: generatedEncounter.encounterSeedContextID,
                selectedField: generatedEncounter.fieldSelection.selectedField.rawValue,
                priorFieldHistorySnapshot: generatedEncounter.fieldSelection.priorFieldHistorySnapshot.map(\.rawValue),
                antiRepeatApplied: generatedEncounter.fieldSelection.antiRepeatApplied,
                fieldWeightsEffective: generatedEncounter.fieldSelection.fieldWeightsEffective
            )
        )
    }

    static func raritySelected(
        generatedEncounter: GeneratedEncounter,
        correlationID: String
    ) -> DomainEventEnvelope<RaritySelectedEventPayload> {
        DomainEventEnvelope(
            eventID: encounterEventID(
                .raritySelected,
                encounterSeedContextID: generatedEncounter.encounterSeedContextID
            ),
            eventType: TokenmonDomainEventType.raritySelected.rawValue,
            occurredAt: generatedEncounter.occurredAt,
            producer: encounterProducer,
            correlationID: correlationID,
            causationID: encounterEventID(
                .fieldSelected,
                encounterSeedContextID: generatedEncounter.encounterSeedContextID
            ),
            aggregateType: "encounter_seed_context",
            aggregateID: generatedEncounter.encounterSeedContextID,
            payload: RaritySelectedEventPayload(
                encounterSeedContextID: generatedEncounter.encounterSeedContextID,
                selectedRarity: generatedEncounter.raritySelection.selectedRarity.rawValue,
                rarityWeightsEffective: generatedEncounter.raritySelection.rarityWeightsEffective,
                rngRoll: generatedEncounter.raritySelection.roll
            )
        )
    }

    static func speciesSelected(
        generatedEncounter: GeneratedEncounter,
        correlationID: String
    ) -> DomainEventEnvelope<SpeciesSelectedEventPayload> {
        DomainEventEnvelope(
            eventID: encounterEventID(
                .speciesSelected,
                encounterSeedContextID: generatedEncounter.encounterSeedContextID
            ),
            eventType: TokenmonDomainEventType.speciesSelected.rawValue,
            occurredAt: generatedEncounter.occurredAt,
            producer: encounterProducer,
            correlationID: correlationID,
            causationID: encounterEventID(
                .raritySelected,
                encounterSeedContextID: generatedEncounter.encounterSeedContextID
            ),
            aggregateType: "encounter_seed_context",
            aggregateID: generatedEncounter.encounterSeedContextID,
            payload: SpeciesSelectedEventPayload(
                encounterSeedContextID: generatedEncounter.encounterSeedContextID,
                selectedField: generatedEncounter.field.rawValue,
                selectedRarity: generatedEncounter.rarity.rawValue,
                speciesID: generatedEncounter.species.id,
                candidateSpeciesIDs: generatedEncounter.speciesSelection.candidateSpeciesIDs,
                rngRoll: generatedEncounter.speciesSelection.roll
            )
        )
    }

    static func backfillStarted(
        runID: Int64,
        provider: ProviderCode,
        sessionID: String?,
        reason: String
    ) -> DomainEventEnvelope<BackfillStartedEventPayload> {
        DomainEventEnvelope(
            eventID: "\(TokenmonDomainEventType.backfillStarted.rawValue):run-\(runID)",
            eventType: TokenmonDomainEventType.backfillStarted.rawValue,
            occurredAt: ISO8601DateFormatter().string(from: Date()),
            producer: backfillProducer,
            aggregateType: "backfill_run",
            aggregateID: String(runID),
            payload: BackfillStartedEventPayload(
                provider: provider.rawValue,
                sessionID: sessionID,
                mode: "transcript_backfill",
                reason: reason
            )
        )
    }

    static func backfillCompleted(
        runID: Int64,
        provider: ProviderCode,
        sessionID: String?,
        samplesExamined: Int64,
        samplesCreated: Int64,
        duplicatesSkipped: Int64,
        errorsCount: Int64
    ) -> DomainEventEnvelope<BackfillCompletedEventPayload> {
        DomainEventEnvelope(
            eventID: "\(TokenmonDomainEventType.backfillCompleted.rawValue):run-\(runID)",
            eventType: TokenmonDomainEventType.backfillCompleted.rawValue,
            occurredAt: ISO8601DateFormatter().string(from: Date()),
            producer: backfillProducer,
            causationID: "\(TokenmonDomainEventType.backfillStarted.rawValue):run-\(runID)",
            aggregateType: "backfill_run",
            aggregateID: String(runID),
            payload: BackfillCompletedEventPayload(
                provider: provider.rawValue,
                sessionID: sessionID,
                mode: "transcript_backfill",
                samplesExamined: samplesExamined,
                samplesCreated: samplesCreated,
                duplicatesSkipped: duplicatesSkipped,
                errorsCount: errorsCount
            )
        )
    }
}

enum DomainEventStore {
    static func persist<Payload: Encodable & Sendable>(
        database: SQLiteDatabase,
        envelope: DomainEventEnvelope<Payload>
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let payloadJSON = String(decoding: try encoder.encode(envelope.payload), as: UTF8.self)
        let createdAt = ISO8601DateFormatter().string(from: Date())

        try database.execute(
            """
            INSERT INTO domain_events (
                event_id,
                event_type,
                occurred_at,
                producer,
                correlation_id,
                causation_id,
                aggregate_type,
                aggregate_id,
                payload_json,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(envelope.eventID),
                .text(envelope.eventType),
                .text(envelope.occurredAt),
                .text(envelope.producer),
                envelope.correlationID.map(SQLiteValue.text) ?? .null,
                envelope.causationID.map(SQLiteValue.text) ?? .null,
                envelope.aggregateType.map(SQLiteValue.text) ?? .null,
                envelope.aggregateID.map(SQLiteValue.text) ?? .null,
                .text(payloadJSON),
                .text(createdAt),
            ]
        )
    }
}
