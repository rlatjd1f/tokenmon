import Foundation
import SQLite3
import TokenmonDomain
import TokenmonGameEngine

public struct EncounterResolutionWriteRequest: Equatable, Sendable {
    public let encounterID: String?
    public let providerCode: ProviderCode?
    public let providerSessionID: String?
    public let providerSessionRowID: Int64?
    public let usageSampleID: Int64
    public let thresholdEventIndex: Int64
    public let occurredAt: String
    public let field: FieldType
    public let rarity: RarityTier
    public let speciesID: String
    public let burstIntensityBand: Int
    public let captureProbability: Double
    public let captureRoll: Double
    public let outcome: EncounterOutcome
    public let encounterSeedContextID: String
    public let encounterSequence: Int64?
    public let correlationID: String?
    public let causationID: String?

    public init(
        encounterID: String? = nil,
        providerCode: ProviderCode? = nil,
        providerSessionID: String? = nil,
        providerSessionRowID: Int64? = nil,
        usageSampleID: Int64,
        thresholdEventIndex: Int64,
        occurredAt: String,
        field: FieldType,
        rarity: RarityTier,
        speciesID: String,
        burstIntensityBand: Int,
        captureProbability: Double,
        captureRoll: Double,
        outcome: EncounterOutcome,
        encounterSeedContextID: String,
        encounterSequence: Int64? = nil,
        correlationID: String? = nil,
        causationID: String? = nil
    ) {
        self.encounterID = encounterID
        self.providerCode = providerCode
        self.providerSessionID = providerSessionID
        self.providerSessionRowID = providerSessionRowID
        self.usageSampleID = usageSampleID
        self.thresholdEventIndex = thresholdEventIndex
        self.occurredAt = occurredAt
        self.field = field
        self.rarity = rarity
        self.speciesID = speciesID
        self.burstIntensityBand = burstIntensityBand
        self.captureProbability = captureProbability
        self.captureRoll = captureRoll
        self.outcome = outcome
        self.encounterSeedContextID = encounterSeedContextID
        self.encounterSequence = encounterSequence
        self.correlationID = correlationID
        self.causationID = causationID
    }
}

public struct PersistedEncounterRecord: Equatable, Sendable {
    public let encounterID: String
    public let encounterSequence: Int64
    public let providerCode: ProviderCode?
    public let providerSessionRowID: Int64?
    public let usageSampleID: Int64
    public let thresholdEventIndex: Int64
    public let occurredAt: String
    public let field: FieldType
    public let rarity: RarityTier
    public let speciesID: String
    public let burstIntensityBand: Int
    public let captureProbability: Double
    public let captureRoll: Double
    public let outcome: EncounterOutcome
    public let createdAt: String
}

public struct CaptureResolvedEventPayload: Codable, Equatable, Sendable {
    public let encounterID: String
    public let speciesID: String
    public let rarity: String
    public let captureProbability: Double
    public let rngRoll: Double
    public let outcome: String

    enum CodingKeys: String, CodingKey {
        case encounterID = "encounter_id"
        case speciesID = "species_id"
        case rarity
        case captureProbability = "capture_probability"
        case rngRoll = "rng_roll"
        case outcome
    }
}

public struct EncounterSpawnedEventPayload: Codable, Equatable, Sendable {
    public let encounterID: String
    public let encounterSequence: Int64
    public let provider: String?
    public let providerSessionID: String?
    public let usageSampleID: Int64
    public let field: String
    public let rarity: String
    public let speciesID: String
    public let burstIntensityBand: Int
    public let observedAt: String

    enum CodingKeys: String, CodingKey {
        case encounterID = "encounter_id"
        case encounterSequence = "encounter_sequence"
        case provider
        case providerSessionID = "provider_session_id"
        case usageSampleID = "usage_sample_id"
        case field
        case rarity
        case speciesID = "species_id"
        case burstIntensityBand = "burst_intensity_band"
        case observedAt = "observed_at"
    }
}

public struct SeenDexUpdatedEventPayload: Codable, Equatable, Sendable {
    public let speciesID: String
    public let encounterID: String
    public let firstSeenCreated: Bool
    public let seenCountBefore: Int64
    public let seenCountAfter: Int64
    public let lastSeenAtAfter: String

    enum CodingKeys: String, CodingKey {
        case speciesID = "species_id"
        case encounterID = "encounter_id"
        case firstSeenCreated = "first_seen_created"
        case seenCountBefore = "seen_count_before"
        case seenCountAfter = "seen_count_after"
        case lastSeenAtAfter = "last_seen_at_after"
    }
}

public struct CapturedDexUpdatedEventPayload: Codable, Equatable, Sendable {
    public let speciesID: String
    public let encounterID: String
    public let firstCaptureCreated: Bool
    public let capturedCountBefore: Int64
    public let capturedCountAfter: Int64
    public let lastCapturedAtAfter: String

    enum CodingKeys: String, CodingKey {
        case speciesID = "species_id"
        case encounterID = "encounter_id"
        case firstCaptureCreated = "first_capture_created"
        case capturedCountBefore = "captured_count_before"
        case capturedCountAfter = "captured_count_after"
        case lastCapturedAtAfter = "last_captured_at_after"
    }
}

public struct SpeciesAffinityUpdatedEventPayload: Codable, Equatable, Sendable {
    public let speciesID: String
    public let encounterID: String
    public let capturedCountAfter: Int64
    public let rarity: String
    public let previousLevel: Int
    public let newLevel: Int
    public let targetLevel: Int?
    public let probability: Double?
    public let rngRoll: Double?
    public let pityCountBefore: Int
    public let pityCountAfter: Int
    public let ceilingFailures: Int?
    public let outcome: String

    enum CodingKeys: String, CodingKey {
        case speciesID = "species_id"
        case encounterID = "encounter_id"
        case capturedCountAfter = "captured_count_after"
        case rarity
        case previousLevel = "previous_level"
        case newLevel = "new_level"
        case targetLevel = "target_level"
        case probability
        case rngRoll = "rng_roll"
        case pityCountBefore = "pity_count_before"
        case pityCountAfter = "pity_count_after"
        case ceilingFailures = "ceiling_failures"
        case outcome
    }
}

private struct DexSeenMutation {
    let firstSeenCreated: Bool
    let seenCountBefore: Int64
    let seenCountAfter: Int64
    let lastSeenAtAfter: String
}

private struct DexCapturedMutation {
    let firstCaptureCreated: Bool
    let capturedCountBefore: Int64
    let capturedCountAfter: Int64
    let lastCapturedAtAfter: String
    let affinityResolution: SpeciesAffinityResolution
}

private struct ExistingDexCapturedAggregate {
    let capturedCount: Int64
    let affinityLevel: Int
    let affinityPityCount: Int
}

public enum EncounterHistoryStoreError: Error, LocalizedError {
    case invalidThresholdEventIndex(Int64)
    case invalidBurstIntensityBand(Int)
    case invalidCaptureProbability(Double)
    case invalidCaptureRoll(Double)
    case speciesNotFound(speciesID: String, field: FieldType, rarity: RarityTier)
    case immutableEncounterConflict(encounterID: String, usageSampleID: Int64, thresholdEventIndex: Int64)
    case invalidStoredField(String)
    case invalidStoredRarity(String)
    case invalidStoredOutcome(String)
    case encounterLookupFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidThresholdEventIndex(let value):
            return "threshold event index must be positive: \(value)"
        case .invalidBurstIntensityBand(let value):
            return "burst intensity band must be between 0 and 4 inclusive: \(value)"
        case .invalidCaptureProbability(let value):
            return "capture probability must be between 0 and 1 inclusive: \(value)"
        case .invalidCaptureRoll(let value):
            return "capture roll must be in [0, 1): \(value)"
        case .speciesNotFound(let speciesID, let field, let rarity):
            return "species \(speciesID) is not active for field \(field.rawValue) and rarity \(rarity.rawValue)"
        case .immutableEncounterConflict(let encounterID, let usageSampleID, let thresholdEventIndex):
            return "encounter \(encounterID) already exists for usage sample \(usageSampleID) threshold index \(thresholdEventIndex) and cannot be mutated"
        case .invalidStoredField(let value):
            return "stored encounter field is invalid: \(value)"
        case .invalidStoredRarity(let value):
            return "stored encounter rarity is invalid: \(value)"
        case .invalidStoredOutcome(let value):
            return "stored encounter outcome is invalid: \(value)"
        case .encounterLookupFailed(let encounterID):
            return "failed to read persisted encounter \(encounterID)"
        }
    }
}

/// Persists immutable resolved encounters and the accompanying capture result audit event.
public enum EncounterHistoryStore {
    public static func persistResolvedEncounter(
        databasePath: String,
        request: EncounterResolutionWriteRequest
    ) throws -> PersistedEncounterRecord {
        let database = try TokenmonDatabaseManager(path: databasePath).open()
        return try persistResolvedEncounter(database: database, request: request)
    }

    public static func persistResolvedEncounter(
        database: SQLiteDatabase,
        request: EncounterResolutionWriteRequest
    ) throws -> PersistedEncounterRecord {
        try validate(request: request, database: database)

        if let existing = try fetchEncounter(
            database: database,
            usageSampleID: request.usageSampleID,
            thresholdEventIndex: request.thresholdEventIndex
        ) {
            guard matches(existing: existing, request: request) else {
                throw EncounterHistoryStoreError.immutableEncounterConflict(
                    encounterID: existing.encounterID,
                    usageSampleID: request.usageSampleID,
                    thresholdEventIndex: request.thresholdEventIndex
                )
            }
            return existing
        }

        let encounterID = request.encounterID ?? UUID().uuidString.lowercased()
        let encounterSequence: Int64
        if let requestedSequence = request.encounterSequence {
            encounterSequence = requestedSequence
        } else {
            encounterSequence = try nextEncounterSequence(database: database)
        }
        let createdAt = ISO8601DateFormatter().string(from: Date())

        try database.execute(
            """
            INSERT INTO encounters (
                encounter_id,
                encounter_sequence,
                provider_code,
                provider_session_row_id,
                usage_sample_id,
                threshold_event_index,
                occurred_at,
                field_code,
                rarity_tier,
                species_id,
                burst_intensity_band,
                capture_probability,
                capture_roll,
                outcome,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(encounterID),
                .integer(encounterSequence),
                request.providerCode.map { .text($0.rawValue) } ?? .null,
                request.providerSessionRowID.map(SQLiteValue.integer) ?? .null,
                .integer(request.usageSampleID),
                .integer(request.thresholdEventIndex),
                .text(request.occurredAt),
                .text(request.field.rawValue),
                .text(request.rarity.rawValue),
                .text(request.speciesID),
                .integer(Int64(request.burstIntensityBand)),
                .double(request.captureProbability),
                .double(request.captureRoll),
                .text(request.outcome.rawValue),
                .text(createdAt),
            ]
        )

        try DomainEventStore.persist(
            database: database,
            envelope: encounterSpawnedEnvelope(
                encounterID: encounterID,
                encounterSequence: encounterSequence,
                request: request
            )
        )

        let seenMutation = try upsertDexSeen(
            database: database,
            speciesID: request.speciesID,
            occurredAt: request.occurredAt,
            encounterID: encounterID,
            updatedAt: createdAt
        )

        try DomainEventStore.persist(
            database: database,
            envelope: captureResolvedEnvelope(
                encounterID: encounterID,
                encounterSequence: encounterSequence,
                request: request
            )
        )

        try DomainEventStore.persist(
            database: database,
            envelope: seenDexUpdatedEnvelope(
                encounterID: encounterID,
                request: request,
                mutation: seenMutation
            )
        )

        if request.outcome == .captured {
            try database.execute(
                """
                UPDATE exploration_state
                SET total_captures = total_captures + 1,
                    updated_at = ?
                WHERE exploration_state_id = 1;
                """,
                bindings: [.text(createdAt)]
            )

            let capturedMutation = try upsertDexCaptured(
                database: database,
                speciesID: request.speciesID,
                occurredAt: request.occurredAt,
                encounterID: encounterID,
                encounterSeedContextID: request.encounterSeedContextID,
                updatedAt: createdAt
            )

            try DomainEventStore.persist(
                database: database,
                envelope: capturedDexUpdatedEnvelope(
                    encounterID: encounterID,
                    request: request,
                    mutation: capturedMutation
                )
            )

            try DomainEventStore.persist(
                database: database,
                envelope: speciesAffinityUpdatedEnvelope(
                    encounterID: encounterID,
                    request: request,
                    mutation: capturedMutation
                )
            )
        }

        guard let persisted = try fetchEncounter(database: database, encounterID: encounterID) else {
            throw EncounterHistoryStoreError.encounterLookupFailed(encounterID)
        }

        return persisted
    }

    public static func fetchEncounter(
        database: SQLiteDatabase,
        encounterID: String
    ) throws -> PersistedEncounterRecord? {
        try database.fetchOne(
            """
            SELECT encounter_id,
                   encounter_sequence,
                   provider_code,
                   provider_session_row_id,
                   usage_sample_id,
                   threshold_event_index,
                   occurred_at,
                   field_code,
                   rarity_tier,
                   species_id,
                   burst_intensity_band,
                   capture_probability,
                   capture_roll,
                   outcome,
                   created_at
            FROM encounters
            WHERE encounter_id = ?
            LIMIT 1;
            """,
            bindings: [.text(encounterID)],
            map: mapEncounterRecord
        )
    }

    public static func fetchEncounter(
        database: SQLiteDatabase,
        usageSampleID: Int64,
        thresholdEventIndex: Int64
    ) throws -> PersistedEncounterRecord? {
        try database.fetchOne(
            """
            SELECT encounter_id,
                   encounter_sequence,
                   provider_code,
                   provider_session_row_id,
                   usage_sample_id,
                   threshold_event_index,
                   occurred_at,
                   field_code,
                   rarity_tier,
                   species_id,
                   burst_intensity_band,
                   capture_probability,
                   capture_roll,
                   outcome,
                   created_at
            FROM encounters
            WHERE usage_sample_id = ? AND threshold_event_index = ?
            LIMIT 1;
            """,
            bindings: [
                .integer(usageSampleID),
                .integer(thresholdEventIndex),
            ],
            map: mapEncounterRecord
        )
    }

    private static func validate(
        request: EncounterResolutionWriteRequest,
        database: SQLiteDatabase
    ) throws {
        guard request.thresholdEventIndex > 0 else {
            throw EncounterHistoryStoreError.invalidThresholdEventIndex(request.thresholdEventIndex)
        }

        guard (0 ... 4).contains(request.burstIntensityBand) else {
            throw EncounterHistoryStoreError.invalidBurstIntensityBand(request.burstIntensityBand)
        }

        guard (0 ... 1).contains(request.captureProbability) else {
            throw EncounterHistoryStoreError.invalidCaptureProbability(request.captureProbability)
        }

        guard (0 ..< 1).contains(request.captureRoll) else {
            throw EncounterHistoryStoreError.invalidCaptureRoll(request.captureRoll)
        }

        let speciesExists = try database.fetchOne(
            """
            SELECT species_id
            FROM species
            WHERE species_id = ?
              AND field_code = ?
              AND rarity_tier = ?
              AND is_active = 1
            LIMIT 1;
            """,
            bindings: [
                .text(request.speciesID),
                .text(request.field.rawValue),
                .text(request.rarity.rawValue),
            ]
        ) { statement in
            SQLiteDatabase.columnText(statement, index: 0)
        } != nil

        guard speciesExists else {
            throw EncounterHistoryStoreError.speciesNotFound(
                speciesID: request.speciesID,
                field: request.field,
                rarity: request.rarity
            )
        }
    }

    private static func nextEncounterSequence(database: SQLiteDatabase) throws -> Int64 {
        try database.fetchOne(
            """
            SELECT COALESCE(MAX(encounter_sequence), 0) + 1
            FROM encounters;
            """
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 1
    }

    private static func upsertDexSeen(
        database: SQLiteDatabase,
        speciesID: String,
        occurredAt: String,
        encounterID: String,
        updatedAt: String
    ) throws -> DexSeenMutation {
        let existingSeenCount = try database.fetchOne(
            """
            SELECT seen_count
            FROM dex_seen
            WHERE species_id = ?
            LIMIT 1;
            """,
            bindings: [.text(speciesID)]
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        }

        try database.execute(
            """
            INSERT INTO dex_seen (
                species_id,
                first_seen_at,
                last_seen_at,
                seen_count,
                last_encounter_id,
                updated_at
            ) VALUES (?, ?, ?, 1, ?, ?)
            ON CONFLICT(species_id) DO UPDATE SET
                last_seen_at = excluded.last_seen_at,
                seen_count = dex_seen.seen_count + 1,
                last_encounter_id = excluded.last_encounter_id,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(speciesID),
                .text(occurredAt),
                .text(occurredAt),
                .text(encounterID),
                .text(updatedAt),
            ]
        )

        let seenCountBefore = existingSeenCount ?? 0
        return DexSeenMutation(
            firstSeenCreated: existingSeenCount == nil,
            seenCountBefore: seenCountBefore,
            seenCountAfter: seenCountBefore + 1,
            lastSeenAtAfter: occurredAt
        )
    }

    private static func upsertDexCaptured(
        database: SQLiteDatabase,
        speciesID: String,
        occurredAt: String,
        encounterID: String,
        encounterSeedContextID: String,
        updatedAt: String
    ) throws -> DexCapturedMutation {
        let existing = try database.fetchOne(
            """
            SELECT captured_count,
                   COALESCE(affinity_level, 1),
                   COALESCE(affinity_pity_count, 0)
            FROM dex_captured
            WHERE species_id = ?
            LIMIT 1;
            """,
            bindings: [.text(speciesID)]
        ) { statement in
            ExistingDexCapturedAggregate(
                capturedCount: SQLiteDatabase.columnInt64(statement, index: 0),
                affinityLevel: Int(SQLiteDatabase.columnInt64(statement, index: 1)),
                affinityPityCount: Int(SQLiteDatabase.columnInt64(statement, index: 2))
            )
        }
        let capturedCountBefore = existing?.capturedCount ?? 0
        let capturedCountAfter = capturedCountBefore + 1
        let affinityResolution = try SpeciesAffinityResolver().resolveCapture(
            speciesID: speciesID,
            rarity: try rarityForSpecies(database: database, speciesID: speciesID),
            encounterSeedContextID: encounterSeedContextID,
            capturedCountAfter: capturedCountAfter,
            currentLevel: existing?.affinityLevel ?? 0,
            pityCount: existing?.affinityPityCount ?? 0
        )

        try database.execute(
            """
            INSERT INTO dex_captured (
                species_id,
                first_captured_at,
                last_captured_at,
                captured_count,
                affinity_level,
                affinity_pity_count,
                affinity_last_roll,
                affinity_last_probability,
                affinity_last_outcome,
                affinity_updated_at,
                last_encounter_id,
                updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(species_id) DO UPDATE SET
                last_captured_at = excluded.last_captured_at,
                captured_count = dex_captured.captured_count + 1,
                affinity_level = excluded.affinity_level,
                affinity_pity_count = excluded.affinity_pity_count,
                affinity_last_roll = excluded.affinity_last_roll,
                affinity_last_probability = excluded.affinity_last_probability,
                affinity_last_outcome = excluded.affinity_last_outcome,
                affinity_updated_at = excluded.affinity_updated_at,
                last_encounter_id = excluded.last_encounter_id,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(speciesID),
                .text(occurredAt),
                .text(occurredAt),
                .integer(capturedCountAfter),
                .integer(Int64(affinityResolution.newLevel)),
                .integer(Int64(affinityResolution.pityCountAfter)),
                affinityResolution.roll.map(SQLiteValue.double) ?? .null,
                affinityResolution.probability.map(SQLiteValue.double) ?? .null,
                .text(affinityResolution.outcome.rawValue),
                .text(updatedAt),
                .text(encounterID),
                .text(updatedAt),
            ]
        )

        return DexCapturedMutation(
            firstCaptureCreated: existing == nil,
            capturedCountBefore: capturedCountBefore,
            capturedCountAfter: capturedCountAfter,
            lastCapturedAtAfter: occurredAt,
            affinityResolution: affinityResolution
        )
    }

    private static func rarityForSpecies(database: SQLiteDatabase, speciesID: String) throws -> RarityTier {
        let rarityValue = try database.fetchOne(
            """
            SELECT rarity_tier
            FROM species
            WHERE species_id = ?
            LIMIT 1;
            """,
            bindings: [.text(speciesID)]
        ) { statement in
            SQLiteDatabase.columnText(statement, index: 0)
        }

        guard let rarityValue, let rarity = RarityTier(rawValue: rarityValue) else {
            throw EncounterHistoryStoreError.invalidStoredRarity(rarityValue ?? "")
        }
        return rarity
    }

    private static func mapEncounterRecord(_ statement: OpaquePointer) throws -> PersistedEncounterRecord {
        let fieldValue = SQLiteDatabase.columnText(statement, index: 7)
        guard let field = FieldType(rawValue: fieldValue) else {
            throw EncounterHistoryStoreError.invalidStoredField(fieldValue)
        }

        let rarityValue = SQLiteDatabase.columnText(statement, index: 8)
        guard let rarity = RarityTier(rawValue: rarityValue) else {
            throw EncounterHistoryStoreError.invalidStoredRarity(rarityValue)
        }

        let outcomeValue = SQLiteDatabase.columnText(statement, index: 13)
        guard let outcome = EncounterOutcome(rawValue: outcomeValue) else {
            throw EncounterHistoryStoreError.invalidStoredOutcome(outcomeValue)
        }

        let providerCode = SQLiteDatabase.columnOptionalText(statement, index: 2)
            .flatMap(ProviderCode.init(rawValue:))
        let providerSessionRowID = sqliteColumnOptionalInt64(statement, index: 3)

        return PersistedEncounterRecord(
            encounterID: SQLiteDatabase.columnText(statement, index: 0),
            encounterSequence: SQLiteDatabase.columnInt64(statement, index: 1),
            providerCode: providerCode,
            providerSessionRowID: providerSessionRowID,
            usageSampleID: SQLiteDatabase.columnInt64(statement, index: 4),
            thresholdEventIndex: SQLiteDatabase.columnInt64(statement, index: 5),
            occurredAt: SQLiteDatabase.columnText(statement, index: 6),
            field: field,
            rarity: rarity,
            speciesID: SQLiteDatabase.columnText(statement, index: 9),
            burstIntensityBand: Int(SQLiteDatabase.columnInt64(statement, index: 10)),
            captureProbability: SQLiteDatabase.columnDouble(statement, index: 11),
            captureRoll: SQLiteDatabase.columnDouble(statement, index: 12),
            outcome: outcome,
            createdAt: SQLiteDatabase.columnText(statement, index: 14)
        )
    }

    private static func matches(
        existing: PersistedEncounterRecord,
        request: EncounterResolutionWriteRequest
    ) -> Bool {
        let encounterIDMatches = request.encounterID.map { $0 == existing.encounterID } ?? true

        return encounterIDMatches
            && existing.providerCode == request.providerCode
            && existing.providerSessionRowID == request.providerSessionRowID
            && existing.usageSampleID == request.usageSampleID
            && existing.thresholdEventIndex == request.thresholdEventIndex
            && (request.encounterSequence.map { $0 == existing.encounterSequence } ?? true)
            && existing.occurredAt == request.occurredAt
            && existing.field == request.field
            && existing.rarity == request.rarity
            && existing.speciesID == request.speciesID
            && existing.burstIntensityBand == request.burstIntensityBand
            && existing.captureProbability == request.captureProbability
            && existing.captureRoll == request.captureRoll
            && existing.outcome == request.outcome
    }

    private static func encounterSpawnedEnvelope(
        encounterID: String,
        encounterSequence: Int64,
        request: EncounterResolutionWriteRequest
    ) -> DomainEventEnvelope<EncounterSpawnedEventPayload> {
        DomainEventEnvelope(
            eventID: "\(TokenmonDomainEventType.encounterSpawned.rawValue):\(request.encounterSeedContextID)",
            eventType: TokenmonDomainEventType.encounterSpawned.rawValue,
            occurredAt: request.occurredAt,
            producer: "TokenmonPersistence.EncounterHistoryStore",
            correlationID: request.correlationID,
            causationID: "\(TokenmonDomainEventType.speciesSelected.rawValue):\(request.encounterSeedContextID)",
            aggregateType: "encounter",
            aggregateID: encounterID,
            payload: EncounterSpawnedEventPayload(
                encounterID: encounterID,
                encounterSequence: encounterSequence,
                provider: request.providerCode?.rawValue,
                providerSessionID: request.providerSessionID,
                usageSampleID: request.usageSampleID,
                field: request.field.rawValue,
                rarity: request.rarity.rawValue,
                speciesID: request.speciesID,
                burstIntensityBand: request.burstIntensityBand,
                observedAt: request.occurredAt
            )
        )
    }

    private static func captureResolvedEnvelope(
        encounterID: String,
        encounterSequence _: Int64,
        request: EncounterResolutionWriteRequest
    ) -> DomainEventEnvelope<CaptureResolvedEventPayload> {
        DomainEventEnvelope(
            eventID: "\(TokenmonDomainEventType.captureResolved.rawValue):\(request.encounterSeedContextID)",
            eventType: TokenmonDomainEventType.captureResolved.rawValue,
            occurredAt: request.occurredAt,
            producer: "TokenmonPersistence.EncounterHistoryStore",
            correlationID: request.correlationID,
            causationID: "\(TokenmonDomainEventType.encounterSpawned.rawValue):\(request.encounterSeedContextID)",
            aggregateType: "encounter",
            aggregateID: encounterID,
            payload: CaptureResolvedEventPayload(
                encounterID: encounterID,
                speciesID: request.speciesID,
                rarity: request.rarity.rawValue,
                captureProbability: request.captureProbability,
                rngRoll: request.captureRoll,
                outcome: request.outcome.rawValue
            )
        )
    }

    private static func seenDexUpdatedEnvelope(
        encounterID: String,
        request: EncounterResolutionWriteRequest,
        mutation: DexSeenMutation
    ) -> DomainEventEnvelope<SeenDexUpdatedEventPayload> {
        DomainEventEnvelope(
            eventID: "\(TokenmonDomainEventType.seenDexUpdated.rawValue):\(request.encounterSeedContextID)",
            eventType: TokenmonDomainEventType.seenDexUpdated.rawValue,
            occurredAt: request.occurredAt,
            producer: "TokenmonPersistence.EncounterHistoryStore",
            correlationID: request.correlationID,
            causationID: "\(TokenmonDomainEventType.captureResolved.rawValue):\(request.encounterSeedContextID)",
            aggregateType: "dex_seen",
            aggregateID: request.speciesID,
            payload: SeenDexUpdatedEventPayload(
                speciesID: request.speciesID,
                encounterID: encounterID,
                firstSeenCreated: mutation.firstSeenCreated,
                seenCountBefore: mutation.seenCountBefore,
                seenCountAfter: mutation.seenCountAfter,
                lastSeenAtAfter: mutation.lastSeenAtAfter
            )
        )
    }

    private static func capturedDexUpdatedEnvelope(
        encounterID: String,
        request: EncounterResolutionWriteRequest,
        mutation: DexCapturedMutation
    ) -> DomainEventEnvelope<CapturedDexUpdatedEventPayload> {
        DomainEventEnvelope(
            eventID: "\(TokenmonDomainEventType.capturedDexUpdated.rawValue):\(request.encounterSeedContextID)",
            eventType: TokenmonDomainEventType.capturedDexUpdated.rawValue,
            occurredAt: request.occurredAt,
            producer: "TokenmonPersistence.EncounterHistoryStore",
            correlationID: request.correlationID,
            causationID: "\(TokenmonDomainEventType.captureResolved.rawValue):\(request.encounterSeedContextID)",
            aggregateType: "dex_captured",
            aggregateID: request.speciesID,
            payload: CapturedDexUpdatedEventPayload(
                speciesID: request.speciesID,
                encounterID: encounterID,
                firstCaptureCreated: mutation.firstCaptureCreated,
                capturedCountBefore: mutation.capturedCountBefore,
                capturedCountAfter: mutation.capturedCountAfter,
                lastCapturedAtAfter: mutation.lastCapturedAtAfter
            )
        )
    }

    private static func speciesAffinityUpdatedEnvelope(
        encounterID: String,
        request: EncounterResolutionWriteRequest,
        mutation: DexCapturedMutation
    ) -> DomainEventEnvelope<SpeciesAffinityUpdatedEventPayload> {
        let resolution = mutation.affinityResolution
        return DomainEventEnvelope(
            eventID: "\(TokenmonDomainEventType.speciesAffinityUpdated.rawValue):\(request.encounterSeedContextID)",
            eventType: TokenmonDomainEventType.speciesAffinityUpdated.rawValue,
            occurredAt: request.occurredAt,
            producer: "TokenmonPersistence.EncounterHistoryStore",
            correlationID: request.correlationID,
            causationID: "\(TokenmonDomainEventType.capturedDexUpdated.rawValue):\(request.encounterSeedContextID)",
            aggregateType: "dex_captured",
            aggregateID: request.speciesID,
            payload: SpeciesAffinityUpdatedEventPayload(
                speciesID: request.speciesID,
                encounterID: encounterID,
                capturedCountAfter: mutation.capturedCountAfter,
                rarity: request.rarity.rawValue,
                previousLevel: resolution.previousLevel,
                newLevel: resolution.newLevel,
                targetLevel: resolution.targetLevel,
                probability: resolution.probability,
                rngRoll: resolution.roll,
                pityCountBefore: resolution.pityCountBefore,
                pityCountAfter: resolution.pityCountAfter,
                ceilingFailures: resolution.ceilingFailures,
                outcome: resolution.outcome.rawValue
            )
        )
    }

    private static func sqliteColumnOptionalInt64(
        _ statement: OpaquePointer,
        index: Int32
    ) -> Int64? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else {
            return nil
        }
        return SQLiteDatabase.columnInt64(statement, index: index)
    }
}
