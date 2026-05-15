import Foundation
import TokenmonDomain
import TokenmonGameEngine
import TokenmonProviders

public struct InboxIngestionResult: Sendable {
    public let acceptedEvents: Int
    public let duplicateEvents: Int
    public let rejectedEvents: Int
    public let partialTrailingLines: Int
    public let usageSamplesCreated: Int
    public let sourceKey: String
    public let lastOffset: Int64
    public let lastLineNumber: Int
}

private enum EventIngestionDisposition {
    case accepted
    case duplicate
    case rejected
}

private struct PreviousUsageSampleState {
    let normalizedTotalTokens: Int64
    let observedAt: String
}

private struct GameplayEligibilityDecision {
    let eligibility: UsageSampleGameplayEligibility
    let rawEligibleDeltaTokens: Int64
}

public final class UsageSampleIngestionService {
    private let databaseManager: TokenmonDatabaseManager
    private let explorationAccumulator: ExplorationAccumulator
    private let encounterGenerator: EncounterGenerator
    private let captureResolver: CaptureResolver

    public init(databasePath: String) {
        databaseManager = TokenmonDatabaseManager(path: databasePath)
        explorationAccumulator = ExplorationAccumulator()
        encounterGenerator = EncounterGenerator()
        captureResolver = CaptureResolver()
    }

    public func ingestInboxFile(at inboxPath: String, sourceKey: String? = nil) throws -> InboxIngestionResult {
        let database = try databaseManager.open()
        let resolvedSourceKey = sourceKey ?? "ndjson:\(URL(fileURLWithPath: inboxPath).path)"
        var sourceState = try IngestSourceCheckpointStore.loadOrCreate(
            database: database,
            sourceKey: resolvedSourceKey,
            sourceKind: "ndjson_file",
            path: inboxPath
        )
        sourceState = try IngestSourceCheckpointStore.reconcileWithCurrentFile(
            database: database,
            checkpoint: sourceState,
            path: inboxPath
        )
        let readResult = try ProviderInboxReader.read(from: inboxPath, startingAt: sourceState.lastOffset)

        var acceptedEvents = 0
        var duplicateEvents = 0
        var rejectedEvents = 0
        var partialTrailingLines = 0
        var usageSamplesCreated = 0
        var lastOffset = sourceState.lastOffset
        var lastLineNumber = sourceState.lastLineNumber

        let decoder = JSONDecoder()

        for line in readResult.lines {
            let candidateLineNumber = lastLineNumber + 1
            let trimmed = line.rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.isEmpty {
                lastOffset = line.nextOffset
                lastLineNumber = candidateLineNumber
                try IngestSourceCheckpointStore.advance(
                    database: database,
                    sourceID: sourceState.ingestSourceID,
                    path: inboxPath,
                    offset: lastOffset,
                    lineNumber: lastLineNumber,
                    fingerprint: nil
                )
                continue
            }

            let data = Data(trimmed.utf8)
            let event: ProviderUsageSampleEvent
            do {
                event = try decoder.decode(ProviderUsageSampleEvent.self, from: data)
                try event.validate()
            } catch {
                if !line.newlineTerminated {
                    partialTrailingLines += 1
                    break
                }

                rejectedEvents += 1
                lastOffset = line.nextOffset
                lastLineNumber = candidateLineNumber
                try IngestSourceCheckpointStore.advance(
                    database: database,
                    sourceID: sourceState.ingestSourceID,
                    path: inboxPath,
                    offset: lastOffset,
                    lineNumber: lastLineNumber,
                    fingerprint: nil
                )
                continue
            }

            switch try ingestValidatedEvent(
                database: database,
                event: event,
                rawPayload: trimmed,
                ingestSourceID: sourceState.ingestSourceID,
                sourceKey: resolvedSourceKey,
                sourceKind: "ndjson_file",
                sourcePath: inboxPath,
                nextOffset: line.nextOffset,
                lineNumber: candidateLineNumber
            ) {
            case .accepted:
                acceptedEvents += 1
                usageSamplesCreated += 1
            case .duplicate:
                duplicateEvents += 1
            case .rejected:
                rejectedEvents += 1
            }

            lastOffset = line.nextOffset
            lastLineNumber = candidateLineNumber
        }

        return InboxIngestionResult(
            acceptedEvents: acceptedEvents,
            duplicateEvents: duplicateEvents,
            rejectedEvents: rejectedEvents,
            partialTrailingLines: partialTrailingLines,
            usageSamplesCreated: usageSamplesCreated,
            sourceKey: resolvedSourceKey,
            lastOffset: lastOffset,
            lastLineNumber: lastLineNumber
        )
    }

    public func ingestProviderEvents(
        _ events: [ProviderUsageSampleEvent],
        sourceKey: String,
        sourcePath: String? = nil,
        sourceKind: String = "recovery_scan"
    ) throws -> InboxIngestionResult {
        let database = try databaseManager.open()
        return try ingestProviderEvents(
            database: database,
            events: events,
            sourceKey: sourceKey,
            sourcePath: sourcePath,
            sourceKind: sourceKind
        )
    }

    public func ingestProviderEvents(
        database: SQLiteDatabase,
        events: [ProviderUsageSampleEvent],
        sourceKey: String,
        sourcePath: String? = nil,
        sourceKind: String = "recovery_scan",
        manageSourceCheckpoint: Bool = true
    ) throws -> InboxIngestionResult {
        let sourceState = try manageSourceCheckpoint
            ? IngestSourceCheckpointStore.loadOrCreate(
                database: database,
                sourceKey: sourceKey,
                sourceKind: sourceKind,
                path: sourcePath
            )
            : nil
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var acceptedEvents = 0
        var duplicateEvents = 0
        var rejectedEvents = 0
        var lastOffset: Int64 = 0
        var lastLineNumber = 0

        for (index, event) in events.enumerated() {
            let lineNumber = index + 1
            let nextOffset = Int64(lineNumber)
            let rawPayload: String

            do {
                try event.validate()
                try databaseManager.ensureProviderRegistered(event.provider, database: database)
                rawPayload = String(decoding: try encoder.encode(event), as: UTF8.self)
            } catch {
                rejectedEvents += 1
                lastOffset = nextOffset
                lastLineNumber = lineNumber
                try updateIngestSource(
                    database: database,
                    sourceID: sourceState?.ingestSourceID,
                    sourceKey: sourceKey,
                    path: sourcePath,
                    offset: lastOffset,
                    lineNumber: lastLineNumber,
                    fingerprint: nil
                )
                continue
            }

            switch try ingestValidatedEvent(
                database: database,
                event: event,
                rawPayload: rawPayload,
                ingestSourceID: sourceState?.ingestSourceID,
                sourceKey: sourceKey,
                sourceKind: sourceKind,
                sourcePath: sourcePath,
                nextOffset: nextOffset,
                lineNumber: lineNumber
            ) {
            case .accepted:
                acceptedEvents += 1
            case .duplicate:
                duplicateEvents += 1
            case .rejected:
                rejectedEvents += 1
            }

            lastOffset = nextOffset
            lastLineNumber = lineNumber
        }

        return InboxIngestionResult(
            acceptedEvents: acceptedEvents,
            duplicateEvents: duplicateEvents,
            rejectedEvents: rejectedEvents,
            partialTrailingLines: 0,
            usageSamplesCreated: acceptedEvents,
            sourceKey: sourceKey,
            lastOffset: lastOffset,
            lastLineNumber: lastLineNumber
        )
    }

    private func resolveEncounterThreshold(
        database: SQLiteDatabase,
        event: ProviderUsageSampleEvent,
        providerSessionRowID: Int64,
        usageSampleID: Int64,
        burstIntensityBand: Int,
        threshold: EncounterThresholdCrossedSnapshot
    ) throws {
        let seedContextID = "usage-sample-\(usageSampleID):threshold-\(threshold.thresholdIndexGlobal)"
        let priorEncounterFields = try recentEncounterFields(database: database, limit: 2)
        let priorEncounterSpeciesIDs = try recentEncounterSpeciesIDs(database: database, limit: 5)
        let capturedSpeciesCounts = try dexCapturedCounts(database: database)
        let leaderTraitContext = try databaseManager.leaderTraitContext(database: database)
        var encounterRNG = SeededEncounterRandomNumberGenerator(
            seed: Self.stableSeed(for: "\(seedContextID):encounter")
        )
        let generatedEncounter = try encounterGenerator.generateEncounter(
            context: EncounterGenerationContext(
                threshold: threshold,
                usageSampleID: usageSampleID,
                provider: event.provider,
                providerSessionRowID: providerSessionRowID,
                occurredAt: event.observedAt,
                burstIntensityBand: burstIntensityBand,
                priorEncounterFields: priorEncounterFields,
                priorEncounterSpeciesIDs: priorEncounterSpeciesIDs,
                capturedSpeciesCounts: capturedSpeciesCounts,
                leaderTraitContext: leaderTraitContext
            ),
            using: &encounterRNG
        )
        var captureRNG = SeededCaptureRandomNumberGenerator(
            seed: Self.stableSeed(for: "\(seedContextID):capture")
        )
        let baseCaptureProbability = try captureResolver.captureProbability(for: generatedEncounter.rarity)
        let captureBonusResult = LeaderTraitBonusResolver().applyCapture(
            baseProbability: baseCaptureProbability,
            encounterField: generatedEncounter.field,
            encounterRarity: generatedEncounter.rarity,
            lead: leaderTraitContext
        )
        let captureResolution = try captureResolver.resolve(
            rarity: generatedEncounter.rarity,
            probability: captureBonusResult.probability,
            roll: captureRNG.nextUnitInterval()
        )

        try DomainEventStore.persist(
            database: database,
            envelope: TokenmonDomainEventRegistry.fieldSelected(
                generatedEncounter: generatedEncounter,
                correlationID: event.providerEventFingerprint
            )
        )
        try DomainEventStore.persist(
            database: database,
            envelope: TokenmonDomainEventRegistry.raritySelected(
                generatedEncounter: generatedEncounter,
                correlationID: event.providerEventFingerprint
            )
        )
        try DomainEventStore.persist(
            database: database,
            envelope: TokenmonDomainEventRegistry.speciesSelected(
                generatedEncounter: generatedEncounter,
                correlationID: event.providerEventFingerprint
            )
        )

        let persistedEncounter = try EncounterHistoryStore.persistResolvedEncounter(
            database: database,
            request: EncounterResolutionWriteRequest(
                encounterID: generatedEncounter.encounterID,
                providerCode: event.provider,
                providerSessionID: event.providerSessionID,
                providerSessionRowID: providerSessionRowID,
                usageSampleID: usageSampleID,
                thresholdEventIndex: threshold.thresholdIndexGlobal,
                occurredAt: event.observedAt,
                field: generatedEncounter.field,
                rarity: generatedEncounter.rarity,
                speciesID: generatedEncounter.species.id,
                burstIntensityBand: burstIntensityBand,
                captureProbability: captureResolution.captureProbability,
                captureRoll: captureResolution.captureRoll,
                outcome: captureResolution.outcome,
                encounterSeedContextID: generatedEncounter.encounterSeedContextID,
                encounterSequence: generatedEncounter.encounterSequence,
                correlationID: event.providerEventFingerprint,
                causationID: seedContextID
            )
        )
        try databaseManager.persistLeaderTraitBonusApplications(
            database: database,
            applications: generatedEncounter.traitBonusApplications
                + [captureBonusResult.application].compactMap { $0 },
            usageSampleID: usageSampleID,
            encounterID: persistedEncounter.encounterID,
            raidAttackID: nil,
            observedAt: event.observedAt,
            correlationID: event.providerEventFingerprint,
            causationID: "\(TokenmonDomainEventType.encounterSpawned.rawValue):\(generatedEncounter.encounterSeedContextID)"
        )
    }

    private func ingestValidatedEvent(
        database: SQLiteDatabase,
        event: ProviderUsageSampleEvent,
        rawPayload: String,
        ingestSourceID: Int64?,
        sourceKey: String,
        sourceKind: String,
        sourcePath: String?,
        nextOffset: Int64,
        lineNumber: Int
    ) throws -> EventIngestionDisposition {
        try databaseManager.ensureProviderRegistered(event.provider, database: database)
        if try fingerprintExists(database: database, fingerprint: event.providerEventFingerprint) {
            try updateIngestSource(
                database: database,
                sourceID: ingestSourceID,
                sourceKey: sourceKey,
                path: sourcePath,
                offset: nextOffset,
                lineNumber: lineNumber,
                fingerprint: event.providerEventFingerprint
            )
            return .duplicate
        }

        if event.provider == .cursor {
            _ = try insertProviderIngestEvent(
                database: database,
                event: event,
                sessionRowID: nil,
                ingestSourceID: ingestSourceID,
                rawPayload: rawPayload,
                acceptanceState: "rejected",
                rejectionReason: "cursor_stats_only_provider_usage_unsupported"
            )
            try updateIngestSource(
                database: database,
                sourceID: ingestSourceID,
                sourceKey: sourceKey,
                path: sourcePath,
                offset: nextOffset,
                lineNumber: lineNumber,
                fingerprint: event.providerEventFingerprint
            )
            return .rejected
        }

        let sessionRowID = try upsertProviderSession(database: database, event: event)
        let previousSample = try previousUsageSample(database: database, sessionRowID: sessionRowID)
        let previousTotal = previousSample?.normalizedTotalTokens

        if let previousTotal, event.normalizedTotalTokens < previousTotal {
            _ = try insertProviderIngestEvent(
                database: database,
                event: event,
                sessionRowID: sessionRowID,
                ingestSourceID: ingestSourceID,
                rawPayload: rawPayload,
                acceptanceState: "rejected",
                rejectionReason: "negative_total_regression"
            )
            try updateIngestSource(
                database: database,
                sourceID: ingestSourceID,
                sourceKey: sourceKey,
                path: sourcePath,
                offset: nextOffset,
                lineNumber: lineNumber,
                fingerprint: event.providerEventFingerprint
            )
            return .rejected
        }

        let sessionResetBaseline = try previousPredatedGameplayStartNormalizedTotal(
            database: database,
            event: event
        )
        let baselineTotal = previousTotal ?? sessionResetBaseline ?? 0
        let delta = max(0, event.normalizedTotalTokens - baselineTotal)
        let gameplayDecision = try gameplayEligibilityDecision(
            database: database,
            event: event,
            sourceKind: sourceKind,
            previousSample: previousSample,
            sessionResetBaseline: sessionResetBaseline
        )

        try database.inTransaction {
            let ingestEventID = try insertProviderIngestEvent(
                database: database,
                event: event,
                sessionRowID: sessionRowID,
                ingestSourceID: ingestSourceID,
                rawPayload: rawPayload,
                acceptanceState: "accepted",
                rejectionReason: nil
            )

            let balanceDecision = try GameplayTokenBalancer.balance(
                database: database,
                event: event,
                rawEligibleDeltaTokens: gameplayDecision.rawEligibleDeltaTokens
            )
            let burstIntensityBand = Self.burstIntensityBand(
                forNormalizedDelta: balanceDecision.gameplayDeltaTokens
            )

            let usageSampleID = try insertUsageSample(
                database: database,
                event: event,
                providerIngestEventID: ingestEventID,
                providerSessionRowID: sessionRowID,
                normalizedDeltaTokens: delta,
                burstIntensityBand: burstIntensityBand,
                gameplayEligibility: gameplayDecision.eligibility,
                balanceDecision: balanceDecision
            )

            try DomainEventStore.persist(
                database: database,
                envelope: TokenmonDomainEventRegistry.usageSampleRecorded(
                    usageSampleID: usageSampleID,
                    event: event,
                    normalizedDeltaTokens: delta,
                    gameplayEligibility: gameplayDecision.eligibility,
                    gameplayDeltaTokens: balanceDecision.gameplayDeltaTokens,
                    gameplayBalanceBucket: balanceDecision.bucketKey,
                    gameplayBalanceWeight: balanceDecision.appliedWeight,
                    gameplayBalancePolicy: balanceDecision.policy
                )
            )

            if gameplayDecision.eligibility == .eligibleLive,
               balanceDecision.gameplayDeltaTokens > 0 {
                _ = try databaseManager.addNowCampFocus(
                    database: database,
                    usageSampleID: usageSampleID,
                    gameplayDeltaTokens: balanceDecision.gameplayDeltaTokens,
                    observedAt: event.observedAt,
                    correlationID: event.providerEventFingerprint
                )
                _ = try databaseManager.processRaidAttackForUsageSample(
                    database: database,
                    usageSampleID: usageSampleID,
                    observedAt: event.observedAt,
                    correlationID: event.providerEventFingerprint
                )
            }

            if balanceDecision.gameplayDeltaTokens > 0 {
                let explorationUpdate = try accumulateExplorationProgress(
                    database: database,
                    usageSampleID: usageSampleID,
                    normalizedDeltaTokens: balanceDecision.gameplayDeltaTokens,
                    observedAt: event.observedAt,
                    correlationID: event.providerEventFingerprint
                )

                if let progress = explorationUpdate.progress {
                    try DomainEventStore.persist(
                        database: database,
                        envelope: TokenmonDomainEventRegistry.explorationProgressUpdated(
                            usageSampleID: usageSampleID,
                            observedAt: event.observedAt,
                            correlationID: event.providerEventFingerprint,
                            burstIntensityBand: burstIntensityBand,
                            progress: progress
                        )
                    )
                }

                for threshold in explorationUpdate.thresholds {
                    try DomainEventStore.persist(
                        database: database,
                        envelope: TokenmonDomainEventRegistry.encounterThresholdCrossed(
                            usageSampleID: usageSampleID,
                            observedAt: event.observedAt,
                            correlationID: event.providerEventFingerprint,
                            burstIntensityBand: burstIntensityBand,
                            threshold: threshold
                        )
                    )

                    try resolveEncounterThreshold(
                        database: database,
                        event: event,
                        providerSessionRowID: sessionRowID,
                        usageSampleID: usageSampleID,
                        burstIntensityBand: burstIntensityBand,
                        threshold: threshold
                    )
                }
            }

            try databaseManager.evaluateAchievementBadges(database: database, occurredAt: event.observedAt)

            try updateIngestSource(
                database: database,
                sourceID: ingestSourceID,
                sourceKey: sourceKey,
                path: sourcePath,
                offset: nextOffset,
                lineNumber: lineNumber,
                fingerprint: event.providerEventFingerprint
            )
        }

        return .accepted
    }

    private func previousUsageSample(database: SQLiteDatabase, sessionRowID: Int64) throws -> PreviousUsageSampleState? {
        try database.fetchOne(
            """
            SELECT normalized_total_tokens, observed_at
            FROM usage_samples
            WHERE provider_session_row_id = ?
            ORDER BY usage_sample_id DESC
            LIMIT 1;
            """,
            bindings: [.integer(sessionRowID)]
        ) { statement in
            PreviousUsageSampleState(
                normalizedTotalTokens: SQLiteDatabase.columnInt64(statement, index: 0),
                observedAt: SQLiteDatabase.columnText(statement, index: 1)
            )
        }
    }

    private func previousPredatedGameplayStartNormalizedTotal(
        database: SQLiteDatabase,
        event: ProviderUsageSampleEvent
    ) throws -> Int64? {
        try database.fetchOne(
            """
            SELECT json_extract(payload_json, '$.normalized_total_tokens')
            FROM provider_ingest_events
            WHERE provider_code = ?
              AND acceptance_state = 'rejected'
              AND rejection_reason = 'predates_gameplay_start'
              AND json_extract(payload_json, '$.provider_session_id') = ?
            ORDER BY observed_at DESC, provider_ingest_event_id DESC
            LIMIT 1;
            """,
            bindings: [
                .text(event.provider.rawValue),
                .text(event.providerSessionID),
            ]
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        }
    }

    private func fingerprintExists(database: SQLiteDatabase, fingerprint: String) throws -> Bool {
        let match = try database.fetchOne(
            """
            SELECT provider_ingest_event_id
            FROM provider_ingest_events
            WHERE provider_event_fingerprint = ?
            LIMIT 1;
            """,
            bindings: [.text(fingerprint)]
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        }
        return match != nil
    }

    private func recentEncounterSpeciesIDs(database: SQLiteDatabase, limit: Int) throws -> [String] {
        guard limit > 0 else {
            return []
        }

        return try database.fetchAll(
            """
            SELECT species_id
            FROM encounters
            ORDER BY encounter_sequence DESC, encounter_id DESC
            LIMIT ?;
            """,
            bindings: [.integer(Int64(limit))]
        ) { statement in
            SQLiteDatabase.columnText(statement, index: 0)
        }
    }

    private func dexCapturedSpeciesCount(database: SQLiteDatabase) throws -> Int {
        let count = try database.fetchOne(
            "SELECT COUNT(*) FROM dex_captured;"
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0
        return Int(count)
    }

    private func dexCapturedCounts(database: SQLiteDatabase) throws -> [String: Int64] {
        let rows = try database.fetchAll(
            """
            SELECT species_id, captured_count
            FROM dex_captured;
            """
        ) { statement in
            (
                speciesID: SQLiteDatabase.columnText(statement, index: 0),
                capturedCount: SQLiteDatabase.columnInt64(statement, index: 1)
            )
        }

        return Dictionary(uniqueKeysWithValues: rows.map { ($0.speciesID, $0.capturedCount) })
    }

    private func insertProviderIngestEvent(
        database: SQLiteDatabase,
        event: ProviderUsageSampleEvent,
        sessionRowID: Int64?,
        ingestSourceID: Int64?,
        rawPayload: String,
        acceptanceState: String,
        rejectionReason: String?
    ) throws -> Int64 {
        let createdAt = ISO8601DateFormatter().string(from: Date())

        try database.execute(
            """
            INSERT INTO provider_ingest_events (
                provider_code,
                source_mode,
                provider_session_row_id,
                ingest_source_id,
                provider_event_fingerprint,
                raw_reference_kind,
                raw_reference_event_name,
                raw_reference_offset,
                observed_at,
                payload_json,
                acceptance_state,
                rejection_reason,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(event.provider.rawValue),
                .text(event.sourceMode),
                sessionRowID.map(SQLiteValue.integer) ?? .null,
                ingestSourceID.map(SQLiteValue.integer) ?? .null,
                .text(event.providerEventFingerprint),
                .text(event.rawReference.kind),
                event.rawReference.eventName.map(SQLiteValue.text) ?? .null,
                event.rawReference.offset.map(SQLiteValue.text) ?? .null,
                .text(event.observedAt),
                .text(rawPayload),
                .text(acceptanceState),
                rejectionReason.map(SQLiteValue.text) ?? .null,
                .text(createdAt),
            ]
        )

        return database.lastInsertRowID()
    }

    private func gameplayStartedAt(database: SQLiteDatabase) throws -> String {
        let decoder = JSONDecoder()
        if let rawJSON = try database.fetchOne(
            """
            SELECT setting_value_json
            FROM settings
            WHERE setting_key = 'gameplay_started_at'
            LIMIT 1;
            """,
            map: { statement in
                SQLiteDatabase.columnText(statement, index: 0)
            }
        ) {
            return try decoder.decode(String.self, from: Data(rawJSON.utf8))
        }

        return ISO8601DateFormatter().string(from: Date())
    }

    private func liveGameplayStartedAt(database: SQLiteDatabase) throws -> String? {
        let decoder = JSONDecoder()
        guard let rawJSON = try database.fetchOne(
            """
            SELECT setting_value_json
            FROM settings
            WHERE setting_key = 'live_gameplay_started_at'
            LIMIT 1;
            """,
            map: { statement in
                SQLiteDatabase.columnText(statement, index: 0)
            }
        ) else {
            return nil
        }

        return try decoder.decode(String.self, from: Data(rawJSON.utf8))
    }

    private func gameplayEligibilityDecision(
        database: SQLiteDatabase,
        event: ProviderUsageSampleEvent,
        sourceKind: String,
        previousSample: PreviousUsageSampleState?,
        sessionResetBaseline: Int64?
    ) throws -> GameplayEligibilityDecision {
        if event.sourceMode == "antigravity_rpc_metadata_recovery" {
            return GameplayEligibilityDecision(
                eligibility: .recoveryOnly,
                rawEligibleDeltaTokens: 0
            )
        }

        if sourceKind != "ndjson_file" {
            return GameplayEligibilityDecision(
                eligibility: .recoveryOnly,
                rawEligibleDeltaTokens: 0
            )
        }

        guard let liveGameplayStartedAt = try liveGameplayStartedAt(database: database) else {
            return GameplayEligibilityDecision(
                eligibility: .outsideLiveRuntime,
                rawEligibleDeltaTokens: 0
            )
        }

        if Self.predatesGameplayStart(eventObservedAt: event.observedAt, gameplayStartedAt: liveGameplayStartedAt) {
            return GameplayEligibilityDecision(
                eligibility: .outsideLiveRuntime,
                rawEligibleDeltaTokens: 0
            )
        }

        if let previousSample,
           Self.predatesGameplayStart(
               eventObservedAt: previousSample.observedAt,
               gameplayStartedAt: liveGameplayStartedAt
           ) == false {
            return GameplayEligibilityDecision(
                eligibility: .eligibleLive,
                rawEligibleDeltaTokens: max(0, event.normalizedTotalTokens - previousSample.normalizedTotalTokens)
            )
        }

        if let previousSample {
            return GameplayEligibilityDecision(
                eligibility: .eligibleLive,
                rawEligibleDeltaTokens: max(0, event.normalizedTotalTokens - previousSample.normalizedTotalTokens)
            )
        }

        if event.sessionOriginHint == .startedDuringLiveRuntime {
            return GameplayEligibilityDecision(
                eligibility: .eligibleLive,
                rawEligibleDeltaTokens: max(0, event.normalizedTotalTokens - (sessionResetBaseline ?? 0))
            )
        }

        if let sessionResetBaseline {
            return GameplayEligibilityDecision(
                eligibility: .eligibleLive,
                rawEligibleDeltaTokens: max(0, event.normalizedTotalTokens - sessionResetBaseline)
            )
        }

        return GameplayEligibilityDecision(
            eligibility: .runtimeBaseline,
            rawEligibleDeltaTokens: 0
        )
    }

    private static func predatesGameplayStart(eventObservedAt: String, gameplayStartedAt: String) -> Bool {
        let eventDate = parseTimestamp(eventObservedAt)
        let startDate = parseTimestamp(gameplayStartedAt)

        if let eventDate, let startDate {
            return eventDate < startDate
        }

        return eventObservedAt < gameplayStartedAt
    }

    private static func parseTimestamp(_ rawValue: String) -> Date? {
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]

        let formatters = [precise, standard]
        for formatter in formatters {
            if let date = formatter.date(from: rawValue) {
                return date
            }
        }
        return nil
    }

    private func insertUsageSample(
        database: SQLiteDatabase,
        event: ProviderUsageSampleEvent,
        providerIngestEventID: Int64,
        providerSessionRowID: Int64,
        normalizedDeltaTokens: Int64,
        burstIntensityBand: Int,
        gameplayEligibility: UsageSampleGameplayEligibility,
        balanceDecision: GameplayTokenBalanceDecision
    ) throws -> Int64 {
        try database.execute(
            """
            INSERT INTO usage_samples (
                provider_ingest_event_id,
                provider_code,
                provider_session_row_id,
                observed_at,
                total_input_tokens,
                total_output_tokens,
                total_cached_input_tokens,
                normalized_total_tokens,
                normalized_delta_tokens,
                current_input_tokens,
                current_output_tokens,
                gameplay_eligibility,
                gameplay_delta_tokens,
                gameplay_balance_bucket,
                gameplay_balance_weight,
                gameplay_balance_policy,
                burst_intensity_band,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .integer(providerIngestEventID),
                .text(event.provider.rawValue),
                .integer(providerSessionRowID),
                .text(event.observedAt),
                .integer(event.totalInputTokens),
                .integer(event.totalOutputTokens),
                .integer(event.totalCachedInputTokens),
                .integer(event.normalizedTotalTokens),
                .integer(normalizedDeltaTokens),
                event.currentInputTokens.map(SQLiteValue.integer) ?? .null,
                event.currentOutputTokens.map(SQLiteValue.integer) ?? .null,
                .text(gameplayEligibility.rawValue),
                .integer(balanceDecision.gameplayDeltaTokens),
                balanceDecision.bucketKey.map(SQLiteValue.text) ?? .null,
                balanceDecision.appliedWeight.map(SQLiteValue.double) ?? .null,
                balanceDecision.policy.map(SQLiteValue.text) ?? .null,
                .integer(Int64(burstIntensityBand)),
                .text(ISO8601DateFormatter().string(from: Date())),
            ]
        )

        return database.lastInsertRowID()
    }

    private func accumulateExplorationProgress(
        database: SQLiteDatabase,
        usageSampleID: Int64,
        normalizedDeltaTokens: Int64,
        observedAt: String,
        correlationID: String
    ) throws -> ExplorationAccumulationResult {
        let currentState = try currentExplorationState(database: database)
        let capturedSpeciesCount = try dexCapturedSpeciesCount(database: database)
        let result = try explorationAccumulator.accumulate(
            state: currentState,
            normalizedDeltaTokens: normalizedDeltaTokens,
            capturedSpeciesCount: capturedSpeciesCount,
            observedAt: observedAt,
            correlationID: correlationID,
            causationID: "usage-sample-\(usageSampleID)"
        )

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE exploration_state
            SET total_normalized_tokens = ?,
                tokens_since_last_encounter = ?,
                next_encounter_threshold_tokens = ?,
                total_encounters = ?,
                total_captures = ?,
                last_usage_sample_id = ?,
                updated_at = ?
            WHERE exploration_state_id = 1;
            """,
            bindings: [
                .integer(result.updatedState.totalNormalizedTokens),
                .integer(result.updatedState.tokensSinceLastEncounter),
                .integer(result.updatedState.nextEncounterThresholdTokens),
                .integer(result.updatedState.totalEncounters),
                .integer(result.updatedState.totalCaptures),
                .integer(usageSampleID),
                .text(now),
            ]
        )

        return result
    }

    private func currentExplorationState(database: SQLiteDatabase) throws -> ExplorationAccumulatorState {
        guard let state = try database.fetchOne(
            """
            SELECT total_normalized_tokens,
                   tokens_since_last_encounter,
                   next_encounter_threshold_tokens,
                   total_encounters,
                   total_captures
            FROM exploration_state
            WHERE exploration_state_id = 1
            LIMIT 1;
            """,
            map: { statement in
            ExplorationAccumulatorState(
                totalNormalizedTokens: SQLiteDatabase.columnInt64(statement, index: 0),
                tokensSinceLastEncounter: SQLiteDatabase.columnInt64(statement, index: 1),
                nextEncounterThresholdTokens: SQLiteDatabase.columnInt64(statement, index: 2),
                totalEncounters: SQLiteDatabase.columnInt64(statement, index: 3),
                totalCaptures: SQLiteDatabase.columnInt64(statement, index: 4)
            )
        }) else {
            throw SQLiteError.statementFailed(
                message: "missing exploration_state row",
                sql: "SELECT ... FROM exploration_state WHERE exploration_state_id = 1"
            )
        }

        return state
    }

    private func recentEncounterFields(
        database: SQLiteDatabase,
        limit: Int
    ) throws -> [FieldType] {
        guard limit > 0 else {
            return []
        }

        let sql = """
        SELECT field_code
        FROM encounters
        ORDER BY encounter_sequence DESC
        LIMIT ?;
        """

        let rows = try database.fetchAll(
            sql,
            bindings: [.integer(Int64(limit))]
        ) { statement in
            SQLiteDatabase.columnText(statement, index: 0)
        }

        return try rows.reversed().map { fieldCode in
            guard let field = FieldType(rawValue: fieldCode) else {
                throw SQLiteError.statementFailed(
                    message: "invalid encounter field code \(fieldCode)",
                    sql: sql
                )
            }
            return field
        }
    }

    private func upsertProviderSession(database: SQLiteDatabase, event: ProviderUsageSampleEvent) throws -> Int64 {
        let now = ISO8601DateFormatter().string(from: Date())

        try database.execute(
            """
            INSERT INTO provider_sessions (
                provider_code,
                provider_session_id,
                session_identity_kind,
                source_mode,
                model_slug,
                workspace_dir,
                transcript_path,
                started_at,
                ended_at,
                last_seen_at,
                session_state,
                created_at,
                updated_at
            ) VALUES (?, ?, 'authoritative', ?, ?, ?, ?, NULL, NULL, ?, 'active', ?, ?)
            ON CONFLICT(provider_code, provider_session_id) DO UPDATE SET
                source_mode = excluded.source_mode,
                model_slug = excluded.model_slug,
                workspace_dir = excluded.workspace_dir,
                transcript_path = excluded.transcript_path,
                last_seen_at = excluded.last_seen_at,
                session_state = 'active',
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(event.provider.rawValue),
                .text(event.providerSessionID),
                .text(event.sourceMode),
                event.modelSlug.map(SQLiteValue.text) ?? .null,
                event.workspaceDir.map(SQLiteValue.text) ?? .null,
                event.transcriptPath.map(SQLiteValue.text) ?? .null,
                .text(event.observedAt),
                .text(now),
                .text(now),
            ]
        )

        let sessionLookupSQL = """
        SELECT provider_session_row_id
        FROM provider_sessions
        WHERE provider_code = ? AND provider_session_id = ?
        LIMIT 1;
        """

        let rowID: Int64? = try database.fetchOne(
            sessionLookupSQL,
            bindings: [
                .text(event.provider.rawValue),
                .text(event.providerSessionID),
            ],
            map: { statement in
                SQLiteDatabase.columnInt64(statement, index: 0)
            }
        )

        guard let rowID else {
            throw UsageSampleIngestionError.sessionLookupFailed(event.providerSessionID)
        }

        return rowID
    }

    private func updateIngestSource(
        database: SQLiteDatabase,
        sourceID: Int64?,
        sourceKey: String,
        path: String?,
        offset: Int64,
        lineNumber: Int,
        fingerprint: String?
    ) throws {
        guard let sourceID else {
            return
        }
        _ = sourceKey
        try IngestSourceCheckpointStore.advance(
            database: database,
            sourceID: sourceID,
            path: path,
            offset: offset,
            lineNumber: lineNumber,
            fingerprint: fingerprint
        )
    }

    private static func burstIntensityBand(forNormalizedDelta delta: Int64) -> Int {
        switch delta {
        case 0...999:
            return 0
        case 1_000...1_999:
            return 1
        case 2_000...3_999:
            return 2
        case 4_000...6_999:
            return 3
        default:
            return 4
        }
    }

    private static func stableSeed(for value: String) -> UInt64 {
        value.utf8.reduce(0xcbf2_9ce4_8422_2325) { hash, byte in
            (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3
        }
    }
}

public enum UsageSampleIngestionError: Error, LocalizedError {
    case sessionLookupFailed(String)

    public var errorDescription: String? {
        switch self {
        case .sessionLookupFailed(let sessionID):
            return "failed to locate provider session row for session \(sessionID)"
        }
    }
}
