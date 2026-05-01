import Foundation
import TokenmonDomain

public protocol EncounterRandomNumberGenerator: Sendable {
    mutating func nextUnitInterval() -> Double
}

public struct SystemEncounterRandomNumberGenerator: EncounterRandomNumberGenerator {
    public init() {}

    public mutating func nextUnitInterval() -> Double {
        Double.random(in: 0..<1)
    }
}

/// Small deterministic generator for repeatable encounter tests and replay-safe encounter resolution.
public struct SeededEncounterRandomNumberGenerator: EncounterRandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed
    }

    public mutating func nextUnitInterval() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        mixed = mixed ^ (mixed >> 31)

        let upper53Bits = mixed >> 11
        return Double(upper53Bits) / 9_007_199_254_740_992.0
    }
}

public struct EncounterFieldWeight: Equatable, Codable, Sendable {
    public let field: FieldType
    public let weight: Double

    public init(field: FieldType, weight: Double) {
        self.field = field
        self.weight = weight
    }
}

public struct EncounterRarityWeight: Equatable, Codable, Sendable {
    public let rarity: RarityTier
    public let weight: Double

    public init(rarity: RarityTier, weight: Double) {
        self.rarity = rarity
        self.weight = weight
    }
}

public struct EncounterGenerationConfig: Equatable, Sendable {
    public let repeatedFieldWeight: Double
    public let baseFieldWeights: [FieldType: Double]
    public let baseRarityWeights: [RarityTier: Double]
    public let speciesCatalog: [SpeciesDefinition]
    public let immediateRepeatSpeciesMultiplier: Double
    public let recentRepeatSpeciesMultiplier: Double
    public let recentSpeciesWindow: Int
    public let capturedCountPenaltyPerCapture: Double

    public init(
        repeatedFieldWeight: Double = 5,
        baseFieldWeights: [FieldType: Double] = [
            .grassland: 32,
            .ice: 20,
            .coast: 24,
            .sky: 24,
        ],
        baseRarityWeights: [RarityTier: Double] = [
            .common: 54,
            .uncommon: 28,
            .rare: 11,
            .epic: 5,
            .legendary: 2,
        ],
        speciesCatalog: [SpeciesDefinition] = SpeciesCatalog.all,
        immediateRepeatSpeciesMultiplier: Double = 0.05,
        recentRepeatSpeciesMultiplier: Double = 0.35,
        recentSpeciesWindow: Int = 5,
        capturedCountPenaltyPerCapture: Double = 0.25
    ) {
        self.repeatedFieldWeight = repeatedFieldWeight
        self.baseFieldWeights = baseFieldWeights
        self.baseRarityWeights = baseRarityWeights
        self.speciesCatalog = speciesCatalog
        self.immediateRepeatSpeciesMultiplier = immediateRepeatSpeciesMultiplier
        self.recentRepeatSpeciesMultiplier = recentRepeatSpeciesMultiplier
        self.recentSpeciesWindow = recentSpeciesWindow
        self.capturedCountPenaltyPerCapture = capturedCountPenaltyPerCapture
    }
}

public struct EncounterGenerationContext: Equatable, Sendable {
    public let threshold: EncounterThresholdCrossedSnapshot
    public let usageSampleID: Int64
    public let provider: ProviderCode?
    public let providerSessionRowID: Int64?
    public let occurredAt: String
    public let burstIntensityBand: Int
    public let priorEncounterFields: [FieldType]
    public let priorEncounterSpeciesIDs: [String]
    public let capturedSpeciesCounts: [String: Int64]
    public let encounterID: String?
    public let leaderTraitContext: LeaderTraitContext?

    public init(
        threshold: EncounterThresholdCrossedSnapshot,
        usageSampleID: Int64,
        provider: ProviderCode? = nil,
        providerSessionRowID: Int64? = nil,
        occurredAt: String,
        burstIntensityBand: Int,
        priorEncounterFields: [FieldType] = [],
        priorEncounterSpeciesIDs: [String] = [],
        capturedSpeciesCounts: [String: Int64] = [:],
        encounterID: String? = nil,
        leaderTraitContext: LeaderTraitContext? = nil
    ) {
        self.threshold = threshold
        self.usageSampleID = usageSampleID
        self.provider = provider
        self.providerSessionRowID = providerSessionRowID
        self.occurredAt = occurredAt
        self.burstIntensityBand = burstIntensityBand
        self.priorEncounterFields = priorEncounterFields
        self.priorEncounterSpeciesIDs = priorEncounterSpeciesIDs
        self.capturedSpeciesCounts = capturedSpeciesCounts
        self.encounterID = encounterID
        self.leaderTraitContext = leaderTraitContext
    }

    public var encounterSeedContextID: String {
        "usage-sample-\(usageSampleID):threshold-\(threshold.thresholdIndexGlobal)"
    }
}

public struct EncounterFieldSelection: Equatable, Codable, Sendable {
    public let selectedField: FieldType
    public let priorFieldHistorySnapshot: [FieldType]
    public let antiRepeatApplied: Bool
    public let fieldWeightsEffective: [EncounterFieldWeight]
    public let roll: Double
    public let leaderTraitBonusApplication: LeaderTraitBonusApplication?

    public init(
        selectedField: FieldType,
        priorFieldHistorySnapshot: [FieldType],
        antiRepeatApplied: Bool,
        fieldWeightsEffective: [EncounterFieldWeight],
        roll: Double,
        leaderTraitBonusApplication: LeaderTraitBonusApplication? = nil
    ) {
        self.selectedField = selectedField
        self.priorFieldHistorySnapshot = priorFieldHistorySnapshot
        self.antiRepeatApplied = antiRepeatApplied
        self.fieldWeightsEffective = fieldWeightsEffective
        self.roll = roll
        self.leaderTraitBonusApplication = leaderTraitBonusApplication
    }
}

public struct EncounterRaritySelection: Equatable, Codable, Sendable {
    public let selectedRarity: RarityTier
    public let rarityWeightsEffective: [EncounterRarityWeight]
    public let roll: Double
    public let leaderTraitBonusApplication: LeaderTraitBonusApplication?

    public init(
        selectedRarity: RarityTier,
        rarityWeightsEffective: [EncounterRarityWeight],
        roll: Double,
        leaderTraitBonusApplication: LeaderTraitBonusApplication? = nil
    ) {
        self.selectedRarity = selectedRarity
        self.rarityWeightsEffective = rarityWeightsEffective
        self.roll = roll
        self.leaderTraitBonusApplication = leaderTraitBonusApplication
    }
}

public struct EncounterSpeciesSelection: Equatable, Codable, Sendable {
    public let selectedSpecies: SpeciesDefinition
    public let candidateSpeciesIDs: [String]
    public let roll: Double

    public init(selectedSpecies: SpeciesDefinition, candidateSpeciesIDs: [String], roll: Double) {
        self.selectedSpecies = selectedSpecies
        self.candidateSpeciesIDs = candidateSpeciesIDs
        self.roll = roll
    }
}

public struct GeneratedEncounter: Equatable, Codable, Sendable {
    public let encounterID: String
    public let encounterSeedContextID: String
    public let encounterSequence: Int64
    public let thresholdIndexGlobal: Int64
    public let usageSampleID: Int64
    public let provider: ProviderCode?
    public let providerSessionRowID: Int64?
    public let occurredAt: String
    public let field: FieldType
    public let rarity: RarityTier
    public let species: SpeciesDefinition
    public let burstIntensityBand: Int
    public let fieldSelection: EncounterFieldSelection
    public let raritySelection: EncounterRaritySelection
    public let speciesSelection: EncounterSpeciesSelection
    public let traitBonusApplications: [LeaderTraitBonusApplication]

    public init(
        encounterID: String,
        encounterSeedContextID: String,
        encounterSequence: Int64,
        thresholdIndexGlobal: Int64,
        usageSampleID: Int64,
        provider: ProviderCode?,
        providerSessionRowID: Int64?,
        occurredAt: String,
        field: FieldType,
        rarity: RarityTier,
        species: SpeciesDefinition,
        burstIntensityBand: Int,
        fieldSelection: EncounterFieldSelection,
        raritySelection: EncounterRaritySelection,
        speciesSelection: EncounterSpeciesSelection,
        traitBonusApplications: [LeaderTraitBonusApplication] = []
    ) {
        self.encounterID = encounterID
        self.encounterSeedContextID = encounterSeedContextID
        self.encounterSequence = encounterSequence
        self.thresholdIndexGlobal = thresholdIndexGlobal
        self.usageSampleID = usageSampleID
        self.provider = provider
        self.providerSessionRowID = providerSessionRowID
        self.occurredAt = occurredAt
        self.field = field
        self.rarity = rarity
        self.species = species
        self.burstIntensityBand = burstIntensityBand
        self.fieldSelection = fieldSelection
        self.raritySelection = raritySelection
        self.speciesSelection = speciesSelection
        self.traitBonusApplications = traitBonusApplications
    }
}

public enum EncounterGenerationError: Error, LocalizedError {
    case invalidRepeatedFieldWeight(Double)
    case invalidFieldWeights
    case invalidRarityWeights
    case invalidRandomRoll(Double)
    case missingEligibleSpecies(field: FieldType, rarity: RarityTier)

    public var errorDescription: String? {
        switch self {
        case .invalidRepeatedFieldWeight(let weight):
            return "repeated field weight must be positive: \(weight)"
        case .invalidFieldWeights:
            return "field weights must cover every field with positive weights"
        case .invalidRarityWeights:
            return "rarity weights must cover every rarity tier with positive weights"
        case .invalidRandomRoll(let roll):
            return "encounter RNG roll must be finite and in [0, 1): \(roll)"
        case .missingEligibleSpecies(let field, let rarity):
            return "no active species available for field=\(field.rawValue) rarity=\(rarity.rawValue)"
        }
    }
}

public struct EncounterGenerator {
    public let config: EncounterGenerationConfig

    public init(config: EncounterGenerationConfig = EncounterGenerationConfig()) {
        self.config = config
    }

    public func generateEncounter(
        context: EncounterGenerationContext
    ) throws -> GeneratedEncounter {
        var generator = SystemEncounterRandomNumberGenerator()
        return try generateEncounter(context: context, using: &generator)
    }

    public func generateEncounter<RNG: EncounterRandomNumberGenerator>(
        context: EncounterGenerationContext,
        using generator: inout RNG
    ) throws -> GeneratedEncounter {
        try validate(config: config)

        let fieldSelection = try selectField(
            priorEncounterFields: context.priorEncounterFields,
            leaderTraitContext: context.leaderTraitContext,
            using: &generator
        )
        let raritySelection = try selectRarity(
            selectedField: fieldSelection.selectedField,
            leaderTraitContext: context.leaderTraitContext,
            using: &generator
        )
        let speciesSelection = try selectSpecies(
            field: fieldSelection.selectedField,
            rarity: raritySelection.selectedRarity,
            priorEncounterSpeciesIDs: context.priorEncounterSpeciesIDs,
            capturedSpeciesCounts: context.capturedSpeciesCounts,
            using: &generator
        )
        let encounterID = context.encounterID ?? UUID().uuidString.lowercased()
        let bonusApplications = [
            fieldSelection.leaderTraitBonusApplication,
            raritySelection.leaderTraitBonusApplication,
        ].compactMap { $0 }

        return GeneratedEncounter(
            encounterID: encounterID,
            encounterSeedContextID: context.encounterSeedContextID,
            encounterSequence: context.threshold.thresholdIndexGlobal,
            thresholdIndexGlobal: context.threshold.thresholdIndexGlobal,
            usageSampleID: context.usageSampleID,
            provider: context.provider,
            providerSessionRowID: context.providerSessionRowID,
            occurredAt: context.occurredAt,
            field: fieldSelection.selectedField,
            rarity: raritySelection.selectedRarity,
            species: speciesSelection.selectedSpecies,
            burstIntensityBand: context.burstIntensityBand,
            fieldSelection: fieldSelection,
            raritySelection: raritySelection,
            speciesSelection: speciesSelection,
            traitBonusApplications: bonusApplications
        )
    }

    private func validate(config: EncounterGenerationConfig) throws {
        guard config.repeatedFieldWeight > 0 else {
            throw EncounterGenerationError.invalidRepeatedFieldWeight(config.repeatedFieldWeight)
        }

        let hasAllFieldWeights = FieldType.allCases.allSatisfy { field in
            guard let weight = config.baseFieldWeights[field] else {
                return false
            }
            return weight > 0
        }
        guard hasAllFieldWeights else {
            throw EncounterGenerationError.invalidFieldWeights
        }

        let hasAllRarityWeights = RarityTier.allCases.allSatisfy { rarity in
            guard let weight = config.baseRarityWeights[rarity] else {
                return false
            }
            return weight > 0
        }
        guard hasAllRarityWeights else {
            throw EncounterGenerationError.invalidRarityWeights
        }

        guard config.immediateRepeatSpeciesMultiplier > 0,
              config.immediateRepeatSpeciesMultiplier <= 1,
              config.recentRepeatSpeciesMultiplier > 0,
              config.recentRepeatSpeciesMultiplier <= 1,
              config.recentSpeciesWindow >= 1,
              config.capturedCountPenaltyPerCapture >= 0 else {
            throw EncounterGenerationError.invalidRarityWeights
        }
    }

    private func selectField<RNG: EncounterRandomNumberGenerator>(
        priorEncounterFields: [FieldType],
        leaderTraitContext: LeaderTraitContext?,
        using generator: inout RNG
    ) throws -> EncounterFieldSelection {
        let historySnapshot = Array(priorEncounterFields.suffix(2))
        let antiRepeatField = historySnapshot.count == 2 && historySnapshot[0] == historySnapshot[1]
            ? historySnapshot[0]
            : nil
        let baseWeights = adjustedFieldWeights(forRepeatedField: antiRepeatField)
        let traitResult = LeaderTraitBonusResolver().applyTrail(
            weights: baseWeights,
            lead: leaderTraitContext
        )
        let roll = try normalizedRoll(using: &generator)
        let selectedField = try weightedSelection(
            options: traitResult.weights,
            roll: roll,
            value: \.field,
            weight: \.weight
        )

        return EncounterFieldSelection(
            selectedField: selectedField,
            priorFieldHistorySnapshot: historySnapshot,
            antiRepeatApplied: antiRepeatField != nil,
            fieldWeightsEffective: traitResult.weights,
            roll: roll,
            leaderTraitBonusApplication: traitResult.application
        )
    }

    private func selectRarity<RNG: EncounterRandomNumberGenerator>(
        selectedField: FieldType,
        leaderTraitContext: LeaderTraitContext?,
        using generator: inout RNG
    ) throws -> EncounterRaritySelection {
        let baseWeights = RarityTier.allCases.map { rarity in
            EncounterRarityWeight(rarity: rarity, weight: config.baseRarityWeights[rarity] ?? 0)
        }
        let traitResult = LeaderTraitBonusResolver().applyScout(
            weights: baseWeights,
            selectedField: selectedField,
            lead: leaderTraitContext
        )
        let roll = try normalizedRoll(using: &generator)
        let selectedRarity = try weightedSelection(
            options: traitResult.weights,
            roll: roll,
            value: \.rarity,
            weight: \.weight
        )

        return EncounterRaritySelection(
            selectedRarity: selectedRarity,
            rarityWeightsEffective: traitResult.weights,
            roll: roll,
            leaderTraitBonusApplication: traitResult.application
        )
    }

    private func selectSpecies<RNG: EncounterRandomNumberGenerator>(
        field: FieldType,
        rarity: RarityTier,
        priorEncounterSpeciesIDs: [String],
        capturedSpeciesCounts: [String: Int64],
        using generator: inout RNG
    ) throws -> EncounterSpeciesSelection {
        let candidates = config.speciesCatalog
            .filter { $0.isActive && $0.field == field && $0.rarity == rarity }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.id < rhs.id
                }
                return lhs.sortOrder < rhs.sortOrder
            }

        guard !candidates.isEmpty else {
            throw EncounterGenerationError.missingEligibleSpecies(field: field, rarity: rarity)
        }

        let recentSpeciesIDs = Array(priorEncounterSpeciesIDs.prefix(config.recentSpeciesWindow))
        let immediateSpeciesID = recentSpeciesIDs.first
        let weightedCandidates = candidates.map { species in
            weightedSpeciesMultiplier(
                speciesID: species.id,
                immediateSpeciesID: immediateSpeciesID,
                recentSpeciesIDs: recentSpeciesIDs,
                capturedCount: capturedSpeciesCounts[species.id] ?? 0
            )
        }

        let roll = try normalizedRoll(using: &generator)
        let selectedSpecies = try weightedSelection(
            options: Array(zip(candidates, weightedCandidates)),
            roll: roll,
            value: { option in option.0 },
            weight: { option in option.1 }
        )

        return EncounterSpeciesSelection(
            selectedSpecies: selectedSpecies,
            candidateSpeciesIDs: candidates.map(\.id),
            roll: roll
        )
    }

    private func weightedSpeciesMultiplier(
        speciesID: String,
        immediateSpeciesID: String?,
        recentSpeciesIDs: [String],
        capturedCount: Int64
    ) -> Double {
        var multiplier = 1.0

        if speciesID == immediateSpeciesID {
            multiplier *= config.immediateRepeatSpeciesMultiplier
        } else if recentSpeciesIDs.contains(speciesID) {
            multiplier *= config.recentRepeatSpeciesMultiplier
        }

        if capturedCount > 0 {
            multiplier *= 1 / (1 + (Double(capturedCount) * config.capturedCountPenaltyPerCapture))
        }

        return max(multiplier, 0.0001)
    }

    private func adjustedFieldWeights(forRepeatedField repeatedField: FieldType?) -> [EncounterFieldWeight] {
        let baseWeights = FieldType.allCases.map { field in
            EncounterFieldWeight(field: field, weight: config.baseFieldWeights[field] ?? 0)
        }

        guard let repeatedField,
              let repeatedBaseWeight = config.baseFieldWeights[repeatedField] else {
            return baseWeights
        }

        let penalizedWeight = min(config.repeatedFieldWeight, repeatedBaseWeight)
        let removedWeight = max(0, repeatedBaseWeight - penalizedWeight)
        guard removedWeight > 0 else {
            return baseWeights
        }

        let remainingWeightTotal = baseWeights
            .filter { $0.field != repeatedField }
            .reduce(0) { partialResult, entry in
                partialResult + entry.weight
            }

        guard remainingWeightTotal > 0 else {
            return baseWeights
        }

        return baseWeights.map { entry in
            guard entry.field != repeatedField else {
                return EncounterFieldWeight(field: entry.field, weight: penalizedWeight)
            }

            let proportionalShare = entry.weight / remainingWeightTotal
            return EncounterFieldWeight(
                field: entry.field,
                weight: entry.weight + (removedWeight * proportionalShare)
            )
        }
    }

    private func normalizedRoll<RNG: EncounterRandomNumberGenerator>(
        using generator: inout RNG
    ) throws -> Double {
        let roll = generator.nextUnitInterval()

        guard roll.isFinite, roll >= 0 else {
            throw EncounterGenerationError.invalidRandomRoll(roll)
        }

        if roll < 1 {
            return roll
        }

        if roll == 1 {
            return roll.nextDown
        }

        throw EncounterGenerationError.invalidRandomRoll(roll)
    }

    private func weightedSelection<Option, Value>(
        options: [Option],
        roll: Double,
        value: (Option) -> Value,
        weight: (Option) -> Double
    ) throws -> Value {
        let totalWeight = options.reduce(0) { partialResult, option in
            partialResult + weight(option)
        }

        guard totalWeight > 0 else {
            throw EncounterGenerationError.invalidFieldWeights
        }

        let threshold = roll * totalWeight
        var cumulativeWeight = 0.0

        for (index, option) in options.enumerated() {
            cumulativeWeight += weight(option)
            if threshold < cumulativeWeight || index == options.index(before: options.endIndex) {
                return value(option)
            }
        }

        throw EncounterGenerationError.invalidRandomRoll(roll)
    }
}
