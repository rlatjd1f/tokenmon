import Foundation
import TokenmonDomain
import TokenmonGameEngine

public struct NowCampTrainingSummary: Equatable, Sendable {
    public let trainingRank: TrainingRank
    public let trainingResonance: Int
    public let trainingAttemptCount: Int
    public let careCharge: Bool

    public init(
        trainingRank: TrainingRank,
        trainingResonance: Int,
        trainingAttemptCount: Int,
        careCharge: Bool
    ) {
        self.trainingRank = trainingRank
        self.trainingResonance = trainingResonance
        self.trainingAttemptCount = trainingAttemptCount
        self.careCharge = careCharge
    }
}

public struct NowCampLeadSummary: Equatable, Sendable {
    public let speciesID: String
    public let displayName: String
    public let assetKey: String
    public let field: FieldType
    public let rarity: RarityTier
    public let trainingTrait: TrainingTrait
    public let affinityLevel: Int64
    public let slotOrder: Int
    public let training: NowCampTrainingSummary

    public init(
        speciesID: String,
        displayName: String,
        assetKey: String,
        field: FieldType,
        rarity: RarityTier,
        trainingTrait: TrainingTrait,
        affinityLevel: Int64,
        slotOrder: Int,
        training: NowCampTrainingSummary
    ) {
        self.speciesID = speciesID
        self.displayName = displayName
        self.assetKey = assetKey
        self.field = field
        self.rarity = rarity
        self.trainingTrait = trainingTrait
        self.affinityLevel = affinityLevel
        self.slotOrder = slotOrder
        self.training = training
    }
}

public struct NowCampSummary: Equatable, Sendable {
    public let leadSpeciesID: String?
    public let focusEnergy: Int
    public let focusRemainderTokens: Int64
    public let focusEarnedLocalDate: String
    public let focusEarnedToday: Int
    public let lead: NowCampLeadSummary?
    public let supports: [PartyMemberSummary]

    public init(
        leadSpeciesID: String?,
        focusEnergy: Int,
        focusRemainderTokens: Int64,
        focusEarnedLocalDate: String,
        focusEarnedToday: Int,
        lead: NowCampLeadSummary?,
        supports: [PartyMemberSummary]
    ) {
        self.leadSpeciesID = leadSpeciesID
        self.focusEnergy = focusEnergy
        self.focusRemainderTokens = focusRemainderTokens
        self.focusEarnedLocalDate = focusEarnedLocalDate
        self.focusEarnedToday = focusEarnedToday
        self.lead = lead
        self.supports = supports
    }
}

public struct NowCampCareResult: Equatable, Sendable {
    public let speciesID: String
    public let focusEnergyAfter: Int
}

public struct NowCampTrainingAttemptResult: Equatable, Sendable {
    public let resolution: LeaderTrainingResolution
    public let focusEnergyAfter: Int
}

public enum NowCampStoreError: Error, LocalizedError, Equatable {
    case missingLead
    case leadNotInParty(String)
    case missingTraining(String)
    case insufficientFocus(required: Int, available: Int)
    case careAlreadyCharged(String)
    case rankAtAffinityGate(speciesID: String, rank: TrainingRank, affinityLevel: Int64)

    public var errorDescription: String? {
        switch self {
        case .missingLead:
            return "No Now Camp Lead is selected."
        case .leadNotInParty(let speciesID):
            return "Species \(speciesID) is not in the current Party."
        case .missingTraining(let speciesID):
            return "Species \(speciesID) does not have training state."
        case .insufficientFocus(let required, let available):
            return "Focus \(required) required; \(available) available."
        case .careAlreadyCharged(let speciesID):
            return "Species \(speciesID) already has a care charge."
        case .rankAtAffinityGate(let speciesID, let rank, let affinityLevel):
            return "Species \(speciesID) Training Rank \(rank.romanNumeral) has reached Bond \(affinityLevel)."
        }
    }
}

struct FocusEnergyEarnedEventPayload: Codable, Equatable, Sendable {
    let usageSampleID: Int64
    let focusEarned: Int
    let rawFocusGain: Int
    let focusEnergyAfter: Int
    let focusRemainderTokensAfter: Int64
    let focusEarnedLocalDate: String
    let focusEarnedTodayAfter: Int
    let discardedByDailyCap: Int
    let discardedByStorageCap: Int

    enum CodingKeys: String, CodingKey {
        case usageSampleID = "usage_sample_id"
        case focusEarned = "focus_earned"
        case rawFocusGain = "raw_focus_gain"
        case focusEnergyAfter = "focus_energy_after"
        case focusRemainderTokensAfter = "focus_remainder_tokens_after"
        case focusEarnedLocalDate = "focus_earned_local_date"
        case focusEarnedTodayAfter = "focus_earned_today_after"
        case discardedByDailyCap = "discarded_by_daily_cap"
        case discardedByStorageCap = "discarded_by_storage_cap"
    }
}

struct NowCampLeadSelectedEventPayload: Codable, Equatable, Sendable {
    let previousLeadSpeciesID: String?
    let leadSpeciesID: String?
    let reason: String

    enum CodingKeys: String, CodingKey {
        case previousLeadSpeciesID = "previous_lead_species_id"
        case leadSpeciesID = "lead_species_id"
        case reason
    }
}

struct LeadCareAppliedEventPayload: Codable, Equatable, Sendable {
    let actionID: String
    let speciesID: String
    let focusSpent: Int
    let focusEnergyAfter: Int
    let trainingRank: Int
    let trainingResonance: Int

    enum CodingKeys: String, CodingKey {
        case actionID = "action_id"
        case speciesID = "species_id"
        case focusSpent = "focus_spent"
        case focusEnergyAfter = "focus_energy_after"
        case trainingRank = "training_rank"
        case trainingResonance = "training_resonance"
    }
}

struct LeadTrainingAttemptedEventPayload: Codable, Equatable, Sendable {
    let actionID: String
    let speciesID: String
    let focusSpent: Int
    let focusEnergyAfter: Int
    let previousRank: Int
    let targetRank: Int
    let attemptCountAfter: Int
    let careChargeConsumed: Bool

    enum CodingKeys: String, CodingKey {
        case actionID = "action_id"
        case speciesID = "species_id"
        case focusSpent = "focus_spent"
        case focusEnergyAfter = "focus_energy_after"
        case previousRank = "previous_rank"
        case targetRank = "target_rank"
        case attemptCountAfter = "attempt_count_after"
        case careChargeConsumed = "care_charge_consumed"
    }
}

struct LeadTrainingResolvedEventPayload: Codable, Equatable, Sendable {
    let actionID: String
    let speciesID: String
    let outcome: String
    let previousRank: Int
    let newRank: Int
    let targetRank: Int
    let probability: Double
    let rngRoll: Double?
    let resonanceBefore: Int
    let resonanceAfter: Int
    let ceilingFailures: Int

    enum CodingKeys: String, CodingKey {
        case actionID = "action_id"
        case speciesID = "species_id"
        case outcome
        case previousRank = "previous_rank"
        case newRank = "new_rank"
        case targetRank = "target_rank"
        case probability
        case rngRoll = "rng_roll"
        case resonanceBefore = "resonance_before"
        case resonanceAfter = "resonance_after"
        case ceilingFailures = "ceiling_failures"
    }
}

public struct LeaderTraitBonusAppliedEventPayload: Codable, Equatable, Sendable {
    public let usageSampleID: Int64?
    public let encounterID: String?
    public let raidAttackID: Int64?
    public let speciesID: String
    public let trait: String
    public let bonusKind: String
    public let field: String
    public let trainingRank: Int
    public let bonusAmount: Double
    public let capApplied: Double?

    enum CodingKeys: String, CodingKey {
        case usageSampleID = "usage_sample_id"
        case encounterID = "encounter_id"
        case raidAttackID = "raid_attack_id"
        case speciesID = "species_id"
        case trait
        case bonusKind = "bonus_kind"
        case field
        case trainingRank = "training_rank"
        case bonusAmount = "bonus_amount"
        case capApplied = "cap_applied"
    }
}

public extension TokenmonDatabaseManager {
    func nowCampSummary(database providedDatabase: SQLiteDatabase? = nil) throws -> NowCampSummary {
        let database = try providedDatabase ?? open()
        try ensureNowCampState(database: database)
        try ensureSpeciesTrainingRowsForCaptured(database: database)
        try repairNowCampLead(database: database)

        let state = try nowCampState(database: database)
        let lead = try state.leadSpeciesID.flatMap { try nowCampLead(speciesID: $0, database: database) }
        let supports = try partyMemberSummaries(database: database)
            .filter { $0.speciesID != state.leadSpeciesID }
            .prefix(2)

        return NowCampSummary(
            leadSpeciesID: state.leadSpeciesID,
            focusEnergy: state.focusEnergy,
            focusRemainderTokens: state.focusRemainderTokens,
            focusEarnedLocalDate: state.focusEarnedLocalDate,
            focusEarnedToday: state.focusEarnedToday,
            lead: lead,
            supports: Array(supports)
        )
    }

    func setNowCampLead(speciesID: String?) throws {
        let database = try open()
        try database.inTransaction {
            try ensureNowCampState(database: database)
            let previous = try nowCampState(database: database).leadSpeciesID
            if let speciesID {
                let isPartyMember = try database.fetchOne(
                    "SELECT 1 FROM party_members WHERE species_id = ? LIMIT 1;",
                    bindings: [.text(speciesID)]
                ) { _ in true } ?? false
                guard isPartyMember else {
                    throw NowCampStoreError.leadNotInParty(speciesID)
                }
            }
            guard previous != speciesID else { return }
            let now = ISO8601DateFormatter().string(from: Date())
            try database.execute(
                """
                UPDATE now_camp_state
                SET lead_species_id = ?,
                    updated_at = ?
                WHERE singleton_id = 1;
                """,
                bindings: [
                    speciesID.map(SQLiteValue.text) ?? .null,
                    .text(now),
                ]
            )
            try persistLeadSelectedEvent(
                database: database,
                previousLeadSpeciesID: previous,
                leadSpeciesID: speciesID,
                reason: "user",
                occurredAt: now
            )
        }
    }

    @discardableResult
    func applyLeadCare() throws -> NowCampCareResult {
        let database = try open()
        var result: NowCampCareResult?
        try database.inTransaction {
            try ensureNowCampState(database: database)
            try ensureSpeciesTrainingRowsForCaptured(database: database)
            try repairNowCampLead(database: database)
            let state = try nowCampState(database: database)
            guard let leadSpeciesID = state.leadSpeciesID else {
                throw NowCampStoreError.missingLead
            }
            let lead = try requireNowCampLead(speciesID: leadSpeciesID, database: database)
            guard state.focusEnergy >= LeaderTrainingResolver().careFocusCost else {
                throw NowCampStoreError.insufficientFocus(
                    required: LeaderTrainingResolver().careFocusCost,
                    available: state.focusEnergy
                )
            }
            guard lead.training.careCharge == false else {
                throw NowCampStoreError.careAlreadyCharged(leadSpeciesID)
            }
            guard lead.training.trainingRank.rawValue < Int(lead.affinityLevel) else {
                throw NowCampStoreError.rankAtAffinityGate(
                    speciesID: leadSpeciesID,
                    rank: lead.training.trainingRank,
                    affinityLevel: lead.affinityLevel
                )
            }

            let focusAfter = state.focusEnergy - LeaderTrainingResolver().careFocusCost
            let now = ISO8601DateFormatter().string(from: Date())
            let actionID = UUID().uuidString.lowercased()

            try database.execute(
                """
                UPDATE now_camp_state
                SET focus_energy = ?,
                    updated_at = ?
                WHERE singleton_id = 1;
                """,
                bindings: [.integer(Int64(focusAfter)), .text(now)]
            )
            try database.execute(
                """
                UPDATE species_training
                SET care_charge = 1,
                    updated_at = ?
                WHERE species_id = ?;
                """,
                bindings: [.text(now), .text(leadSpeciesID)]
            )
            try DomainEventStore.persist(
                database: database,
                envelope: DomainEventEnvelope(
                    eventID: "\(TokenmonDomainEventType.leadCareApplied.rawValue):\(actionID)",
                    eventType: TokenmonDomainEventType.leadCareApplied.rawValue,
                    occurredAt: now,
                    producer: "TokenmonPersistence.NowCampStore",
                    aggregateType: "species_training",
                    aggregateID: leadSpeciesID,
                    payload: LeadCareAppliedEventPayload(
                        actionID: actionID,
                        speciesID: leadSpeciesID,
                        focusSpent: LeaderTrainingResolver().careFocusCost,
                        focusEnergyAfter: focusAfter,
                        trainingRank: lead.training.trainingRank.rawValue,
                        trainingResonance: lead.training.trainingResonance
                    )
                )
            )
            result = NowCampCareResult(speciesID: leadSpeciesID, focusEnergyAfter: focusAfter)
        }

        guard let result else {
            throw NowCampStoreError.missingLead
        }
        return result
    }

    @discardableResult
    func trainNowCampLead() throws -> NowCampTrainingAttemptResult {
        let database = try open()
        var result: NowCampTrainingAttemptResult?
        try database.inTransaction {
            try ensureNowCampState(database: database)
            try ensureSpeciesTrainingRowsForCaptured(database: database)
            try repairNowCampLead(database: database)
            let state = try nowCampState(database: database)
            guard let leadSpeciesID = state.leadSpeciesID else {
                throw NowCampStoreError.missingLead
            }
            let lead = try requireNowCampLead(speciesID: leadSpeciesID, database: database)
            let resolver = LeaderTrainingResolver()
            guard state.focusEnergy >= resolver.trainFocusCost else {
                throw NowCampStoreError.insufficientFocus(
                    required: resolver.trainFocusCost,
                    available: state.focusEnergy
                )
            }
            guard lead.training.trainingRank.rawValue < Int(lead.affinityLevel) else {
                throw NowCampStoreError.rankAtAffinityGate(
                    speciesID: leadSpeciesID,
                    rank: lead.training.trainingRank,
                    affinityLevel: lead.affinityLevel
                )
            }

            let resolution = try resolver.resolveTrain(
                speciesID: leadSpeciesID,
                rarity: lead.rarity,
                saveTrainingSeed: state.saveTrainingSeed,
                currentRank: lead.training.trainingRank,
                affinityLevel: Int(lead.affinityLevel),
                resonance: lead.training.trainingResonance,
                attemptCount: lead.training.trainingAttemptCount,
                careCharge: lead.training.careCharge
            )
            let focusAfter = state.focusEnergy - resolver.trainFocusCost
            let now = ISO8601DateFormatter().string(from: Date())
            let actionID = UUID().uuidString.lowercased()

            try database.execute(
                """
                UPDATE now_camp_state
                SET focus_energy = ?,
                    updated_at = ?
                WHERE singleton_id = 1;
                """,
                bindings: [.integer(Int64(focusAfter)), .text(now)]
            )
            try DomainEventStore.persist(
                database: database,
                envelope: DomainEventEnvelope(
                    eventID: "\(TokenmonDomainEventType.leadTrainingAttempted.rawValue):\(actionID)",
                    eventType: TokenmonDomainEventType.leadTrainingAttempted.rawValue,
                    occurredAt: now,
                    producer: "TokenmonPersistence.NowCampStore",
                    aggregateType: "species_training",
                    aggregateID: leadSpeciesID,
                    payload: LeadTrainingAttemptedEventPayload(
                        actionID: actionID,
                        speciesID: leadSpeciesID,
                        focusSpent: resolver.trainFocusCost,
                        focusEnergyAfter: focusAfter,
                        previousRank: resolution.previousRank.rawValue,
                        targetRank: resolution.targetRank.rawValue,
                        attemptCountAfter: resolution.attemptCountAfter,
                        careChargeConsumed: resolution.careChargeConsumed
                    )
                )
            )
            try database.execute(
                """
                UPDATE species_training
                SET training_rank = ?,
                    training_resonance = ?,
                    training_attempt_count = ?,
                    care_charge = 0,
                    updated_at = ?
                WHERE species_id = ?;
                """,
                bindings: [
                    .integer(resolution.newRank.storageValue),
                    .integer(Int64(resolution.resonanceAfter)),
                    .integer(Int64(resolution.attemptCountAfter)),
                    .text(now),
                    .text(leadSpeciesID),
                ]
            )
            try DomainEventStore.persist(
                database: database,
                envelope: DomainEventEnvelope(
                    eventID: "\(TokenmonDomainEventType.leadTrainingResolved.rawValue):\(actionID)",
                    eventType: TokenmonDomainEventType.leadTrainingResolved.rawValue,
                    occurredAt: now,
                    producer: "TokenmonGameEngine.LeaderTrainingResolver",
                    causationID: "\(TokenmonDomainEventType.leadTrainingAttempted.rawValue):\(actionID)",
                    aggregateType: "species_training",
                    aggregateID: leadSpeciesID,
                    payload: LeadTrainingResolvedEventPayload(
                        actionID: actionID,
                        speciesID: leadSpeciesID,
                        outcome: resolution.outcome.rawValue,
                        previousRank: resolution.previousRank.rawValue,
                        newRank: resolution.newRank.rawValue,
                        targetRank: resolution.targetRank.rawValue,
                        probability: resolution.probability,
                        rngRoll: resolution.roll,
                        resonanceBefore: resolution.resonanceBefore,
                        resonanceAfter: resolution.resonanceAfter,
                        ceilingFailures: resolution.ceilingFailures
                    )
                )
            )
            result = NowCampTrainingAttemptResult(resolution: resolution, focusEnergyAfter: focusAfter)
        }

        guard let result else {
            throw NowCampStoreError.missingLead
        }
        return result
    }

    @discardableResult
    func addNowCampFocus(
        database: SQLiteDatabase,
        usageSampleID: Int64,
        gameplayDeltaTokens: Int64,
        observedAt: String,
        correlationID: String?,
        localDate: String = TokenmonDatabaseManager.currentLocalDate()
    ) throws -> NowCampFocusAccumulation {
        try ensureNowCampState(database: database)
        let state = try nowCampState(database: database)
        let focusState = NowCampFocusState(
            focusEnergy: state.focusEnergy,
            focusRemainderTokens: state.focusRemainderTokens,
            focusEarnedLocalDate: state.focusEarnedLocalDate,
            focusEarnedToday: state.focusEarnedToday
        )
        let accumulation = try NowCampFocusAccumulator().accumulate(
            state: focusState,
            gameplayDeltaTokens: gameplayDeltaTokens,
            localDate: localDate
        )
        try database.execute(
            """
            UPDATE now_camp_state
            SET focus_energy = ?,
                focus_remainder_tokens = ?,
                focus_earned_local_date = ?,
                focus_earned_today = ?,
                updated_at = ?
            WHERE singleton_id = 1;
            """,
            bindings: [
                .integer(Int64(accumulation.updatedState.focusEnergy)),
                .integer(accumulation.updatedState.focusRemainderTokens),
                .text(accumulation.updatedState.focusEarnedLocalDate),
                .integer(Int64(accumulation.updatedState.focusEarnedToday)),
                .text(ISO8601DateFormatter().string(from: Date())),
            ]
        )

        if accumulation.focusEarned > 0 {
            try DomainEventStore.persist(
                database: database,
                envelope: DomainEventEnvelope(
                    eventID: "\(TokenmonDomainEventType.focusEnergyEarned.rawValue):usage-sample-\(usageSampleID)",
                    eventType: TokenmonDomainEventType.focusEnergyEarned.rawValue,
                    occurredAt: observedAt,
                    producer: "TokenmonGameEngine.NowCampFocusAccumulator",
                    correlationID: correlationID,
                    causationID: TokenmonDomainEventRegistry.usageSampleEventID(usageSampleID),
                    aggregateType: "now_camp_state",
                    aggregateID: "1",
                    payload: FocusEnergyEarnedEventPayload(
                        usageSampleID: usageSampleID,
                        focusEarned: accumulation.focusEarned,
                        rawFocusGain: accumulation.rawFocusGain,
                        focusEnergyAfter: accumulation.updatedState.focusEnergy,
                        focusRemainderTokensAfter: accumulation.updatedState.focusRemainderTokens,
                        focusEarnedLocalDate: accumulation.updatedState.focusEarnedLocalDate,
                        focusEarnedTodayAfter: accumulation.updatedState.focusEarnedToday,
                        discardedByDailyCap: accumulation.discardedByDailyCap,
                        discardedByStorageCap: accumulation.discardedByStorageCap
                    )
                )
            )
        }
        return accumulation
    }

    func leaderTraitContext(database: SQLiteDatabase) throws -> LeaderTraitContext? {
        try ensureNowCampState(database: database)
        try ensureSpeciesTrainingRowsForCaptured(database: database)
        try repairNowCampLead(database: database)
        guard let leadSpeciesID = try nowCampState(database: database).leadSpeciesID,
              let lead = try nowCampLead(speciesID: leadSpeciesID, database: database) else {
            return nil
        }
        return LeaderTraitContext(
            speciesID: lead.speciesID,
            homeField: lead.field,
            rarity: lead.rarity,
            trait: lead.trainingTrait,
            trainingRank: lead.training.trainingRank,
            slotOrder: lead.slotOrder
        )
    }

    func partyLeaderTraitContexts(database: SQLiteDatabase) throws -> [LeaderTraitContext] {
        try ensureSpeciesTrainingRowsForCaptured(database: database)
        let sql = """
        SELECT party_members.species_id,
               species.field_code,
               species.rarity_tier,
               species.training_trait,
               COALESCE(species_training.training_rank, 1),
               party_members.slot_order
        FROM party_members
        INNER JOIN species ON species.species_id = party_members.species_id
        LEFT JOIN species_training ON species_training.species_id = party_members.species_id
        ORDER BY party_members.slot_order ASC;
        """
        return try database.fetchAll(sql) { statement in
            let field = try decodeFieldType(SQLiteDatabase.columnText(statement, index: 1), sql: sql)
            let rarity = try decodeRarityTier(SQLiteDatabase.columnText(statement, index: 2), sql: sql)
            let traitRaw = SQLiteDatabase.columnText(statement, index: 3)
            guard let trait = TrainingTrait(rawValue: traitRaw),
                  let rank = TrainingRank(storageValue: SQLiteDatabase.columnInt64(statement, index: 4)) else {
                throw SQLiteError.statementFailed(message: "invalid training row for party member", sql: sql)
            }
            return LeaderTraitContext(
                speciesID: SQLiteDatabase.columnText(statement, index: 0),
                homeField: field,
                rarity: rarity,
                trait: trait,
                trainingRank: rank,
                slotOrder: Int(SQLiteDatabase.columnInt64(statement, index: 5))
            )
        }
    }

    func persistLeaderTraitBonusApplications(
        database: SQLiteDatabase,
        applications: [LeaderTraitBonusApplication],
        usageSampleID: Int64?,
        encounterID: String?,
        raidAttackID: Int64?,
        observedAt: String,
        correlationID: String?,
        causationID: String?
    ) throws {
        guard applications.isEmpty == false else { return }

        for (index, application) in applications.enumerated() {
            let scopeID = encounterID
                ?? raidAttackID.map { "raid-attack-\($0)" }
                ?? usageSampleID.map { "usage-sample-\($0)" }
                ?? UUID().uuidString.lowercased()
            try DomainEventStore.persist(
                database: database,
                envelope: DomainEventEnvelope(
                    eventID: "\(TokenmonDomainEventType.leaderTraitBonusApplied.rawValue):\(scopeID):\(application.kind.rawValue):\(application.speciesID):\(index)",
                    eventType: TokenmonDomainEventType.leaderTraitBonusApplied.rawValue,
                    occurredAt: observedAt,
                    producer: "TokenmonGameEngine.LeaderTraitBonusResolver",
                    correlationID: correlationID,
                    causationID: causationID,
                    aggregateType: application.kind == .raider ? "raid_attack" : "encounter",
                    aggregateID: encounterID ?? raidAttackID.map(String.init),
                    payload: LeaderTraitBonusAppliedEventPayload(
                        usageSampleID: usageSampleID,
                        encounterID: encounterID,
                        raidAttackID: raidAttackID,
                        speciesID: application.speciesID,
                        trait: application.trait.rawValue,
                        bonusKind: application.kind.rawValue,
                        field: application.field.rawValue,
                        trainingRank: application.trainingRank.rawValue,
                        bonusAmount: application.bonusAmount,
                        capApplied: application.capApplied
                    )
                )
            )
        }
    }

    func ensureNowCampState(database: SQLiteDatabase) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT OR IGNORE INTO now_camp_state (
                singleton_id,
                lead_species_id,
                focus_energy,
                focus_remainder_tokens,
                focus_earned_local_date,
                focus_earned_today,
                save_training_seed,
                updated_at
            ) VALUES (1, NULL, 0, 0, ?, 0, ?, ?);
            """,
            bindings: [
                .text(Self.currentLocalDate()),
                .text(UUID().uuidString.lowercased()),
                .text(now),
            ]
        )
    }

    func ensureSpeciesTrainingRowsForCaptured(database: SQLiteDatabase) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT INTO species_training (
                species_id,
                training_rank,
                training_resonance,
                training_attempt_count,
                care_charge,
                updated_at
            )
            SELECT dex_captured.species_id,
                   1,
                   0,
                   0,
                   0,
                   ?
            FROM dex_captured
            LEFT JOIN species_training ON species_training.species_id = dex_captured.species_id
            WHERE species_training.species_id IS NULL;
            """,
            bindings: [.text(now)]
        )
    }

    func repairNowCampLead(database: SQLiteDatabase) throws {
        let state = try nowCampState(database: database)
        let currentLeadIsValid: Bool
        if let lead = state.leadSpeciesID {
            currentLeadIsValid = try database.fetchOne(
                "SELECT 1 FROM party_members WHERE species_id = ? LIMIT 1;",
                bindings: [.text(lead)]
            ) { _ in true } ?? false
        } else {
            currentLeadIsValid = false
        }

        if currentLeadIsValid {
            return
        }

        let repairedLead = try database.fetchOne(
            """
            SELECT species_id
            FROM party_members
            ORDER BY slot_order ASC
            LIMIT 1;
            """
        ) { statement in
            SQLiteDatabase.columnText(statement, index: 0)
        }
        guard repairedLead != state.leadSpeciesID else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE now_camp_state
            SET lead_species_id = ?,
                updated_at = ?
            WHERE singleton_id = 1;
            """,
            bindings: [
                repairedLead.map(SQLiteValue.text) ?? .null,
                .text(now),
            ]
        )
        try persistLeadSelectedEvent(
            database: database,
            previousLeadSpeciesID: state.leadSpeciesID,
            leadSpeciesID: repairedLead,
            reason: "auto_repair",
            occurredAt: now
        )
    }

    static func currentLocalDate(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private extension TokenmonDatabaseManager {
    struct NowCampStateRecord {
        let leadSpeciesID: String?
        let focusEnergy: Int
        let focusRemainderTokens: Int64
        let focusEarnedLocalDate: String
        let focusEarnedToday: Int
        let saveTrainingSeed: String
    }

    func nowCampState(database: SQLiteDatabase) throws -> NowCampStateRecord {
        guard let state = try database.fetchOne(
            """
            SELECT lead_species_id,
                   focus_energy,
                   focus_remainder_tokens,
                   focus_earned_local_date,
                   focus_earned_today,
                   save_training_seed
            FROM now_camp_state
            WHERE singleton_id = 1
            LIMIT 1;
            """,
            map: { statement in
            NowCampStateRecord(
                leadSpeciesID: SQLiteDatabase.columnOptionalText(statement, index: 0),
                focusEnergy: Int(SQLiteDatabase.columnInt64(statement, index: 1)),
                focusRemainderTokens: SQLiteDatabase.columnInt64(statement, index: 2),
                focusEarnedLocalDate: SQLiteDatabase.columnText(statement, index: 3),
                focusEarnedToday: Int(SQLiteDatabase.columnInt64(statement, index: 4)),
                saveTrainingSeed: SQLiteDatabase.columnText(statement, index: 5)
            )
        }) else {
            throw SQLiteError.statementFailed(
                message: "missing now_camp_state singleton",
                sql: "SELECT ... FROM now_camp_state WHERE singleton_id = 1"
            )
        }
        return state
    }

    func requireNowCampLead(speciesID: String, database: SQLiteDatabase) throws -> NowCampLeadSummary {
        guard let lead = try nowCampLead(speciesID: speciesID, database: database) else {
            throw NowCampStoreError.leadNotInParty(speciesID)
        }
        return lead
    }

    func nowCampLead(speciesID: String, database: SQLiteDatabase) throws -> NowCampLeadSummary? {
        let sql = """
        SELECT party_members.species_id,
               species.name,
               species.asset_key,
               species.field_code,
               species.rarity_tier,
               species.training_trait,
               dex_captured.affinity_level,
               party_members.slot_order,
               COALESCE(species_training.training_rank, 1),
               COALESCE(species_training.training_resonance, 0),
               COALESCE(species_training.training_attempt_count, 0),
               COALESCE(species_training.care_charge, 0)
        FROM party_members
        INNER JOIN species ON species.species_id = party_members.species_id
        INNER JOIN dex_captured ON dex_captured.species_id = party_members.species_id
        LEFT JOIN species_training ON species_training.species_id = party_members.species_id
        WHERE party_members.species_id = ?
        LIMIT 1;
        """
        return try database.fetchOne(sql, bindings: [.text(speciesID)]) { statement in
            let field = try decodeFieldType(SQLiteDatabase.columnText(statement, index: 3), sql: sql)
            let rarity = try decodeRarityTier(SQLiteDatabase.columnText(statement, index: 4), sql: sql)
            let traitRaw = SQLiteDatabase.columnText(statement, index: 5)
            guard let trait = TrainingTrait(rawValue: traitRaw),
                  let rank = TrainingRank(storageValue: SQLiteDatabase.columnInt64(statement, index: 8)) else {
                throw SQLiteError.statementFailed(message: "invalid Now Camp lead training row", sql: sql)
            }
            return NowCampLeadSummary(
                speciesID: SQLiteDatabase.columnText(statement, index: 0),
                displayName: SQLiteDatabase.columnText(statement, index: 1),
                assetKey: SQLiteDatabase.columnText(statement, index: 2),
                field: field,
                rarity: rarity,
                trainingTrait: trait,
                affinityLevel: SQLiteDatabase.columnInt64(statement, index: 6),
                slotOrder: Int(SQLiteDatabase.columnInt64(statement, index: 7)),
                training: NowCampTrainingSummary(
                    trainingRank: rank,
                    trainingResonance: Int(SQLiteDatabase.columnInt64(statement, index: 9)),
                    trainingAttemptCount: Int(SQLiteDatabase.columnInt64(statement, index: 10)),
                    careCharge: SQLiteDatabase.columnInt64(statement, index: 11) != 0
                )
            )
        }
    }

    func persistLeadSelectedEvent(
        database: SQLiteDatabase,
        previousLeadSpeciesID: String?,
        leadSpeciesID: String?,
        reason: String,
        occurredAt: String
    ) throws {
        try DomainEventStore.persist(
            database: database,
            envelope: DomainEventEnvelope(
                eventID: "\(TokenmonDomainEventType.nowCampLeadSelected.rawValue):\(UUID().uuidString.lowercased())",
                eventType: TokenmonDomainEventType.nowCampLeadSelected.rawValue,
                occurredAt: occurredAt,
                producer: "TokenmonPersistence.NowCampStore",
                aggregateType: "now_camp_state",
                aggregateID: "1",
                payload: NowCampLeadSelectedEventPayload(
                    previousLeadSpeciesID: previousLeadSpeciesID,
                    leadSpeciesID: leadSpeciesID,
                    reason: reason
                )
            )
        )
    }
}
