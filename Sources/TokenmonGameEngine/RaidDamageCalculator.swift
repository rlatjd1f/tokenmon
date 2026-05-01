import Foundation
import TokenmonDomain

public struct RaidMemberHitResult: Equatable, Sendable {
    public let member: RaidPartyMember
    public let axisScore: Double
    public let roundedAxisScore: Int
    public let roleFitBonus: Int
    public let fieldFitBonus: Int
    public let traitFitBonus: Int
    public let captureBondBonus: Int
    public let trainingRaidBonus: Int
    public let baseHitPower: Int
    public let rollOutcome: RaidHitRollOutcome
    public let rollMultiplier: Double
    public let hitPower: Int
}

public enum RaidHitRollOutcome: String, Equatable, Sendable {
    case miss
    case glancing
    case normal
    case strong
    case critical
}

public struct RaidAttackResolution: Equatable, Sendable {
    public let raid: RaidDefinition
    public let memberHits: [RaidMemberHitResult]
    public let rawPartyDamage: Int
    public let formationMultiplier: Double
    public let unmodifiedTotalDamage: Int
    public let damageBlessing: RaidDamageBlessing?
    public let totalDamage: Int
}

public struct RaidDamageBlessing: Equatable, Sendable {
    public let id: String
    public let damageMultiplier: Double
    public let minimumTotalDamage: Int

    public init(id: String, damageMultiplier: Double, minimumTotalDamage: Int) {
        self.id = id
        self.damageMultiplier = damageMultiplier
        self.minimumTotalDamage = minimumTotalDamage
    }
}

public enum RaidDamageCalculator {
    public static func resolveAttack(
        raid: RaidDefinition,
        partyMembers: [RaidPartyMember],
        usageSampleID: Int64? = nil,
        damageBlessing: RaidDamageBlessing? = nil
    ) -> RaidAttackResolution {
        let orderedMembers = partyMembers.sorted { lhs, rhs in
            lhs.slotOrder == rhs.slotOrder
                ? lhs.speciesID < rhs.speciesID
                : lhs.slotOrder < rhs.slotOrder
        }
        let trainingBonuses = LeaderTraitBonusResolver().raidBonuses(
            raidField: raid.raidField,
            partyMembers: orderedMembers.map { member in
                LeaderTraitContext(
                    speciesID: member.speciesID,
                    homeField: member.field,
                    rarity: member.rarity,
                    trait: member.trainingTrait,
                    trainingRank: member.trainingRank,
                    slotOrder: member.slotOrder
                )
            }
        )
        let hits = orderedMembers.map { member in
            let base = memberHit(
                raid: raid,
                member: member,
                trainingRaidBonus: trainingBonuses.memberBonuses[member.speciesID] ?? 0
            )
            guard let usageSampleID else { return base }
            return applyHitRoll(base, raidID: raid.raidID, usageSampleID: usageSampleID)
        }
        let rawDamage = hits.reduce(0) { $0 + $1.hitPower }
        let multiplier = formationMultiplier(partySize: hits.count)
        let unmodifiedTotalDamage = hits.isEmpty ? 0 : Int(floor(Double(rawDamage) * multiplier))
        let totalDamage: Int
        if let damageBlessing, unmodifiedTotalDamage > 0 {
            totalDamage = max(
                Int(floor(Double(unmodifiedTotalDamage) * damageBlessing.damageMultiplier)),
                damageBlessing.minimumTotalDamage
            )
        } else {
            totalDamage = unmodifiedTotalDamage
        }

        return RaidAttackResolution(
            raid: raid,
            memberHits: hits,
            rawPartyDamage: rawDamage,
            formationMultiplier: multiplier,
            unmodifiedTotalDamage: unmodifiedTotalDamage,
            damageBlessing: damageBlessing,
            totalDamage: totalDamage
        )
    }

    public static func memberHit(
        raid: RaidDefinition,
        member: RaidPartyMember,
        trainingRaidBonus: Int = 0
    ) -> RaidMemberHitResult {
        let axisScore = SpeciesStatAxis.allCases.reduce(0.0) { partial, axis in
            partial + Double(member.stats.value(for: axis)) * Double(raid.axisWeights.value(for: axis)) / 100.0
        }
        let roundedAxisScore = Int(axisScore.rounded())
        let roleFitBonus = roleFitBonus(raid: raid, member: member)
        let fieldFitBonus = member.field == raid.raidField ? 1 : 0
        let traitFitBonus = min(
            2,
            member.stats.traits.filter { raid.preferredTraitTags.contains($0) }.count
        )
        let captureBondBonus = captureBondBonus(affinityLevel: member.affinityLevel)
        let hitPower = max(
            1,
            roundedAxisScore
                + roleFitBonus
                + fieldFitBonus
                + traitFitBonus
                + captureBondBonus
                + max(0, trainingRaidBonus)
        )

        return RaidMemberHitResult(
            member: member,
            axisScore: axisScore,
            roundedAxisScore: roundedAxisScore,
            roleFitBonus: roleFitBonus,
            fieldFitBonus: fieldFitBonus,
            traitFitBonus: traitFitBonus,
            captureBondBonus: captureBondBonus,
            trainingRaidBonus: max(0, trainingRaidBonus),
            baseHitPower: hitPower,
            rollOutcome: .normal,
            rollMultiplier: 1.0,
            hitPower: hitPower
        )
    }

    public static func formationMultiplier(partySize: Int) -> Double {
        switch partySize {
        case 10...:
            return 1.15
        case 6...9:
            return 1.10
        case 3...5:
            return 1.05
        default:
            return 1.0
        }
    }

    public static func captureBondBonus(affinityLevel: Int64) -> Int {
        switch affinityLevel {
        case 4...:
            return 3
        case 3:
            return 2
        case 2:
            return 1
        default:
            return 0
        }
    }

    private static func roleFitBonus(raid: RaidDefinition, member: RaidPartyMember) -> Int {
        let raidTopAxes = topAxes { raid.axisWeights.value(for: $0) }
        let memberTopAxes = topAxes { member.stats.value(for: $0) }
        return raidTopAxes.contains { memberTopAxes.contains($0) } ? 1 : 0
    }

    private static func applyHitRoll(
        _ base: RaidMemberHitResult,
        raidID: String,
        usageSampleID: Int64
    ) -> RaidMemberHitResult {
        let roll = deterministicRoll(
            "\(raidID):\(usageSampleID):\(base.member.speciesID):\(base.member.slotOrder)"
        )
        let outcome: RaidHitRollOutcome
        let multiplier: Double
        switch roll {
        case 0..<8:
            outcome = .miss
            multiplier = 0
        case 8..<22:
            outcome = .glancing
            multiplier = 0.75
        case 22..<78:
            outcome = .normal
            multiplier = 0.90 + (Double(roll - 22) / 55.0 * 0.20)
        case 78..<94:
            outcome = .strong
            multiplier = 1.20
        default:
            outcome = .critical
            multiplier = 1.65
        }
        let rolledPower = outcome == .miss
            ? 0
            : max(1, Int((Double(base.baseHitPower) * multiplier).rounded()))

        return RaidMemberHitResult(
            member: base.member,
            axisScore: base.axisScore,
            roundedAxisScore: base.roundedAxisScore,
            roleFitBonus: base.roleFitBonus,
            fieldFitBonus: base.fieldFitBonus,
            traitFitBonus: base.traitFitBonus,
            captureBondBonus: base.captureBondBonus,
            trainingRaidBonus: base.trainingRaidBonus,
            baseHitPower: base.baseHitPower,
            rollOutcome: outcome,
            rollMultiplier: multiplier,
            hitPower: rolledPower
        )
    }

    private static func deterministicRoll(_ key: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return Int(hash % 100)
    }

    private static func topAxes(score: (SpeciesStatAxis) -> Int) -> [SpeciesStatAxis] {
        Array(
            SpeciesStatAxis.allCases.sorted { lhs, rhs in
                let leftScore = score(lhs)
                let rightScore = score(rhs)
                if leftScore == rightScore {
                    return axisRank(lhs) < axisRank(rhs)
                }
                return leftScore > rightScore
            }.prefix(2)
        )
    }

    private static func axisRank(_ axis: SpeciesStatAxis) -> Int {
        SpeciesStatAxis.allCases.firstIndex(of: axis) ?? 0
    }
}
