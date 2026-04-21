import Foundation

public enum ExplorationDomainEventType: String, Sendable {
    case explorationProgressUpdated = "exploration_progress_updated"
    case encounterThresholdCrossed = "encounter_threshold_crossed"
}

public struct ExplorationAccumulatorConfig: Equatable, Sendable {
    /// Lowest normalized-token threshold the dynamic pacing curve can sample.
    public let minimumEncounterThresholdTokens: Int64

    /// Highest normalized-token threshold the dynamic pacing curve can sample.
    public let maximumEncounterThresholdTokens: Int64

    /// Upper bound for the early-game threshold range.
    public let startingEncounterThresholdMaxTokens: Int64

    /// Lower bound for the completion threshold range.
    public let completionEncounterThresholdMinTokens: Int64

    /// Keep threshold generation on a 200-token grid so migrated saves preserve
    /// the same replay-safe cadence as the legacy implementation.
    let encounterThresholdQuantumTokens: Int64

    /// Total species in the catalog (used for progression scaling).
    public let totalSpeciesCount: Int

    public init(
        minimumEncounterThresholdTokens: Int64 = 180_000,
        startingEncounterThresholdMaxTokens: Int64 = 260_000,
        completionEncounterThresholdMinTokens: Int64 = 700_000,
        maximumEncounterThresholdTokens: Int64 = 900_000,
        encounterThresholdQuantumTokens: Int64 = 200,
        totalSpeciesCount: Int = 151
    ) {
        self.minimumEncounterThresholdTokens = minimumEncounterThresholdTokens
        self.startingEncounterThresholdMaxTokens = startingEncounterThresholdMaxTokens
        self.completionEncounterThresholdMinTokens = completionEncounterThresholdMinTokens
        self.maximumEncounterThresholdTokens = maximumEncounterThresholdTokens
        self.encounterThresholdQuantumTokens = encounterThresholdQuantumTokens
        self.totalSpeciesCount = totalSpeciesCount
    }

    /// Returns the token threshold for the next encounter, scaled by collection
    /// progress. Fewer captured species → lower threshold (faster encounters).
    /// More captured species → higher threshold (slower encounters).
    /// The curve is quadratic (back-loaded): most of the increase happens in
    /// the last ~30% of the collection.
    public func tokensRequiredForEncounter(
        _ encounterIndexGlobal: Int64,
        capturedSpeciesCount: Int = 0
    ) -> Int64 {
        let (scaledMin, scaledMax) = scaledThresholdRange(capturedSpeciesCount: capturedSpeciesCount)

        let stableEncounterIndex = max(1, encounterIndexGlobal)
        let minimumUnits = scaledMin / encounterThresholdQuantumTokens
        let maximumUnits = scaledMax / encounterThresholdQuantumTokens
        let span = maximumUnits - minimumUnits + 1

        guard span > 1 else {
            return scaledMin
        }

        var state = UInt64(bitPattern: stableEncounterIndex) &+ 0x9E37_79B9_7F4A_7C15
        state = (state ^ (state >> 30)) &* 0xBF58_476D_1CE4_E5B9
        state = (state ^ (state >> 27)) &* 0x94D0_49BB_1331_11EB
        state = state ^ (state >> 31)

        let selectedUnits = minimumUnits + Int64(state % UInt64(span))
        return selectedUnits * encounterThresholdQuantumTokens
    }

    /// Computes the dynamic min/max threshold range based on how many unique
    /// species the player has captured. Uses a quadratic curve so the threshold
    /// stays low through mid-game and ramps steeply near completion.
    ///
    /// - 0 captured:   ~180K – 260K (fast encounters, early game)
    /// - ~75 captured:  ~310K – 420K (mid game)
    /// - ~120 captured: ~510K – 660K (approaching completion)
    /// - 151 captured: ~700K – 900K (slow encounters, late game)
    public func scaledThresholdRange(capturedSpeciesCount: Int) -> (min: Int64, max: Int64) {
        let total = max(1, totalSpeciesCount)
        let clamped = min(max(0, capturedSpeciesCount), total)
        let progress = Double(clamped) / Double(total)
        let factor = progress * progress // quadratic — back-loaded

        let dynamicMin = minimumEncounterThresholdTokens
            + Int64(Double(completionEncounterThresholdMinTokens - minimumEncounterThresholdTokens) * factor)
        let dynamicMax = startingEncounterThresholdMaxTokens
            + Int64(Double(maximumEncounterThresholdTokens - startingEncounterThresholdMaxTokens) * factor)
        return (dynamicMin, dynamicMax)
    }
}

/// Provider-neutral exploration state that mirrors the persistence slice while
/// keeping encounter cadence token-native.
public struct ExplorationAccumulatorState: Equatable, Codable, Sendable {
    public let totalNormalizedTokens: Int64
    public let tokensSinceLastEncounter: Int64
    public let nextEncounterThresholdTokens: Int64
    public let totalEncounters: Int64
    public let totalCaptures: Int64

    public init(
        totalNormalizedTokens: Int64 = 0,
        tokensSinceLastEncounter: Int64 = 0,
        nextEncounterThresholdTokens: Int64? = nil,
        totalEncounters: Int64 = 0,
        totalCaptures: Int64 = 0
    ) {
        self.totalNormalizedTokens = totalNormalizedTokens
        self.tokensSinceLastEncounter = tokensSinceLastEncounter
        self.nextEncounterThresholdTokens = nextEncounterThresholdTokens
            ?? ExplorationAccumulatorConfig().tokensRequiredForEncounter(totalEncounters + 1)
        self.totalEncounters = totalEncounters
        self.totalCaptures = totalCaptures
    }
}

public struct ExplorationProgressSnapshot: Equatable, Codable, Sendable {
    public let normalizedDeltaTokens: Int64
    public let totalNormalizedTokens: Int64
    public let tokensSinceLastEncounterBefore: Int64
    public let tokensSinceLastEncounterAfter: Int64
    public let nextEncounterThresholdTokensAfter: Int64
}

public struct EncounterThresholdCrossedSnapshot: Equatable, Codable, Sendable {
    public let thresholdIndexGlobal: Int64
    public let totalNormalizedTokensAtThreshold: Int64
    public let thresholdTokens: Int64
    public let remainingTokensAfter: Int64
    public let nextEncounterThresholdTokens: Int64
}

public struct ExplorationAccumulationResult: Equatable, Sendable {
    public let updatedState: ExplorationAccumulatorState
    public let progress: ExplorationProgressSnapshot?
    public let thresholds: [EncounterThresholdCrossedSnapshot]

    public var tokensSinceLastEncounterAfter: Int64 { updatedState.tokensSinceLastEncounter }
    public var nextEncounterThresholdTokensAfter: Int64 { updatedState.nextEncounterThresholdTokens }
    public var thresholdCrossings: [EncounterThresholdCrossedSnapshot] { thresholds }
}

public enum ExplorationAccumulatorError: Error, LocalizedError {
    case invalidConfiguration(
        minimumEncounterThresholdTokens: Int64,
        maximumEncounterThresholdTokens: Int64,
        encounterThresholdQuantumTokens: Int64
    )
    case negativeDeltaTokens(Int64)
    case invalidState(ExplorationAccumulatorState)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(
            let minimumEncounterThresholdTokens,
            let maximumEncounterThresholdTokens,
            let encounterThresholdQuantumTokens
        ):
            return """
            exploration accumulator config must be positive, ordered, and divisible by the threshold quantum: \
            minimumEncounterThresholdTokens=\(minimumEncounterThresholdTokens) \
            maximumEncounterThresholdTokens=\(maximumEncounterThresholdTokens) \
            encounterThresholdQuantumTokens=\(encounterThresholdQuantumTokens)
            """
        case .negativeDeltaTokens(let value):
            return "normalized delta tokens must be non-negative: \(value)"
        case .invalidState(let state):
            return "exploration state is invalid for token-native cadence: \(state)"
        }
    }
}

/// Converts normalized token deltas into encounter-threshold events while
/// keeping the cadence anchored directly to tokens.
public struct ExplorationAccumulator {
    public let config: ExplorationAccumulatorConfig

    public init(config: ExplorationAccumulatorConfig = ExplorationAccumulatorConfig()) {
        self.config = config
    }

    public func accumulate(
        state: ExplorationAccumulatorState,
        normalizedDeltaTokens: Int64,
        capturedSpeciesCount: Int = 0,
        observedAt _: String,
        producer _: String = TokenmonGameEngineModule.name,
        correlationID _: String? = nil,
        causationID _: String? = nil
    ) throws -> ExplorationAccumulationResult {
        try validate(config: config)
        try validate(state: state)

        guard normalizedDeltaTokens >= 0 else {
            throw ExplorationAccumulatorError.negativeDeltaTokens(normalizedDeltaTokens)
        }

        let totalNormalizedTokensAfter = state.totalNormalizedTokens + normalizedDeltaTokens
        let tokensSinceLastEncounterBefore = state.tokensSinceLastEncounter
        var tokensSinceLastEncounter = state.tokensSinceLastEncounter + normalizedDeltaTokens
        var nextEncounterThresholdTokens = state.nextEncounterThresholdTokens
        var nextTotalEncounters = state.totalEncounters
        var thresholdPayloads: [EncounterThresholdCrossedSnapshot] = []
        var sampleTokensConsumedAcrossThresholds: Int64 = 0
        var carryTokensFromPriorState = state.tokensSinceLastEncounter

        while tokensSinceLastEncounter >= nextEncounterThresholdTokens {
            let tokensNeededToCross = nextEncounterThresholdTokens - carryTokensFromPriorState
            sampleTokensConsumedAcrossThresholds += max(0, tokensNeededToCross)
            tokensSinceLastEncounter -= nextEncounterThresholdTokens
            nextTotalEncounters += 1

            let upcomingThresholdTokens = config.tokensRequiredForEncounter(nextTotalEncounters + 1, capturedSpeciesCount: capturedSpeciesCount)
            thresholdPayloads.append(
                EncounterThresholdCrossedSnapshot(
                    thresholdIndexGlobal: nextTotalEncounters,
                    totalNormalizedTokensAtThreshold: state.totalNormalizedTokens + sampleTokensConsumedAcrossThresholds,
                    thresholdTokens: nextEncounterThresholdTokens,
                    remainingTokensAfter: tokensSinceLastEncounter,
                    nextEncounterThresholdTokens: upcomingThresholdTokens
                )
            )

            nextEncounterThresholdTokens = upcomingThresholdTokens
            carryTokensFromPriorState = 0
        }

        let updatedState = ExplorationAccumulatorState(
            totalNormalizedTokens: totalNormalizedTokensAfter,
            tokensSinceLastEncounter: tokensSinceLastEncounter,
            nextEncounterThresholdTokens: nextEncounterThresholdTokens,
            totalEncounters: nextTotalEncounters,
            totalCaptures: state.totalCaptures
        )

        let progressPayload: ExplorationProgressSnapshot? = normalizedDeltaTokens > 0
            ? ExplorationProgressSnapshot(
                normalizedDeltaTokens: normalizedDeltaTokens,
                totalNormalizedTokens: updatedState.totalNormalizedTokens,
                tokensSinceLastEncounterBefore: tokensSinceLastEncounterBefore,
                tokensSinceLastEncounterAfter: updatedState.tokensSinceLastEncounter,
                nextEncounterThresholdTokensAfter: updatedState.nextEncounterThresholdTokens
            )
            : nil

        return ExplorationAccumulationResult(
            updatedState: updatedState,
            progress: progressPayload,
            thresholds: thresholdPayloads
        )
    }

    private func validate(config: ExplorationAccumulatorConfig) throws {
        let minimumTokens = config.minimumEncounterThresholdTokens
        let maximumTokens = config.maximumEncounterThresholdTokens
        let quantumTokens = config.encounterThresholdQuantumTokens

        guard minimumTokens > 0,
              config.startingEncounterThresholdMaxTokens >= minimumTokens,
              config.completionEncounterThresholdMinTokens >= config.startingEncounterThresholdMaxTokens,
              maximumTokens >= minimumTokens,
              quantumTokens > 0,
              minimumTokens % quantumTokens == 0,
              config.startingEncounterThresholdMaxTokens % quantumTokens == 0,
              config.completionEncounterThresholdMinTokens % quantumTokens == 0,
              maximumTokens % quantumTokens == 0 else {
            throw ExplorationAccumulatorError.invalidConfiguration(
                minimumEncounterThresholdTokens: minimumTokens,
                maximumEncounterThresholdTokens: maximumTokens,
                encounterThresholdQuantumTokens: quantumTokens
            )
        }
    }

    private func validate(state: ExplorationAccumulatorState) throws {
        guard state.totalNormalizedTokens >= 0,
              state.tokensSinceLastEncounter >= 0,
              state.nextEncounterThresholdTokens > 0,
              state.tokensSinceLastEncounter < state.nextEncounterThresholdTokens,
              state.totalEncounters >= 0,
              state.totalCaptures >= 0 else {
            throw ExplorationAccumulatorError.invalidState(state)
        }
    }
}
