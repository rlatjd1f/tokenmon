import Foundation
import TokenmonGameEngine
import TokenmonDomain
import TokenmonProviders

private struct SQLiteMigration {
    let version: Int
    let statements: [String]
    let runsInTransaction: Bool

    init(version: Int, statements: [String], runsInTransaction: Bool = true) {
        self.version = version
        self.statements = statements
        self.runsInTransaction = runsInTransaction
    }
}

public struct TokenmonDatabaseSummary: Equatable, Sendable {
    public let providers: Int
    public let providerSessions: Int
    public let ingestSources: Int
    public let providerIngestEvents: Int
    public let usageSamples: Int
    public let accountUsageSamples: Int
    public let species: Int
    public let domainEvents: Int
    public let totalNormalizedTokens: Int64
    public let tokensSinceLastEncounter: Int64
    public let nextEncounterThresholdTokens: Int64
    public let tokensUntilNextEncounter: Int64
    public let totalEncounters: Int64
    public let totalCaptures: Int64
    public let gameplayStartedAt: String
    public let liveGameplayStartedAt: String?
}

public struct TokenmonDatabaseMaintenanceResult: Equatable, Sendable {
    public let fileSizeBytesBefore: Int64
    public let fileSizeBytesAfter: Int64
    public let freelistPagesBefore: Int64
    public let freelistPagesAfter: Int64
}

public enum TokenmonDeveloperToolsMutationError: Error, LocalizedError {
    case negativeValue(field: String, value: Int64)
    case invalidEncounterProgress(tokensSinceLastEncounter: Int64, nextEncounterThresholdTokens: Int64)
    case inconsistentExplorationTotals(totalNormalizedTokens: Int64, tokensSinceLastEncounter: Int64)
    case invalidCaptureTotals(totalEncounters: Int64, totalCaptures: Int64)
    case missingForgeSpecies(field: FieldType, rarity: RarityTier)

    public var errorDescription: String? {
        switch self {
        case let .negativeValue(field, value):
            return "\(field) must be non-negative: \(value)"
        case let .invalidEncounterProgress(tokensSinceLastEncounter, nextEncounterThresholdTokens):
            return "tokens since last encounter (\(tokensSinceLastEncounter)) must be lower than next encounter threshold (\(nextEncounterThresholdTokens))"
        case let .inconsistentExplorationTotals(totalNormalizedTokens, tokensSinceLastEncounter):
            return "total normalized tokens (\(totalNormalizedTokens)) must be at least tokens since last encounter (\(tokensSinceLastEncounter))"
        case let .invalidCaptureTotals(totalEncounters, totalCaptures):
            return "total captures (\(totalCaptures)) cannot exceed total encounters (\(totalEncounters))"
        case let .missingForgeSpecies(field, rarity):
            return "no active species available for forged encounter in field=\(field.rawValue) rarity=\(rarity.rawValue)"
        }
    }
}

public struct TokenmonDeveloperEncounterForgeRequest: Equatable, Sendable {
    public let provider: ProviderCode
    public let field: FieldType
    public let rarity: RarityTier
    public let speciesID: String
    public let outcome: EncounterOutcome
    public let occurredAt: String
    public let burstIntensityBand: Int

    public init(
        provider: ProviderCode,
        field: FieldType,
        rarity: RarityTier,
        speciesID: String,
        outcome: EncounterOutcome,
        occurredAt: String = ISO8601DateFormatter().string(from: Date()),
        burstIntensityBand: Int = 2
    ) {
        self.provider = provider
        self.field = field
        self.rarity = rarity
        self.speciesID = speciesID
        self.outcome = outcome
        self.occurredAt = occurredAt
        self.burstIntensityBand = burstIntensityBand
    }
}

public final class TokenmonDatabaseManager {
    private final class BootstrapState: @unchecked Sendable {
        let lock = NSLock()
        var bootstrappedPaths = Set<String>()
    }

    private static let bootstrapState = BootstrapState()
    private static let encounterThresholdPolicySettingKey = "encounter_threshold_policy_version"
    private static let encounterThresholdPolicyVersion = "encounter_threshold_v6_hyperfast_personal_pacing"
    private static let encounterThresholdRebaseProgressFraction = 0.50

    public let path: String

    public init(path: String) {
        self.path = path
    }

    public static func defaultPath() -> String {
        defaultSupportDirectoryURL()
            .appendingPathComponent("tokenmon.sqlite")
            .path
    }

    public static func supportDirectory(forDatabasePath path: String? = nil) -> String {
        if let path {
            return URL(fileURLWithPath: path).deletingLastPathComponent().path
        }
        return defaultSupportDirectoryURL().path
    }

    public static func inboxDirectory(forDatabasePath path: String? = nil) -> String {
        URL(fileURLWithPath: supportDirectory(forDatabasePath: path), isDirectory: true)
            .appendingPathComponent("Inbox", isDirectory: true)
            .path
    }

    public static func inboxPath(
        provider: ProviderCode,
        databasePath: String? = nil
    ) -> String {
        URL(fileURLWithPath: inboxDirectory(forDatabasePath: databasePath), isDirectory: true)
            .appendingPathComponent("\(provider.rawValue).ndjson")
            .path
    }

    public static func accountUsageDirectory(forDatabasePath path: String? = nil) -> String {
        URL(fileURLWithPath: supportDirectory(forDatabasePath: path), isDirectory: true)
            .appendingPathComponent("AccountUsage", isDirectory: true)
            .path
    }

    public static func accountUsagePath(
        provider: ProviderCode,
        databasePath: String? = nil
    ) -> String {
        URL(fileURLWithPath: accountUsageDirectory(forDatabasePath: databasePath), isDirectory: true)
            .appendingPathComponent("\(provider.rawValue).ndjson")
            .path
    }

    public func open() throws -> SQLiteDatabase {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let database = try SQLiteDatabase(path: path)
        try ensureBootstrapped(database)
        return database
    }

    public func bootstrap() throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let database = try SQLiteDatabase(path: path)
        try Self.bootstrapState.lock.withLock {
            try bootstrap(database)
            Self.bootstrapState.bootstrappedPaths.insert(path)
        }
    }

    public func performMaintenance() throws -> TokenmonDatabaseMaintenanceResult {
        let beforeFileSize = Self.fileSize(at: path)
        let database = try open()
        let freelistPagesBefore = try pragmaInt64("PRAGMA freelist_count;", database: database)

        try database.execute("PRAGMA optimize;")
        _ = try database.fetchAll("PRAGMA wal_checkpoint(TRUNCATE);") { _ in () }
        try database.execute("VACUUM;")

        let freelistPagesAfter = try pragmaInt64("PRAGMA freelist_count;", database: database)
        let afterFileSize = Self.fileSize(at: path)

        return TokenmonDatabaseMaintenanceResult(
            fileSizeBytesBefore: beforeFileSize,
            fileSizeBytesAfter: afterFileSize,
            freelistPagesBefore: freelistPagesBefore,
            freelistPagesAfter: freelistPagesAfter
        )
    }

    public func summary(database providedDatabase: SQLiteDatabase? = nil) throws -> TokenmonDatabaseSummary {
        let database = try providedDatabase ?? open()
        let explorationState = try currentExplorationState(database: database)
        return TokenmonDatabaseSummary(
            providers: try countRows(in: "providers", database: database),
            providerSessions: try countRows(in: "provider_sessions", database: database),
            ingestSources: try countRows(in: "ingest_sources", database: database),
            providerIngestEvents: try countRows(in: "provider_ingest_events", database: database),
            usageSamples: try countRows(in: "usage_samples", database: database),
            accountUsageSamples: try countRows(in: "account_usage_samples", database: database),
            species: try countRows(in: "species", database: database),
            domainEvents: try countRows(in: "domain_events", database: database),
            totalNormalizedTokens: explorationState.totalNormalizedTokens,
            tokensSinceLastEncounter: explorationState.tokensSinceLastEncounter,
            nextEncounterThresholdTokens: explorationState.nextEncounterThresholdTokens,
            tokensUntilNextEncounter: max(
                0,
                explorationState.nextEncounterThresholdTokens - explorationState.tokensSinceLastEncounter
            ),
            totalEncounters: explorationState.totalEncounters,
            totalCaptures: explorationState.totalCaptures,
            gameplayStartedAt: try gameplayStartedAt(database: database),
            liveGameplayStartedAt: try liveGameplayStartedAt(database: database)
        )
    }

    public func liveGameplayStartedAt() throws -> String? {
        try liveGameplayStartedAt(database: open())
    }

    public func markLiveGameplayStarted(at timestamp: String = ISO8601DateFormatter().string(from: Date())) throws {
        try upsertRawSetting(
            key: "live_gameplay_started_at",
            encodedValue: "\"\(timestamp)\"",
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            database: open()
        )
    }

    public func clearLiveGameplayStartedAt() throws {
        let database = try open()
        try database.execute(
            """
            DELETE FROM settings
            WHERE setting_key = 'live_gameplay_started_at';
            """
        )
    }

    public func upsertProviderHealth(
        provider: ProviderCode,
        sourceMode: String,
        healthState: String,
        message: String,
        lastSuccessAt: String?,
        lastErrorAt: String?,
        lastErrorCode: String?,
        lastErrorSummary: String?,
        updatedAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws {
        let database = try open()
        try database.execute(
            """
            INSERT INTO provider_health (
                provider_code,
                source_mode,
                health_state,
                message,
                last_success_at,
                last_error_at,
                last_error_code,
                last_error_summary,
                updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(provider_code, source_mode) DO UPDATE SET
                health_state = excluded.health_state,
                message = excluded.message,
                last_success_at = COALESCE(excluded.last_success_at, provider_health.last_success_at),
                last_error_at = excluded.last_error_at,
                last_error_code = excluded.last_error_code,
                last_error_summary = excluded.last_error_summary,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(provider.rawValue),
                .text(sourceMode),
                .text(healthState),
                .text(message),
                lastSuccessAt.map(SQLiteValue.text) ?? .null,
                lastErrorAt.map(SQLiteValue.text) ?? .null,
                lastErrorCode.map(SQLiteValue.text) ?? .null,
                lastErrorSummary.map(SQLiteValue.text) ?? .null,
                .text(updatedAt),
            ]
        )
    }

    public func resetProgress(startedAt: String = ISO8601DateFormatter().string(from: Date())) throws {
        let database = try open()
        let now = ISO8601DateFormatter().string(from: Date())

        try database.inTransaction {
            try database.execute(
                """
                UPDATE exploration_state
                SET last_usage_sample_id = NULL,
                    updated_at = ?
                WHERE exploration_state_id = 1;
                """,
                bindings: [.text(now)]
            )
            try database.execute("DELETE FROM backfill_runs;")
            try database.execute("DELETE FROM party_members;")
            try database.execute("DELETE FROM species_training;")
            try database.execute("DELETE FROM dex_captured;")
            try database.execute("DELETE FROM dex_seen;")
            try database.execute("DELETE FROM encounters;")
            try database.execute("DELETE FROM domain_events;")
            try database.execute("DELETE FROM usage_samples;")
            try database.execute("DELETE FROM account_usage_samples;")
            try database.execute("DELETE FROM provider_ingest_events;")
            try database.execute("DELETE FROM ingest_sources;")
            try database.execute("DELETE FROM provider_health;")
            try database.execute("DELETE FROM provider_sessions;")
            try database.execute(
                """
                UPDATE now_camp_state
                SET lead_species_id = NULL,
                    focus_energy = 0,
                    focus_remainder_tokens = 0,
                    focus_earned_local_date = date('now', 'localtime'),
                    focus_earned_today = 0,
                    care_ready = 0,
                    care_elapsed_seconds = 0,
                    care_focus_earned_local_date = date('now', 'localtime'),
                    care_focus_earned_today = 0,
                    updated_at = ?
                WHERE singleton_id = 1;
                """,
                bindings: [.text(now)]
            )
            try database.execute(
                """
                UPDATE exploration_state
                SET total_normalized_tokens = 0,
                    tokens_since_last_encounter = 0,
                    next_encounter_threshold_tokens = ?,
                    total_encounters = 0,
                    total_captures = 0,
                    last_usage_sample_id = NULL,
                    updated_at = ?
                WHERE exploration_state_id = 1;
                """,
                bindings: [
                    .integer(ExplorationAccumulatorConfig().tokensRequiredForEncounter(1)),
                    .text(now),
                ]
            )
            try upsertRawSetting(
                key: "gameplay_started_at",
                encodedValue: "\"\(startedAt)\"",
                updatedAt: now,
                database: database
            )
            try setInternalLowThresholdOverrideEnabled(
                false,
                updatedAt: now,
                database: database
            )
            try upsertRawSetting(
                key: Self.encounterThresholdPolicySettingKey,
                encodedValue: "\"\(Self.encounterThresholdPolicyVersion)\"",
                updatedAt: now,
                database: database
            )
        }
    }

    public func resetDexProgress() throws {
        let database = try open()
        let now = ISO8601DateFormatter().string(from: Date())

        try database.inTransaction {
            try deleteDomainEvents(
                matching: [
                    .seenDexUpdated,
                    .capturedDexUpdated,
                    .speciesAffinityUpdated,
                    .nowCampLeadSelected,
                    .nowCampCareReadied,
                    .leadCareClaimed,
                    .leadTrainingAttempted,
                    .leadTrainingResolved,
                    .leaderTraitBonusApplied,
                ],
                database: database
            )
            try database.execute("DELETE FROM party_members;")
            try database.execute("DELETE FROM species_training;")
            try database.execute("DELETE FROM dex_captured;")
            try database.execute("DELETE FROM dex_seen;")
            try database.execute(
                """
                UPDATE now_camp_state
                SET lead_species_id = NULL,
                    updated_at = ?
                WHERE singleton_id = 1;
                """,
                bindings: [.text(now)]
            )
            try touchExplorationState(updatedAt: now, database: database)
            try ensurePendingEncounterThresholdPolicy(database: database, force: true)
        }
    }

    public func resetEncounterHistory() throws {
        let database = try open()
        let now = ISO8601DateFormatter().string(from: Date())
        let firstThreshold = ExplorationAccumulatorConfig().tokensRequiredForEncounter(1)

        try database.inTransaction {
            try deleteDomainEvents(
                matching: [
                    .encounterThresholdCrossed,
                    .fieldSelected,
                    .raritySelected,
                    .speciesSelected,
                    .encounterSpawned,
                    .captureResolved,
                    .seenDexUpdated,
                    .capturedDexUpdated,
                    .speciesAffinityUpdated,
                    .nowCampLeadSelected,
                    .nowCampCareReadied,
                    .leadCareClaimed,
                    .leadTrainingAttempted,
                    .leadTrainingResolved,
                    .leaderTraitBonusApplied,
                ],
                database: database
            )
            try database.execute("DELETE FROM party_members;")
            try database.execute("DELETE FROM species_training;")
            try database.execute("DELETE FROM dex_captured;")
            try database.execute("DELETE FROM dex_seen;")
            try database.execute("DELETE FROM encounters;")
            try database.execute(
                """
                UPDATE now_camp_state
                SET lead_species_id = NULL,
                    updated_at = ?
                WHERE singleton_id = 1;
                """,
                bindings: [.text(now)]
            )
            try database.execute(
                """
                UPDATE exploration_state
                SET tokens_since_last_encounter = 0,
                    next_encounter_threshold_tokens = ?,
                    total_encounters = 0,
                    total_captures = 0,
                    updated_at = ?
                WHERE exploration_state_id = 1;
                """,
                bindings: [
                    .integer(firstThreshold),
                    .text(now),
                ]
            )
            try setInternalLowThresholdOverrideEnabled(
                false,
                updatedAt: now,
                database: database
            )
            try upsertRawSetting(
                key: Self.encounterThresholdPolicySettingKey,
                encodedValue: "\"\(Self.encounterThresholdPolicyVersion)\"",
                updatedAt: now,
                database: database
            )
        }
    }

    public func makeNextEncounterReady() throws {
        let database = try open()
        let state = try currentExplorationState(database: database)
        let now = ISO8601DateFormatter().string(from: Date())

        try database.execute(
            """
            UPDATE exploration_state
            SET tokens_since_last_encounter = ?,
                updated_at = ?
            WHERE exploration_state_id = 1;
            """,
            bindings: [
                .integer(max(0, state.nextEncounterThresholdTokens - 1)),
                .text(now),
            ]
        )
    }

    func refreshPendingEncounterThresholdPolicy() throws {
        let database = try open()
        try ensurePendingEncounterThresholdPolicy(database: database, force: false)
    }

    public func applyExplorationOverride(
        totalNormalizedTokens: Int64,
        tokensSinceLastEncounter: Int64,
        nextEncounterThresholdTokens: Int64
    ) throws {
        try validateExplorationOverride(
            totalNormalizedTokens: totalNormalizedTokens,
            tokensSinceLastEncounter: tokensSinceLastEncounter,
            nextEncounterThresholdTokens: nextEncounterThresholdTokens
        )

        let database = try open()
        let now = ISO8601DateFormatter().string(from: Date())

        try database.inTransaction {
            try database.execute(
                """
                UPDATE exploration_state
                SET total_normalized_tokens = ?,
                    tokens_since_last_encounter = ?,
                    next_encounter_threshold_tokens = ?,
                    updated_at = ?
                WHERE exploration_state_id = 1;
                """,
                bindings: [
                    .integer(totalNormalizedTokens),
                    .integer(tokensSinceLastEncounter),
                    .integer(nextEncounterThresholdTokens),
                    .text(now),
                ]
            )
            try setInternalLowThresholdOverrideEnabled(
                nextEncounterThresholdTokens < ExplorationAccumulatorConfig().minimumEncounterThresholdTokens,
                updatedAt: now,
                database: database
            )
        }
    }

    public func applyTotalsOverride(
        totalEncounters: Int64,
        totalCaptures: Int64
    ) throws {
        try validateTotalsOverride(
            totalEncounters: totalEncounters,
            totalCaptures: totalCaptures
        )

        let database = try open()
        let now = ISO8601DateFormatter().string(from: Date())

        try database.execute(
            """
            UPDATE exploration_state
            SET total_encounters = ?,
                total_captures = ?,
                updated_at = ?
            WHERE exploration_state_id = 1;
            """,
            bindings: [
                .integer(totalEncounters),
                .integer(totalCaptures),
                .text(now),
            ]
        )
    }

    public func forgeEncounter(
        _ request: TokenmonDeveloperEncounterForgeRequest
    ) throws -> PersistedEncounterRecord {
        let database = try open()
        let currentState = try currentExplorationState(database: database)

        let providerSessionID = "internal-devtools-\(request.provider.rawValue)"
        let eventFingerprint = "internal-devtools:\(UUID().uuidString.lowercased())"
        let rawReference = ProviderRawReference(
            kind: "developer_tool",
            offset: nil,
            eventName: "encounter_forge"
        )
        let usageEvent = ProviderUsageSampleEvent(
            eventType: "provider_usage_sample",
            provider: request.provider,
            sourceMode: "internal_developer_tools",
            providerSessionID: providerSessionID,
            observedAt: request.occurredAt,
            workspaceDir: nil,
            modelSlug: nil,
            transcriptPath: nil,
            totalInputTokens: currentState.totalNormalizedTokens,
            totalOutputTokens: 0,
            totalCachedInputTokens: 0,
            normalizedTotalTokens: currentState.totalNormalizedTokens,
            providerEventFingerprint: eventFingerprint,
            rawReference: rawReference,
            currentInputTokens: 0,
            currentOutputTokens: 0
        )

        let captureResolver = CaptureResolver()
        let captureProbability = try captureResolver.captureProbability(for: request.rarity)
        let captureRoll = forgedCaptureRoll(
            outcome: request.outcome,
            captureProbability: captureProbability
        )
        let now = ISO8601DateFormatter().string(from: Date())

        var persistedEncounter: PersistedEncounterRecord?

        try database.inTransaction {
            let sessionRowID = try upsertDeveloperToolProviderSession(
                database: database,
                provider: request.provider,
                providerSessionID: providerSessionID,
                observedAt: request.occurredAt,
                updatedAt: now
            )
            let ingestSourceID = try upsertDeveloperToolIngestSource(
                database: database,
                provider: request.provider,
                updatedAt: now
            )
            let providerIngestEventID = try insertDeveloperToolProviderIngestEvent(
                database: database,
                event: usageEvent,
                providerSessionRowID: sessionRowID,
                ingestSourceID: ingestSourceID,
                updatedAt: now
            )
            let usageSampleID = try insertDeveloperToolUsageSample(
                database: database,
                event: usageEvent,
                providerIngestEventID: providerIngestEventID,
                providerSessionRowID: sessionRowID,
                burstIntensityBand: request.burstIntensityBand,
                updatedAt: now
            )

            try DomainEventStore.persist(
                database: database,
                envelope: TokenmonDomainEventRegistry.usageSampleRecorded(
                    usageSampleID: usageSampleID,
                    event: usageEvent,
                    normalizedDeltaTokens: 0,
                    gameplayEligibility: .outsideLiveRuntime,
                    gameplayDeltaTokens: 0
                )
            )

            try database.execute(
                """
                UPDATE exploration_state
                SET total_encounters = total_encounters + 1,
                    last_usage_sample_id = ?,
                    updated_at = ?
                WHERE exploration_state_id = 1;
                """,
                bindings: [
                    .integer(usageSampleID),
                    .text(now),
                ]
            )

            persistedEncounter = try EncounterHistoryStore.persistResolvedEncounter(
                database: database,
                request: EncounterResolutionWriteRequest(
                    providerCode: request.provider,
                    providerSessionID: providerSessionID,
                    providerSessionRowID: sessionRowID,
                    usageSampleID: usageSampleID,
                    thresholdEventIndex: 1,
                    occurredAt: request.occurredAt,
                    field: request.field,
                    rarity: request.rarity,
                    speciesID: request.speciesID,
                    burstIntensityBand: request.burstIntensityBand,
                    captureProbability: captureProbability,
                    captureRoll: captureRoll,
                    outcome: request.outcome,
                    encounterSeedContextID: "internal-devtools-\(usageSampleID)"
                )
            )
        }

        guard let persistedEncounter else {
            throw SQLiteError.statementFailed(
                message: "failed to persist internal forged encounter",
                sql: "internal developer tools forge transaction"
            )
        }

        return persistedEncounter
    }

    public func explorationState() throws -> ExplorationAccumulatorState {
        let database = try open()
        return try currentExplorationState(database: database)
    }

    public func recentDomainEvents(limit: Int = 20, database providedDatabase: SQLiteDatabase? = nil) throws -> [PersistedDomainEventRecord] {
        let database = try providedDatabase ?? open()
        return try database.fetchAll(
            """
            SELECT event_id,
                   event_type,
                   occurred_at,
                   producer,
                   correlation_id,
                   causation_id,
                   aggregate_type,
                   aggregate_id,
                   payload_json,
                   created_at
            FROM domain_events
            ORDER BY domain_event_row_id DESC
            LIMIT ?;
            """,
            bindings: [.integer(Int64(max(0, limit)))]
        ) { statement in
            PersistedDomainEventRecord(
                eventID: SQLiteDatabase.columnText(statement, index: 0),
                eventType: SQLiteDatabase.columnText(statement, index: 1),
                occurredAt: SQLiteDatabase.columnText(statement, index: 2),
                producer: SQLiteDatabase.columnText(statement, index: 3),
                correlationID: SQLiteDatabase.columnOptionalText(statement, index: 4),
                causationID: SQLiteDatabase.columnOptionalText(statement, index: 5),
                aggregateType: SQLiteDatabase.columnOptionalText(statement, index: 6),
                aggregateID: SQLiteDatabase.columnOptionalText(statement, index: 7),
                payloadJSON: SQLiteDatabase.columnText(statement, index: 8),
                createdAt: SQLiteDatabase.columnText(statement, index: 9)
            )
        }
    }

    private func bootstrap(_ database: SQLiteDatabase) throws {
        try database.execute("PRAGMA journal_mode = WAL;")
        try applyMigrations(database)
        try seedProviders(database)
        try ensureSpeciesCatalog(database)
        try ensureRaidCatalog(database)
        try ensureExplorationState(database)
        try ensureNowCampState(database: database)
        try ensureSpeciesTrainingRowsForCaptured(database: database)
        try repairNowCampLead(database: database)
        try ensureEncounterTotalsConsistent(database: database)
        try ensurePendingEncounterThresholdPolicy(database: database, force: false)
        try ensureGameplayStartedAt(database)
        try evaluateAchievementBadges(database: database)
    }

    private func ensureEncounterTotalsConsistent(database: SQLiteDatabase) throws {
        let actualMaxSequence = try database.fetchOne(
            "SELECT COALESCE(MAX(encounter_sequence), 0) FROM encounters;"
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0

        let actualCaptureCount = try database.fetchOne(
            "SELECT COUNT(*) FROM encounters WHERE outcome = 'captured';"
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0

        let state = try currentExplorationState(database: database)
        let encountersDesynced = state.totalEncounters < actualMaxSequence
        let capturesDesynced = state.totalCaptures < actualCaptureCount

        guard encountersDesynced || capturesDesynced else {
            return
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE exploration_state
            SET total_encounters = ?,
                total_captures = ?,
                updated_at = ?
            WHERE exploration_state_id = 1;
            """,
            bindings: [
                .integer(max(state.totalEncounters, actualMaxSequence)),
                .integer(max(state.totalCaptures, actualCaptureCount)),
                .text(now),
            ]
        )
    }

    private func touchExplorationState(updatedAt: String, database: SQLiteDatabase) throws {
        try database.execute(
            """
            UPDATE exploration_state
            SET updated_at = ?
            WHERE exploration_state_id = 1;
            """,
            bindings: [.text(updatedAt)]
        )
    }

    private func validateExplorationOverride(
        totalNormalizedTokens: Int64,
        tokensSinceLastEncounter: Int64,
        nextEncounterThresholdTokens: Int64
    ) throws {
        if totalNormalizedTokens < 0 {
            throw TokenmonDeveloperToolsMutationError.negativeValue(
                field: "totalNormalizedTokens",
                value: totalNormalizedTokens
            )
        }
        if tokensSinceLastEncounter < 0 {
            throw TokenmonDeveloperToolsMutationError.negativeValue(
                field: "tokensSinceLastEncounter",
                value: tokensSinceLastEncounter
            )
        }
        if nextEncounterThresholdTokens <= 0 {
            throw TokenmonDeveloperToolsMutationError.negativeValue(
                field: "nextEncounterThresholdTokens",
                value: nextEncounterThresholdTokens
            )
        }
        if totalNormalizedTokens < tokensSinceLastEncounter {
            throw TokenmonDeveloperToolsMutationError.inconsistentExplorationTotals(
                totalNormalizedTokens: totalNormalizedTokens,
                tokensSinceLastEncounter: tokensSinceLastEncounter
            )
        }
        if tokensSinceLastEncounter >= nextEncounterThresholdTokens {
            throw TokenmonDeveloperToolsMutationError.invalidEncounterProgress(
                tokensSinceLastEncounter: tokensSinceLastEncounter,
                nextEncounterThresholdTokens: nextEncounterThresholdTokens
            )
        }
    }

    private func validateTotalsOverride(
        totalEncounters: Int64,
        totalCaptures: Int64
    ) throws {
        if totalEncounters < 0 {
            throw TokenmonDeveloperToolsMutationError.negativeValue(
                field: "totalEncounters",
                value: totalEncounters
            )
        }
        if totalCaptures < 0 {
            throw TokenmonDeveloperToolsMutationError.negativeValue(
                field: "totalCaptures",
                value: totalCaptures
            )
        }
        if totalCaptures > totalEncounters {
            throw TokenmonDeveloperToolsMutationError.invalidCaptureTotals(
                totalEncounters: totalEncounters,
                totalCaptures: totalCaptures
            )
        }
    }

    private func deleteDomainEvents(
        matching eventTypes: [TokenmonDomainEventType],
        database: SQLiteDatabase
    ) throws {
        guard eventTypes.isEmpty == false else {
            return
        }

        let quotedEventTypes = eventTypes
            .map(\.rawValue)
            .map { "'\($0)'" }
            .joined(separator: ", ")
        try database.execute(
            "DELETE FROM domain_events WHERE event_type IN (\(quotedEventTypes));"
        )
    }

    private func internalLowThresholdOverrideEnabled(database: SQLiteDatabase) throws -> Bool {
        let decoder = JSONDecoder()
        guard let rawJSON = try database.fetchOne(
            """
            SELECT setting_value_json
            FROM settings
            WHERE setting_key = 'internal_low_threshold_override_enabled'
            LIMIT 1;
            """,
            map: { statement in
                SQLiteDatabase.columnText(statement, index: 0)
            }
        ) else {
            return false
        }

        return (try? decoder.decode(Bool.self, from: Data(rawJSON.utf8))) ?? false
    }

    private func setInternalLowThresholdOverrideEnabled(
        _ enabled: Bool,
        updatedAt: String,
        database: SQLiteDatabase
    ) throws {
        try upsertRawSetting(
            key: "internal_low_threshold_override_enabled",
            encodedValue: enabled ? "true" : "false",
            updatedAt: updatedAt,
            database: database
        )
    }

    private func upsertDeveloperToolProviderSession(
        database: SQLiteDatabase,
        provider: ProviderCode,
        providerSessionID: String,
        observedAt: String,
        updatedAt: String
    ) throws -> Int64 {
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
            ) VALUES (?, ?, 'internal_tool', 'internal_developer_tools', NULL, NULL, NULL, ?, NULL, ?, 'active', ?, ?)
            ON CONFLICT(provider_code, provider_session_id) DO UPDATE SET
                source_mode = excluded.source_mode,
                last_seen_at = excluded.last_seen_at,
                session_state = 'active',
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(provider.rawValue),
                .text(providerSessionID),
                .text(observedAt),
                .text(observedAt),
                .text(updatedAt),
                .text(updatedAt),
            ]
        )

        guard let rowID = try database.fetchOne(
            """
            SELECT provider_session_row_id
            FROM provider_sessions
            WHERE provider_code = ? AND provider_session_id = ?
            LIMIT 1;
            """,
            bindings: [
                .text(provider.rawValue),
                .text(providerSessionID),
            ],
            map: { statement in
                SQLiteDatabase.columnInt64(statement, index: 0)
            }
        ) else {
            throw SQLiteError.statementFailed(
                message: "failed to look up internal developer session",
                sql: "SELECT provider_session_row_id FROM provider_sessions ..."
            )
        }

        return rowID
    }

    private func upsertDeveloperToolIngestSource(
        database: SQLiteDatabase,
        provider: ProviderCode,
        updatedAt: String
    ) throws -> Int64 {
        let sourceKey = "internal-developer-tools:\(provider.rawValue)"
        try database.execute(
            """
            INSERT INTO ingest_sources (
                source_key,
                source_kind,
                source_path,
                last_offset,
                last_line_number,
                last_event_fingerprint,
                last_seen_at,
                updated_at
            ) VALUES (?, 'internal_developer_tools', NULL, 0, 0, NULL, ?, ?)
            ON CONFLICT(source_key) DO UPDATE SET
                last_seen_at = excluded.last_seen_at,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(sourceKey),
                .text(updatedAt),
                .text(updatedAt),
            ]
        )

        guard let rowID = try database.fetchOne(
            """
            SELECT ingest_source_id
            FROM ingest_sources
            WHERE source_key = ?
            LIMIT 1;
            """,
            bindings: [.text(sourceKey)],
            map: { statement in
                SQLiteDatabase.columnInt64(statement, index: 0)
            }
        ) else {
            throw SQLiteError.statementFailed(
                message: "failed to look up internal developer ingest source",
                sql: "SELECT ingest_source_id FROM ingest_sources ..."
            )
        }

        return rowID
    }

    private func insertDeveloperToolProviderIngestEvent(
        database: SQLiteDatabase,
        event: ProviderUsageSampleEvent,
        providerSessionRowID: Int64,
        ingestSourceID: Int64,
        updatedAt: String
    ) throws -> Int64 {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let rawPayload = String(decoding: try encoder.encode(event), as: UTF8.self)

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
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'accepted', NULL, ?);
            """,
            bindings: [
                .text(event.provider.rawValue),
                .text(event.sourceMode),
                .integer(providerSessionRowID),
                .integer(ingestSourceID),
                .text(event.providerEventFingerprint),
                .text(event.rawReference.kind),
                event.rawReference.eventName.map(SQLiteValue.text) ?? .null,
                event.rawReference.offset.map(SQLiteValue.text) ?? .null,
                .text(event.observedAt),
                .text(rawPayload),
                .text(updatedAt),
            ]
        )

        return database.lastInsertRowID()
    }

    private func insertDeveloperToolUsageSample(
        database: SQLiteDatabase,
        event: ProviderUsageSampleEvent,
        providerIngestEventID: Int64,
        providerSessionRowID: Int64,
        burstIntensityBand: Int,
        updatedAt _: String
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
                burst_intensity_band,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, 0, ?, ?);
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
                event.currentInputTokens.map(SQLiteValue.integer) ?? .null,
                event.currentOutputTokens.map(SQLiteValue.integer) ?? .null,
                .text(UsageSampleGameplayEligibility.outsideLiveRuntime.rawValue),
                .integer(Int64(burstIntensityBand)),
                .text(event.observedAt),
            ]
        )

        return database.lastInsertRowID()
    }

    private func forgedCaptureRoll(
        outcome: EncounterOutcome,
        captureProbability: Double
    ) -> Double {
        switch outcome {
        case .captured:
            return min(max(captureProbability * 0.5, 0.01), max(captureProbability - 0.01, 0))
        case .escaped:
            return min(max(captureProbability + 0.05, captureProbability + 0.001), 0.99)
        }
    }

    private static func defaultSupportDirectoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Tokenmon", isDirectory: true)
    }

    private func pragmaInt64(_ sql: String, database: SQLiteDatabase) throws -> Int64 {
        try database.fetchOne(sql) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0
    }

    private static func fileSize(at path: String) -> Int64 {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
    }

    private func ensureBootstrapped(_ database: SQLiteDatabase) throws {
        try Self.bootstrapState.lock.withLock {
            let alreadyBootstrapped = Self.bootstrapState.bootstrappedPaths.contains(path)
            let currentVersion = try migrationVersion(database)
            let latestVersion = latestMigrationVersion

            guard alreadyBootstrapped == false || currentVersion < latestVersion else {
                return
            }

            try bootstrap(database)
            Self.bootstrapState.bootstrappedPaths.insert(path)
        }
    }

    private var latestMigrationVersion: Int {
        migrations.map(\.version).max() ?? 0
    }

    private func migrationVersion(_ database: SQLiteDatabase) throws -> Int {
        Int(try database.fetchOne("PRAGMA user_version;") { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0)
    }

    private func applyMigrations(_ database: SQLiteDatabase) throws {
        let currentVersion = try migrationVersion(database)

        for migration in migrations where migration.version > currentVersion {
            let applyStatements = {
                for statement in migration.statements {
                    do {
                        try database.execute(statement)
                    } catch let error as SQLiteError
                        where Self.canSkipMigrationStatementFailure(error, statement: statement)
                    {
                        continue
                    }
                }
                try database.execute("PRAGMA user_version = \(migration.version);")
            }

            if migration.runsInTransaction {
                try database.inTransaction {
                    try applyStatements()
                }
            } else {
                try applyStatements()
            }
        }
    }

    private static func canSkipMigrationStatementFailure(_ error: SQLiteError, statement: String) -> Bool {
        guard case .statementFailed(let message, _) = error else {
            return false
        }

        let normalizedStatement = statement
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        if normalizedStatement.hasPrefix("INSERT INTO NOW_CAMP_STATE")
            && message.localizedCaseInsensitiveContains("care_focus_earned_local_date")
        {
            return true
        }
        if normalizedStatement.hasPrefix("INSERT OR IGNORE INTO SPECIES_TRAINING")
            && message.localizedCaseInsensitiveContains("care_charge")
        {
            return true
        }

        return normalizedStatement.hasPrefix("ALTER TABLE")
            && normalizedStatement.contains(" ADD COLUMN ")
            && message.localizedCaseInsensitiveContains("duplicate column name")
    }

    private func seedProviders(_ database: SQLiteDatabase) throws {
        for provider in ProviderCode.allCases {
            try ensureProviderRegistered(provider, database: database)
        }
    }

    func ensureProviderRegistered(_ provider: ProviderCode, database: SQLiteDatabase) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT INTO providers (
                provider_code,
                display_name,
                default_support_level,
                is_enabled,
                created_at,
                updated_at
            ) VALUES (?, ?, ?, 1, ?, ?)
            ON CONFLICT(provider_code) DO UPDATE SET
                display_name = excluded.display_name,
                default_support_level = excluded.default_support_level,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(provider.rawValue),
                .text(provider.displayName),
                .text(provider.defaultSupportLevel),
                .text(now),
                .text(now),
            ]
        )
    }

    private func ensureExplorationState(_ database: SQLiteDatabase) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let initialThresholdTokens = ExplorationAccumulatorConfig().tokensRequiredForEncounter(1)
        try database.execute(
            """
            INSERT OR IGNORE INTO exploration_state (
                exploration_state_id,
                total_normalized_tokens,
                tokens_since_last_encounter,
                next_encounter_threshold_tokens,
                total_encounters,
                total_captures,
                last_usage_sample_id,
                updated_at
            ) VALUES (1, 0, 0, ?, 0, 0, NULL, ?);
            """,
            bindings: [
                .integer(initialThresholdTokens),
                .text(now),
            ]
        )

        if let row = try database.fetchOne(
            """
            SELECT total_encounters,
                   next_encounter_threshold_tokens
            FROM exploration_state
            WHERE exploration_state_id = 1
            LIMIT 1;
            """,
            map: { statement in
            (
                totalEncounters: SQLiteDatabase.columnInt64(statement, index: 0),
                nextEncounterThresholdTokens: SQLiteDatabase.columnInt64(statement, index: 1)
            )
        }) {
            let lowThresholdOverrideEnabled = try internalLowThresholdOverrideEnabled(database: database)
            let shouldHealThreshold =
                row.nextEncounterThresholdTokens <= 0
                || (
                    row.nextEncounterThresholdTokens < initialThresholdTokens
                    && lowThresholdOverrideEnabled == false
                )

            guard shouldHealThreshold else {
                return
            }

            try database.execute(
                """
                UPDATE exploration_state
                SET next_encounter_threshold_tokens = ?,
                    updated_at = ?
                WHERE exploration_state_id = 1;
                """,
                bindings: [
                    .integer(ExplorationAccumulatorConfig().tokensRequiredForEncounter(row.totalEncounters + 1)),
                    .text(now),
                ]
            )
        }
    }

    private func ensurePendingEncounterThresholdPolicy(
        database: SQLiteDatabase,
        force: Bool
    ) throws {
        let lowThresholdOverrideEnabled = try internalLowThresholdOverrideEnabled(database: database)
        guard lowThresholdOverrideEnabled == false else {
            return
        }

        let state = try currentExplorationState(database: database)
        let capturedSpeciesCount = try dexCapturedSpeciesCount(database: database)
        let config = ExplorationAccumulatorConfig()
        let currentPolicy = try stringSetting(
            key: Self.encounterThresholdPolicySettingKey,
            database: database
        )
        let range = config.scaledThresholdRange(capturedSpeciesCount: capturedSpeciesCount)

        let policyChanged = currentPolicy != Self.encounterThresholdPolicyVersion
        let invalidThreshold = state.nextEncounterThresholdTokens <= 0
            || state.nextEncounterThresholdTokens < range.min

        guard force || policyChanged || invalidThreshold else {
            return
        }

        let nextThreshold = config.tokensRequiredForEncounter(
            state.totalEncounters + 1,
            capturedSpeciesCount: capturedSpeciesCount
        )
        let nextTokensSinceLastEncounter = Self.rebasedTokensSinceLastEncounter(
            currentTokensSinceLastEncounter: state.tokensSinceLastEncounter,
            nextEncounterThresholdTokens: nextThreshold
        )

        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            UPDATE exploration_state
            SET tokens_since_last_encounter = ?,
                next_encounter_threshold_tokens = ?,
                updated_at = ?
            WHERE exploration_state_id = 1;
            """,
            bindings: [
                .integer(nextTokensSinceLastEncounter),
                .integer(nextThreshold),
                .text(now),
            ]
        )
        try upsertRawSetting(
            key: Self.encounterThresholdPolicySettingKey,
            encodedValue: "\"\(Self.encounterThresholdPolicyVersion)\"",
            updatedAt: now,
            database: database
        )
    }

    private static func rebasedTokensSinceLastEncounter(
        currentTokensSinceLastEncounter: Int64,
        nextEncounterThresholdTokens: Int64
    ) -> Int64 {
        guard currentTokensSinceLastEncounter >= nextEncounterThresholdTokens else {
            return currentTokensSinceLastEncounter
        }

        let midpoint = Int64(
            (Double(nextEncounterThresholdTokens) * encounterThresholdRebaseProgressFraction)
                .rounded(.down)
        )
        return max(0, min(midpoint, nextEncounterThresholdTokens - 1))
    }

    private func dexCapturedSpeciesCount(database: SQLiteDatabase) throws -> Int {
        let count = try database.fetchOne(
            "SELECT COUNT(*) FROM dex_captured;"
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0
        return Int(count)
    }

    private func ensureGameplayStartedAt(_ database: SQLiteDatabase) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        try database.execute(
            """
            INSERT OR IGNORE INTO settings (
                setting_key,
                setting_value_json,
                updated_at
            ) VALUES ('gameplay_started_at', ?, ?);
            """,
            bindings: [
                .text("\"\(now)\""),
                .text(now),
            ]
        )
    }

    private func gameplayStartedAt(database: SQLiteDatabase) throws -> String {
        if let value = try stringSetting(key: "gameplay_started_at", database: database) {
            return value
        }

        let now = ISO8601DateFormatter().string(from: Date())
        try upsertRawSetting(
            key: "gameplay_started_at",
            encodedValue: "\"\(now)\"",
            updatedAt: now,
            database: database
        )
        return now
    }

    func liveGameplayStartedAt(database: SQLiteDatabase) throws -> String? {
        try stringSetting(key: "live_gameplay_started_at", database: database)
    }

    private func stringSetting(key: String, database: SQLiteDatabase) throws -> String? {
        let decoder = JSONDecoder()
        guard let rawJSON = try database.fetchOne(
            """
            SELECT setting_value_json
            FROM settings
            WHERE setting_key = ?
            LIMIT 1;
            """,
            bindings: [.text(key)],
            map: { statement in
                SQLiteDatabase.columnText(statement, index: 0)
            }
        ) else {
            return nil
        }

        return try decoder.decode(String.self, from: Data(rawJSON.utf8))
    }

    private func upsertRawSetting(
        key: String,
        encodedValue: String,
        updatedAt: String,
        database: SQLiteDatabase
    ) throws {
        try database.execute(
            """
            INSERT INTO settings (
                setting_key,
                setting_value_json,
                updated_at
            ) VALUES (?, ?, ?)
            ON CONFLICT(setting_key) DO UPDATE SET
                setting_value_json = excluded.setting_value_json,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(key),
                .text(encodedValue),
                .text(updatedAt),
            ]
        )
    }

    private func ensureSpeciesCatalog(_ database: SQLiteDatabase) throws {
        let now = ISO8601DateFormatter().string(from: Date())

        for species in SpeciesCatalog.all {
            try database.execute(
                """
                INSERT INTO species (
                    species_id,
                    name,
                    field_code,
                    rarity_tier,
                    is_active,
                    sort_order,
                    asset_key,
                    flavor_text,
                    introduced_in_version,
                    created_at,
                    stat_planning,
                    stat_design,
                    stat_frontend,
                    stat_backend,
                    stat_pm,
                    stat_infra,
                    traits_json,
                    training_trait
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(species_id) DO UPDATE SET
                    name = excluded.name,
                    field_code = excluded.field_code,
                    rarity_tier = excluded.rarity_tier,
                    is_active = excluded.is_active,
                    sort_order = excluded.sort_order,
                    asset_key = excluded.asset_key,
                    flavor_text = excluded.flavor_text,
                    introduced_in_version = excluded.introduced_in_version,
                    stat_planning = excluded.stat_planning,
                    stat_design = excluded.stat_design,
                    stat_frontend = excluded.stat_frontend,
                    stat_backend = excluded.stat_backend,
                    stat_pm = excluded.stat_pm,
                    stat_infra = excluded.stat_infra,
                    traits_json = excluded.traits_json,
                    training_trait = excluded.training_trait;
                """,
                bindings: [
                    .text(species.id),
                    .text(species.name),
                    .text(species.field.rawValue),
                    .text(species.rarity.rawValue),
                    .integer(species.isActive ? 1 : 0),
                    .integer(Int64(species.sortOrder)),
                    .text(species.assetKey),
                    species.flavorText.map(SQLiteValue.text) ?? .null,
                    .text(species.introducedInVersion),
                    .text(now),
                    .integer(Int64(species.stats.planning)),
                    .integer(Int64(species.stats.design)),
                    .integer(Int64(species.stats.frontend)),
                    .integer(Int64(species.stats.backend)),
                    .integer(Int64(species.stats.pm)),
                    .integer(Int64(species.stats.infra)),
                    .text(speciesTraitsJSON(species.stats.traits)),
                    .text(species.trainingTrait.rawValue),
                ]
            )
        }
    }

    private func ensureRaidCatalog(_ database: SQLiteDatabase) throws {
        let now = ISO8601DateFormatter().string(from: Date())
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        for raid in RaidCatalog.allRaids {
            let axisWeightsJSON = String(decoding: try encoder.encode(raid.axisWeights), as: UTF8.self)
            let preferredTraitsJSON = String(decoding: try encoder.encode(raid.preferredTraitTags), as: UTF8.self)
            let rewardIDsJSON = String(decoding: try encoder.encode(raid.rewardIDs), as: UTF8.self)

            try database.execute(
                """
                INSERT INTO raid_definitions (
                    raid_id,
                    title,
                    target_name,
                    target_art_key,
                    raid_field,
                    availability_kind,
                    active_start_at,
                    active_end_at,
                    settlement_grace_seconds,
                    max_hp,
                    axis_weights_json,
                    preferred_trait_tags_json,
                    reward_ids_json,
                    difficulty_tier,
                    created_at,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(raid_id) DO UPDATE SET
                    title = excluded.title,
                    target_name = excluded.target_name,
                    target_art_key = excluded.target_art_key,
                    raid_field = excluded.raid_field,
                    availability_kind = excluded.availability_kind,
                    active_start_at = excluded.active_start_at,
                    active_end_at = excluded.active_end_at,
                    settlement_grace_seconds = excluded.settlement_grace_seconds,
                    max_hp = excluded.max_hp,
                    axis_weights_json = excluded.axis_weights_json,
                    preferred_trait_tags_json = excluded.preferred_trait_tags_json,
                    reward_ids_json = excluded.reward_ids_json,
                    difficulty_tier = excluded.difficulty_tier,
                    updated_at = excluded.updated_at;
                """,
                bindings: [
                    .text(raid.raidID),
                    .text(raid.title),
                    .text(raid.targetName),
                    .text(raid.targetArtKey),
                    .text(raid.raidField.rawValue),
                    .text(raid.availabilityKind.rawValue),
                    raid.activeStartAt.map(SQLiteValue.text) ?? .null,
                    raid.activeEndAt.map(SQLiteValue.text) ?? .null,
                    .integer(Int64(raid.settlementGraceSeconds)),
                    .integer(raid.maxHP),
                    .text(axisWeightsJSON),
                    .text(preferredTraitsJSON),
                    .text(rewardIDsJSON),
                    .text(raid.difficultyTier.rawValue),
                    .text(now),
                    .text(now),
                ]
            )
        }

        for reward in RaidCatalog.allRewards {
            try database.execute(
                """
                INSERT INTO raid_reward_definitions (
                    reward_id,
                    source_raid_id,
                    reward_type,
                    title,
                    art_key,
                    grant_rule,
                    created_at,
                    updated_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(reward_id) DO UPDATE SET
                    source_raid_id = excluded.source_raid_id,
                    reward_type = excluded.reward_type,
                    title = excluded.title,
                    art_key = excluded.art_key,
                    grant_rule = excluded.grant_rule,
                    updated_at = excluded.updated_at;
                """,
                bindings: [
                    .text(reward.rewardID),
                    .text(reward.sourceRaidID),
                    .text(reward.type.rawValue),
                    .text(reward.title),
                    .text(reward.artKey),
                    .text(reward.grantRule.rawValue),
                    .text(now),
                    .text(now),
                ]
            )
        }
    }

    private func speciesTraitsJSON(_ traits: [String]) -> String {
        guard let data = try? JSONEncoder().encode(traits),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }

    private func currentExplorationState(database: SQLiteDatabase) throws -> ExplorationAccumulatorState {
        guard let state = try database.fetchOne(
            """
            SELECT exploration_state_id,
                   total_normalized_tokens,
                   tokens_since_last_encounter,
                   next_encounter_threshold_tokens,
                   total_encounters,
                   total_captures,
                   last_usage_sample_id
            FROM exploration_state
            WHERE exploration_state_id = 1
            LIMIT 1;
            """,
            map: { statement in
            ExplorationAccumulatorState(
                totalNormalizedTokens: SQLiteDatabase.columnInt64(statement, index: 1),
                tokensSinceLastEncounter: SQLiteDatabase.columnInt64(statement, index: 2),
                nextEncounterThresholdTokens: SQLiteDatabase.columnInt64(statement, index: 3),
                totalEncounters: SQLiteDatabase.columnInt64(statement, index: 4),
                totalCaptures: SQLiteDatabase.columnInt64(statement, index: 5)
            )
        }) else {
            throw SQLiteError.statementFailed(
                message: "missing exploration_state row",
                sql: "SELECT ... FROM exploration_state WHERE exploration_state_id = 1"
            )
        }

        return state
    }

    private func countRows(in table: String, database: SQLiteDatabase) throws -> Int {
        Int(try database.fetchOne("SELECT COUNT(*) FROM \(table);") { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0)
    }

    private var migrations: [SQLiteMigration] {
        [
            SQLiteMigration(version: 1, statements: [
                """
                CREATE TABLE IF NOT EXISTS providers (
                    provider_code TEXT PRIMARY KEY NOT NULL,
                    display_name TEXT NOT NULL,
                    default_support_level TEXT NOT NULL,
                    is_enabled INTEGER NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS provider_sessions (
                    provider_session_row_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    provider_session_id TEXT NOT NULL,
                    session_identity_kind TEXT NOT NULL,
                    source_mode TEXT NOT NULL,
                    model_slug TEXT,
                    workspace_dir TEXT,
                    transcript_path TEXT,
                    started_at TEXT,
                    ended_at TEXT,
                    last_seen_at TEXT NOT NULL,
                    session_state TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    UNIQUE(provider_code, provider_session_id)
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS provider_health (
                    provider_health_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    source_mode TEXT NOT NULL,
                    health_state TEXT NOT NULL,
                    message TEXT,
                    last_success_at TEXT,
                    last_error_at TEXT,
                    last_error_code TEXT,
                    last_error_summary TEXT,
                    updated_at TEXT NOT NULL,
                    UNIQUE(provider_code, source_mode)
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS ingest_sources (
                    ingest_source_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    source_key TEXT NOT NULL UNIQUE,
                    source_kind TEXT NOT NULL,
                    source_path TEXT,
                    last_offset INTEGER NOT NULL,
                    last_line_number INTEGER NOT NULL,
                    last_event_fingerprint TEXT,
                    last_seen_at TEXT,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS provider_ingest_events (
                    provider_ingest_event_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    source_mode TEXT NOT NULL,
                    provider_session_row_id INTEGER REFERENCES provider_sessions(provider_session_row_id),
                    ingest_source_id INTEGER REFERENCES ingest_sources(ingest_source_id),
                    provider_event_fingerprint TEXT NOT NULL UNIQUE,
                    raw_reference_kind TEXT NOT NULL,
                    raw_reference_event_name TEXT,
                    raw_reference_offset TEXT,
                    observed_at TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    acceptance_state TEXT NOT NULL,
                    rejection_reason TEXT,
                    created_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS usage_samples (
                    usage_sample_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    provider_ingest_event_id INTEGER NOT NULL UNIQUE REFERENCES provider_ingest_events(provider_ingest_event_id),
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    provider_session_row_id INTEGER NOT NULL REFERENCES provider_sessions(provider_session_row_id),
                    observed_at TEXT NOT NULL,
                    total_input_tokens INTEGER NOT NULL,
                    total_output_tokens INTEGER NOT NULL,
                    total_cached_input_tokens INTEGER NOT NULL,
                    normalized_total_tokens INTEGER NOT NULL CHECK(normalized_total_tokens >= 0),
                    normalized_delta_tokens INTEGER NOT NULL CHECK(normalized_delta_tokens >= 0),
                    current_input_tokens INTEGER,
                    current_output_tokens INTEGER,
                    gameplay_eligibility TEXT NOT NULL DEFAULT 'outside_live_runtime',
                    gameplay_delta_tokens INTEGER NOT NULL DEFAULT 0,
                    gameplay_balance_bucket TEXT,
                    gameplay_balance_weight REAL,
                    gameplay_balance_policy TEXT,
                    burst_intensity_band INTEGER NOT NULL,
                    created_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS account_usage_samples (
                    account_usage_sample_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    source_mode TEXT NOT NULL,
                    observed_at TEXT NOT NULL,
                    model_slug TEXT,
                    usage_kind TEXT NOT NULL,
                    input_tokens INTEGER NOT NULL CHECK(input_tokens >= 0),
                    output_tokens INTEGER NOT NULL CHECK(output_tokens >= 0),
                    cached_input_tokens INTEGER NOT NULL CHECK(cached_input_tokens >= 0),
                    normalized_delta_tokens INTEGER NOT NULL CHECK(normalized_delta_tokens >= 0),
                    provider_event_fingerprint TEXT NOT NULL UNIQUE,
                    raw_reference_kind TEXT NOT NULL,
                    raw_reference_event_name TEXT,
                    raw_reference_offset TEXT,
                    payload_json TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS gameplay_balance_buckets (
                    bucket_key TEXT PRIMARY KEY NOT NULL,
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    model_bucket TEXT NOT NULL,
                    effective_weight REAL NOT NULL,
                    observed_rate_tokens_per_minute REAL NOT NULL,
                    sample_count INTEGER NOT NULL,
                    active_minutes REAL NOT NULL,
                    last_sample_at TEXT,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS exploration_state (
                    exploration_state_id INTEGER PRIMARY KEY NOT NULL,
                    total_normalized_tokens INTEGER NOT NULL,
                    pending_tokens INTEGER NOT NULL CHECK(pending_tokens >= 0),
                    total_steps INTEGER NOT NULL,
                    steps_since_last_encounter INTEGER NOT NULL CHECK(steps_since_last_encounter >= 0),
                    total_encounters INTEGER NOT NULL,
                    total_captures INTEGER NOT NULL,
                    last_usage_sample_id INTEGER REFERENCES usage_samples(usage_sample_id),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS species (
                    species_id TEXT PRIMARY KEY NOT NULL,
                    name TEXT NOT NULL,
                    field_code TEXT NOT NULL,
                    rarity_tier TEXT NOT NULL,
                    is_active INTEGER NOT NULL,
                    sort_order INTEGER NOT NULL,
                    asset_key TEXT,
                    flavor_text TEXT,
                    introduced_in_version TEXT NOT NULL,
                    training_trait TEXT NOT NULL DEFAULT 'trail' CHECK(training_trait IN ('trail', 'scout', 'capture', 'raider')),
                    created_at TEXT NOT NULL,
                    UNIQUE(field_code, name)
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS encounters (
                    encounter_id TEXT PRIMARY KEY NOT NULL,
                    encounter_sequence INTEGER NOT NULL UNIQUE,
                    provider_code TEXT REFERENCES providers(provider_code),
                    provider_session_row_id INTEGER REFERENCES provider_sessions(provider_session_row_id),
                    usage_sample_id INTEGER NOT NULL REFERENCES usage_samples(usage_sample_id),
                    threshold_event_index INTEGER NOT NULL,
                    occurred_at TEXT NOT NULL,
                    field_code TEXT NOT NULL,
                    rarity_tier TEXT NOT NULL,
                    species_id TEXT NOT NULL REFERENCES species(species_id),
                    burst_intensity_band INTEGER NOT NULL,
                    capture_probability REAL NOT NULL DEFAULT 0,
                    capture_roll REAL NOT NULL DEFAULT 0,
                    outcome TEXT NOT NULL DEFAULT 'escaped',
                    created_at TEXT NOT NULL,
                    UNIQUE(usage_sample_id, threshold_event_index)
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS dex_seen (
                    species_id TEXT PRIMARY KEY NOT NULL REFERENCES species(species_id),
                    first_seen_at TEXT NOT NULL,
                    last_seen_at TEXT NOT NULL,
                    seen_count INTEGER NOT NULL CHECK(seen_count >= 1),
                    last_encounter_id TEXT NOT NULL REFERENCES encounters(encounter_id),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS dex_captured (
                    species_id TEXT PRIMARY KEY NOT NULL REFERENCES species(species_id),
                    first_captured_at TEXT NOT NULL,
                    last_captured_at TEXT NOT NULL,
                    captured_count INTEGER NOT NULL CHECK(captured_count >= 1),
                    last_encounter_id TEXT NOT NULL REFERENCES encounters(encounter_id),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS domain_events (
                    domain_event_row_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    event_id TEXT NOT NULL UNIQUE,
                    event_type TEXT NOT NULL,
                    occurred_at TEXT NOT NULL,
                    producer TEXT NOT NULL,
                    correlation_id TEXT,
                    causation_id TEXT,
                    aggregate_type TEXT,
                    aggregate_id TEXT,
                    payload_json TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS settings (
                    setting_key TEXT PRIMARY KEY NOT NULL,
                    setting_value_json TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """,
                "CREATE INDEX IF NOT EXISTS idx_provider_sessions_provider_last_seen ON provider_sessions(provider_code, last_seen_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_provider_ingest_events_provider_observed ON provider_ingest_events(provider_code, observed_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_provider_ingest_events_acceptance_created ON provider_ingest_events(acceptance_state, created_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_usage_samples_session_observed ON usage_samples(provider_session_row_id, observed_at);",
                "CREATE INDEX IF NOT EXISTS idx_usage_samples_observed ON usage_samples(observed_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_usage_samples_gameplay_balance_bucket ON usage_samples(gameplay_balance_bucket, observed_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_gameplay_balance_buckets_provider ON gameplay_balance_buckets(provider_code, updated_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_encounters_occurred ON encounters(occurred_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_account_usage_samples_provider_observed ON account_usage_samples(provider_code, observed_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_account_usage_samples_observed ON account_usage_samples(observed_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_domain_events_event_type_occurred ON domain_events(event_type, occurred_at DESC);",
            ]),
            SQLiteMigration(version: 2, statements: [
                """
                CREATE TABLE IF NOT EXISTS backfill_runs (
                    backfill_run_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    provider_session_row_id INTEGER REFERENCES provider_sessions(provider_session_row_id),
                    mode TEXT NOT NULL,
                    started_at TEXT NOT NULL,
                    completed_at TEXT,
                    status TEXT NOT NULL,
                    samples_examined INTEGER NOT NULL,
                    samples_created INTEGER NOT NULL,
                    duplicates_skipped INTEGER NOT NULL,
                    errors_count INTEGER NOT NULL,
                    summary_json TEXT
                );
                """,
                "CREATE INDEX IF NOT EXISTS idx_backfill_runs_provider_started ON backfill_runs(provider_code, started_at DESC);",
            ]),
            SQLiteMigration(version: 3, statements: [
                """
                UPDATE exploration_state
                SET last_usage_sample_id = NULL,
                    updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
                WHERE exploration_state_id = 1;
                """,
                "DELETE FROM backfill_runs;",
                "DELETE FROM dex_captured;",
                "DELETE FROM dex_seen;",
                "DELETE FROM encounters;",
                "DELETE FROM domain_events;",
                "DELETE FROM usage_samples;",
                "DELETE FROM provider_ingest_events;",
                "DELETE FROM ingest_sources;",
                "DELETE FROM provider_health;",
                "DELETE FROM provider_sessions;",
                "DELETE FROM species;",
                """
                UPDATE exploration_state
                SET total_normalized_tokens = 0,
                    pending_tokens = 0,
                    total_steps = 0,
                    steps_since_last_encounter = 0,
                    total_encounters = 0,
                    total_captures = 0,
                    last_usage_sample_id = NULL,
                    updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
                WHERE exploration_state_id = 1;
                """,
                """
                INSERT INTO settings (
                    setting_key,
                    setting_value_json,
                    updated_at
                ) VALUES (
                    'gameplay_started_at',
                    json_quote(STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
                    STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
                )
                ON CONFLICT(setting_key) DO UPDATE SET
                    setting_value_json = excluded.setting_value_json,
                    updated_at = excluded.updated_at;
                """,
            ]),
            SQLiteMigration(version: 4, statements: [
                """
                UPDATE exploration_state
                SET last_usage_sample_id = NULL,
                    updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
                WHERE exploration_state_id = 1;
                """,
                "DELETE FROM backfill_runs;",
                "DELETE FROM dex_captured;",
                "DELETE FROM dex_seen;",
                "DELETE FROM encounters;",
                "DELETE FROM domain_events;",
                "DELETE FROM usage_samples;",
                "DELETE FROM provider_ingest_events;",
                "DELETE FROM ingest_sources;",
                "DELETE FROM provider_health;",
                "DELETE FROM provider_sessions;",
                "DELETE FROM species;",
                """
                UPDATE exploration_state
                SET total_normalized_tokens = 0,
                    pending_tokens = 0,
                    total_steps = 0,
                    steps_since_last_encounter = 0,
                    total_encounters = 0,
                    total_captures = 0,
                    last_usage_sample_id = NULL,
                    updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
                WHERE exploration_state_id = 1;
                """,
                """
                INSERT INTO settings (
                    setting_key,
                    setting_value_json,
                    updated_at
                ) VALUES (
                    'gameplay_started_at',
                    json_quote(STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
                    STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')
                )
                ON CONFLICT(setting_key) DO UPDATE SET
                    setting_value_json = excluded.setting_value_json,
                    updated_at = excluded.updated_at;
                """,
            ]),
            SQLiteMigration(version: 5, statements: [
                "ALTER TABLE exploration_state RENAME TO exploration_state_legacy_v4;",
                """
                CREATE TABLE IF NOT EXISTS exploration_state (
                    exploration_state_id INTEGER PRIMARY KEY NOT NULL,
                    total_normalized_tokens INTEGER NOT NULL,
                    tokens_since_last_encounter INTEGER NOT NULL CHECK(tokens_since_last_encounter >= 0),
                    next_encounter_threshold_tokens INTEGER NOT NULL CHECK(next_encounter_threshold_tokens > 0),
                    total_encounters INTEGER NOT NULL,
                    total_captures INTEGER NOT NULL,
                    last_usage_sample_id INTEGER REFERENCES usage_samples(usage_sample_id),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                INSERT INTO exploration_state (
                    exploration_state_id,
                    total_normalized_tokens,
                    tokens_since_last_encounter,
                    next_encounter_threshold_tokens,
                    total_encounters,
                    total_captures,
                    last_usage_sample_id,
                    updated_at
                )
                SELECT exploration_state_id,
                       total_normalized_tokens,
                       (steps_since_last_encounter * 200) + pending_tokens,
                       1,
                       total_encounters,
                       total_captures,
                       last_usage_sample_id,
                       updated_at
                FROM exploration_state_legacy_v4;
                """,
                "DROP TABLE exploration_state_legacy_v4;",
            ]),
            SQLiteMigration(version: 6, statements: [
                """
                INSERT INTO providers (
                    provider_code,
                    display_name,
                    default_support_level,
                    is_enabled,
                    created_at,
                    updated_at
                ) VALUES (
                    'gemini',
                    'Gemini CLI',
                    'first_class',
                    1,
                    strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
                    strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                )
                ON CONFLICT(provider_code) DO UPDATE SET
                    display_name = excluded.display_name,
                    default_support_level = excluded.default_support_level,
                    is_enabled = 1,
                    updated_at = excluded.updated_at;
                """,
            ]),
            SQLiteMigration(version: 7, statements: [
                "PRAGMA foreign_keys = OFF;",
                """
                CREATE TABLE IF NOT EXISTS usage_samples_v7 (
                    usage_sample_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    provider_ingest_event_id INTEGER NOT NULL UNIQUE REFERENCES provider_ingest_events(provider_ingest_event_id),
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    provider_session_row_id INTEGER NOT NULL REFERENCES provider_sessions(provider_session_row_id),
                    observed_at TEXT NOT NULL,
                    total_input_tokens INTEGER NOT NULL,
                    total_output_tokens INTEGER NOT NULL,
                    total_cached_input_tokens INTEGER NOT NULL,
                    normalized_total_tokens INTEGER NOT NULL CHECK(normalized_total_tokens >= 0),
                    normalized_delta_tokens INTEGER NOT NULL CHECK(normalized_delta_tokens >= 0),
                    current_input_tokens INTEGER,
                    current_output_tokens INTEGER,
                    gameplay_eligibility TEXT NOT NULL DEFAULT 'outside_live_runtime',
                    gameplay_delta_tokens INTEGER NOT NULL DEFAULT 0,
                    gameplay_balance_bucket TEXT,
                    gameplay_balance_weight REAL,
                    gameplay_balance_policy TEXT,
                    burst_intensity_band INTEGER NOT NULL,
                    created_at TEXT NOT NULL
                );
                """,
                """
                INSERT INTO usage_samples_v7 (
                    usage_sample_id,
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
                    burst_intensity_band,
                    created_at
                )
                SELECT usage_sample_id,
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
                       'outside_live_runtime',
                       0,
                       burst_intensity_band,
                       created_at
                FROM usage_samples;
                """,
                "DROP TABLE usage_samples;",
                "ALTER TABLE usage_samples_v7 RENAME TO usage_samples;",
                "CREATE INDEX IF NOT EXISTS idx_usage_samples_session_observed ON usage_samples(provider_session_row_id, observed_at);",
                "CREATE INDEX IF NOT EXISTS idx_usage_samples_observed ON usage_samples(observed_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_usage_samples_gameplay_eligibility ON usage_samples(gameplay_eligibility, observed_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_usage_samples_gameplay_balance_bucket ON usage_samples(gameplay_balance_bucket, observed_at DESC);",
                "PRAGMA foreign_keys = ON;",
            ], runsInTransaction: false),
            SQLiteMigration(version: 8, statements: [
                "ALTER TABLE species ADD COLUMN stat_planning INTEGER NOT NULL DEFAULT 1;",
                "ALTER TABLE species ADD COLUMN stat_design INTEGER NOT NULL DEFAULT 1;",
                "ALTER TABLE species ADD COLUMN stat_frontend INTEGER NOT NULL DEFAULT 1;",
                "ALTER TABLE species ADD COLUMN stat_backend INTEGER NOT NULL DEFAULT 1;",
                "ALTER TABLE species ADD COLUMN stat_pm INTEGER NOT NULL DEFAULT 1;",
                "ALTER TABLE species ADD COLUMN stat_infra INTEGER NOT NULL DEFAULT 1;",
                "ALTER TABLE species ADD COLUMN traits_json TEXT NOT NULL DEFAULT '[]';",
            ]),
            SQLiteMigration(version: 9, statements: [
                """
                CREATE TABLE IF NOT EXISTS party_members (
                    species_id TEXT NOT NULL PRIMARY KEY
                        REFERENCES species(species_id) ON DELETE CASCADE,
                    slot_order INTEGER NOT NULL,
                    added_at TEXT NOT NULL
                );
                """,
                "CREATE UNIQUE INDEX IF NOT EXISTS idx_party_members_slot ON party_members(slot_order);",
            ]),
            SQLiteMigration(version: 10, statements: [
                """
                WITH codex_ordered AS (
                    SELECT
                        us.usage_sample_id,
                        us.total_input_tokens + us.total_output_tokens AS repaired_total,
                        LAG(us.total_input_tokens + us.total_output_tokens, 1, 0) OVER (
                            PARTITION BY us.provider_session_row_id
                            ORDER BY us.observed_at, us.usage_sample_id
                        ) AS previous_repaired_total
                    FROM usage_samples us
                    INNER JOIN provider_ingest_events pie
                        ON pie.provider_ingest_event_id = us.provider_ingest_event_id
                    WHERE us.provider_code = 'codex'
                      AND pie.source_mode IN (
                          'codex_exec_json',
                          'codex_session_store_live',
                          'codex_session_store_recovery',
                          'codex_transcript_backfill'
                      )
                ),
                repaired AS (
                    SELECT
                        usage_sample_id,
                        repaired_total,
                        CASE
                            WHEN repaired_total > previous_repaired_total
                            THEN repaired_total - previous_repaired_total
                            ELSE 0
                        END AS repaired_delta
                    FROM codex_ordered
                )
                UPDATE usage_samples
                SET normalized_total_tokens = (
                        SELECT repaired_total
                        FROM repaired
                        WHERE repaired.usage_sample_id = usage_samples.usage_sample_id
                    ),
                    normalized_delta_tokens = (
                        SELECT repaired_delta
                        FROM repaired
                        WHERE repaired.usage_sample_id = usage_samples.usage_sample_id
                    ),
                    gameplay_delta_tokens = CASE
                        WHEN gameplay_eligibility = 'eligible_live'
                        THEN (
                            SELECT repaired_delta
                            FROM repaired
                            WHERE repaired.usage_sample_id = usage_samples.usage_sample_id
                        )
                        ELSE 0
                    END
                WHERE usage_sample_id IN (
                    SELECT usage_sample_id
                    FROM repaired
                );
                """,
                """
                WITH repaired AS (
                    SELECT
                        us.provider_ingest_event_id,
                        us.normalized_total_tokens
                    FROM usage_samples us
                    INNER JOIN provider_ingest_events pie
                        ON pie.provider_ingest_event_id = us.provider_ingest_event_id
                    WHERE us.provider_code = 'codex'
                      AND pie.source_mode IN (
                          'codex_exec_json',
                          'codex_session_store_live',
                          'codex_session_store_recovery',
                          'codex_transcript_backfill'
                      )
                )
                UPDATE provider_ingest_events
                SET payload_json = json_set(
                    payload_json,
                    '$.normalized_total_tokens',
                    (
                        SELECT normalized_total_tokens
                        FROM repaired
                        WHERE repaired.provider_ingest_event_id = provider_ingest_events.provider_ingest_event_id
                    )
                )
                WHERE provider_ingest_event_id IN (
                    SELECT provider_ingest_event_id
                    FROM repaired
                )
                  AND json_valid(payload_json);
                """,
                """
                WITH repaired AS (
                    SELECT
                        us.usage_sample_id,
                        us.normalized_total_tokens,
                        us.normalized_delta_tokens,
                        us.gameplay_delta_tokens
                    FROM usage_samples us
                    INNER JOIN provider_ingest_events pie
                        ON pie.provider_ingest_event_id = us.provider_ingest_event_id
                    WHERE us.provider_code = 'codex'
                      AND pie.source_mode IN (
                          'codex_exec_json',
                          'codex_session_store_live',
                          'codex_session_store_recovery',
                          'codex_transcript_backfill'
                      )
                )
                UPDATE domain_events
                SET payload_json = json_set(
                    payload_json,
                    '$.normalized_total_tokens',
                    (
                        SELECT normalized_total_tokens
                        FROM repaired
                        WHERE repaired.usage_sample_id = json_extract(domain_events.payload_json, '$.usage_sample_id')
                    ),
                    '$.normalized_delta_tokens',
                    (
                        SELECT normalized_delta_tokens
                        FROM repaired
                        WHERE repaired.usage_sample_id = json_extract(domain_events.payload_json, '$.usage_sample_id')
                    ),
                    '$.gameplay_delta_tokens',
                    (
                        SELECT gameplay_delta_tokens
                        FROM repaired
                        WHERE repaired.usage_sample_id = json_extract(domain_events.payload_json, '$.usage_sample_id')
                    )
                )
                WHERE event_type = 'usage_sample_recorded'
                  AND json_valid(payload_json)
                  AND json_extract(payload_json, '$.usage_sample_id') IN (
                      SELECT usage_sample_id
                      FROM repaired
                  );
                """,
            ]),
            SQLiteMigration(version: 11, statements: [
                """
                CREATE TABLE IF NOT EXISTS account_usage_samples (
                    account_usage_sample_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    source_mode TEXT NOT NULL,
                    observed_at TEXT NOT NULL,
                    model_slug TEXT,
                    usage_kind TEXT NOT NULL,
                    input_tokens INTEGER NOT NULL CHECK(input_tokens >= 0),
                    output_tokens INTEGER NOT NULL CHECK(output_tokens >= 0),
                    cached_input_tokens INTEGER NOT NULL CHECK(cached_input_tokens >= 0),
                    normalized_delta_tokens INTEGER NOT NULL CHECK(normalized_delta_tokens >= 0),
                    provider_event_fingerprint TEXT NOT NULL UNIQUE,
                    raw_reference_kind TEXT NOT NULL,
                    raw_reference_event_name TEXT,
                    raw_reference_offset TEXT,
                    payload_json TEXT NOT NULL,
                    created_at TEXT NOT NULL
                );
                """,
                "CREATE INDEX IF NOT EXISTS idx_account_usage_samples_provider_observed ON account_usage_samples(provider_code, observed_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_account_usage_samples_observed ON account_usage_samples(observed_at DESC);",
            ]),
            SQLiteMigration(version: 12, statements: [
                "ALTER TABLE usage_samples ADD COLUMN gameplay_balance_bucket TEXT;",
                "ALTER TABLE usage_samples ADD COLUMN gameplay_balance_weight REAL;",
                "ALTER TABLE usage_samples ADD COLUMN gameplay_balance_policy TEXT;",
                """
                CREATE TABLE IF NOT EXISTS gameplay_balance_buckets (
                    bucket_key TEXT PRIMARY KEY NOT NULL,
                    provider_code TEXT NOT NULL REFERENCES providers(provider_code),
                    model_bucket TEXT NOT NULL,
                    effective_weight REAL NOT NULL,
                    observed_rate_tokens_per_minute REAL NOT NULL,
                    sample_count INTEGER NOT NULL,
                    active_minutes REAL NOT NULL,
                    last_sample_at TEXT,
                    updated_at TEXT NOT NULL
                );
                """,
                "CREATE INDEX IF NOT EXISTS idx_usage_samples_gameplay_balance_bucket ON usage_samples(gameplay_balance_bucket, observed_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_gameplay_balance_buckets_provider ON gameplay_balance_buckets(provider_code, updated_at DESC);",
            ]),
            SQLiteMigration(version: 13, statements: [
                """
                CREATE TABLE IF NOT EXISTS raid_definitions (
                    raid_id TEXT PRIMARY KEY NOT NULL,
                    title TEXT NOT NULL,
                    target_name TEXT NOT NULL,
                    target_art_key TEXT NOT NULL,
                    raid_field TEXT NOT NULL,
                    availability_kind TEXT NOT NULL,
                    active_start_at TEXT,
                    active_end_at TEXT,
                    settlement_grace_seconds INTEGER NOT NULL CHECK(settlement_grace_seconds >= 0),
                    max_hp INTEGER NOT NULL CHECK(max_hp > 0),
                    axis_weights_json TEXT NOT NULL,
                    preferred_trait_tags_json TEXT NOT NULL,
                    reward_ids_json TEXT NOT NULL,
                    difficulty_tier TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS raid_reward_definitions (
                    reward_id TEXT PRIMARY KEY NOT NULL,
                    source_raid_id TEXT NOT NULL REFERENCES raid_definitions(raid_id) ON DELETE CASCADE,
                    reward_type TEXT NOT NULL,
                    title TEXT NOT NULL,
                    art_key TEXT NOT NULL,
                    grant_rule TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS raid_instances (
                    raid_instance_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    raid_id TEXT NOT NULL UNIQUE REFERENCES raid_definitions(raid_id) ON DELETE CASCADE,
                    status TEXT NOT NULL,
                    current_hp INTEGER NOT NULL CHECK(current_hp >= 0),
                    total_attacks INTEGER NOT NULL DEFAULT 0 CHECK(total_attacks >= 0),
                    total_damage INTEGER NOT NULL DEFAULT 0 CHECK(total_damage >= 0),
                    first_seen_at TEXT NOT NULL,
                    started_at TEXT,
                    cleared_at TEXT,
                    expired_at TEXT,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS raid_attacks (
                    raid_attack_row_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    raid_instance_id INTEGER NOT NULL REFERENCES raid_instances(raid_instance_id) ON DELETE CASCADE,
                    raid_id TEXT NOT NULL REFERENCES raid_definitions(raid_id) ON DELETE CASCADE,
                    usage_sample_id INTEGER NOT NULL REFERENCES usage_samples(usage_sample_id),
                    occurred_at TEXT NOT NULL,
                    party_snapshot_json TEXT NOT NULL,
                    party_size INTEGER NOT NULL CHECK(party_size >= 0),
                    total_damage INTEGER NOT NULL CHECK(total_damage >= 0),
                    created_at TEXT NOT NULL,
                    UNIQUE(raid_instance_id, usage_sample_id)
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS raid_member_hits (
                    raid_member_hit_id INTEGER PRIMARY KEY AUTOINCREMENT,
                    raid_attack_row_id INTEGER NOT NULL REFERENCES raid_attacks(raid_attack_row_id) ON DELETE CASCADE,
                    species_id TEXT NOT NULL REFERENCES species(species_id),
                    slot_order INTEGER NOT NULL,
                    field_code TEXT NOT NULL,
                    rarity_tier TEXT NOT NULL,
                    axis_score REAL NOT NULL,
                    role_fit_bonus INTEGER NOT NULL,
                    field_fit_bonus INTEGER NOT NULL,
                    trait_fit_bonus INTEGER NOT NULL,
                    capture_bond_bonus INTEGER NOT NULL,
                    hit_power INTEGER NOT NULL CHECK(hit_power >= 0),
                    stats_json TEXT NOT NULL
                );
                """,
                """
                CREATE TABLE IF NOT EXISTS reward_archive_entries (
                    reward_id TEXT PRIMARY KEY NOT NULL REFERENCES raid_reward_definitions(reward_id) ON DELETE CASCADE,
                    source_raid_id TEXT NOT NULL REFERENCES raid_definitions(raid_id) ON DELETE CASCADE,
                    status TEXT NOT NULL,
                    acquired_at TEXT,
                    missed_at TEXT,
                    updated_at TEXT NOT NULL
                );
                """,
                "CREATE INDEX IF NOT EXISTS idx_raid_definitions_availability ON raid_definitions(availability_kind, active_start_at, active_end_at);",
                "CREATE INDEX IF NOT EXISTS idx_raid_instances_status ON raid_instances(status, updated_at DESC);",
                "CREATE INDEX IF NOT EXISTS idx_raid_attacks_usage_sample ON raid_attacks(usage_sample_id);",
                "CREATE INDEX IF NOT EXISTS idx_raid_member_hits_attack ON raid_member_hits(raid_attack_row_id);",
                "CREATE INDEX IF NOT EXISTS idx_reward_archive_status ON reward_archive_entries(status, updated_at DESC);",
            ]),
            SQLiteMigration(version: 14, statements: [
                """
                INSERT INTO providers (
                    provider_code,
                    display_name,
                    default_support_level,
                    is_enabled,
                    created_at,
                    updated_at
                ) VALUES (
                    'cursor',
                    'Cursor',
                    'managed_only',
                    1,
                    strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
                    strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                )
                ON CONFLICT(provider_code) DO UPDATE SET
                    display_name = excluded.display_name,
                    default_support_level = excluded.default_support_level,
                    is_enabled = 1,
                    updated_at = excluded.updated_at;
                """,
                """
                INSERT OR IGNORE INTO account_usage_samples (
                    provider_code,
                    source_mode,
                    observed_at,
                    model_slug,
                    usage_kind,
                    input_tokens,
                    output_tokens,
                    cached_input_tokens,
                    normalized_delta_tokens,
                    provider_event_fingerprint,
                    raw_reference_kind,
                    raw_reference_event_name,
                    raw_reference_offset,
                    payload_json,
                    created_at
                )
                WITH cursor_ordered AS (
                    SELECT
                        us.usage_sample_id,
                        us.observed_at,
                        us.total_input_tokens,
                        us.total_output_tokens,
                        us.total_cached_input_tokens,
                        us.normalized_delta_tokens,
                        us.created_at,
                        ps.model_slug,
                        LAG(us.total_input_tokens, 1, 0) OVER (
                            PARTITION BY us.provider_session_row_id
                            ORDER BY us.observed_at, us.usage_sample_id
                        ) AS previous_input_tokens,
                        LAG(us.total_output_tokens, 1, 0) OVER (
                            PARTITION BY us.provider_session_row_id
                            ORDER BY us.observed_at, us.usage_sample_id
                        ) AS previous_output_tokens,
                        LAG(us.total_cached_input_tokens, 1, 0) OVER (
                            PARTITION BY us.provider_session_row_id
                            ORDER BY us.observed_at, us.usage_sample_id
                        ) AS previous_cached_input_tokens
                    FROM usage_samples us
                    LEFT JOIN provider_sessions ps
                        ON ps.provider_session_row_id = us.provider_session_row_id
                    WHERE us.provider_code = 'cursor'
                ),
                cursor_account_rows AS (
                    SELECT
                        usage_sample_id,
                        observed_at,
                        model_slug,
                        CASE
                            WHEN total_input_tokens >= previous_input_tokens
                            THEN total_input_tokens - previous_input_tokens
                            ELSE 0
                        END AS input_delta_tokens,
                        CASE
                            WHEN total_output_tokens >= previous_output_tokens
                            THEN total_output_tokens - previous_output_tokens
                            ELSE 0
                        END AS output_delta_tokens,
                        CASE
                            WHEN total_cached_input_tokens >= previous_cached_input_tokens
                            THEN total_cached_input_tokens - previous_cached_input_tokens
                            ELSE 0
                        END AS cached_input_delta_tokens,
                        normalized_delta_tokens,
                        created_at
                    FROM cursor_ordered
                )
                SELECT
                    'cursor',
                    'cursor_legacy_usage_sample',
                    observed_at,
                    model_slug,
                    'legacy_usage_sample',
                    input_delta_tokens,
                    output_delta_tokens,
                    cached_input_delta_tokens,
                    normalized_delta_tokens,
                    'cursor:legacy-usage-sample:' || usage_sample_id,
                    'legacy_usage_sample',
                    'legacy_usage_sample',
                    CAST(usage_sample_id AS TEXT),
                    json_object(
                        'event_type', 'account_usage_sample',
                        'provider', 'cursor',
                        'source_mode', 'cursor_legacy_usage_sample',
                        'observed_at', observed_at,
                        'model_slug', model_slug,
                        'usage_kind', 'legacy_usage_sample',
                        'input_tokens', input_delta_tokens,
                        'output_tokens', output_delta_tokens,
                        'cached_input_tokens', cached_input_delta_tokens,
                        'normalized_delta_tokens', normalized_delta_tokens,
                        'provider_event_fingerprint', 'cursor:legacy-usage-sample:' || usage_sample_id,
                        'raw_reference', json_object(
                            'kind', 'legacy_usage_sample',
                            'event_name', 'legacy_usage_sample',
                            'offset', CAST(usage_sample_id AS TEXT)
                        )
                    ),
                    created_at
                FROM cursor_account_rows;
                """,
                """
                UPDATE usage_samples
                SET gameplay_eligibility = 'recovery_only',
                    gameplay_delta_tokens = 0,
                    gameplay_balance_bucket = NULL,
                    gameplay_balance_weight = NULL,
                    gameplay_balance_policy = NULL
                WHERE provider_code = 'cursor';
                """,
                """
                UPDATE domain_events
                SET payload_json = json_set(
                    payload_json,
                    '$.gameplay_eligibility',
                    'recovery_only',
                    '$.gameplay_delta_tokens',
                    0
                )
                WHERE event_type = 'usage_sample_recorded'
                  AND json_valid(payload_json)
                  AND json_extract(payload_json, '$.usage_sample_id') IN (
                      SELECT usage_sample_id
                      FROM usage_samples
                      WHERE provider_code = 'cursor'
                  );
                """,
            ]),
            SQLiteMigration(version: 15, statements: [
                "ALTER TABLE dex_captured ADD COLUMN affinity_level INTEGER NOT NULL DEFAULT 1 CHECK(affinity_level BETWEEN 1 AND 5);",
                "ALTER TABLE dex_captured ADD COLUMN affinity_pity_count INTEGER NOT NULL DEFAULT 0 CHECK(affinity_pity_count >= 0);",
                "ALTER TABLE dex_captured ADD COLUMN affinity_last_roll REAL;",
                "ALTER TABLE dex_captured ADD COLUMN affinity_last_probability REAL;",
                "ALTER TABLE dex_captured ADD COLUMN affinity_last_outcome TEXT;",
                "ALTER TABLE dex_captured ADD COLUMN affinity_updated_at TEXT;",
                """
                UPDATE dex_captured
                SET affinity_level = CASE
                        WHEN captured_count >= 25 THEN 4
                        WHEN captured_count >= 10 THEN 3
                        WHEN captured_count >= 3 THEN 2
                        ELSE 1
                    END,
                    affinity_pity_count = 0,
                    affinity_last_roll = NULL,
                    affinity_last_probability = NULL,
                    affinity_last_outcome = 'migration_seeded',
                    affinity_updated_at = COALESCE(affinity_updated_at, updated_at)
                WHERE affinity_last_outcome IS NULL
                   OR affinity_last_outcome = '';
                """,
            ]),
            SQLiteMigration(version: 16, statements: [
                "ALTER TABLE species ADD COLUMN training_trait TEXT NOT NULL DEFAULT 'trail' CHECK(training_trait IN ('trail', 'scout', 'capture', 'raider'));",
                """
                CREATE TABLE IF NOT EXISTS now_camp_state (
                    singleton_id INTEGER PRIMARY KEY NOT NULL CHECK(singleton_id = 1),
                    lead_species_id TEXT REFERENCES species(species_id),
                    focus_energy INTEGER NOT NULL DEFAULT 0 CHECK(focus_energy BETWEEN 0 AND 50),
                    focus_remainder_tokens INTEGER NOT NULL DEFAULT 0 CHECK(focus_remainder_tokens >= 0 AND focus_remainder_tokens < 50000),
                    focus_earned_local_date TEXT NOT NULL,
                    focus_earned_today INTEGER NOT NULL DEFAULT 0 CHECK(focus_earned_today >= 0),
                    save_training_seed TEXT NOT NULL,
                    updated_at TEXT NOT NULL
                );
                """,
                """
                INSERT INTO now_camp_state (
                    singleton_id,
                    lead_species_id,
                    focus_energy,
                    focus_remainder_tokens,
                    focus_earned_local_date,
                    focus_earned_today,
                    save_training_seed,
                    updated_at
                ) VALUES (
                    1,
                    (SELECT species_id FROM party_members ORDER BY slot_order ASC LIMIT 1),
                    0,
                    0,
                    date('now', 'localtime'),
                    0,
                    lower(hex(randomblob(16))),
                    strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                )
                ON CONFLICT(singleton_id) DO NOTHING;
                """,
                """
                CREATE TABLE IF NOT EXISTS species_training (
                    species_id TEXT PRIMARY KEY NOT NULL REFERENCES species(species_id) ON DELETE CASCADE,
                    training_rank INTEGER NOT NULL DEFAULT 1 CHECK(training_rank BETWEEN 1 AND 5),
                    training_resonance INTEGER NOT NULL DEFAULT 0 CHECK(training_resonance >= 0),
                    training_attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(training_attempt_count >= 0),
                    care_charge INTEGER NOT NULL DEFAULT 0 CHECK(care_charge IN (0, 1)),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                INSERT OR IGNORE INTO species_training (
                    species_id,
                    training_rank,
                    training_resonance,
                    training_attempt_count,
                    care_charge,
                    updated_at
                )
                SELECT species_id,
                       1,
                       0,
                       0,
                       0,
                       strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
                FROM dex_captured;
                """,
                "ALTER TABLE raid_member_hits ADD COLUMN training_raid_bonus INTEGER NOT NULL DEFAULT 0 CHECK(training_raid_bonus >= 0);",
                "CREATE INDEX IF NOT EXISTS idx_species_training_rank ON species_training(training_rank);",
            ]),
            SQLiteMigration(version: 17, statements: [
                """
                CREATE TABLE IF NOT EXISTS now_camp_state_v17 (
                    singleton_id INTEGER PRIMARY KEY NOT NULL CHECK(singleton_id = 1),
                    lead_species_id TEXT REFERENCES species(species_id),
                    focus_energy INTEGER NOT NULL DEFAULT 0 CHECK(focus_energy BETWEEN 0 AND 50),
                    focus_remainder_tokens INTEGER NOT NULL DEFAULT 0 CHECK(focus_remainder_tokens >= 0 AND focus_remainder_tokens < 25000),
                    focus_earned_local_date TEXT NOT NULL,
                    focus_earned_today INTEGER NOT NULL DEFAULT 0 CHECK(focus_earned_today >= 0),
                    save_training_seed TEXT NOT NULL,
                    care_ready INTEGER NOT NULL DEFAULT 0 CHECK(care_ready IN (0, 1)),
                    care_elapsed_seconds INTEGER NOT NULL DEFAULT 0 CHECK(care_elapsed_seconds BETWEEN 0 AND 3600),
                    care_focus_earned_local_date TEXT NOT NULL,
                    care_focus_earned_today INTEGER NOT NULL DEFAULT 0 CHECK(care_focus_earned_today >= 0),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                WITH normalized AS (
                    SELECT singleton_id,
                           lead_species_id,
                           focus_energy,
                           focus_remainder_tokens,
                           CASE
                               WHEN focus_earned_local_date = date('now', 'localtime') THEN focus_earned_today
                               ELSE 0
                           END AS focus_earned_today_before,
                           save_training_seed,
                           updated_at
                    FROM now_camp_state
                ),
                grants AS (
                    SELECT singleton_id,
                           lead_species_id,
                           focus_energy,
                           focus_remainder_tokens,
                           focus_earned_today_before,
                           save_training_seed,
                           updated_at,
                           CASE
                               WHEN focus_remainder_tokens >= 25000 THEN
                                   min(1, max(0, 50 - focus_energy), max(0, 120 - focus_earned_today_before))
                               ELSE 0
                           END AS focus_granted
                    FROM normalized
                )
                INSERT INTO now_camp_state_v17 (
                    singleton_id,
                    lead_species_id,
                    focus_energy,
                    focus_remainder_tokens,
                    focus_earned_local_date,
                    focus_earned_today,
                    save_training_seed,
                    care_ready,
                    care_elapsed_seconds,
                    care_focus_earned_local_date,
                    care_focus_earned_today,
                    updated_at
                )
                SELECT singleton_id,
                       lead_species_id,
                       min(focus_energy + focus_granted, 50),
                       CASE
                           WHEN focus_energy + focus_granted >= 50 THEN 0
                           ELSE focus_remainder_tokens % 25000
                       END,
                       date('now', 'localtime'),
                       focus_earned_today_before + focus_granted,
                       save_training_seed,
                       0,
                       0,
                       date('now', 'localtime'),
                       0,
                       updated_at
                FROM grants;
                """,
                "DROP TABLE now_camp_state;",
                "ALTER TABLE now_camp_state_v17 RENAME TO now_camp_state;",
                """
                CREATE TABLE IF NOT EXISTS species_training_v17 (
                    species_id TEXT PRIMARY KEY NOT NULL REFERENCES species(species_id) ON DELETE CASCADE,
                    training_rank INTEGER NOT NULL DEFAULT 1 CHECK(training_rank BETWEEN 1 AND 5),
                    training_resonance INTEGER NOT NULL DEFAULT 0 CHECK(training_resonance >= 0),
                    training_attempt_count INTEGER NOT NULL DEFAULT 0 CHECK(training_attempt_count >= 0),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                INSERT INTO species_training_v17 (
                    species_id,
                    training_rank,
                    training_resonance,
                    training_attempt_count,
                    updated_at
                )
                SELECT species_id,
                       training_rank,
                       training_resonance,
                       training_attempt_count,
                       updated_at
                FROM species_training;
                """,
                "DROP TABLE species_training;",
                "ALTER TABLE species_training_v17 RENAME TO species_training;",
                "CREATE INDEX IF NOT EXISTS idx_species_training_rank ON species_training(training_rank);",
            ]),
            SQLiteMigration(version: 18, statements: [
                """
                CREATE TABLE IF NOT EXISTS now_camp_state_v18 (
                    singleton_id INTEGER PRIMARY KEY NOT NULL CHECK(singleton_id = 1),
                    lead_species_id TEXT REFERENCES species(species_id),
                    focus_energy INTEGER NOT NULL DEFAULT 0 CHECK(focus_energy BETWEEN 0 AND 50),
                    focus_remainder_tokens INTEGER NOT NULL DEFAULT 0 CHECK(focus_remainder_tokens >= 0 AND focus_remainder_tokens < 25000),
                    focus_earned_local_date TEXT NOT NULL,
                    focus_earned_today INTEGER NOT NULL DEFAULT 0 CHECK(focus_earned_today >= 0),
                    save_training_seed TEXT NOT NULL,
                    care_ready INTEGER NOT NULL DEFAULT 0 CHECK(care_ready IN (0, 1)),
                    care_elapsed_seconds INTEGER NOT NULL DEFAULT 0 CHECK(care_elapsed_seconds BETWEEN 0 AND 3600),
                    care_focus_earned_local_date TEXT NOT NULL,
                    care_focus_earned_today INTEGER NOT NULL DEFAULT 0 CHECK(care_focus_earned_today >= 0),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                INSERT INTO now_camp_state_v18 (
                    singleton_id,
                    lead_species_id,
                    focus_energy,
                    focus_remainder_tokens,
                    focus_earned_local_date,
                    focus_earned_today,
                    save_training_seed,
                    care_ready,
                    care_elapsed_seconds,
                    care_focus_earned_local_date,
                    care_focus_earned_today,
                    updated_at
                )
                SELECT singleton_id,
                       lead_species_id,
                       min(focus_energy, 50),
                       CASE WHEN focus_energy >= 50 THEN 0 ELSE focus_remainder_tokens END,
                       focus_earned_local_date,
                       focus_earned_today,
                       save_training_seed,
                       care_ready,
                       care_elapsed_seconds,
                       care_focus_earned_local_date,
                       care_focus_earned_today,
                       updated_at
                FROM now_camp_state;
                """,
                "DROP TABLE now_camp_state;",
                "ALTER TABLE now_camp_state_v18 RENAME TO now_camp_state;",
            ]),
            SQLiteMigration(version: 19, statements: [
                """
                CREATE TABLE IF NOT EXISTS now_camp_state_v19 (
                    singleton_id INTEGER PRIMARY KEY NOT NULL CHECK(singleton_id = 1),
                    lead_species_id TEXT REFERENCES species(species_id),
                    focus_energy INTEGER NOT NULL DEFAULT 0 CHECK(focus_energy >= 0),
                    focus_remainder_tokens INTEGER NOT NULL DEFAULT 0 CHECK(focus_remainder_tokens >= 0),
                    focus_earned_local_date TEXT NOT NULL,
                    focus_earned_today INTEGER NOT NULL DEFAULT 0 CHECK(focus_earned_today >= 0),
                    save_training_seed TEXT NOT NULL,
                    care_ready INTEGER NOT NULL DEFAULT 0 CHECK(care_ready IN (0, 1)),
                    care_elapsed_seconds INTEGER NOT NULL DEFAULT 0 CHECK(care_elapsed_seconds BETWEEN 0 AND 3600),
                    care_focus_earned_local_date TEXT NOT NULL,
                    care_focus_earned_today INTEGER NOT NULL DEFAULT 0 CHECK(care_focus_earned_today >= 0),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                INSERT INTO now_camp_state_v19 (
                    singleton_id,
                    lead_species_id,
                    focus_energy,
                    focus_remainder_tokens,
                    focus_earned_local_date,
                    focus_earned_today,
                    save_training_seed,
                    care_ready,
                    care_elapsed_seconds,
                    care_focus_earned_local_date,
                    care_focus_earned_today,
                    updated_at
                )
                SELECT singleton_id,
                       lead_species_id,
                       max(focus_energy, 0),
                       0,
                       focus_earned_local_date,
                       focus_earned_today,
                       save_training_seed,
                       care_ready,
                       care_elapsed_seconds,
                       care_focus_earned_local_date,
                       care_focus_earned_today,
                       updated_at
                FROM now_camp_state;
                """,
                "DROP TABLE now_camp_state;",
                "ALTER TABLE now_camp_state_v19 RENAME TO now_camp_state;",
            ]),
            SQLiteMigration(version: 20, statements: [
                """
                CREATE TABLE IF NOT EXISTS now_camp_state_v20 (
                    singleton_id INTEGER PRIMARY KEY NOT NULL CHECK(singleton_id = 1),
                    lead_species_id TEXT REFERENCES species(species_id),
                    focus_energy INTEGER NOT NULL DEFAULT 0 CHECK(focus_energy BETWEEN 0 AND 50),
                    focus_remainder_tokens INTEGER NOT NULL DEFAULT 0 CHECK(focus_remainder_tokens >= 0),
                    focus_earned_local_date TEXT NOT NULL,
                    focus_earned_today INTEGER NOT NULL DEFAULT 0 CHECK(focus_earned_today >= 0),
                    save_training_seed TEXT NOT NULL,
                    care_ready INTEGER NOT NULL DEFAULT 0 CHECK(care_ready IN (0, 1)),
                    care_elapsed_seconds INTEGER NOT NULL DEFAULT 0 CHECK(care_elapsed_seconds BETWEEN 0 AND 3600),
                    care_focus_earned_local_date TEXT NOT NULL,
                    care_focus_earned_today INTEGER NOT NULL DEFAULT 0 CHECK(care_focus_earned_today >= 0),
                    updated_at TEXT NOT NULL
                );
                """,
                """
                INSERT INTO now_camp_state_v20 (
                    singleton_id,
                    lead_species_id,
                    focus_energy,
                    focus_remainder_tokens,
                    focus_earned_local_date,
                    focus_earned_today,
                    save_training_seed,
                    care_ready,
                    care_elapsed_seconds,
                    care_focus_earned_local_date,
                    care_focus_earned_today,
                    updated_at
                )
                SELECT singleton_id,
                       lead_species_id,
                       min(max(focus_energy, 0), 50),
                       0,
                       focus_earned_local_date,
                       focus_earned_today,
                       save_training_seed,
                       care_ready,
                       care_elapsed_seconds,
                       care_focus_earned_local_date,
                       care_focus_earned_today,
                       updated_at
                FROM now_camp_state;
                """,
                "DROP TABLE now_camp_state;",
                "ALTER TABLE now_camp_state_v20 RENAME TO now_camp_state;",
            ]),
            SQLiteMigration(version: 21, statements: [
                """
                CREATE TABLE IF NOT EXISTS achievement_badge_entries (
                    badge_id TEXT PRIMARY KEY NOT NULL,
                    status TEXT NOT NULL CHECK(status = 'unlocked'),
                    unlocked_at TEXT NOT NULL,
                    progress INTEGER NOT NULL DEFAULT 0 CHECK(progress >= 0),
                    target INTEGER NOT NULL DEFAULT 1 CHECK(target > 0),
                    updated_at TEXT NOT NULL
                );
                """,
                "CREATE INDEX IF NOT EXISTS idx_achievement_badge_status ON achievement_badge_entries(status, updated_at DESC);",
            ]),
        ]
    }
}
