import Foundation
import TokenmonDomain

public enum AchievementBadgeStatus: String, CaseIterable, Sendable {
    case locked
    case unlocked
}

public enum AchievementBadgeCategory: String, CaseIterable, Sendable {
    case start
    case field
    case dex
    case camp
    case raidUsage = "raid_usage"
}

public enum AchievementBadgeRequirement: Equatable, Sendable {
    case totalSeen(Int64)
    case totalCaptured(Int64)
    case capturedRarity(RarityTier, Int64)
    case capturedField(FieldType, Int64)
    case partySize(Int64)
    case leadSelected
    case careClaimed
    case trainingRank(Int64)
    case affinityLevel(Int64)
    case raidAttackCount(Int64)
    case raidClearCount(Int64)
    case raidRewardAcquiredCount(Int64)
    case liveUsageSamples(Int64)

    var target: Int64 {
        switch self {
        case .leadSelected, .careClaimed:
            return 1
        case .totalSeen(let target),
             .totalCaptured(let target),
             .capturedRarity(_, let target),
             .capturedField(_, let target),
             .partySize(let target),
             .trainingRank(let target),
             .affinityLevel(let target),
             .raidAttackCount(let target),
             .raidClearCount(let target),
             .raidRewardAcquiredCount(let target),
             .liveUsageSamples(let target):
            return target
        }
    }
}

public struct AchievementBadgeDefinition: Equatable, Sendable {
    public let badgeID: String
    public let titleKey: String
    public let descriptionKey: String
    public let category: AchievementBadgeCategory
    public let artKey: String
    public let requirement: AchievementBadgeRequirement

    public var target: Int64 {
        requirement.target
    }
}

public struct AchievementBadgeSummary: Equatable, Sendable {
    public let badgeID: String
    public let titleKey: String
    public let descriptionKey: String
    public let category: AchievementBadgeCategory
    public let artKey: String
    public let status: AchievementBadgeStatus
    public let progress: Int64
    public let target: Int64
    public let unlockedAt: String?

    public var isUnlocked: Bool {
        status == .unlocked
    }
}

public enum AchievementCatalog {
    public static let allBadges: [AchievementBadgeDefinition] = [
        badge("badge_first_seen", .start, "achievement_first_seen", .totalSeen(1)),
        badge("badge_first_capture", .start, "achievement_first_capture", .totalCaptured(1)),
        badge("badge_common_capture", .start, "achievement_common_capture", .capturedRarity(.common, 1)),
        badge("badge_uncommon_capture", .start, "achievement_uncommon_capture", .capturedRarity(.uncommon, 1)),
        badge("badge_rare_capture", .start, "achievement_rare_capture", .capturedRarity(.rare, 1)),
        badge("badge_epic_capture", .start, "achievement_epic_capture", .capturedRarity(.epic, 1)),
        badge("badge_legendary_capture", .start, "achievement_legendary_capture", .capturedRarity(.legendary, 1)),

        badge("badge_grassland_first_capture", .field, "achievement_grassland_first_capture", .capturedField(.grassland, 1)),
        badge("badge_ice_first_capture", .field, "achievement_ice_first_capture", .capturedField(.ice, 1)),
        badge("badge_coast_first_capture", .field, "achievement_coast_first_capture", .capturedField(.coast, 1)),
        badge("badge_sky_first_capture", .field, "achievement_sky_first_capture", .capturedField(.sky, 1)),
        badge("badge_grassland_collector_10", .field, "achievement_grassland_collector_10", .capturedField(.grassland, 10)),
        badge("badge_ice_collector_10", .field, "achievement_ice_collector_10", .capturedField(.ice, 10)),
        badge("badge_coast_collector_10", .field, "achievement_coast_collector_10", .capturedField(.coast, 10)),
        badge("badge_sky_collector_10", .field, "achievement_sky_collector_10", .capturedField(.sky, 10)),

        badge("badge_seen_10", .dex, "achievement_seen_10", .totalSeen(10)),
        badge("badge_seen_50", .dex, "achievement_seen_50", .totalSeen(50)),
        badge("badge_seen_100", .dex, "achievement_seen_100", .totalSeen(100)),
        badge("badge_seen_complete", .dex, "achievement_seen_complete", .totalSeen(151)),
        badge("badge_captured_10", .dex, "achievement_captured_10", .totalCaptured(10)),
        badge("badge_captured_50", .dex, "achievement_captured_50", .totalCaptured(50)),
        badge("badge_captured_100", .dex, "achievement_captured_100", .totalCaptured(100)),
        badge("badge_captured_complete", .dex, "achievement_captured_complete", .totalCaptured(151)),

        badge("badge_party_first_member", .camp, "achievement_party_first_member", .partySize(1)),
        badge("badge_party_five", .camp, "achievement_party_five", .partySize(5)),
        badge("badge_party_full", .camp, "achievement_party_full", .partySize(10)),
        badge("badge_lead_selected", .camp, "achievement_lead_selected", .leadSelected),
        badge("badge_care_claimed", .camp, "achievement_care_claimed", .careClaimed),
        badge("badge_training_rank_ii", .camp, "achievement_training_rank_ii", .trainingRank(2)),
        badge("badge_training_rank_v", .camp, "achievement_training_rank_v", .trainingRank(5)),

        badge("badge_affinity_level_3", .raidUsage, "achievement_affinity_level_3", .affinityLevel(3)),
        badge("badge_affinity_level_5", .raidUsage, "achievement_affinity_level_5", .affinityLevel(5)),
        badge("badge_first_raid_attack", .raidUsage, "achievement_first_raid_attack", .raidAttackCount(1)),
        badge("badge_first_raid_clear", .raidUsage, "achievement_first_raid_clear", .raidClearCount(1)),
        badge("badge_first_raid_reward", .raidUsage, "achievement_first_raid_reward", .raidRewardAcquiredCount(1)),
        badge("badge_live_usage_100", .raidUsage, "achievement_live_usage_100", .liveUsageSamples(100)),
    ]

    private static func badge(
        _ badgeID: String,
        _ category: AchievementBadgeCategory,
        _ artKey: String,
        _ requirement: AchievementBadgeRequirement
    ) -> AchievementBadgeDefinition {
        AchievementBadgeDefinition(
            badgeID: badgeID,
            titleKey: "achievement.\(badgeID).title",
            descriptionKey: "achievement.\(badgeID).description",
            category: category,
            artKey: artKey,
            requirement: requirement
        )
    }
}

struct AchievementBadgeUnlockedEventPayload: Codable, Equatable, Sendable {
    let badgeID: String
    let category: String
    let progress: Int64
    let target: Int64

    enum CodingKeys: String, CodingKey {
        case badgeID = "badge_id"
        case category
        case progress
        case target
    }
}

public extension TokenmonDatabaseManager {
    @discardableResult
    func evaluateAchievementBadges(
        database providedDatabase: SQLiteDatabase? = nil,
        occurredAt: String = ISO8601DateFormatter().string(from: Date())
    ) throws -> [AchievementBadgeSummary] {
        let database = try providedDatabase ?? open()
        let unlocked = try unlockedAchievementBadges(database: database)

        for definition in AchievementCatalog.allBadges {
            let progress = try achievementProgress(for: definition.requirement, database: database)
            let target = definition.target
            if unlocked[definition.badgeID] == nil, progress >= target {
                try unlockAchievementBadge(
                    definition,
                    progress: progress,
                    target: target,
                    occurredAt: occurredAt,
                    database: database
                )
            }
        }

        return try achievementBadgeSummaries(database: database)
    }

    func achievementBadgeSummaries(database providedDatabase: SQLiteDatabase? = nil) throws -> [AchievementBadgeSummary] {
        let database = try providedDatabase ?? open()
        let unlocked = try unlockedAchievementBadges(database: database)
        return try AchievementCatalog.allBadges.map { definition in
            let progress = try achievementProgress(for: definition.requirement, database: database)
            let unlockedAt = unlocked[definition.badgeID]
            return AchievementBadgeSummary(
                badgeID: definition.badgeID,
                titleKey: definition.titleKey,
                descriptionKey: definition.descriptionKey,
                category: definition.category,
                artKey: definition.artKey,
                status: unlockedAt == nil ? .locked : .unlocked,
                progress: min(progress, definition.target),
                target: definition.target,
                unlockedAt: unlockedAt
            )
        }
    }
}

private extension TokenmonDatabaseManager {
    func unlockedAchievementBadges(database: SQLiteDatabase) throws -> [String: String] {
        let rows: [(String, String)] = try database.fetchAll(
            """
            SELECT badge_id, unlocked_at
            FROM achievement_badge_entries
            WHERE status = 'unlocked';
            """
        ) { statement in
            (
                SQLiteDatabase.columnText(statement, index: 0),
                SQLiteDatabase.columnText(statement, index: 1)
            )
        }
        return Dictionary(uniqueKeysWithValues: rows)
    }

    func unlockAchievementBadge(
        _ definition: AchievementBadgeDefinition,
        progress: Int64,
        target: Int64,
        occurredAt: String,
        database: SQLiteDatabase
    ) throws {
        try database.execute(
            """
            INSERT OR IGNORE INTO achievement_badge_entries (
                badge_id,
                status,
                unlocked_at,
                progress,
                target,
                updated_at
            ) VALUES (?, 'unlocked', ?, ?, ?, ?);
            """,
            bindings: [
                .text(definition.badgeID),
                .text(occurredAt),
                .integer(progress),
                .integer(target),
                .text(occurredAt),
            ]
        )

        guard database.changes() > 0 else {
            return
        }

        try DomainEventStore.persist(
            database: database,
            envelope: DomainEventEnvelope(
                eventID: "\(TokenmonDomainEventType.achievementBadgeUnlocked.rawValue):\(definition.badgeID)",
                eventType: TokenmonDomainEventType.achievementBadgeUnlocked.rawValue,
                occurredAt: occurredAt,
                producer: "TokenmonPersistence.AchievementStore",
                aggregateType: "achievement_badge",
                aggregateID: definition.badgeID,
                payload: AchievementBadgeUnlockedEventPayload(
                    badgeID: definition.badgeID,
                    category: definition.category.rawValue,
                    progress: progress,
                    target: target
                )
            )
        )
    }

    func achievementProgress(for requirement: AchievementBadgeRequirement, database: SQLiteDatabase) throws -> Int64 {
        switch requirement {
        case .totalSeen:
            return try count("SELECT COUNT(*) FROM dex_seen;", database: database)
        case .totalCaptured:
            return try count("SELECT COUNT(*) FROM dex_captured;", database: database)
        case .capturedRarity(let rarity, _):
            return try count(
                """
                SELECT COUNT(*)
                FROM dex_captured
                INNER JOIN species ON species.species_id = dex_captured.species_id
                WHERE species.rarity_tier = ?;
                """,
                bindings: [.text(rarity.rawValue)],
                database: database
            )
        case .capturedField(let field, _):
            return try count(
                """
                SELECT COUNT(*)
                FROM dex_captured
                INNER JOIN species ON species.species_id = dex_captured.species_id
                WHERE species.field_code = ?;
                """,
                bindings: [.text(field.rawValue)],
                database: database
            )
        case .partySize:
            return try count("SELECT COUNT(*) FROM party_members;", database: database)
        case .leadSelected:
            return try count(
                """
                SELECT
                    (SELECT COUNT(*) FROM now_camp_state WHERE lead_species_id IS NOT NULL)
                    + (SELECT COUNT(*) FROM domain_events WHERE event_type = 'now_camp_lead_selected');
                """,
                database: database
            )
        case .careClaimed:
            return try count(
                "SELECT COUNT(*) FROM domain_events WHERE event_type = 'lead_care_claimed';",
                database: database
            )
        case .trainingRank:
            return try count(
                "SELECT COALESCE(MAX(training_rank), 0) FROM species_training;",
                database: database
            )
        case .affinityLevel:
            return try count(
                "SELECT COALESCE(MAX(affinity_level), 0) FROM dex_captured;",
                database: database
            )
        case .raidAttackCount:
            return try count("SELECT COUNT(*) FROM raid_attacks;", database: database)
        case .raidClearCount:
            return try count("SELECT COUNT(*) FROM raid_instances WHERE status = 'cleared';", database: database)
        case .raidRewardAcquiredCount:
            return try count(
                "SELECT COUNT(*) FROM reward_archive_entries WHERE status = 'acquired';",
                database: database
            )
        case .liveUsageSamples:
            return try count(
                """
                SELECT COUNT(*)
                FROM usage_samples
                WHERE gameplay_eligibility = 'eligible_live'
                  AND gameplay_delta_tokens > 0;
                """,
                database: database
            )
        }
    }

    func count(_ sql: String, bindings: [SQLiteValue] = [], database: SQLiteDatabase) throws -> Int64 {
        try database.fetchOne(sql, bindings: bindings) { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0
    }
}
