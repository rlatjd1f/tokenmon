import Foundation

public enum RaidAvailabilityKind: String, CaseIterable, Codable, Sendable {
    case tutorialAlways = "tutorial_always"
    case scheduled
}

public enum RaidDifficultyTier: String, CaseIterable, Codable, Sendable {
    case tiny
    case small
    case standard
    case large
    case marathon
}

public enum RaidRewardType: String, CaseIterable, Codable, Sendable {
    case trophy
    case logoRelic = "logo_relic"
    case badge
    case cosmetic
    case eventSpecies = "event_species"
}

public enum RaidRewardGrantRule: String, CaseIterable, Codable, Sendable {
    case clear
}

public enum RaidInstanceStatus: String, CaseIterable, Codable, Sendable {
    case upcoming
    case active
    case cleared
    case expired
    case missed
}

public enum RaidRewardArchiveStatus: String, CaseIterable, Codable, Sendable {
    case unknown
    case available
    case acquired
    case missed
}

public struct RaidAxisWeights: Equatable, Codable, Sendable {
    public let planning: Int
    public let design: Int
    public let frontend: Int
    public let backend: Int
    public let pm: Int
    public let infra: Int

    public var total: Int {
        planning + design + frontend + backend + pm + infra
    }

    public init(
        planning: Int,
        design: Int,
        frontend: Int,
        backend: Int,
        pm: Int,
        infra: Int
    ) {
        self.planning = planning
        self.design = design
        self.frontend = frontend
        self.backend = backend
        self.pm = pm
        self.infra = infra
    }

    public func value(for axis: SpeciesStatAxis) -> Int {
        switch axis {
        case .planning: return planning
        case .design: return design
        case .frontend: return frontend
        case .backend: return backend
        case .pm: return pm
        case .infra: return infra
        }
    }
}

public struct RaidDefinition: Equatable, Codable, Sendable {
    public let raidID: String
    public let title: String
    public let targetName: String
    public let targetArtKey: String
    public let raidField: FieldType
    public let availabilityKind: RaidAvailabilityKind
    public let activeStartAt: String?
    public let activeEndAt: String?
    public let settlementGraceSeconds: Int
    public let maxHP: Int64
    public let axisWeights: RaidAxisWeights
    public let preferredTraitTags: [String]
    public let difficultyTier: RaidDifficultyTier
    public let rewardIDs: [String]

    public init(
        raidID: String,
        title: String,
        targetName: String,
        targetArtKey: String,
        raidField: FieldType,
        availabilityKind: RaidAvailabilityKind,
        activeStartAt: String?,
        activeEndAt: String?,
        settlementGraceSeconds: Int,
        maxHP: Int64,
        axisWeights: RaidAxisWeights,
        preferredTraitTags: [String],
        difficultyTier: RaidDifficultyTier,
        rewardIDs: [String]
    ) {
        self.raidID = raidID
        self.title = title
        self.targetName = targetName
        self.targetArtKey = targetArtKey
        self.raidField = raidField
        self.availabilityKind = availabilityKind
        self.activeStartAt = activeStartAt
        self.activeEndAt = activeEndAt
        self.settlementGraceSeconds = settlementGraceSeconds
        self.maxHP = maxHP
        self.axisWeights = axisWeights
        self.preferredTraitTags = preferredTraitTags
        self.difficultyTier = difficultyTier
        self.rewardIDs = rewardIDs
    }
}

public struct RaidRewardDefinition: Equatable, Codable, Sendable {
    public let rewardID: String
    public let sourceRaidID: String
    public let type: RaidRewardType
    public let title: String
    public let artKey: String
    public let grantRule: RaidRewardGrantRule

    public init(
        rewardID: String,
        sourceRaidID: String,
        type: RaidRewardType,
        title: String,
        artKey: String,
        grantRule: RaidRewardGrantRule
    ) {
        self.rewardID = rewardID
        self.sourceRaidID = sourceRaidID
        self.type = type
        self.title = title
        self.artKey = artKey
        self.grantRule = grantRule
    }
}

public struct RaidPartyMember: Equatable, Codable, Sendable {
    public let speciesID: String
    public let assetKey: String
    public let displayName: String
    public let field: FieldType
    public let rarity: RarityTier
    public let slotOrder: Int
    public let capturedCount: Int64
    public let stats: SpeciesStatBlock

    public init(
        speciesID: String,
        assetKey: String,
        displayName: String,
        field: FieldType,
        rarity: RarityTier,
        slotOrder: Int,
        capturedCount: Int64,
        stats: SpeciesStatBlock
    ) {
        self.speciesID = speciesID
        self.assetKey = assetKey
        self.displayName = displayName
        self.field = field
        self.rarity = rarity
        self.slotOrder = slotOrder
        self.capturedCount = capturedCount
        self.stats = stats
    }
}
