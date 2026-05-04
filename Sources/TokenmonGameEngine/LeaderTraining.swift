import Foundation
import TokenmonDomain

public struct NowCampFocusState: Equatable, Codable, Sendable {
    public let focusEnergy: Int
    public let focusRemainderTokens: Int64
    public let focusEarnedLocalDate: String
    public let focusEarnedToday: Int

    public init(
        focusEnergy: Int,
        focusRemainderTokens: Int64,
        focusEarnedLocalDate: String,
        focusEarnedToday: Int
    ) {
        self.focusEnergy = focusEnergy
        self.focusRemainderTokens = focusRemainderTokens
        self.focusEarnedLocalDate = focusEarnedLocalDate
        self.focusEarnedToday = focusEarnedToday
    }
}

public struct NowCampFocusAccumulation: Equatable, Codable, Sendable {
    public let updatedState: NowCampFocusState
    public let focusEarned: Int
    public let rawFocusGain: Int
    public let discardedByDailyCap: Int
    public let discardedByStorageCap: Int
}

public enum NowCampFocusAccumulatorError: Error, LocalizedError {
    case negativeGameplayDelta(Int64)
    case invalidState(NowCampFocusState)

    public var errorDescription: String? {
        switch self {
        case .negativeGameplayDelta(let delta):
            return "Focus gameplay delta must be non-negative: \(delta)"
        case .invalidState(let state):
            return "Focus state is invalid: \(state)"
        }
    }
}

public struct NowCampFocusAccumulator: Sendable {
    public let tokensPerFocus: Int64
    public let storageCap: Int
    public let dailyEarnCap: Int

    public init(
        tokensPerFocus: Int64 = 50_000,
        storageCap: Int = 100,
        dailyEarnCap: Int = 120
    ) {
        self.tokensPerFocus = tokensPerFocus
        self.storageCap = storageCap
        self.dailyEarnCap = dailyEarnCap
    }

    public func accumulate(
        state: NowCampFocusState,
        gameplayDeltaTokens: Int64,
        localDate: String
    ) throws -> NowCampFocusAccumulation {
        guard gameplayDeltaTokens >= 0 else {
            throw NowCampFocusAccumulatorError.negativeGameplayDelta(gameplayDeltaTokens)
        }
        guard state.focusEnergy >= 0,
              state.focusEnergy <= storageCap,
              state.focusRemainderTokens >= 0,
              state.focusRemainderTokens < tokensPerFocus,
              state.focusEarnedToday >= 0 else {
            throw NowCampFocusAccumulatorError.invalidState(state)
        }

        let earnedTodayBefore = state.focusEarnedLocalDate == localDate ? state.focusEarnedToday : 0
        let remainderTotal = state.focusRemainderTokens + gameplayDeltaTokens
        let rawFocusGain = Int(remainderTotal / tokensPerFocus)
        let remainderAfter = remainderTotal % tokensPerFocus
        let dailyAllowed = min(rawFocusGain, max(0, dailyEarnCap - earnedTodayBefore))
        let storageAllowed = min(dailyAllowed, max(0, storageCap - state.focusEnergy))
        let discardedByDailyCap = max(0, rawFocusGain - dailyAllowed)
        let discardedByStorageCap = max(0, dailyAllowed - storageAllowed)

        return NowCampFocusAccumulation(
            updatedState: NowCampFocusState(
                focusEnergy: state.focusEnergy + storageAllowed,
                focusRemainderTokens: remainderAfter,
                focusEarnedLocalDate: localDate,
                focusEarnedToday: earnedTodayBefore + storageAllowed
            ),
            focusEarned: storageAllowed,
            rawFocusGain: rawFocusGain,
            discardedByDailyCap: discardedByDailyCap,
            discardedByStorageCap: discardedByStorageCap
        )
    }
}

public enum LeaderTrainingOutcome: String, Codable, Sendable {
    case success
    case failure
    case guaranteedSuccess = "guaranteed_success"
}

public struct LeaderTrainingResolution: Equatable, Codable, Sendable {
    public let speciesID: String
    public let rarity: RarityTier
    public let previousRank: TrainingRank
    public let newRank: TrainingRank
    public let targetRank: TrainingRank
    public let affinityGateRank: TrainingRank
    public let probability: Double
    public let roll: Double?
    public let resonanceBefore: Int
    public let resonanceAfter: Int
    public let ceilingFailures: Int
    public let careChargeConsumed: Bool
    public let attemptCountAfter: Int
    public let outcome: LeaderTrainingOutcome
}

public enum LeaderTrainingResolverError: Error, LocalizedError {
    case invalidAffinityLevel(Int)
    case invalidResonance(Int)
    case invalidAttemptCount(Int)
    case rankAtAffinityGate(current: TrainingRank, gate: TrainingRank)
    case rankAlreadyMaximum(TrainingRank)
    case invalidProbability(Double)

    public var errorDescription: String? {
        switch self {
        case .invalidAffinityLevel(let level):
            return "Affinity gate level must be between 1 and 5: \(level)"
        case .invalidResonance(let resonance):
            return "Training resonance must be non-negative: \(resonance)"
        case .invalidAttemptCount(let count):
            return "Training attempt count must be non-negative: \(count)"
        case .rankAtAffinityGate(let current, let gate):
            return "Training rank \(current.romanNumeral) has reached affinity gate \(gate.romanNumeral)."
        case .rankAlreadyMaximum(let rank):
            return "Training rank \(rank.romanNumeral) is already maximum."
        case .invalidProbability(let probability):
            return "Training probability must be between 0 and 1 inclusive: \(probability)"
        }
    }
}

public struct LeaderTrainingResolver: Sendable {
    public let trainFocusCost: Int
    public let careFocusCost: Int

    public init(trainFocusCost: Int = 100, careFocusCost: Int = 10) {
        self.trainFocusCost = trainFocusCost
        self.careFocusCost = careFocusCost
    }

    public func resolveTrain(
        speciesID: String,
        rarity: RarityTier,
        saveTrainingSeed: String,
        currentRank: TrainingRank,
        affinityLevel: Int,
        resonance: Int,
        attemptCount: Int,
        careCharge: Bool
    ) throws -> LeaderTrainingResolution {
        guard let affinityGate = TrainingRank(rawValue: affinityLevel) else {
            throw LeaderTrainingResolverError.invalidAffinityLevel(affinityLevel)
        }
        guard resonance >= 0 else {
            throw LeaderTrainingResolverError.invalidResonance(resonance)
        }
        guard attemptCount >= 0 else {
            throw LeaderTrainingResolverError.invalidAttemptCount(attemptCount)
        }
        guard currentRank.rawValue < affinityGate.rawValue else {
            throw LeaderTrainingResolverError.rankAtAffinityGate(current: currentRank, gate: affinityGate)
        }
        guard let targetRank = currentRank.next else {
            throw LeaderTrainingResolverError.rankAlreadyMaximum(currentRank)
        }

        let probability = try successProbability(
            rarity: rarity,
            targetRank: targetRank,
            careCharge: careCharge
        )
        let ceiling = try ceilingFailures(probability: probability)
        let attemptCountAfter = attemptCount + 1

        if resonance >= ceiling {
            return LeaderTrainingResolution(
                speciesID: speciesID,
                rarity: rarity,
                previousRank: currentRank,
                newRank: targetRank,
                targetRank: targetRank,
                affinityGateRank: affinityGate,
                probability: probability,
                roll: nil,
                resonanceBefore: resonance,
                resonanceAfter: 0,
                ceilingFailures: ceiling,
                careChargeConsumed: careCharge,
                attemptCountAfter: attemptCountAfter,
                outcome: .guaranteedSuccess
            )
        }

        let roll = deterministicRoll(
            saveTrainingSeed: saveTrainingSeed,
            speciesID: speciesID,
            targetRank: targetRank,
            attemptCountAfter: attemptCountAfter
        )
        let didSucceed = roll < probability

        return LeaderTrainingResolution(
            speciesID: speciesID,
            rarity: rarity,
            previousRank: currentRank,
            newRank: didSucceed ? targetRank : currentRank,
            targetRank: targetRank,
            affinityGateRank: affinityGate,
            probability: probability,
            roll: roll,
            resonanceBefore: resonance,
            resonanceAfter: didSucceed ? 0 : resonance + 1,
            ceilingFailures: ceiling,
            careChargeConsumed: careCharge,
            attemptCountAfter: attemptCountAfter,
            outcome: didSucceed ? .success : .failure
        )
    }

    public func successProbability(
        rarity: RarityTier,
        targetRank: TrainingRank,
        careCharge: Bool
    ) throws -> Double {
        let base = baseProbability(for: rarity)
        let multiplied = base * targetRankMultiplier(targetRank)
        let boosted = multiplied + (careCharge ? 0.05 : 0)
        let probability = min(0.85, max(0.10, boosted))
        guard (0 ... 1).contains(probability) else {
            throw LeaderTrainingResolverError.invalidProbability(probability)
        }
        return probability
    }

    public func ceilingFailures(probability: Double) throws -> Int {
        guard probability > 0, probability <= 1 else {
            throw LeaderTrainingResolverError.invalidProbability(probability)
        }
        return min(10, max(2, Int(ceil(1.0 / probability))))
    }

    private func baseProbability(for rarity: RarityTier) -> Double {
        switch rarity {
        case .common: return 0.68
        case .uncommon: return 0.60
        case .rare: return 0.52
        case .epic: return 0.44
        case .legendary: return 0.36
        }
    }

    private func targetRankMultiplier(_ rank: TrainingRank) -> Double {
        switch rank {
        case .rankI, .rankII: return 1.00
        case .rankIII: return 0.78
        case .rankIV: return 0.58
        case .rankV: return 0.42
        }
    }

    private func deterministicRoll(
        saveTrainingSeed: String,
        speciesID: String,
        targetRank: TrainingRank,
        attemptCountAfter: Int
    ) -> Double {
        let key = "\(saveTrainingSeed):\(speciesID):\(targetRank.rawValue):\(attemptCountAfter)"
        var generator = SeededCaptureRandomNumberGenerator(seed: stableSeed(for: key))
        return generator.nextUnitInterval()
    }

    private func stableSeed(for key: String) -> UInt64 {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return hash == 0 ? 0x9E37_79B9_7F4A_7C15 : hash
    }
}

public struct LeaderTraitContext: Equatable, Codable, Sendable {
    public let speciesID: String
    public let homeField: FieldType
    public let rarity: RarityTier
    public let trait: TrainingTrait
    public let trainingRank: TrainingRank
    public let slotOrder: Int?

    public init(
        speciesID: String,
        homeField: FieldType,
        rarity: RarityTier,
        trait: TrainingTrait,
        trainingRank: TrainingRank,
        slotOrder: Int? = nil
    ) {
        self.speciesID = speciesID
        self.homeField = homeField
        self.rarity = rarity
        self.trait = trait
        self.trainingRank = trainingRank
        self.slotOrder = slotOrder
    }
}

public enum LeaderTraitBonusKind: String, Codable, Sendable {
    case trail
    case scout
    case capture
    case raider
}

public struct LeaderTraitBonusApplication: Equatable, Codable, Sendable {
    public let kind: LeaderTraitBonusKind
    public let speciesID: String
    public let trait: TrainingTrait
    public let field: FieldType
    public let trainingRank: TrainingRank
    public let bonusAmount: Double
    public let capApplied: Double?

    public init(
        kind: LeaderTraitBonusKind,
        speciesID: String,
        trait: TrainingTrait,
        field: FieldType,
        trainingRank: TrainingRank,
        bonusAmount: Double,
        capApplied: Double? = nil
    ) {
        self.kind = kind
        self.speciesID = speciesID
        self.trait = trait
        self.field = field
        self.trainingRank = trainingRank
        self.bonusAmount = bonusAmount
        self.capApplied = capApplied
    }
}

public enum LeaderTraitBonusPreviewUnit: String, Codable, Sendable {
    case fieldWeight
    case rarityWeightShift
    case probabilityPoints
    case raidPower
}

public struct LeaderTraitBonusPreview: Equatable, Codable, Sendable {
    public let kind: LeaderTraitBonusKind
    public let speciesID: String
    public let trait: TrainingTrait
    public let field: FieldType
    public let trainingRank: TrainingRank
    public let bonusAmount: Double
    public let unit: LeaderTraitBonusPreviewUnit
    public let isActive: Bool
    public let capApplied: Double?

    public init(
        kind: LeaderTraitBonusKind,
        speciesID: String,
        trait: TrainingTrait,
        field: FieldType,
        trainingRank: TrainingRank,
        bonusAmount: Double,
        unit: LeaderTraitBonusPreviewUnit,
        isActive: Bool,
        capApplied: Double? = nil
    ) {
        self.kind = kind
        self.speciesID = speciesID
        self.trait = trait
        self.field = field
        self.trainingRank = trainingRank
        self.bonusAmount = bonusAmount
        self.unit = unit
        self.isActive = isActive
        self.capApplied = capApplied
    }
}

public struct LeaderTraitFieldBonusResult: Equatable, Sendable {
    public let weights: [EncounterFieldWeight]
    public let application: LeaderTraitBonusApplication?
}

public struct LeaderTraitRarityBonusResult: Equatable, Sendable {
    public let weights: [EncounterRarityWeight]
    public let application: LeaderTraitBonusApplication?
}

public struct LeaderTraitCaptureBonusResult: Equatable, Sendable {
    public let probability: Double
    public let application: LeaderTraitBonusApplication?
}

public struct LeaderTraitRaidBonusResult: Equatable, Sendable {
    public let memberBonuses: [String: Int]
    public let applications: [LeaderTraitBonusApplication]
    public let totalBonus: Int
}

public struct LeaderTraitBonusResolver: Sendable {
    public init() {}

    public func previewBonus(
        lead: LeaderTraitContext,
        encounterField: FieldType? = nil,
        encounterRarity: RarityTier? = nil,
        raidField: FieldType? = nil
    ) -> LeaderTraitBonusPreview {
        switch lead.trait {
        case .trail:
            let baseWeights = EncounterGenerationConfig().baseFieldWeights.map { field, weight in
                EncounterFieldWeight(field: field, weight: weight)
            }
            let result = applyTrail(weights: baseWeights, lead: lead)
            return preview(
                kind: .trail,
                lead: lead,
                field: lead.homeField,
                application: result.application,
                fallbackAmount: 0,
                unit: .fieldWeight,
                capApplied: 8
            )
        case .scout:
            let selectedField = encounterField ?? lead.homeField
            let baseWeights = RarityTier.allCases.map { rarity in
                EncounterRarityWeight(
                    rarity: rarity,
                    weight: EncounterGenerationConfig().baseRarityWeights[rarity] ?? 0
                )
            }
            let result = applyScout(weights: baseWeights, selectedField: selectedField, lead: lead)
            return preview(
                kind: .scout,
                lead: lead,
                field: selectedField,
                application: result.application,
                fallbackAmount: 0,
                unit: .rarityWeightShift,
                capApplied: 6
            )
        case .capture:
            let selectedField = encounterField ?? lead.homeField
            let selectedRarity = encounterRarity ?? lead.rarity
            let baseProbability = (try? CaptureResolver().captureProbability(for: selectedRarity)) ?? 0
            let result = applyCapture(
                baseProbability: baseProbability,
                encounterField: selectedField,
                encounterRarity: selectedRarity,
                lead: lead
            )
            return preview(
                kind: .capture,
                lead: lead,
                field: selectedField,
                application: result.application,
                fallbackAmount: 0,
                unit: .probabilityPoints,
                capApplied: captureProbabilityCap(selectedRarity)
            )
        case .raider:
            let selectedField = raidField ?? lead.homeField
            let result = raidBonuses(raidField: selectedField, partyMembers: [lead])
            return preview(
                kind: .raider,
                lead: lead,
                field: selectedField,
                application: result.applications.first,
                fallbackAmount: 0,
                unit: .raidPower,
                capApplied: 8
            )
        }
    }

    public func applyTrail(
        weights: [EncounterFieldWeight],
        lead: LeaderTraitContext?
    ) -> LeaderTraitFieldBonusResult {
        guard let lead,
              lead.trait == .trail,
              lead.trainingRank.rawValue >= TrainingRank.rankII.rawValue else {
            return LeaderTraitFieldBonusResult(weights: weights, application: nil)
        }

        let bonus = min(Double(traitPower(for: lead)), 8)
        let updated = weights.map { weight in
            weight.field == lead.homeField
                ? EncounterFieldWeight(field: weight.field, weight: weight.weight + bonus)
                : weight
        }
        return LeaderTraitFieldBonusResult(
            weights: updated,
            application: LeaderTraitBonusApplication(
                kind: .trail,
                speciesID: lead.speciesID,
                trait: lead.trait,
                field: lead.homeField,
                trainingRank: lead.trainingRank,
                bonusAmount: bonus,
                capApplied: 8
            )
        )
    }

    public func applyScout(
        weights: [EncounterRarityWeight],
        selectedField: FieldType,
        lead: LeaderTraitContext?
    ) -> LeaderTraitRarityBonusResult {
        guard let lead,
              lead.trait == .scout,
              lead.trainingRank.rawValue >= TrainingRank.rankII.rawValue,
              lead.homeField == selectedField else {
            return LeaderTraitRarityBonusResult(weights: weights, application: nil)
        }

        let shift = min(Double(traitPower(for: lead)), 6)
        let commonWeight = weights.first { $0.rarity == .common }?.weight ?? 0
        let effectiveShift = min(shift, max(0, commonWeight - 40))
        guard effectiveShift > 0 else {
            return LeaderTraitRarityBonusResult(weights: weights, application: nil)
        }

        let updated = weights.map { weight in
            switch weight.rarity {
            case .common:
                return EncounterRarityWeight(rarity: weight.rarity, weight: weight.weight - effectiveShift)
            case .uncommon:
                return EncounterRarityWeight(rarity: weight.rarity, weight: weight.weight + effectiveShift * 0.70)
            case .rare:
                return EncounterRarityWeight(rarity: weight.rarity, weight: weight.weight + effectiveShift * 0.25)
            case .epic:
                return EncounterRarityWeight(rarity: weight.rarity, weight: weight.weight + effectiveShift * 0.05)
            case .legendary:
                return weight
            }
        }

        return LeaderTraitRarityBonusResult(
            weights: updated,
            application: LeaderTraitBonusApplication(
                kind: .scout,
                speciesID: lead.speciesID,
                trait: lead.trait,
                field: selectedField,
                trainingRank: lead.trainingRank,
                bonusAmount: effectiveShift,
                capApplied: 6
            )
        )
    }

    public func applyCapture(
        baseProbability: Double,
        encounterField: FieldType,
        encounterRarity: RarityTier,
        lead: LeaderTraitContext?
    ) -> LeaderTraitCaptureBonusResult {
        guard let lead,
              lead.trait == .capture,
              lead.trainingRank.rawValue >= TrainingRank.rankII.rawValue,
              lead.homeField == encounterField else {
            return LeaderTraitCaptureBonusResult(probability: baseProbability, application: nil)
        }

        let bonus = captureBonus(leadRarity: lead.rarity, rank: lead.trainingRank)
        let cap = captureProbabilityCap(encounterRarity)
        let probability = min(cap, baseProbability + bonus)
        guard probability > baseProbability else {
            return LeaderTraitCaptureBonusResult(probability: baseProbability, application: nil)
        }

        return LeaderTraitCaptureBonusResult(
            probability: probability,
            application: LeaderTraitBonusApplication(
                kind: .capture,
                speciesID: lead.speciesID,
                trait: lead.trait,
                field: encounterField,
                trainingRank: lead.trainingRank,
                bonusAmount: max(0, probability - baseProbability),
                capApplied: cap
            )
        )
    }

    public func raidBonuses(
        raidField: FieldType?,
        partyMembers: [LeaderTraitContext]
    ) -> LeaderTraitRaidBonusResult {
        guard let raidField else {
            return LeaderTraitRaidBonusResult(memberBonuses: [:], applications: [], totalBonus: 0)
        }

        var remainingCap = 8
        var memberBonuses: [String: Int] = [:]
        var applications: [LeaderTraitBonusApplication] = []

        for member in partyMembers.sorted(by: { lhs, rhs in
            let leftSlot = lhs.slotOrder ?? Int.max
            let rightSlot = rhs.slotOrder ?? Int.max
            if leftSlot == rightSlot { return lhs.speciesID < rhs.speciesID }
            return leftSlot < rightSlot
        }) {
            guard remainingCap > 0,
                  member.trait == .raider,
                  member.trainingRank.rawValue >= TrainingRank.rankII.rawValue,
                  member.homeField == raidField else {
                continue
            }

            let rawBonus = member.trainingRank.rankPower + raidRarityBonus(member.rarity)
            let applied = min(rawBonus, remainingCap)
            guard applied > 0 else { continue }

            remainingCap -= applied
            memberBonuses[member.speciesID] = applied
            applications.append(
                LeaderTraitBonusApplication(
                    kind: .raider,
                    speciesID: member.speciesID,
                    trait: member.trait,
                    field: raidField,
                    trainingRank: member.trainingRank,
                    bonusAmount: Double(applied),
                    capApplied: 8
                )
            )
        }

        return LeaderTraitRaidBonusResult(
            memberBonuses: memberBonuses,
            applications: applications,
            totalBonus: 8 - remainingCap
        )
    }

    private func preview(
        kind: LeaderTraitBonusKind,
        lead: LeaderTraitContext,
        field: FieldType,
        application: LeaderTraitBonusApplication?,
        fallbackAmount: Double,
        unit: LeaderTraitBonusPreviewUnit,
        capApplied: Double?
    ) -> LeaderTraitBonusPreview {
        LeaderTraitBonusPreview(
            kind: kind,
            speciesID: lead.speciesID,
            trait: lead.trait,
            field: field,
            trainingRank: lead.trainingRank,
            bonusAmount: application?.bonusAmount ?? fallbackAmount,
            unit: unit,
            isActive: application != nil,
            capApplied: application?.capApplied ?? capApplied
        )
    }

    private func traitPower(for lead: LeaderTraitContext) -> Int {
        lead.trainingRank.rankPower + rarityPowerTier(lead.rarity)
    }

    private func rarityPowerTier(_ rarity: RarityTier) -> Int {
        switch rarity {
        case .common: return 1
        case .uncommon: return 2
        case .rare: return 3
        case .epic: return 4
        case .legendary: return 5
        }
    }

    private func captureBonus(leadRarity: RarityTier, rank: TrainingRank) -> Double {
        let points: Int
        switch (leadRarity, rank) {
        case (_, .rankI):
            points = 0
        case (.common, .rankII):
            points = 0
        case (.common, .rankIII), (.uncommon, .rankII), (.uncommon, .rankIII),
             (.rare, .rankII), (.epic, .rankII), (.legendary, .rankII):
            points = 1
        case (.common, .rankIV), (.uncommon, .rankIV), (.rare, .rankIII), (.epic, .rankIII):
            points = 2
        case (.common, .rankV), (.uncommon, .rankV), (.rare, .rankIV), (.legendary, .rankIII):
            points = 3
        case (.rare, .rankV), (.epic, .rankIV), (.legendary, .rankIV):
            points = 4
        case (.epic, .rankV), (.legendary, .rankV):
            points = 5
        }
        return Double(points) / 100.0
    }

    private func captureProbabilityCap(_ encounterRarity: RarityTier) -> Double {
        switch encounterRarity {
        case .common: return 0.95
        case .uncommon: return 0.82
        case .rare: return 0.48
        case .epic: return 0.24
        case .legendary: return 0.10
        }
    }

    private func raidRarityBonus(_ rarity: RarityTier) -> Int {
        switch rarity {
        case .common, .uncommon: return 0
        case .rare, .epic: return 1
        case .legendary: return 2
        }
    }
}
