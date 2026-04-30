import Foundation
import TokenmonDomain

public enum SpeciesAffinityOutcome: String, Codable, Equatable, Sendable {
    case initialized
    case success
    case failure
    case guaranteedSuccess = "guaranteed_success"
    case maxLevel = "max_level"
}

public struct SpeciesAffinityConfig: Equatable, Sendable {
    public let minimumLevel: Int
    public let maximumLevel: Int
    public let minimumProbability: Double
    public let minimumCeilingFailures: Int
    public let maximumCeilingFailures: Int

    public init(
        minimumLevel: Int = 1,
        maximumLevel: Int = 5,
        minimumProbability: Double = 0.05,
        minimumCeilingFailures: Int = 2,
        maximumCeilingFailures: Int = 10
    ) {
        self.minimumLevel = minimumLevel
        self.maximumLevel = maximumLevel
        self.minimumProbability = minimumProbability
        self.minimumCeilingFailures = minimumCeilingFailures
        self.maximumCeilingFailures = maximumCeilingFailures
    }
}

public struct SpeciesAffinityResolution: Equatable, Codable, Sendable {
    public let speciesID: String
    public let rarity: RarityTier
    public let capturedCountAfter: Int64
    public let previousLevel: Int
    public let newLevel: Int
    public let targetLevel: Int?
    public let probability: Double?
    public let roll: Double?
    public let pityCountBefore: Int
    public let pityCountAfter: Int
    public let ceilingFailures: Int?
    public let outcome: SpeciesAffinityOutcome
}

public enum SpeciesAffinityResolverError: Error, LocalizedError {
    case invalidCurrentLevel(Int)
    case invalidPityCount(Int)
    case invalidCapturedCount(Int64)
    case invalidTargetLevel(Int)
    case invalidProbability(Double)

    public var errorDescription: String? {
        switch self {
        case .invalidCurrentLevel(let level):
            return "affinity level must be between 0 and 5: \(level)"
        case .invalidPityCount(let count):
            return "affinity pity count must be non-negative: \(count)"
        case .invalidCapturedCount(let count):
            return "captured count after affinity update must be positive: \(count)"
        case .invalidTargetLevel(let level):
            return "affinity target level must be between II and V: \(level)"
        case .invalidProbability(let probability):
            return "affinity probability must be between 0 and 1 inclusive: \(probability)"
        }
    }
}

public struct SpeciesAffinityResolver: Sendable {
    public let config: SpeciesAffinityConfig

    public init(config: SpeciesAffinityConfig = SpeciesAffinityConfig()) {
        self.config = config
    }

    public func resolveCapture(
        speciesID: String,
        rarity: RarityTier,
        encounterSeedContextID: String,
        capturedCountAfter: Int64,
        currentLevel: Int,
        pityCount: Int
    ) throws -> SpeciesAffinityResolution {
        try validate(currentLevel: currentLevel, pityCount: pityCount, capturedCountAfter: capturedCountAfter)

        if currentLevel == 0 {
            return SpeciesAffinityResolution(
                speciesID: speciesID,
                rarity: rarity,
                capturedCountAfter: capturedCountAfter,
                previousLevel: 0,
                newLevel: config.minimumLevel,
                targetLevel: nil,
                probability: nil,
                roll: nil,
                pityCountBefore: 0,
                pityCountAfter: 0,
                ceilingFailures: nil,
                outcome: .initialized
            )
        }

        if currentLevel >= config.maximumLevel {
            return SpeciesAffinityResolution(
                speciesID: speciesID,
                rarity: rarity,
                capturedCountAfter: capturedCountAfter,
                previousLevel: config.maximumLevel,
                newLevel: config.maximumLevel,
                targetLevel: nil,
                probability: nil,
                roll: nil,
                pityCountBefore: pityCount,
                pityCountAfter: 0,
                ceilingFailures: nil,
                outcome: .maxLevel
            )
        }

        let targetLevel = currentLevel + 1
        let probability = try successProbability(rarity: rarity, targetLevel: targetLevel)
        let ceiling = try ceilingFailures(probability: probability)

        if pityCount >= ceiling {
            return SpeciesAffinityResolution(
                speciesID: speciesID,
                rarity: rarity,
                capturedCountAfter: capturedCountAfter,
                previousLevel: currentLevel,
                newLevel: targetLevel,
                targetLevel: targetLevel,
                probability: probability,
                roll: nil,
                pityCountBefore: pityCount,
                pityCountAfter: 0,
                ceilingFailures: ceiling,
                outcome: .guaranteedSuccess
            )
        }

        let roll = deterministicRoll(
            encounterSeedContextID: encounterSeedContextID,
            speciesID: speciesID,
            capturedCountAfter: capturedCountAfter,
            targetLevel: targetLevel
        )
        let didSucceed = roll < probability

        return SpeciesAffinityResolution(
            speciesID: speciesID,
            rarity: rarity,
            capturedCountAfter: capturedCountAfter,
            previousLevel: currentLevel,
            newLevel: didSucceed ? targetLevel : currentLevel,
            targetLevel: targetLevel,
            probability: probability,
            roll: roll,
            pityCountBefore: pityCount,
            pityCountAfter: didSucceed ? 0 : pityCount + 1,
            ceilingFailures: ceiling,
            outcome: didSucceed ? .success : .failure
        )
    }

    public func successProbability(rarity: RarityTier, targetLevel: Int) throws -> Double {
        guard (2 ... config.maximumLevel).contains(targetLevel) else {
            throw SpeciesAffinityResolverError.invalidTargetLevel(targetLevel)
        }
        return max(config.minimumProbability, baseProbability(for: rarity) * targetLevelMultiplier(targetLevel))
    }

    public func ceilingFailures(probability: Double) throws -> Int {
        guard (0 ... 1).contains(probability), probability > 0 else {
            throw SpeciesAffinityResolverError.invalidProbability(probability)
        }
        let raw = Int(ceil(1.0 / probability))
        return min(config.maximumCeilingFailures, max(config.minimumCeilingFailures, raw))
    }

    public static func migratedLevel(capturedCount: Int64) -> Int {
        switch capturedCount {
        case 25...:
            return 4
        case 10...24:
            return 3
        case 3...9:
            return 2
        default:
            return 1
        }
    }

    public static func romanLevel(_ level: Int) -> String {
        switch level {
        case 1:
            return "I"
        case 2:
            return "II"
        case 3:
            return "III"
        case 4:
            return "IV"
        case 5:
            return "V"
        default:
            return "\(level)"
        }
    }

    private func validate(currentLevel: Int, pityCount: Int, capturedCountAfter: Int64) throws {
        guard (0 ... config.maximumLevel).contains(currentLevel) else {
            throw SpeciesAffinityResolverError.invalidCurrentLevel(currentLevel)
        }
        guard pityCount >= 0 else {
            throw SpeciesAffinityResolverError.invalidPityCount(pityCount)
        }
        guard capturedCountAfter > 0 else {
            throw SpeciesAffinityResolverError.invalidCapturedCount(capturedCountAfter)
        }
    }

    private func baseProbability(for rarity: RarityTier) -> Double {
        switch rarity {
        case .common:
            return 0.50
        case .uncommon:
            return 0.42
        case .rare:
            return 0.34
        case .epic:
            return 0.26
        case .legendary:
            return 0.18
        }
    }

    private func targetLevelMultiplier(_ targetLevel: Int) -> Double {
        switch targetLevel {
        case 2:
            return 1.00
        case 3:
            return 0.78
        case 4:
            return 0.58
        case 5:
            return 0.42
        default:
            return 1.00
        }
    }

    private func deterministicRoll(
        encounterSeedContextID: String,
        speciesID: String,
        capturedCountAfter: Int64,
        targetLevel: Int
    ) -> Double {
        let key = "\(encounterSeedContextID):\(speciesID):\(capturedCountAfter):\(targetLevel)"
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
