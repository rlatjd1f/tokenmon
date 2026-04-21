import Foundation
import TokenmonProviders

public struct AccountUsageIngestionResult: Sendable {
    public let acceptedEvents: Int
    public let duplicateEvents: Int
    public let rejectedEvents: Int
    public let partialTrailingLines: Int
    public let accountUsageSamplesCreated: Int
    public let sourceKey: String
}

public final class AccountUsageIngestionService {
    private let databaseManager: TokenmonDatabaseManager

    public init(databasePath: String) {
        databaseManager = TokenmonDatabaseManager(path: databasePath)
    }

    public func ingestAccountUsageFile(
        at path: String,
        sourceKey: String? = nil
    ) throws -> AccountUsageIngestionResult {
        let database = try databaseManager.open()
        let resolvedSourceKey = sourceKey ?? "account-usage:\(URL(fileURLWithPath: path).path)"
        let readResult = try ProviderInboxReader.read(from: path)
        let decoder = JSONDecoder()

        var acceptedEvents = 0
        var duplicateEvents = 0
        var rejectedEvents = 0
        var partialTrailingLines = 0

        for line in readResult.lines {
            let trimmed = line.rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                continue
            }

            let event: AccountUsageSampleEvent
            do {
                event = try decoder.decode(AccountUsageSampleEvent.self, from: Data(trimmed.utf8))
                try event.validate()
            } catch {
                if !line.newlineTerminated {
                    partialTrailingLines += 1
                    break
                }
                rejectedEvents += 1
                continue
            }

            switch try ingestValidatedEvent(database: database, event: event, rawPayload: trimmed) {
            case .accepted:
                acceptedEvents += 1
            case .duplicate:
                duplicateEvents += 1
            }
        }

        return AccountUsageIngestionResult(
            acceptedEvents: acceptedEvents,
            duplicateEvents: duplicateEvents,
            rejectedEvents: rejectedEvents,
            partialTrailingLines: partialTrailingLines,
            accountUsageSamplesCreated: acceptedEvents,
            sourceKey: resolvedSourceKey
        )
    }

    public func ingestAccountUsageEvents(
        _ events: [AccountUsageSampleEvent],
        sourceKey: String
    ) throws -> AccountUsageIngestionResult {
        let database = try databaseManager.open()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var acceptedEvents = 0
        var duplicateEvents = 0
        var rejectedEvents = 0

        for event in events {
            do {
                try event.validate()
                let rawPayload = String(decoding: try encoder.encode(event), as: UTF8.self)
                switch try ingestValidatedEvent(database: database, event: event, rawPayload: rawPayload) {
                case .accepted:
                    acceptedEvents += 1
                case .duplicate:
                    duplicateEvents += 1
                }
            } catch {
                rejectedEvents += 1
            }
        }

        return AccountUsageIngestionResult(
            acceptedEvents: acceptedEvents,
            duplicateEvents: duplicateEvents,
            rejectedEvents: rejectedEvents,
            partialTrailingLines: 0,
            accountUsageSamplesCreated: acceptedEvents,
            sourceKey: sourceKey
        )
    }

    private enum AccountUsageDisposition {
        case accepted
        case duplicate
    }

    private func ingestValidatedEvent(
        database: SQLiteDatabase,
        event: AccountUsageSampleEvent,
        rawPayload: String
    ) throws -> AccountUsageDisposition {
        try databaseManager.ensureProviderRegistered(event.provider, database: database)

        if try accountUsageFingerprintExists(database: database, fingerprint: event.providerEventFingerprint) {
            return .duplicate
        }

        try database.execute(
            """
            INSERT INTO account_usage_samples (
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
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .text(event.provider.rawValue),
                .text(event.sourceMode),
                .text(event.observedAt),
                event.modelSlug.map(SQLiteValue.text) ?? .null,
                .text(event.usageKind),
                .integer(event.inputTokens),
                .integer(event.outputTokens),
                .integer(event.cachedInputTokens),
                .integer(event.normalizedDeltaTokens),
                .text(event.providerEventFingerprint),
                .text(event.rawReference.kind),
                event.rawReference.eventName.map(SQLiteValue.text) ?? .null,
                event.rawReference.offset.map(SQLiteValue.text) ?? .null,
                .text(rawPayload),
                .text(ISO8601DateFormatter().string(from: Date())),
            ]
        )

        return .accepted
    }

    private func accountUsageFingerprintExists(
        database: SQLiteDatabase,
        fingerprint: String
    ) throws -> Bool {
        let match = try database.fetchOne(
            """
            SELECT account_usage_sample_id
            FROM account_usage_samples
            WHERE provider_event_fingerprint = ?
            LIMIT 1;
            """,
            bindings: [.text(fingerprint)]
        ) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        }
        return match != nil
    }
}
