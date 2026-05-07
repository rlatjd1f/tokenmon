import Foundation
import TokenmonDomain

/// P0 capture odds from `game-rules.md` kept in provider-neutral gameplay code.
public struct CaptureResolverConfig: Equatable, Sendable {
    public let commonProbability: Double
    public let uncommonProbability: Double
    public let rareProbability: Double
    public let epicProbability: Double
    public let legendaryProbability: Double

    public init(
        commonProbability: Double = 0.88,
        uncommonProbability: Double = 0.68,
        rareProbability: Double = 0.36,
        epicProbability: Double = 0.16,
        legendaryProbability: Double = 0.06
    ) {
        self.commonProbability = commonProbability
        self.uncommonProbability = uncommonProbability
        self.rareProbability = rareProbability
        self.epicProbability = epicProbability
        self.legendaryProbability = legendaryProbability
    }

    public func probability(for rarity: RarityTier) -> Double {
        switch rarity {
        case .common:
            return commonProbability
        case .uncommon:
            return uncommonProbability
        case .rare:
            return rareProbability
        case .epic:
            return epicProbability
        case .legendary:
            return legendaryProbability
        }
    }
}

/// Narrow RNG boundary so tests can supply deterministic rolls without changing resolver logic.
public protocol CaptureRandomNumberGenerator: Sendable {
    mutating func nextUnitInterval() -> Double
}

public struct SystemCaptureRandomNumberGenerator: CaptureRandomNumberGenerator {
    public init() {}

    public mutating func nextUnitInterval() -> Double {
        Double.random(in: 0 ..< 1)
    }
}

/// Small deterministic generator for repeatable encounter/capture tests.
public struct SeededCaptureRandomNumberGenerator: CaptureRandomNumberGenerator {
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

public struct CaptureResolution: Equatable, Codable, Sendable {
    public let rarity: RarityTier
    public let captureProbability: Double
    public let captureRoll: Double
    public let outcome: EncounterOutcome
}

public enum CaptureResolverError: Error, LocalizedError {
    case invalidProbability(rarity: RarityTier, value: Double)
    case invalidRoll(Double)

    public var errorDescription: String? {
        switch self {
        case .invalidProbability(let rarity, let value):
            return "capture probability for rarity \(rarity.rawValue) must be between 0 and 1 inclusive: \(value)"
        case .invalidRoll(let value):
            return "capture roll must be in [0, 1): \(value)"
        }
    }
}

public struct CaptureResolver {
    public let config: CaptureResolverConfig

    public init(config: CaptureResolverConfig = CaptureResolverConfig()) {
        self.config = config
    }

    public func captureProbability(for rarity: RarityTier) throws -> Double {
        let probability = config.probability(for: rarity)
        try validateProbability(probability, rarity: rarity)
        return probability
    }

    public func resolve(rarity: RarityTier, roll: Double) throws -> CaptureResolution {
        let probability = try captureProbability(for: rarity)
        return try resolve(rarity: rarity, probability: probability, roll: roll)
    }

    public func resolve(rarity: RarityTier, probability: Double, roll: Double) throws -> CaptureResolution {
        try validateProbability(probability, rarity: rarity)

        guard (0 ..< 1).contains(roll) else {
            throw CaptureResolverError.invalidRoll(roll)
        }

        return CaptureResolution(
            rarity: rarity,
            captureProbability: probability,
            captureRoll: roll,
            outcome: roll < probability ? .captured : .escaped
        )
    }

    public func resolve<RNG: CaptureRandomNumberGenerator>(
        rarity: RarityTier,
        using generator: inout RNG
    ) throws -> CaptureResolution {
        try resolve(rarity: rarity, roll: generator.nextUnitInterval())
    }

    public func resolve<RNG: CaptureRandomNumberGenerator>(
        species: SpeciesDefinition,
        using generator: inout RNG
    ) throws -> CaptureResolution {
        try resolve(rarity: species.rarity, using: &generator)
    }

    private func validateProbability(_ probability: Double, rarity: RarityTier) throws {
        guard (0 ... 1).contains(probability) else {
            throw CaptureResolverError.invalidProbability(rarity: rarity, value: probability)
        }
    }
}
