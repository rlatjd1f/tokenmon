import Foundation
import TokenmonDomain
import TokenmonGameEngine

public struct RaidRewardSummary: Equatable, Sendable {
    public let rewardID: String
    public let title: String
    public let type: RaidRewardType
    public let artKey: String
    public let status: RaidRewardArchiveStatus
    public let acquiredAt: String?
    public let missedAt: String?
}

public struct RaidMemberHitSummary: Equatable, Sendable {
    public let speciesID: String
    public let displayName: String
    public let assetKey: String
    public let slotOrder: Int
    public let baseHitPower: Int
    public let trainingRaidBonus: Int
    public let rollOutcome: RaidHitRollOutcome
    public let hitPower: Int
}

public struct RaidAttackSummary: Equatable, Sendable {
    public let attackID: Int64
    public let occurredAt: String
    public let partySize: Int
    public let totalDamage: Int
    public let missCount: Int
    public let criticalCount: Int
    public let memberHits: [RaidMemberHitSummary]
}

public struct RaidBlessingSummary: Equatable, Sendable {
    public let id: String
    public let damageMultiplier: Double
    public let minimumTotalDamage: Int
}

public struct RaidProgressSummary: Equatable, Sendable {
    public let raidID: String
    public let title: String
    public let targetName: String
    public let targetArtKey: String
    public let raidField: FieldType
    public let availabilityKind: RaidAvailabilityKind
    public let activeStartAt: String?
    public let activeEndAt: String?
    public let status: RaidInstanceStatus
    public let currentHP: Int64
    public let maxHP: Int64
    public let totalAttacks: Int64
    public let totalDamage: Int64
    public let partyPower: Int
    public let fieldMatchCount: Int
    public let fieldSynergyMultiplier: Double
    public let activeBlessing: RaidBlessingSummary?
    public let rewards: [RaidRewardSummary]
    public let recentAttacks: [RaidAttackSummary]

    public var progressFraction: Double {
        guard maxHP > 0 else { return 0 }
        return min(1, max(0, Double(maxHP - currentHP) / Double(maxHP)))
    }
}

public struct RaidArchiveEntrySummary: Equatable, Sendable {
    public let rewardID: String
    public let title: String
    public let type: RaidRewardType
    public let artKey: String
    public let status: RaidRewardArchiveStatus
    public let sourceRaidID: String
    public let sourceRaidTitle: String
    public let sourceRaidTargetName: String
    public let sourceRaidTargetArtKey: String
    public let activeStartAt: String?
    public let activeEndAt: String?
    public let acquiredAt: String?
    public let missedAt: String?
}

public struct RaidDashboardSummary: Equatable, Sendable {
    public let currentRaid: RaidProgressSummary?
    public let archiveEntries: [RaidArchiveEntrySummary]
    public let partyMembers: [PartyMemberSummary]
}

struct RaidAttackTriggeredEventPayload: Codable, Equatable, Sendable {
    let raidID: String
    let raidInstanceID: Int64
    let usageSampleID: Int64
    let partySize: Int
    let unmodifiedTotalDamage: Int
    let fieldMatchCount: Int
    let fieldSynergyMultiplier: Double
    let totalDamage: Int
    let damageBlessingID: String?
    let damageBlessingMultiplier: Double?
    let damageBlessingMinimumTotalDamage: Int?

    enum CodingKeys: String, CodingKey {
        case raidID = "raid_id"
        case raidInstanceID = "raid_instance_id"
        case usageSampleID = "usage_sample_id"
        case partySize = "party_size"
        case unmodifiedTotalDamage = "unmodified_total_damage"
        case fieldMatchCount = "field_match_count"
        case fieldSynergyMultiplier = "field_synergy_multiplier"
        case totalDamage = "total_damage"
        case damageBlessingID = "damage_blessing_id"
        case damageBlessingMultiplier = "damage_blessing_multiplier"
        case damageBlessingMinimumTotalDamage = "damage_blessing_minimum_total_damage"
    }
}

struct RaidMemberHitResolvedEventPayload: Codable, Equatable, Sendable {
    let raidID: String
    let usageSampleID: Int64
    let speciesID: String
    let slotOrder: Int
    let axisScore: Double
    let roleFitBonus: Int
    let fieldFitBonus: Int
    let traitFitBonus: Int
    let captureBondBonus: Int
    let trainingRaidBonus: Int
    let hitPower: Int

    enum CodingKeys: String, CodingKey {
        case raidID = "raid_id"
        case usageSampleID = "usage_sample_id"
        case speciesID = "species_id"
        case slotOrder = "slot_order"
        case axisScore = "axis_score"
        case roleFitBonus = "role_fit_bonus"
        case fieldFitBonus = "field_fit_bonus"
        case traitFitBonus = "trait_fit_bonus"
        case captureBondBonus = "capture_bond_bonus"
        case trainingRaidBonus = "training_raid_bonus"
        case hitPower = "hit_power"
    }
}

struct RaidProgressUpdatedEventPayload: Codable, Equatable, Sendable {
    let raidID: String
    let usageSampleID: Int64
    let currentHPBefore: Int64
    let currentHPAfter: Int64
    let totalDamage: Int

    enum CodingKeys: String, CodingKey {
        case raidID = "raid_id"
        case usageSampleID = "usage_sample_id"
        case currentHPBefore = "current_hp_before"
        case currentHPAfter = "current_hp_after"
        case totalDamage = "total_damage"
    }
}

struct RaidClearedEventPayload: Codable, Equatable, Sendable {
    let raidID: String
    let raidInstanceID: Int64
    let usageSampleID: Int64
    let totalAttacks: Int64
    let totalDamage: Int64

    enum CodingKeys: String, CodingKey {
        case raidID = "raid_id"
        case raidInstanceID = "raid_instance_id"
        case usageSampleID = "usage_sample_id"
        case totalAttacks = "total_attacks"
        case totalDamage = "total_damage"
    }
}

struct RaidExpiredEventPayload: Codable, Equatable, Sendable {
    let raidID: String
    let raidInstanceID: Int64
    let totalAttacks: Int64
    let totalDamage: Int64

    enum CodingKeys: String, CodingKey {
        case raidID = "raid_id"
        case raidInstanceID = "raid_instance_id"
        case totalAttacks = "total_attacks"
        case totalDamage = "total_damage"
    }
}

struct RaidRewardArchiveEventPayload: Codable, Equatable, Sendable {
    let rewardID: String
    let raidID: String
    let rewardType: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case rewardID = "reward_id"
        case raidID = "raid_id"
        case rewardType = "reward_type"
        case status
    }
}

private struct RaidInstanceRecord: Equatable {
    let rowID: Int64
    let raidID: String
    let status: RaidInstanceStatus
    let currentHP: Int64
    let totalAttacks: Int64
    let totalDamage: Int64
}

public extension TokenmonDatabaseManager {
    func raidDashboardSummary(asOf reference: Date = Date(), database providedDatabase: SQLiteDatabase? = nil) throws -> RaidDashboardSummary {
        let database = try providedDatabase ?? open()
        try settleExpiredRaids(database: database, asOf: reference)

        let partyMembers = try partyMembers(database: database)
        let currentRaid = try currentDisplayRaid(database: database, asOf: reference).map { raid in
            let instance = try ensureRaidInstance(database: database, raid: raid, status: .active, at: reference)
            return try raidProgressSummary(
                database: database,
                raid: raid,
                instance: instance,
                partyMembers: partyMembers,
                asOf: reference
            )
        }

        return RaidDashboardSummary(
            currentRaid: currentRaid,
            archiveEntries: try rewardArchiveEntries(database: database, asOf: reference),
            partyMembers: partyMembers
        )
    }

    @discardableResult
    func processRaidAttackForUsageSample(
        database: SQLiteDatabase,
        usageSampleID: Int64,
        observedAt: String,
        correlationID: String?
    ) throws -> RaidAttackSummary? {
        guard let observedDate = Self.raidDate(from: observedAt),
              let raid = try currentAttackableRaid(database: database, at: observedDate)
        else {
            return nil
        }

        try settleExpiredRaids(database: database, asOf: observedDate)
        let instance = try ensureRaidInstance(database: database, raid: raid, status: .active, at: observedDate)
        guard instance.status != .cleared, instance.status != .expired, instance.status != .missed else {
            return nil
        }
        guard try raidAttackExists(database: database, raidInstanceID: instance.rowID, usageSampleID: usageSampleID) == false else {
            return nil
        }

        let partyMembers = try raidPartyMembers(database: database)
        let damageBlessing = try activeRaidDamageBlessing(
            database: database,
            raid: raid,
            partyMembers: partyMembers,
            at: observedDate
        )
        let resolution = RaidDamageCalculator.resolveAttack(
            raid: raid,
            partyMembers: partyMembers,
            usageSampleID: usageSampleID,
            damageBlessing: damageBlessing
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let partySnapshotJSON = String(decoding: try encoder.encode(partyMembers), as: UTF8.self)
        let now = ISO8601DateFormatter().string(from: Date())

        try database.execute(
            """
            INSERT INTO raid_attacks (
                raid_instance_id,
                raid_id,
                usage_sample_id,
                occurred_at,
                party_snapshot_json,
                party_size,
                total_damage,
                created_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """,
            bindings: [
                .integer(instance.rowID),
                .text(raid.raidID),
                .integer(usageSampleID),
                .text(observedAt),
                .text(partySnapshotJSON),
                .integer(Int64(partyMembers.count)),
                .integer(Int64(resolution.totalDamage)),
                .text(now),
            ]
        )
        let attackID = database.lastInsertRowID()

        for hit in resolution.memberHits {
            let statsJSON = String(decoding: try encoder.encode(hit.member.stats), as: UTF8.self)
            try database.execute(
                """
                INSERT INTO raid_member_hits (
                    raid_attack_row_id,
                    species_id,
                    slot_order,
                    field_code,
                    rarity_tier,
                    axis_score,
                    role_fit_bonus,
                    field_fit_bonus,
                    trait_fit_bonus,
                    capture_bond_bonus,
                    training_raid_bonus,
                    hit_power,
                    stats_json
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                bindings: [
                    .integer(attackID),
                    .text(hit.member.speciesID),
                    .integer(Int64(hit.member.slotOrder)),
                    .text(hit.member.field.rawValue),
                    .text(hit.member.rarity.rawValue),
                    .double(hit.axisScore),
                    .integer(Int64(hit.roleFitBonus)),
                    .integer(Int64(hit.fieldFitBonus)),
                    .integer(Int64(hit.traitFitBonus)),
                    .integer(Int64(hit.captureBondBonus)),
                    .integer(Int64(hit.trainingRaidBonus)),
                    .integer(Int64(hit.hitPower)),
                    .text(statsJSON),
                ]
            )
        }

        let currentHPAfter = max(0, instance.currentHP - Int64(resolution.totalDamage))
        let cleared = currentHPAfter == 0 && instance.currentHP > 0
        let nextStatus: RaidInstanceStatus = cleared ? .cleared : .active
        try database.execute(
            """
            UPDATE raid_instances
            SET status = ?,
                current_hp = ?,
                total_attacks = total_attacks + 1,
                total_damage = total_damage + ?,
                started_at = COALESCE(started_at, ?),
                cleared_at = CASE WHEN ? = 1 THEN ? ELSE cleared_at END,
                updated_at = ?
            WHERE raid_instance_id = ?;
            """,
            bindings: [
                .text(nextStatus.rawValue),
                .integer(currentHPAfter),
                .integer(Int64(resolution.totalDamage)),
                .text(observedAt),
                .integer(cleared ? 1 : 0),
                .text(observedAt),
                .text(now),
                .integer(instance.rowID),
            ]
        )

        try persistRaidAttackEvents(
            database: database,
            raid: raid,
            instance: instance,
            usageSampleID: usageSampleID,
            observedAt: observedAt,
            correlationID: correlationID,
            attackID: attackID,
            resolution: resolution,
            currentHPBefore: instance.currentHP,
            currentHPAfter: currentHPAfter
        )

        if cleared {
            try acquireClearRewards(
                database: database,
                raid: raid,
                instanceID: instance.rowID,
                usageSampleID: usageSampleID,
                occurredAt: observedAt,
                correlationID: correlationID
            )
        }
        try evaluateAchievementBadges(database: database, occurredAt: observedAt)

        return RaidAttackSummary(
            attackID: attackID,
            occurredAt: observedAt,
            partySize: partyMembers.count,
            totalDamage: resolution.totalDamage,
            missCount: resolution.memberHits.filter { $0.rollOutcome == .miss }.count,
            criticalCount: resolution.memberHits.filter { $0.rollOutcome == .critical }.count,
            memberHits: resolution.memberHits.map { hit in
                RaidMemberHitSummary(
                    speciesID: hit.member.speciesID,
                    displayName: hit.member.displayName,
                    assetKey: hit.member.assetKey,
                    slotOrder: hit.member.slotOrder,
                    baseHitPower: hit.baseHitPower,
                    trainingRaidBonus: hit.trainingRaidBonus,
                    rollOutcome: hit.rollOutcome,
                    hitPower: hit.hitPower
                )
            }
        )
    }
}

private extension TokenmonDatabaseManager {
    static let firstSparkBlessingDuration: TimeInterval = 14 * 24 * 60 * 60

    static let firstSparkBlessing = RaidDamageBlessing(
        id: "first_spark_blessing",
        damageMultiplier: 3.0,
        minimumTotalDamage: 120
    )

    static func raidDate(from rawValue: String) -> Date? {
        let precise = ISO8601DateFormatter()
        precise.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        return precise.date(from: rawValue) ?? standard.date(from: rawValue)
    }

    static func raidString(from date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    func currentDisplayRaid(database: SQLiteDatabase, asOf reference: Date) throws -> RaidDefinition? {
        let raids = try raidDefinitions(database: database)
        for scheduled in raids
            .filter({ $0.availabilityKind == .scheduled && isActive($0, at: reference) })
            .sorted(by: raidPrioritySort)
        {
            let instance = try ensureRaidInstance(database: database, raid: scheduled, status: .active, at: reference)
            if instance.status == .active || instance.status == .upcoming {
                return scheduled
            }
        }

        for tutorial in raids.filter({ $0.availabilityKind == .tutorialAlways }).sorted(by: tutorialRaidPrioritySort) {
            let instance = try ensureRaidInstance(database: database, raid: tutorial, status: .active, at: reference)
            if instance.status != .cleared, instance.status != .expired, instance.status != .missed {
                return tutorial
            }
        }

        return raids
            .filter { $0.availabilityKind == .scheduled }
            .sorted(by: raidPrioritySort)
            .first
    }

    func currentAttackableRaid(database: SQLiteDatabase, at observedDate: Date) throws -> RaidDefinition? {
        let raids = try raidDefinitions(database: database)

        for raid in raids
            .filter({ $0.availabilityKind == .scheduled && isActive($0, at: observedDate) })
            .sorted(by: raidPrioritySort)
        {
            let instance = try ensureRaidInstance(database: database, raid: raid, status: .active, at: observedDate)
            if instance.status == .active || instance.status == .upcoming {
                return raid
            }
        }

        for tutorial in raids.filter({ $0.availabilityKind == .tutorialAlways }).sorted(by: tutorialRaidPrioritySort) {
            let instance = try ensureRaidInstance(database: database, raid: tutorial, status: .active, at: observedDate)
            if instance.status != .cleared, instance.status != .expired, instance.status != .missed {
                return tutorial
            }
        }

        return nil
    }

    func raidPrioritySort(_ lhs: RaidDefinition, _ rhs: RaidDefinition) -> Bool {
        (lhs.activeStartAt ?? "") > (rhs.activeStartAt ?? "")
    }

    func tutorialRaidPrioritySort(_ lhs: RaidDefinition, _ rhs: RaidDefinition) -> Bool {
        let leftRank = lhs.difficultyTier == .small ? 0 : 1
        let rightRank = rhs.difficultyTier == .small ? 0 : 1
        return leftRank == rightRank ? lhs.raidID < rhs.raidID : leftRank < rightRank
    }

    func isActive(_ raid: RaidDefinition, at date: Date) -> Bool {
        switch raid.availabilityKind {
        case .tutorialAlways:
            return true
        case .scheduled:
            guard let start = raid.activeStartAt.flatMap(Self.raidDate),
                  let end = raid.activeEndAt.flatMap(Self.raidDate)
            else {
                return false
            }
            return date >= start && date <= end
        }
    }

    func isExpired(_ raid: RaidDefinition, asOf date: Date) -> Bool {
        guard raid.availabilityKind == .scheduled,
              let end = raid.activeEndAt.flatMap(Self.raidDate)
        else {
            return false
        }
        return date > end.addingTimeInterval(TimeInterval(raid.settlementGraceSeconds))
    }

    func raidDefinitions(database: SQLiteDatabase) throws -> [RaidDefinition] {
        let sql = """
        SELECT raid_id,
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
               difficulty_tier
        FROM raid_definitions
        ORDER BY availability_kind DESC, active_start_at DESC, raid_id ASC;
        """
        let decoder = JSONDecoder()
        return try database.fetchAll(sql) { statement in
            let fieldRaw = SQLiteDatabase.columnText(statement, index: 4)
            let availabilityRaw = SQLiteDatabase.columnText(statement, index: 5)
            let difficultyRaw = SQLiteDatabase.columnText(statement, index: 13)
            guard let field = FieldType(rawValue: fieldRaw),
                  let availability = RaidAvailabilityKind(rawValue: availabilityRaw),
                  let difficulty = RaidDifficultyTier(rawValue: difficultyRaw)
            else {
                throw SQLiteError.statementFailed(message: "invalid raid definition row", sql: sql)
            }

            let axisWeights = try decoder.decode(
                RaidAxisWeights.self,
                from: Data(SQLiteDatabase.columnText(statement, index: 10).utf8)
            )
            let preferredTraits = try decoder.decode(
                [String].self,
                from: Data(SQLiteDatabase.columnText(statement, index: 11).utf8)
            )
            let rewardIDs = try decoder.decode(
                [String].self,
                from: Data(SQLiteDatabase.columnText(statement, index: 12).utf8)
            )

            return RaidDefinition(
                raidID: SQLiteDatabase.columnText(statement, index: 0),
                title: SQLiteDatabase.columnText(statement, index: 1),
                targetName: SQLiteDatabase.columnText(statement, index: 2),
                targetArtKey: SQLiteDatabase.columnText(statement, index: 3),
                raidField: field,
                availabilityKind: availability,
                activeStartAt: SQLiteDatabase.columnOptionalText(statement, index: 6),
                activeEndAt: SQLiteDatabase.columnOptionalText(statement, index: 7),
                settlementGraceSeconds: Int(SQLiteDatabase.columnInt64(statement, index: 8)),
                maxHP: SQLiteDatabase.columnInt64(statement, index: 9),
                axisWeights: axisWeights,
                preferredTraitTags: preferredTraits,
                difficultyTier: difficulty,
                rewardIDs: rewardIDs
            )
        }
    }

    func raidPartyMembers(database: SQLiteDatabase) throws -> [RaidPartyMember] {
        try partyMembers(database: database).map { member in
            RaidPartyMember(
                speciesID: member.speciesID,
                assetKey: member.assetKey,
                displayName: member.displayName,
                field: member.field,
                rarity: member.rarity,
                slotOrder: member.slotOrder,
                capturedCount: member.capturedCount,
                affinityLevel: member.affinityLevel,
                trainingTrait: member.trainingTrait,
                trainingRank: member.trainingRank,
                stats: member.stats
            )
        }
    }

    func partyMembers(database: SQLiteDatabase) throws -> [PartyMemberSummary] {
        try partyMemberSummaries(database: database)
    }

    func ensureRaidInstance(
        database: SQLiteDatabase,
        raid: RaidDefinition,
        status: RaidInstanceStatus,
        at date: Date
    ) throws -> RaidInstanceRecord {
        let now = Self.raidString(from: date)
        try database.execute(
            """
            INSERT OR IGNORE INTO raid_instances (
                raid_id,
                status,
                current_hp,
                total_attacks,
                total_damage,
                first_seen_at,
                started_at,
                updated_at
            ) VALUES (?, ?, ?, 0, 0, ?, ?, ?);
            """,
            bindings: [
                .text(raid.raidID),
                .text(status.rawValue),
                .integer(raid.maxHP),
                .text(now),
                status == .active ? .text(now) : .null,
                .text(now),
            ]
        )
        try reconcileRaidInstanceHPWithDefinition(database: database, raid: raid, at: date)

        guard let instance = try raidInstance(database: database, raidID: raid.raidID) else {
            throw SQLiteError.statementFailed(message: "missing raid instance after insert", sql: "SELECT ... FROM raid_instances")
        }
        return instance
    }

    func reconcileRaidInstanceHPWithDefinition(
        database: SQLiteDatabase,
        raid: RaidDefinition,
        at date: Date
    ) throws {
        let now = Self.raidString(from: date)
        let instanceBefore = try raidInstance(database: database, raidID: raid.raidID)
        let shouldClear = instanceBefore.map {
            ($0.status == .active || $0.status == .upcoming)
                && $0.totalDamage >= raid.maxHP
                && raid.maxHP > 0
        } ?? false
        try database.execute(
            """
            UPDATE raid_instances
            SET status = CASE
                    WHEN total_damage >= ? THEN 'cleared'
                    ELSE status
                END,
                current_hp = max(0, ? - total_damage),
                cleared_at = CASE
                    WHEN total_damage >= ? THEN COALESCE(cleared_at, ?)
                    ELSE cleared_at
                END,
                updated_at = ?
            WHERE raid_id = ?
              AND status IN ('upcoming', 'active')
              AND (
                  current_hp != max(0, ? - total_damage)
                  OR (total_damage >= ? AND status != 'cleared')
              );
            """,
            bindings: [
                .integer(raid.maxHP),
                .integer(raid.maxHP),
                .integer(raid.maxHP),
                .text(now),
                .text(now),
                .text(raid.raidID),
                .integer(raid.maxHP),
                .integer(raid.maxHP),
            ]
        )
        if shouldClear, let instanceBefore {
            try acquireClearRewards(
                database: database,
                raid: raid,
                instanceID: instanceBefore.rowID,
                usageSampleID: 0,
                occurredAt: now,
                correlationID: nil
            )
            try evaluateAchievementBadges(database: database, occurredAt: now)
        }
    }

    func raidInstance(database: SQLiteDatabase, raidID: String) throws -> RaidInstanceRecord? {
        let sql = """
        SELECT raid_instance_id,
               raid_id,
               status,
               current_hp,
               total_attacks,
               total_damage
        FROM raid_instances
        WHERE raid_id = ?
        LIMIT 1;
        """
        return try database.fetchOne(sql, bindings: [.text(raidID)]) { statement in
            let statusRaw = SQLiteDatabase.columnText(statement, index: 2)
            guard let status = RaidInstanceStatus(rawValue: statusRaw) else {
                throw SQLiteError.statementFailed(message: "invalid raid instance status \(statusRaw)", sql: sql)
            }
            return RaidInstanceRecord(
                rowID: SQLiteDatabase.columnInt64(statement, index: 0),
                raidID: SQLiteDatabase.columnText(statement, index: 1),
                status: status,
                currentHP: SQLiteDatabase.columnInt64(statement, index: 3),
                totalAttacks: SQLiteDatabase.columnInt64(statement, index: 4),
                totalDamage: SQLiteDatabase.columnInt64(statement, index: 5)
            )
        }
    }

    func raidAttackExists(database: SQLiteDatabase, raidInstanceID: Int64, usageSampleID: Int64) throws -> Bool {
        try database.fetchOne(
            """
            SELECT 1
            FROM raid_attacks
            WHERE raid_instance_id = ? AND usage_sample_id = ?
            LIMIT 1;
            """,
            bindings: [.integer(raidInstanceID), .integer(usageSampleID)]
        ) { _ in true } ?? false
    }

    func raidProgressSummary(
        database: SQLiteDatabase,
        raid: RaidDefinition,
        instance: RaidInstanceRecord,
        partyMembers: [PartyMemberSummary],
        asOf reference: Date
    ) throws -> RaidProgressSummary {
        let raidParty = partyMembers.map {
            RaidPartyMember(
                speciesID: $0.speciesID,
                assetKey: $0.assetKey,
                displayName: $0.displayName,
                field: $0.field,
                rarity: $0.rarity,
                slotOrder: $0.slotOrder,
                capturedCount: $0.capturedCount,
                affinityLevel: $0.affinityLevel,
                trainingTrait: $0.trainingTrait,
                trainingRank: $0.trainingRank,
                stats: $0.stats
            )
        }
        let damageBlessing = try activeRaidDamageBlessing(
            database: database,
            raid: raid,
            partyMembers: raidParty,
            at: reference
        )
        let partyPower = RaidDamageCalculator.resolveAttack(
            raid: raid,
            partyMembers: raidParty,
            damageBlessing: damageBlessing
        )
        return RaidProgressSummary(
            raidID: raid.raidID,
            title: raid.title,
            targetName: raid.targetName,
            targetArtKey: raid.targetArtKey,
            raidField: raid.raidField,
            availabilityKind: raid.availabilityKind,
            activeStartAt: raid.activeStartAt,
            activeEndAt: raid.activeEndAt,
            status: instance.status,
            currentHP: instance.currentHP,
            maxHP: raid.maxHP,
            totalAttacks: instance.totalAttacks,
            totalDamage: instance.totalDamage,
            partyPower: partyPower.totalDamage,
            fieldMatchCount: partyPower.fieldMatchCount,
            fieldSynergyMultiplier: partyPower.fieldSynergyMultiplier,
            activeBlessing: damageBlessing.map {
                RaidBlessingSummary(
                    id: $0.id,
                    damageMultiplier: $0.damageMultiplier,
                    minimumTotalDamage: $0.minimumTotalDamage
                )
            },
            rewards: try raidRewards(database: database, raid: raid, asOf: reference),
            recentAttacks: try recentRaidAttacks(database: database, raidInstanceID: instance.rowID, limit: 5)
        )
    }

    func raidRewards(database: SQLiteDatabase, raid: RaidDefinition, asOf reference: Date) throws -> [RaidRewardSummary] {
        try rewardDefinitions(database: database, raidID: raid.raidID).map { reward in
            let stored = try rewardArchiveStatus(database: database, rewardID: reward.rewardID)
            let status = stored?.status ?? (isActive(raid, at: reference) ? .available : .unknown)
            return RaidRewardSummary(
                rewardID: reward.rewardID,
                title: reward.title,
                type: reward.type,
                artKey: reward.artKey,
                status: status,
                acquiredAt: stored?.acquiredAt,
                missedAt: stored?.missedAt
            )
        }
    }

    func activeRaidDamageBlessing(
        database: SQLiteDatabase,
        raid: RaidDefinition,
        partyMembers: [RaidPartyMember],
        at reference: Date
    ) throws -> RaidDamageBlessing? {
        guard raid.availabilityKind == .scheduled,
              partyMembers.isEmpty == false,
              try hasAcquiredMonthlyReward(database: database) == false,
              let startedAtRaw = try raidLiveGameplayStartedAt(database: database),
              let startedAt = Self.raidDate(from: startedAtRaw)
        else {
            return nil
        }

        let blessingEndsAt = startedAt.addingTimeInterval(Self.firstSparkBlessingDuration)
        guard reference >= startedAt, reference < blessingEndsAt else {
            return nil
        }

        return Self.firstSparkBlessing
    }

    func raidLiveGameplayStartedAt(database: SQLiteDatabase) throws -> String? {
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

    func hasAcquiredMonthlyReward(database: SQLiteDatabase) throws -> Bool {
        try database.fetchOne(
            """
            SELECT 1
            FROM reward_archive_entries archive
            INNER JOIN raid_reward_definitions rewards ON rewards.reward_id = archive.reward_id
            INNER JOIN raid_definitions raids ON raids.raid_id = rewards.source_raid_id
            WHERE archive.status = 'acquired'
              AND raids.availability_kind = 'scheduled'
            LIMIT 1;
            """
        ) { _ in true } ?? false
    }

    func rewardDefinitions(database: SQLiteDatabase, raidID: String) throws -> [RaidRewardDefinition] {
        let sql = """
        SELECT reward_id,
               source_raid_id,
               reward_type,
               title,
               art_key,
               grant_rule
        FROM raid_reward_definitions
        WHERE source_raid_id = ?
        ORDER BY reward_id ASC;
        """
        return try database.fetchAll(sql, bindings: [.text(raidID)]) { statement in
            let typeRaw = SQLiteDatabase.columnText(statement, index: 2)
            let grantRaw = SQLiteDatabase.columnText(statement, index: 5)
            guard let type = RaidRewardType(rawValue: typeRaw),
                  let grantRule = RaidRewardGrantRule(rawValue: grantRaw)
            else {
                throw SQLiteError.statementFailed(message: "invalid raid reward row", sql: sql)
            }
            return RaidRewardDefinition(
                rewardID: SQLiteDatabase.columnText(statement, index: 0),
                sourceRaidID: SQLiteDatabase.columnText(statement, index: 1),
                type: type,
                title: SQLiteDatabase.columnText(statement, index: 3),
                artKey: SQLiteDatabase.columnText(statement, index: 4),
                grantRule: grantRule
            )
        }
    }

    func rewardArchiveStatus(
        database: SQLiteDatabase,
        rewardID: String
    ) throws -> (status: RaidRewardArchiveStatus, acquiredAt: String?, missedAt: String?)? {
        let sql = """
        SELECT status, acquired_at, missed_at
        FROM reward_archive_entries
        WHERE reward_id = ?
        LIMIT 1;
        """
        return try database.fetchOne(sql, bindings: [.text(rewardID)]) { statement in
            let statusRaw = SQLiteDatabase.columnText(statement, index: 0)
            guard let status = RaidRewardArchiveStatus(rawValue: statusRaw) else {
                throw SQLiteError.statementFailed(message: "invalid reward archive status \(statusRaw)", sql: sql)
            }
            return (
                status,
                SQLiteDatabase.columnOptionalText(statement, index: 1),
                SQLiteDatabase.columnOptionalText(statement, index: 2)
            )
        }
    }

    func rewardArchiveEntries(database: SQLiteDatabase, asOf reference: Date) throws -> [RaidArchiveEntrySummary] {
        let raidsByID = Dictionary(uniqueKeysWithValues: try raidDefinitions(database: database).map { ($0.raidID, $0) })
        let sql = """
        SELECT rewards.reward_id,
               rewards.title,
               rewards.reward_type,
               rewards.art_key,
               rewards.source_raid_id,
               raids.title,
               raids.target_name,
               raids.target_art_key,
               raids.active_start_at,
               raids.active_end_at,
               archive.status,
               archive.acquired_at,
               archive.missed_at
        FROM raid_reward_definitions rewards
        INNER JOIN raid_definitions raids ON raids.raid_id = rewards.source_raid_id
        LEFT JOIN reward_archive_entries archive ON archive.reward_id = rewards.reward_id
        ORDER BY COALESCE(raids.active_start_at, ''), rewards.reward_id;
        """
        return try database.fetchAll(sql) { statement in
            let typeRaw = SQLiteDatabase.columnText(statement, index: 2)
            let sourceRaidID = SQLiteDatabase.columnText(statement, index: 4)
            guard let rewardType = RaidRewardType(rawValue: typeRaw),
                  let raid = raidsByID[sourceRaidID]
            else {
                throw SQLiteError.statementFailed(message: "invalid reward archive row", sql: sql)
            }

            let storedStatus = SQLiteDatabase.columnOptionalText(statement, index: 10)
                .flatMap(RaidRewardArchiveStatus.init(rawValue:))
            let computedStatus: RaidRewardArchiveStatus
            if let storedStatus {
                computedStatus = storedStatus
            } else if isActive(raid, at: reference) {
                computedStatus = .available
            } else {
                computedStatus = .unknown
            }

            return RaidArchiveEntrySummary(
                rewardID: SQLiteDatabase.columnText(statement, index: 0),
                title: SQLiteDatabase.columnText(statement, index: 1),
                type: rewardType,
                artKey: SQLiteDatabase.columnText(statement, index: 3),
                status: computedStatus,
                sourceRaidID: sourceRaidID,
                sourceRaidTitle: SQLiteDatabase.columnText(statement, index: 5),
                sourceRaidTargetName: SQLiteDatabase.columnText(statement, index: 6),
                sourceRaidTargetArtKey: SQLiteDatabase.columnText(statement, index: 7),
                activeStartAt: SQLiteDatabase.columnOptionalText(statement, index: 8),
                activeEndAt: SQLiteDatabase.columnOptionalText(statement, index: 9),
                acquiredAt: SQLiteDatabase.columnOptionalText(statement, index: 11),
                missedAt: SQLiteDatabase.columnOptionalText(statement, index: 12)
            )
        }
    }

    func recentRaidAttacks(database: SQLiteDatabase, raidInstanceID: Int64, limit: Int) throws -> [RaidAttackSummary] {
        let attackSQL = """
        SELECT raid_attack_row_id,
               occurred_at,
               party_size,
               total_damage
        FROM raid_attacks
        WHERE raid_instance_id = ?
        ORDER BY raid_attack_row_id DESC
        LIMIT ?;
        """
        return try database.fetchAll(
            attackSQL,
            bindings: [.integer(raidInstanceID), .integer(Int64(limit))]
        ) { statement in
            let attackID = SQLiteDatabase.columnInt64(statement, index: 0)
            let memberHits = try recentRaidMemberHits(database: database, attackID: attackID)
            return RaidAttackSummary(
                attackID: attackID,
                occurredAt: SQLiteDatabase.columnText(statement, index: 1),
                partySize: Int(SQLiteDatabase.columnInt64(statement, index: 2)),
                totalDamage: Int(SQLiteDatabase.columnInt64(statement, index: 3)),
                missCount: memberHits.filter { $0.rollOutcome == .miss }.count,
                criticalCount: memberHits.filter { $0.rollOutcome == .critical }.count,
                memberHits: memberHits
            )
        }
    }

    func recentRaidMemberHits(database: SQLiteDatabase, attackID: Int64) throws -> [RaidMemberHitSummary] {
        let sql = """
        SELECT hits.species_id,
               species.name,
               species.asset_key,
               hits.slot_order,
               hits.axis_score,
               hits.role_fit_bonus,
               hits.field_fit_bonus,
               hits.trait_fit_bonus,
               hits.capture_bond_bonus,
               hits.training_raid_bonus,
               hits.hit_power
        FROM raid_member_hits hits
        INNER JOIN species ON species.species_id = hits.species_id
        WHERE hits.raid_attack_row_id = ?
        ORDER BY hits.slot_order ASC;
        """
        return try database.fetchAll(sql, bindings: [.integer(attackID)]) { statement in
            let baseHitPower = max(
                1,
                Int(SQLiteDatabase.columnDouble(statement, index: 4).rounded())
                    + Int(SQLiteDatabase.columnInt64(statement, index: 5))
                    + Int(SQLiteDatabase.columnInt64(statement, index: 6))
                    + Int(SQLiteDatabase.columnInt64(statement, index: 7))
                    + Int(SQLiteDatabase.columnInt64(statement, index: 8))
                    + Int(SQLiteDatabase.columnInt64(statement, index: 9))
            )
            let hitPower = Int(SQLiteDatabase.columnInt64(statement, index: 10))
            return RaidMemberHitSummary(
                speciesID: SQLiteDatabase.columnText(statement, index: 0),
                displayName: SQLiteDatabase.columnText(statement, index: 1),
                assetKey: SQLiteDatabase.columnText(statement, index: 2),
                slotOrder: Int(SQLiteDatabase.columnInt64(statement, index: 3)),
                baseHitPower: baseHitPower,
                trainingRaidBonus: Int(SQLiteDatabase.columnInt64(statement, index: 9)),
                rollOutcome: Self.inferredHitRollOutcome(baseHitPower: baseHitPower, hitPower: hitPower),
                hitPower: hitPower
            )
        }
    }

    static func inferredHitRollOutcome(baseHitPower: Int, hitPower: Int) -> RaidHitRollOutcome {
        guard hitPower > 0 else { return .miss }
        let ratio = Double(hitPower) / Double(max(1, baseHitPower))
        if ratio >= 1.45 { return .critical }
        if ratio >= 1.15 { return .strong }
        if ratio <= 0.80 { return .glancing }
        return .normal
    }

    func settleExpiredRaids(database: SQLiteDatabase, asOf reference: Date) throws {
        let raids = try raidDefinitions(database: database)
        for raid in raids where isExpired(raid, asOf: reference) {
            let instance = try ensureRaidInstance(database: database, raid: raid, status: .expired, at: reference)
            guard instance.status != .cleared else {
                continue
            }
            let now = Self.raidString(from: reference)
            if instance.status != .expired && instance.status != .missed {
                try database.execute(
                    """
                    UPDATE raid_instances
                    SET status = ?,
                        expired_at = COALESCE(expired_at, ?),
                        updated_at = ?
                    WHERE raid_instance_id = ?;
                    """,
                    bindings: [
                        .text(RaidInstanceStatus.expired.rawValue),
                        .text(now),
                        .text(now),
                        .integer(instance.rowID),
                    ]
                )
            }

            let expiredEventID = "\(TokenmonDomainEventType.raidExpired.rawValue):\(raid.raidID)"
            if try domainEventExists(database: database, eventID: expiredEventID) == false {
                try DomainEventStore.persist(
                    database: database,
                    envelope: DomainEventEnvelope(
                        eventID: expiredEventID,
                        eventType: TokenmonDomainEventType.raidExpired.rawValue,
                        occurredAt: now,
                        producer: "TokenmonPersistence.RaidStore",
                        aggregateType: "raid_instance",
                        aggregateID: String(instance.rowID),
                        payload: RaidExpiredEventPayload(
                            raidID: raid.raidID,
                            raidInstanceID: instance.rowID,
                            totalAttacks: instance.totalAttacks,
                            totalDamage: instance.totalDamage
                        )
                    )
                )
            }

            for reward in try rewardDefinitions(database: database, raidID: raid.raidID) where reward.grantRule == .clear {
                let existingStatus = try rewardArchiveStatus(database: database, rewardID: reward.rewardID)?.status
                guard existingStatus != .acquired, existingStatus != .missed else {
                    continue
                }
                try upsertRewardArchiveEntry(
                    database: database,
                    reward: reward,
                    status: .missed,
                    occurredAt: now
                )
                try persistRewardArchiveEvent(
                    database: database,
                    reward: reward,
                    status: .missed,
                    occurredAt: now,
                    correlationID: nil
                )
                try persistRewardArchiveRecordedEvent(
                    database: database,
                    reward: reward,
                    status: .missed,
                    occurredAt: now,
                    correlationID: nil
                )
            }
        }
    }

    func acquireClearRewards(
        database: SQLiteDatabase,
        raid: RaidDefinition,
        instanceID: Int64,
        usageSampleID: Int64,
        occurredAt: String,
        correlationID: String?
    ) throws {
        let updatedInstance = try raidInstance(database: database, raidID: raid.raidID)
        try DomainEventStore.persist(
            database: database,
            envelope: DomainEventEnvelope(
                eventID: "\(TokenmonDomainEventType.raidCleared.rawValue):\(raid.raidID)",
                eventType: TokenmonDomainEventType.raidCleared.rawValue,
                occurredAt: occurredAt,
                producer: "TokenmonPersistence.RaidStore",
                correlationID: correlationID,
                causationID: "\(TokenmonDomainEventType.raidAttackTriggered.rawValue):\(raid.raidID):usage-sample-\(usageSampleID)",
                aggregateType: "raid_instance",
                aggregateID: String(instanceID),
                payload: RaidClearedEventPayload(
                    raidID: raid.raidID,
                    raidInstanceID: instanceID,
                    usageSampleID: usageSampleID,
                    totalAttacks: updatedInstance?.totalAttacks ?? 0,
                    totalDamage: updatedInstance?.totalDamage ?? 0
                )
            )
        )

        for reward in try rewardDefinitions(database: database, raidID: raid.raidID) where reward.grantRule == .clear {
            try upsertRewardArchiveEntry(
                database: database,
                reward: reward,
                status: .acquired,
                occurredAt: occurredAt
            )
            try DomainEventStore.persist(
                database: database,
                envelope: DomainEventEnvelope(
                    eventID: "\(TokenmonDomainEventType.raidRewardAcquired.rawValue):\(reward.rewardID)",
                    eventType: TokenmonDomainEventType.raidRewardAcquired.rawValue,
                    occurredAt: occurredAt,
                    producer: "TokenmonPersistence.RaidStore",
                    correlationID: correlationID,
                    causationID: "\(TokenmonDomainEventType.raidCleared.rawValue):\(raid.raidID)",
                    aggregateType: "raid_reward",
                    aggregateID: reward.rewardID,
                    payload: RaidRewardArchiveEventPayload(
                        rewardID: reward.rewardID,
                        raidID: reward.sourceRaidID,
                        rewardType: reward.type.rawValue,
                        status: RaidRewardArchiveStatus.acquired.rawValue
                    )
                )
            )
            try persistRewardArchiveEvent(
                database: database,
                reward: reward,
                status: .acquired,
                occurredAt: occurredAt,
                correlationID: correlationID
            )
        }
    }

    func upsertRewardArchiveEntry(
        database: SQLiteDatabase,
        reward: RaidRewardDefinition,
        status: RaidRewardArchiveStatus,
        occurredAt: String
    ) throws {
        try database.execute(
            """
            INSERT INTO reward_archive_entries (
                reward_id,
                source_raid_id,
                status,
                acquired_at,
                missed_at,
                updated_at
            ) VALUES (?, ?, ?, ?, ?, ?)
            ON CONFLICT(reward_id) DO UPDATE SET
                status = CASE
                    WHEN reward_archive_entries.status = 'acquired' THEN reward_archive_entries.status
                    ELSE excluded.status
                END,
                acquired_at = CASE
                    WHEN reward_archive_entries.status = 'acquired' THEN reward_archive_entries.acquired_at
                    ELSE excluded.acquired_at
                END,
                missed_at = CASE
                    WHEN reward_archive_entries.status = 'acquired' THEN reward_archive_entries.missed_at
                    ELSE excluded.missed_at
                END,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(reward.rewardID),
                .text(reward.sourceRaidID),
                .text(status.rawValue),
                status == .acquired ? .text(occurredAt) : .null,
                status == .missed ? .text(occurredAt) : .null,
                .text(occurredAt),
            ]
        )
    }

    func persistRaidAttackEvents(
        database: SQLiteDatabase,
        raid: RaidDefinition,
        instance: RaidInstanceRecord,
        usageSampleID: Int64,
        observedAt: String,
        correlationID: String?,
        attackID: Int64,
        resolution: RaidAttackResolution,
        currentHPBefore: Int64,
        currentHPAfter: Int64
    ) throws {
        let attackEventID = "\(TokenmonDomainEventType.raidAttackTriggered.rawValue):\(raid.raidID):usage-sample-\(usageSampleID)"
        try DomainEventStore.persist(
            database: database,
            envelope: DomainEventEnvelope(
                eventID: attackEventID,
                eventType: TokenmonDomainEventType.raidAttackTriggered.rawValue,
                occurredAt: observedAt,
                producer: "TokenmonPersistence.RaidStore",
                correlationID: correlationID,
                causationID: TokenmonDomainEventRegistry.usageSampleEventID(usageSampleID),
                aggregateType: "raid_instance",
                aggregateID: String(instance.rowID),
                payload: RaidAttackTriggeredEventPayload(
                    raidID: raid.raidID,
                    raidInstanceID: instance.rowID,
                    usageSampleID: usageSampleID,
                    partySize: resolution.memberHits.count,
                    unmodifiedTotalDamage: resolution.unmodifiedTotalDamage,
                    fieldMatchCount: resolution.fieldMatchCount,
                    fieldSynergyMultiplier: resolution.fieldSynergyMultiplier,
                    totalDamage: resolution.totalDamage,
                    damageBlessingID: resolution.damageBlessing?.id,
                    damageBlessingMultiplier: resolution.damageBlessing?.damageMultiplier,
                    damageBlessingMinimumTotalDamage: resolution.damageBlessing?.minimumTotalDamage
                )
            )
        )

        for hit in resolution.memberHits {
            try DomainEventStore.persist(
                database: database,
                envelope: DomainEventEnvelope(
                    eventID: "\(TokenmonDomainEventType.raidMemberHitResolved.rawValue):\(raid.raidID):usage-sample-\(usageSampleID):slot-\(hit.member.slotOrder)",
                    eventType: TokenmonDomainEventType.raidMemberHitResolved.rawValue,
                    occurredAt: observedAt,
                    producer: "TokenmonGameEngine.RaidDamageCalculator",
                    correlationID: correlationID,
                    causationID: attackEventID,
                    aggregateType: "raid_attack",
                    aggregateID: "\(raid.raidID):usage-sample-\(usageSampleID)",
                    payload: RaidMemberHitResolvedEventPayload(
                        raidID: raid.raidID,
                        usageSampleID: usageSampleID,
                        speciesID: hit.member.speciesID,
                        slotOrder: hit.member.slotOrder,
                        axisScore: hit.axisScore,
                        roleFitBonus: hit.roleFitBonus,
                        fieldFitBonus: hit.fieldFitBonus,
                        traitFitBonus: hit.traitFitBonus,
                        captureBondBonus: hit.captureBondBonus,
                        trainingRaidBonus: hit.trainingRaidBonus,
                        hitPower: hit.hitPower
                    )
                )
            )
        }

        let raiderApplications = resolution.memberHits.compactMap { hit -> LeaderTraitBonusApplication? in
            guard hit.trainingRaidBonus > 0 else { return nil }
            return LeaderTraitBonusApplication(
                kind: .raider,
                speciesID: hit.member.speciesID,
                trait: hit.member.trainingTrait,
                field: raid.raidField,
                trainingRank: hit.member.trainingRank,
                bonusAmount: Double(hit.trainingRaidBonus),
                capApplied: 8
            )
        }
        try persistLeaderTraitBonusApplications(
            database: database,
            applications: raiderApplications,
            usageSampleID: usageSampleID,
            encounterID: nil,
            raidAttackID: attackID,
            observedAt: observedAt,
            correlationID: correlationID,
            causationID: attackEventID
        )

        try DomainEventStore.persist(
            database: database,
            envelope: DomainEventEnvelope(
                eventID: "\(TokenmonDomainEventType.raidProgressUpdated.rawValue):\(raid.raidID):usage-sample-\(usageSampleID)",
                eventType: TokenmonDomainEventType.raidProgressUpdated.rawValue,
                occurredAt: observedAt,
                producer: "TokenmonPersistence.RaidStore",
                correlationID: correlationID,
                causationID: attackEventID,
                aggregateType: "raid_instance",
                aggregateID: String(instance.rowID),
                payload: RaidProgressUpdatedEventPayload(
                    raidID: raid.raidID,
                    usageSampleID: usageSampleID,
                    currentHPBefore: currentHPBefore,
                    currentHPAfter: currentHPAfter,
                    totalDamage: resolution.totalDamage
                )
            )
        )
    }

    func domainEventExists(database: SQLiteDatabase, eventID: String) throws -> Bool {
        try database.fetchOne(
            """
            SELECT 1
            FROM domain_events
            WHERE event_id = ?
            LIMIT 1;
            """,
            bindings: [.text(eventID)]
        ) { _ in true } ?? false
    }

    func persistRewardArchiveEvent(
        database: SQLiteDatabase,
        reward: RaidRewardDefinition,
        status: RaidRewardArchiveStatus,
        occurredAt: String,
        correlationID: String?
    ) throws {
        let eventType: TokenmonDomainEventType = status == .missed
            ? .raidRewardMissed
            : .rewardArchiveRecorded
        try DomainEventStore.persist(
            database: database,
            envelope: DomainEventEnvelope(
                eventID: "\(eventType.rawValue):\(reward.rewardID)",
                eventType: eventType.rawValue,
                occurredAt: occurredAt,
                producer: "TokenmonPersistence.RaidStore",
                correlationID: correlationID,
                aggregateType: "raid_reward",
                aggregateID: reward.rewardID,
                payload: RaidRewardArchiveEventPayload(
                    rewardID: reward.rewardID,
                    raidID: reward.sourceRaidID,
                    rewardType: reward.type.rawValue,
                    status: status.rawValue
                )
            )
        )
    }

    func persistRewardArchiveRecordedEvent(
        database: SQLiteDatabase,
        reward: RaidRewardDefinition,
        status: RaidRewardArchiveStatus,
        occurredAt: String,
        correlationID: String?
    ) throws {
        let eventID = "\(TokenmonDomainEventType.rewardArchiveRecorded.rawValue):\(reward.rewardID)"
        guard try domainEventExists(database: database, eventID: eventID) == false else {
            return
        }
        try DomainEventStore.persist(
            database: database,
            envelope: DomainEventEnvelope(
                eventID: eventID,
                eventType: TokenmonDomainEventType.rewardArchiveRecorded.rawValue,
                occurredAt: occurredAt,
                producer: "TokenmonPersistence.RaidStore",
                correlationID: correlationID,
                aggregateType: "raid_reward",
                aggregateID: reward.rewardID,
                payload: RaidRewardArchiveEventPayload(
                    rewardID: reward.rewardID,
                    raidID: reward.sourceRaidID,
                    rewardType: reward.type.rawValue,
                    status: status.rawValue
                )
            )
        )
    }
}
