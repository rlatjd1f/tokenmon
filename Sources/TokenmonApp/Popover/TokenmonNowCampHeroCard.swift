import Dispatch
import SwiftUI
import TokenmonDomain
import TokenmonGameEngine
import TokenmonPersistence

struct NowCampHeroMemberPresentation: Equatable, Identifiable {
    let speciesID: String
    let displayName: String
    let assetKey: String
    let field: FieldType
    let rarity: RarityTier
    let trainingTrait: TrainingTrait
    let affinityLevel: Int64
    let trainingRank: TrainingRank
    let trainingResonance: Int

    var id: String { speciesID }

    init(lead: NowCampLeadSummary) {
        speciesID = lead.speciesID
        displayName = lead.displayName
        assetKey = lead.assetKey
        field = lead.field
        rarity = lead.rarity
        trainingTrait = lead.trainingTrait
        affinityLevel = lead.affinityLevel
        trainingRank = lead.training.trainingRank
        trainingResonance = lead.training.trainingResonance
    }

    init(member: PartyMemberSummary) {
        speciesID = member.speciesID
        displayName = member.displayName
        assetKey = member.assetKey
        field = member.field
        rarity = member.rarity
        trainingTrait = member.trainingTrait
        affinityLevel = member.affinityLevel
        trainingRank = member.trainingRank
        trainingResonance = 0
    }

    init(
        species: SpeciesDefinition,
        affinityLevel: Int64 = 3,
        trainingRank: TrainingRank = .rankII,
        trainingResonance: Int = 0
    ) {
        speciesID = species.id
        displayName = species.name
        assetKey = species.assetKey
        field = species.field
        rarity = species.rarity
        trainingTrait = species.trainingTrait
        self.affinityLevel = affinityLevel
        self.trainingRank = trainingRank
        self.trainingResonance = trainingResonance
    }
}

enum NowCampHeroSupportSlot: Equatable, Identifiable {
    case occupied(NowCampHeroMemberPresentation, index: Int)
    case empty(index: Int)

    var id: String {
        switch self {
        case .occupied(let member, let index):
            return "support-\(index)-\(member.speciesID)"
        case .empty(let index):
            return "support-\(index)-empty"
        }
    }

    var index: Int {
        switch self {
        case .occupied(_, let index), .empty(let index):
            return index
        }
    }
}

enum NowCampHeroActionKind: Equatable {
    case train
    case care
}

enum NowCampHeroActionAvailability: Equatable {
    case enabled
    case missingLead
    case insufficientFocus(current: Int, required: Int)
    case rankAtAffinityGate(current: Int, required: Int)
    case rankMaximum
    case careCharging(remainingSeconds: Int)
    case focusStorageFull
    case careDailyCapReached
}

struct NowCampHeroActionState: Equatable {
    let kind: NowCampHeroActionKind
    let cost: Int
    let focusEnergy: Int
    let availability: NowCampHeroActionAvailability

    var isEnabled: Bool {
        availability == .enabled
    }

    static func train(
        cost: Int,
        focusEnergy: Int,
        lead: NowCampHeroMemberPresentation?
    ) -> NowCampHeroActionState {
        guard let lead else {
            return NowCampHeroActionState(kind: .train, cost: cost, focusEnergy: focusEnergy, availability: .missingLead)
        }
        guard lead.trainingRank.next != nil else {
            return NowCampHeroActionState(kind: .train, cost: cost, focusEnergy: focusEnergy, availability: .rankMaximum)
        }
        guard lead.trainingRank.rawValue < Int(lead.affinityLevel) else {
            return NowCampHeroActionState(
                kind: .train,
                cost: cost,
                focusEnergy: focusEnergy,
                availability: .rankAtAffinityGate(
                    current: Int(lead.affinityLevel),
                    required: min(TrainingRank.rankV.rawValue, lead.trainingRank.rawValue + 1)
                )
            )
        }
        guard focusEnergy >= cost else {
            return NowCampHeroActionState(
                kind: .train,
                cost: cost,
                focusEnergy: focusEnergy,
                availability: .insufficientFocus(current: focusEnergy, required: cost)
            )
        }
        return NowCampHeroActionState(kind: .train, cost: cost, focusEnergy: focusEnergy, availability: .enabled)
    }

    static func care(
        focusGrant: Int,
        focusEnergy: Int,
        careReady: Bool,
        careElapsedSeconds: Int,
        careFocusEarnedToday: Int,
        lead: NowCampHeroMemberPresentation?
    ) -> NowCampHeroActionState {
        guard lead != nil else {
            return NowCampHeroActionState(kind: .care, cost: focusGrant, focusEnergy: focusEnergy, availability: .missingLead)
        }
        guard focusEnergy < NowCampHeroPresentation.focusCapacity else {
            return NowCampHeroActionState(kind: .care, cost: focusGrant, focusEnergy: focusEnergy, availability: .focusStorageFull)
        }
        guard careFocusEarnedToday < NowCampCarePolicy.dailyFocusCap else {
            return NowCampHeroActionState(kind: .care, cost: focusGrant, focusEnergy: focusEnergy, availability: .careDailyCapReached)
        }
        guard careReady else {
            let remaining = max(0, NowCampCarePolicy.intervalSeconds - careElapsedSeconds)
            return NowCampHeroActionState(
                kind: .care,
                cost: focusGrant,
                focusEnergy: focusEnergy,
                availability: .careCharging(remainingSeconds: remaining)
            )
        }
        return NowCampHeroActionState(kind: .care, cost: focusGrant, focusEnergy: focusEnergy, availability: .enabled)
    }
}

struct NowCampHeroV2RewardPreview: Equatable {
    let titleText: String
    let valueText: String
    let detailText: String
    let compactValueText: String
    let compactDetailText: String
    let currentLine: NowCampHeroV2EffectLine
    let successLine: NowCampHeroV2EffectLine
    let systemImage: String
    let isActive: Bool
}

struct NowCampHeroV2EffectLine: Equatable {
    let labelText: String
    let valueText: String
    let isActive: Bool
}

struct NowCampHeroLeadMenuStatus: Equatable, Identifiable {
    let speciesID: String
    let titleText: String
    let statusText: String
    let systemImage: String
    let isSelected: Bool
    let isTrainable: Bool

    var id: String { speciesID }
}

struct NowCampHeroV2Telemetry: Equatable {
    let focusTitleText: String
    let focusValueText: String
    let practiceTitleText: String
    let practiceChanceText: String
    let resonanceValueText: String
    let rewardTitleText: String
    let rewardPreview: NowCampHeroV2RewardPreview
    let scoutActionTitleText: String
    let scoutActionHelpText: String
}

struct NowCampHeroPresentation: Equatable {
    static let focusCapacity = 50

    let sceneContext: TokenmonSceneContext
    let field: FieldType
    let fieldTitle: String
    let fieldSystemImage: String
    let lead: NowCampHeroMemberPresentation?
    let supportSlots: [NowCampHeroSupportSlot]
    let focusEnergy: Int
    let trainingLine: String
    let trainingLevelText: String
    let trainTargetLine: String
    let targetLevelText: String
    let trainRewardLine: String
    let trainRewardShortLine: String
    let trainRewardSystemImage: String
    let trainBenefitLine: String
    let benefitText: String
    let practiceControlTitleText: String
    let practiceControlDetailText: String
    let practiceProgressFraction: Double
    let practiceReadinessText: String
    let practiceStatusText: String
    let attemptHelpText: String
    let campStatusLine: String
    let energySourceLine: String
    let headerLeadTitle: String
    let headerLeadDetail: String
    let careStatusLine: String?
    let trainingLevelPipCount: Int
    let leadMenuStatuses: [NowCampHeroLeadMenuStatus]
    let v2: NowCampHeroV2Telemetry
    let trainAction: NowCampHeroActionState
    let careAction: NowCampHeroActionState

    static func make(
        nowCamp: NowCampSummary?,
        partyMembers: [PartyMemberSummary],
        sceneContext: TokenmonSceneContext
    ) -> NowCampHeroPresentation {
        let focusEnergy = nowCamp?.focusEnergy ?? 0
        let lead = nowCamp?.lead.map(NowCampHeroMemberPresentation.init(lead:))
        let supports = supportMembers(
            nowCamp: nowCamp,
            partyMembers: partyMembers,
            leadSpeciesID: lead?.speciesID
        )
        let supportSlots = resolvedSupportSlots(from: supports)
        let resolver = LeaderTrainingResolver()
        let trainAction = NowCampHeroActionState.train(
            cost: resolver.trainFocusCost,
            focusEnergy: focusEnergy,
            lead: lead
        )
        let careAction = NowCampHeroActionState.care(
            focusGrant: resolver.careFocusGrant,
            focusEnergy: focusEnergy,
            careReady: nowCamp?.careReady ?? false,
            careElapsedSeconds: nowCamp?.careElapsedSeconds ?? 0,
            careFocusEarnedToday: careFocusEarnedToday(nowCamp),
            lead: lead
        )
        let targetLevelText = targetLevelText(for: lead)
        let practiceReadinessText = practiceReadinessText(focusEnergy: focusEnergy, trainAction: trainAction)
        let practiceStatusText = practiceStatusText(for: trainAction)
        let leadMenuStatuses = leadMenuStatuses(
            partyMembers: partyMembers,
            focusEnergy: focusEnergy,
            selectedLeadSpeciesID: lead?.speciesID
        )
        let hasTrainableAlternative = leadMenuStatuses.contains { status in
            status.isSelected == false && status.isTrainable
        }
        let v2 = v2Telemetry(focusEnergy: focusEnergy, lead: lead, trainAction: trainAction)

        return NowCampHeroPresentation(
            sceneContext: sceneContext,
            field: sceneContext.fieldKind.heroFieldType,
            fieldTitle: sceneContext.fieldKind.heroFieldTitle,
            fieldSystemImage: sceneContext.fieldKind.heroFieldSystemImage,
            lead: lead,
            supportSlots: supportSlots,
            focusEnergy: focusEnergy,
            trainingLine: trainingLine(for: lead),
            trainingLevelText: trainingLevelText(for: lead),
            trainTargetLine: trainTargetLine(for: lead),
            targetLevelText: targetLevelText,
            trainRewardLine: trainRewardLine(for: lead),
            trainRewardShortLine: trainRewardShortLine(for: lead),
            trainRewardSystemImage: trainRewardSystemImage(for: lead),
            trainBenefitLine: trainBenefitLine(for: lead),
            benefitText: benefitText(for: lead),
            practiceControlTitleText: practiceControlTitleText(for: trainAction),
            practiceControlDetailText: practiceControlDetailText(
                for: trainAction,
                readinessText: practiceReadinessText,
                targetLevelText: targetLevelText,
                hasTrainableAlternative: hasTrainableAlternative
            ),
            practiceProgressFraction: practiceProgressFraction(focusEnergy: focusEnergy, trainAction: trainAction),
            practiceReadinessText: practiceReadinessText,
            practiceStatusText: practiceStatusText,
            attemptHelpText: attemptHelpText(for: lead, trainAction: trainAction),
            campStatusLine: campStatusLine(for: lead, trainAction: trainAction, careAction: careAction),
            energySourceLine: energySourceLine(focusEnergy: focusEnergy, trainAction: trainAction),
            headerLeadTitle: lead?.displayName ?? TokenmonL10n.string("now.camp.lead.empty"),
            headerLeadDetail: headerLeadDetail(for: lead),
            careStatusLine: careStatusLine(for: careAction),
            trainingLevelPipCount: trainingLevelPipCount(for: lead),
            leadMenuStatuses: leadMenuStatuses,
            v2: v2,
            trainAction: trainAction,
            careAction: careAction
        )
    }

    static func preview(
        sceneContext: TokenmonSceneContext,
        lead: SpeciesDefinition?,
        supports: [SpeciesDefinition],
        focusEnergy: Int = 68
    ) -> NowCampHeroPresentation {
        let leadPresentation = lead.map {
            NowCampHeroMemberPresentation(species: $0)
        }
        let supportSlots = resolvedSupportSlots(
            from: supports.prefix(2).map {
                NowCampHeroMemberPresentation(
                    species: $0,
                    affinityLevel: 1,
                    trainingRank: .rankI
                )
            }
        )
        let resolver = LeaderTrainingResolver()
        let trainAction = NowCampHeroActionState.train(
            cost: resolver.trainFocusCost,
            focusEnergy: focusEnergy,
            lead: leadPresentation
        )
        let careAction = NowCampHeroActionState.care(
            focusGrant: resolver.careFocusGrant,
            focusEnergy: focusEnergy,
            careReady: false,
            careElapsedSeconds: 0,
            careFocusEarnedToday: 0,
            lead: leadPresentation
        )
        let targetLevelText = targetLevelText(for: leadPresentation)
        let practiceReadinessText = practiceReadinessText(focusEnergy: focusEnergy, trainAction: trainAction)
        let practiceStatusText = practiceStatusText(for: trainAction)
        let leadMenuStatuses: [NowCampHeroLeadMenuStatus] = []
        let v2 = v2Telemetry(focusEnergy: focusEnergy, lead: leadPresentation, trainAction: trainAction)
        return NowCampHeroPresentation(
            sceneContext: sceneContext,
            field: sceneContext.fieldKind.heroFieldType,
            fieldTitle: sceneContext.fieldKind.heroFieldTitle,
            fieldSystemImage: sceneContext.fieldKind.heroFieldSystemImage,
            lead: leadPresentation,
            supportSlots: supportSlots,
            focusEnergy: focusEnergy,
            trainingLine: trainingLine(for: leadPresentation),
            trainingLevelText: trainingLevelText(for: leadPresentation),
            trainTargetLine: trainTargetLine(for: leadPresentation),
            targetLevelText: targetLevelText,
            trainRewardLine: trainRewardLine(for: leadPresentation),
            trainRewardShortLine: trainRewardShortLine(for: leadPresentation),
            trainRewardSystemImage: trainRewardSystemImage(for: leadPresentation),
            trainBenefitLine: trainBenefitLine(for: leadPresentation),
            benefitText: benefitText(for: leadPresentation),
            practiceControlTitleText: practiceControlTitleText(for: trainAction),
            practiceControlDetailText: practiceControlDetailText(
                for: trainAction,
                readinessText: practiceReadinessText,
                targetLevelText: targetLevelText,
                hasTrainableAlternative: false
            ),
            practiceProgressFraction: practiceProgressFraction(focusEnergy: focusEnergy, trainAction: trainAction),
            practiceReadinessText: practiceReadinessText,
            practiceStatusText: practiceStatusText,
            attemptHelpText: attemptHelpText(for: leadPresentation, trainAction: trainAction),
            campStatusLine: campStatusLine(for: leadPresentation, trainAction: trainAction, careAction: careAction),
            energySourceLine: energySourceLine(focusEnergy: focusEnergy, trainAction: trainAction),
            headerLeadTitle: leadPresentation?.displayName ?? TokenmonL10n.string("now.camp.lead.empty"),
            headerLeadDetail: headerLeadDetail(for: leadPresentation),
            careStatusLine: careStatusLine(for: careAction),
            trainingLevelPipCount: trainingLevelPipCount(for: leadPresentation),
            leadMenuStatuses: leadMenuStatuses,
            v2: v2,
            trainAction: trainAction,
            careAction: careAction
        )
    }

    func leadMenuStatus(for speciesID: String) -> NowCampHeroLeadMenuStatus? {
        leadMenuStatuses.first { $0.speciesID == speciesID }
    }

    private static func supportMembers(
        nowCamp: NowCampSummary?,
        partyMembers: [PartyMemberSummary],
        leadSpeciesID: String?
    ) -> [NowCampHeroMemberPresentation] {
        if let supports = nowCamp?.supports, supports.isEmpty == false {
            return supports.prefix(2).map(NowCampHeroMemberPresentation.init(member:))
        }
        guard let leadSpeciesID else {
            return partyMembers.prefix(2).map(NowCampHeroMemberPresentation.init(member:))
        }
        return partyMembers
            .filter { $0.speciesID != leadSpeciesID }
            .prefix(2)
            .map(NowCampHeroMemberPresentation.init(member:))
    }

    private static func resolvedSupportSlots(
        from supports: [NowCampHeroMemberPresentation]
    ) -> [NowCampHeroSupportSlot] {
        (0..<2).map { index in
            if index < supports.count {
                return .occupied(supports[index], index: index)
            }
            return .empty(index: index)
        }
    }

    private static func careFocusEarnedToday(_ nowCamp: NowCampSummary?) -> Int {
        guard let nowCamp else {
            return 0
        }
        return nowCamp.careFocusEarnedLocalDate == TokenmonDatabaseManager.currentLocalDate()
            ? nowCamp.careFocusEarnedToday
            : 0
    }

    private static func leadMenuStatuses(
        partyMembers: [PartyMemberSummary],
        focusEnergy: Int,
        selectedLeadSpeciesID: String?
    ) -> [NowCampHeroLeadMenuStatus] {
        let resolver = LeaderTrainingResolver()
        return partyMembers.map { member in
            let lead = NowCampHeroMemberPresentation(member: member)
            let action = NowCampHeroActionState.train(
                cost: resolver.trainFocusCost,
                focusEnergy: focusEnergy,
                lead: lead
            )
            let isSelected = member.speciesID == selectedLeadSpeciesID
            let statusText: String
            let systemImage: String
            let isTrainable: Bool

            switch action.availability {
            case .enabled:
                statusText = TokenmonL10n.string("now.camp.lead_picker.status.ready")
                systemImage = isSelected ? "crown.fill" : "checkmark.circle.fill"
                isTrainable = true
            case .insufficientFocus(let current, let required):
                statusText = TokenmonL10n.format(
                    "now.camp.lead_picker.status.focus_needed",
                    Int64(max(0, required - current))
                )
                systemImage = isSelected ? "crown.fill" : "bolt.circle.fill"
                isTrainable = false
            case .rankAtAffinityGate(let current, let required):
                statusText = TokenmonL10n.format(
                    "now.camp.lead_picker.status.bond",
                    Int64(current),
                    Int64(required)
                )
                systemImage = isSelected ? "crown.fill" : "heart.circle.fill"
                isTrainable = false
            case .rankMaximum:
                statusText = TokenmonL10n.string("now.camp.lead_picker.status.max")
                systemImage = isSelected ? "crown.fill" : "checkmark.seal.fill"
                isTrainable = false
            case .missingLead, .careCharging, .focusStorageFull, .careDailyCapReached:
                statusText = TokenmonL10n.string("now.camp.lead_picker.status.unavailable")
                systemImage = isSelected ? "crown.fill" : "person.crop.circle"
                isTrainable = false
            }

            return NowCampHeroLeadMenuStatus(
                speciesID: member.speciesID,
                titleText: "\(member.displayName) · \(statusText)",
                statusText: statusText,
                systemImage: systemImage,
                isSelected: isSelected,
                isTrainable: isTrainable
            )
        }
    }

    private static func trainingLine(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.no_party")
        }
        return trainingLevelText(for: lead)
    }

    private static func trainingLevelText(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.no_party")
        }
        return TokenmonL10n.format(
            "now.camp.training_level",
            Int64(lead.trainingRank.rawValue),
            Int64(TrainingRank.rankV.rawValue)
        )
    }

    private static func trainTargetLine(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead, let targetRank = lead.trainingRank.next else {
            return TokenmonL10n.string("now.camp.train.target.empty")
        }
        return TokenmonL10n.format(
            "now.camp.train.target",
            lead.trainingRank.romanNumeral,
            targetRank.romanNumeral
        )
    }

    private static func targetLevelText(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead, let targetRank = lead.trainingRank.next else {
            return TokenmonL10n.string("now.camp.train.target.empty")
        }
        return TokenmonL10n.format(
            "now.camp.practice.target_level",
            Int64(lead.trainingRank.rawValue),
            Int64(targetRank.rawValue)
        )
    }

    private static func trainRewardLine(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.train.reward.empty")
        }
        return TokenmonL10n.format(
            "now.camp.train.reward",
            trainRewardName(for: lead.trainingTrait)
        )
    }

    private static func trainRewardShortLine(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.train.reward.empty")
        }
        return trainRewardShortName(for: lead.trainingTrait)
    }

    private static func trainRewardSystemImage(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead else {
            return "questionmark.circle.fill"
        }
        switch lead.trainingTrait {
        case .trail:
            return "map.fill"
        case .scout:
            return "star.fill"
        case .capture:
            return "scope"
        case .raider:
            return "bolt.fill"
        }
    }

    private static func trainRewardName(for trait: TrainingTrait) -> String {
        switch trait {
        case .trail:
            return TokenmonL10n.string("now.camp.train.reward.trail")
        case .scout:
            return TokenmonL10n.string("now.camp.train.reward.scout")
        case .capture:
            return TokenmonL10n.string("now.camp.train.reward.capture")
        case .raider:
            return TokenmonL10n.string("now.camp.train.reward.raider")
        }
    }

    private static func trainRewardShortName(for trait: TrainingTrait) -> String {
        switch trait {
        case .trail:
            return TokenmonL10n.string("now.camp.train.reward.trail.short")
        case .scout:
            return TokenmonL10n.string("now.camp.train.reward.scout.short")
        case .capture:
            return TokenmonL10n.string("now.camp.train.reward.capture.short")
        case .raider:
            return TokenmonL10n.string("now.camp.train.reward.raider.short")
        }
    }

    private static func trainBenefitLine(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.train.reward.empty")
        }
        return TokenmonL10n.format(
            "now.camp.train.benefit",
            trainRewardShortName(for: lead.trainingTrait)
        )
    }

    private static func benefitText(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.practice.benefit.empty")
        }
        switch lead.trainingTrait {
        case .trail:
            return TokenmonL10n.format("now.camp.practice.benefit.trail", lead.field.displayName)
        case .scout:
            return TokenmonL10n.string("now.camp.practice.benefit.scout")
        case .capture:
            return TokenmonL10n.format("now.camp.practice.benefit.capture", lead.field.displayName)
        case .raider:
            return TokenmonL10n.string("now.camp.practice.benefit.raider")
        }
    }

    private static func practiceReadinessText(
        focusEnergy: Int,
        trainAction: NowCampHeroActionState
    ) -> String {
        switch trainAction.availability {
        case .insufficientFocus(let current, let required):
            return TokenmonL10n.format("now.camp.practice.need_more", Int64(max(0, required - current)))
        case .enabled:
            return TokenmonL10n.format(
                "now.camp.practice.readiness",
                Int64(min(focusEnergy, trainAction.cost)),
                Int64(trainAction.cost)
            )
        case .rankAtAffinityGate(let current, let required):
            return TokenmonL10n.format("now.camp.action.rank_gate.short", Int64(current), Int64(required))
        case .rankMaximum:
            return TokenmonL10n.string("now.camp.action.rank_max")
        case .missingLead:
            return TokenmonL10n.string("now.camp.action.no_lead.short")
        case .careCharging, .focusStorageFull, .careDailyCapReached:
            return TokenmonL10n.string("now.camp.practice.status.preparing")
        }
    }

    private static func practiceStatusText(for trainAction: NowCampHeroActionState) -> String {
        switch trainAction.availability {
        case .enabled:
            return TokenmonL10n.string("now.camp.practice.status.ready")
        case .insufficientFocus:
            return TokenmonL10n.string("now.camp.practice.status.preparing")
        case .rankAtAffinityGate:
            return TokenmonL10n.string("now.camp.practice.status.bond_gate")
        case .rankMaximum:
            return TokenmonL10n.string("now.camp.practice.status.max_rank")
        case .missingLead:
            return TokenmonL10n.string("now.camp.practice.status.no_lead")
        case .careCharging, .focusStorageFull, .careDailyCapReached:
            return TokenmonL10n.string("now.camp.practice.status.preparing")
        }
    }

    private static func practiceControlTitleText(for trainAction: NowCampHeroActionState) -> String {
        switch trainAction.availability {
        case .enabled:
            return TokenmonL10n.string("now.camp.practice.action")
        case .insufficientFocus, .rankAtAffinityGate, .rankMaximum, .missingLead, .careCharging, .focusStorageFull, .careDailyCapReached:
            return practiceStatusText(for: trainAction)
        }
    }

    private static func practiceControlDetailText(
        for trainAction: NowCampHeroActionState,
        readinessText: String,
        targetLevelText: String,
        hasTrainableAlternative: Bool
    ) -> String {
        switch trainAction.availability {
        case .enabled:
            return targetLevelText
        case .insufficientFocus(let current, let required):
            return TokenmonL10n.format("now.camp.practice.shared_focus.detail", Int64(current), Int64(required))
        case .rankAtAffinityGate(let current, let required):
            if hasTrainableAlternative {
                return TokenmonL10n.format("now.camp.practice.bond_gate.alternative", Int64(current), Int64(required))
            }
            return TokenmonL10n.format("now.camp.action.rank_gate.short", Int64(current), Int64(required))
        case .rankMaximum:
            return TokenmonL10n.string("now.camp.action.rank_max")
        case .missingLead:
            return TokenmonL10n.string("now.camp.action.no_lead.short")
        case .careCharging, .focusStorageFull, .careDailyCapReached:
            return readinessText
        }
    }

    private static func practiceProgressFraction(
        focusEnergy: Int,
        trainAction: NowCampHeroActionState
    ) -> Double {
        guard trainAction.cost > 0 else {
            return 0
        }
        return min(1.0, max(0.0, Double(focusEnergy) / Double(trainAction.cost)))
    }

    private static func attemptHelpText(
        for lead: NowCampHeroMemberPresentation?,
        trainAction: NowCampHeroActionState
    ) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.action.missing_lead")
        }
        guard let targetRank = lead.trainingRank.next else {
            return TokenmonL10n.string("now.camp.action.rank_max")
        }

        let resolver = LeaderTrainingResolver()
        let fallback = TokenmonL10n.string("now.camp.practice.help.fallback")
        let probability: Double
        let ceiling: Int
        do {
            probability = try resolver.successProbability(
                rarity: lead.rarity,
                targetRank: targetRank
            )
            ceiling = try resolver.ceilingFailures(probability: probability)
        } catch {
            return fallback
        }

        let probabilityPercent = Int64((probability * 100).rounded())
        let baseHelp: String
        if lead.trainingResonance >= ceiling {
            baseHelp = TokenmonL10n.format(
                "now.camp.practice.help.guaranteed",
                Int64(targetRank.rawValue),
                probabilityPercent,
                Int64(ceiling)
            )
        } else {
            baseHelp = TokenmonL10n.format(
                "now.camp.practice.help",
                Int64(targetRank.rawValue),
                probabilityPercent,
                Int64(ceiling - lead.trainingResonance),
                Int64(ceiling)
            )
        }

        switch trainAction.availability {
        case .enabled:
            return baseHelp
        case .insufficientFocus(let current, let required):
            return TokenmonL10n.format(
                "now.camp.practice.help.insufficient",
                Int64(max(0, required - current)),
                baseHelp
            )
        case .rankAtAffinityGate(let current, let required):
            return TokenmonL10n.format(
                "now.camp.practice.help.bond_gate",
                Int64(current),
                Int64(required),
                baseHelp
            )
        case .rankMaximum:
            return TokenmonL10n.string("now.camp.action.rank_max")
        case .missingLead:
            return TokenmonL10n.string("now.camp.action.missing_lead")
        case .careCharging, .focusStorageFull, .careDailyCapReached:
            return baseHelp
        }
    }

    private static func campStatusLine(
        for lead: NowCampHeroMemberPresentation?,
        trainAction: NowCampHeroActionState,
        careAction: NowCampHeroActionState
    ) -> String {
        guard lead != nil else {
            return TokenmonL10n.string("now.camp.status.no_lead")
        }
        if trainAction.isEnabled {
            return TokenmonL10n.string("now.camp.status.ready")
        }
        if careAction.isEnabled {
            return TokenmonL10n.string("now.camp.status.care_ready")
        }
        switch trainAction.availability {
        case .enabled:
            return TokenmonL10n.string("now.camp.status.ready")
        case .insufficientFocus, .rankAtAffinityGate:
            return TokenmonL10n.string("now.camp.status.gathering")
        case .rankMaximum:
            return TokenmonL10n.string("now.camp.status.max_rank")
        case .missingLead:
            return TokenmonL10n.string("now.camp.status.no_lead")
        case .careCharging, .focusStorageFull, .careDailyCapReached:
            return TokenmonL10n.string("now.camp.status.gathering")
        }
    }

    private static func energySourceLine(
        focusEnergy: Int,
        trainAction: NowCampHeroActionState
    ) -> String {
        if trainAction.isEnabled || focusEnergy >= trainAction.cost {
            return TokenmonL10n.string("now.camp.energy.source.ready")
        }
        return ""
    }

    private static func headerLeadDetail(for lead: NowCampHeroMemberPresentation?) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.header.no_rank")
        }
        return trainingLevelText(for: lead)
    }

    private static func careStatusLine(for careAction: NowCampHeroActionState) -> String? {
        careAction.kind == .care ? careDisplayText(for: careAction) : nil
    }

    static func careDisplayText(for careAction: NowCampHeroActionState) -> String {
        switch careAction.availability {
        case .enabled:
            return TokenmonL10n.string("now.camp.care.ready.short")
        case .careCharging(let remainingSeconds):
            return TokenmonL10n.format(
                "now.camp.care.minutes_remaining",
                Int64(max(1, (remainingSeconds + 59) / 60))
            )
        case .focusStorageFull:
            return TokenmonL10n.string("now.camp.care.full")
        case .careDailyCapReached:
            return TokenmonL10n.string("now.camp.care.daily_cap")
        case .rankAtAffinityGate(let current, let required):
            return TokenmonL10n.format("now.camp.action.rank_gate.short", Int64(current), Int64(required))
        case .rankMaximum:
            return TokenmonL10n.string("now.camp.action.rank_max")
        case .missingLead:
            return TokenmonL10n.string("now.camp.action.no_lead.short")
        case .insufficientFocus:
            return TokenmonL10n.string("now.camp.care.blocked")
        }
    }

    static func careDetailText(for careAction: NowCampHeroActionState) -> String {
        switch careAction.availability {
        case .enabled:
            return TokenmonL10n.format("now.camp.care.grant", Int64(careAction.cost))
        case .careCharging:
            return TokenmonL10n.string("now.camp.care.charging")
        case .focusStorageFull:
            return TokenmonL10n.string("now.camp.care.full.detail")
        case .careDailyCapReached:
            return TokenmonL10n.string("now.camp.care.daily_cap.detail")
        case .rankAtAffinityGate:
            return TokenmonL10n.string("now.camp.practice.status.bond_gate")
        case .rankMaximum:
            return TokenmonL10n.string("now.camp.action.rank_max")
        case .missingLead:
            return TokenmonL10n.string("now.camp.action.no_lead.short")
        case .insufficientFocus:
            return TokenmonL10n.string("now.camp.care.blocked")
        }
    }

    private static func trainingLevelPipCount(for lead: NowCampHeroMemberPresentation?) -> Int {
        lead?.trainingRank.rawValue ?? 0
    }

    private static func v2Telemetry(
        focusEnergy: Int,
        lead: NowCampHeroMemberPresentation?,
        trainAction: NowCampHeroActionState
    ) -> NowCampHeroV2Telemetry {
        NowCampHeroV2Telemetry(
            focusTitleText: TokenmonL10n.string("now.camp.v2.focus.title"),
            focusValueText: "\(min(max(focusEnergy, 0), focusCapacity))/\(focusCapacity)",
            practiceTitleText: TokenmonL10n.string("now.camp.v2.practice.title"),
            practiceChanceText: v2PracticeChanceText(for: lead, trainAction: trainAction),
            resonanceValueText: v2ResonanceText(for: lead, trainAction: trainAction),
            rewardTitleText: TokenmonL10n.string("now.camp.v2.reward.title"),
            rewardPreview: v2RewardPreview(for: lead, trainAction: trainAction),
            scoutActionTitleText: TokenmonL10n.string("now.camp.v2.scout"),
            scoutActionHelpText: TokenmonL10n.string("now.camp.v2.scout.help")
        )
    }

    private static func v2PracticeChanceText(
        for lead: NowCampHeroMemberPresentation?,
        trainAction: NowCampHeroActionState
    ) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.v2.unavailable")
        }
        guard let targetRank = lead.trainingRank.next else {
            return TokenmonL10n.string("now.camp.v2.max")
        }
        if case .rankAtAffinityGate = trainAction.availability {
            return TokenmonL10n.string("now.camp.v2.bond_gate")
        }

        do {
            let probability = try LeaderTrainingResolver().successProbability(
                rarity: lead.rarity,
                targetRank: targetRank
            )
            return TokenmonL10n.format(
                "now.camp.v2.percent",
                Int64((probability * 100).rounded())
            )
        } catch {
            return TokenmonL10n.string("now.camp.v2.unavailable")
        }
    }

    private static func v2ResonanceText(
        for lead: NowCampHeroMemberPresentation?,
        trainAction: NowCampHeroActionState
    ) -> String {
        guard let lead else {
            return TokenmonL10n.string("now.camp.v2.unavailable")
        }
        guard let targetRank = lead.trainingRank.next else {
            return TokenmonL10n.string("now.camp.v2.max")
        }
        if case .rankAtAffinityGate = trainAction.availability {
            return TokenmonL10n.string("now.camp.v2.bond_gate")
        }

        do {
            let resolver = LeaderTrainingResolver()
            let probability = try resolver.successProbability(
                rarity: lead.rarity,
                targetRank: targetRank
            )
            let ceiling = try resolver.ceilingFailures(probability: probability)
            let resonance = min(max(lead.trainingResonance, 0), ceiling)
            return TokenmonL10n.format(
                "now.camp.v2.resonance.value",
                Int64(resonance),
                Int64(ceiling)
            )
        } catch {
            return TokenmonL10n.string("now.camp.v2.unavailable")
        }
    }

    private static func v2RewardPreview(
        for lead: NowCampHeroMemberPresentation?,
        trainAction: NowCampHeroActionState
    ) -> NowCampHeroV2RewardPreview {
        guard let lead else {
            let currentLine = NowCampHeroV2EffectLine(
                labelText: TokenmonL10n.string("now.camp.v2.reward.current.label"),
                valueText: TokenmonL10n.string("now.camp.v2.unavailable"),
                isActive: false
            )
            let successLine = NowCampHeroV2EffectLine(
                labelText: TokenmonL10n.string("now.camp.v2.reward.success.label"),
                valueText: TokenmonL10n.string("now.camp.v2.unavailable"),
                isActive: false
            )
            return NowCampHeroV2RewardPreview(
                titleText: TokenmonL10n.string("now.camp.train.reward.empty"),
                valueText: TokenmonL10n.string("now.camp.v2.unavailable"),
                detailText: TokenmonL10n.string("now.camp.train.reward.empty"),
                compactValueText: TokenmonL10n.string("now.camp.v2.unavailable"),
                compactDetailText: TokenmonL10n.string("now.camp.train.reward.empty"),
                currentLine: currentLine,
                successLine: successLine,
                systemImage: "questionmark.circle.fill",
                isActive: false
            )
        }

        let resolver = LeaderTraitBonusResolver()
        let current = resolver.previewBonus(
            lead: v2LeaderTraitContext(for: lead, trainingRank: lead.trainingRank)
        )
        let next = lead.trainingRank.next.map { nextRank in
            resolver.previewBonus(lead: v2LeaderTraitContext(for: lead, trainingRank: nextRank))
        }
        let nextRank = lead.trainingRank.next
        let nextIsBlocked: Bool
        if case .rankAtAffinityGate = trainAction.availability {
            nextIsBlocked = true
        } else {
            nextIsBlocked = false
        }
        let currentLine = v2CurrentEffectLine(current: current)
        let successLine = v2SuccessEffectLine(
            next: next,
            nextRank: nextRank,
            trainAction: trainAction
        )

        return NowCampHeroV2RewardPreview(
            titleText: v2RewardTitleText(for: lead.trainingTrait),
            valueText: v2LeadEffectValueText(current: current),
            detailText: v2LeadEffectSummaryDetailText(currentLine: currentLine, successLine: successLine),
            compactValueText: v2LeadEffectCompactValueText(
                current: current,
                next: next,
                nextIsBlocked: nextIsBlocked
            ),
            compactDetailText: v2LeadEffectCompactDetailText(
                current: current,
                next: next,
                nextIsBlocked: nextIsBlocked
            ),
            currentLine: currentLine,
            successLine: successLine,
            systemImage: trainRewardSystemImage(for: lead),
            isActive: current.isActive
        )
    }

    private static func v2LeaderTraitContext(
        for lead: NowCampHeroMemberPresentation,
        trainingRank: TrainingRank
    ) -> LeaderTraitContext {
        LeaderTraitContext(
            speciesID: lead.speciesID,
            homeField: lead.field,
            rarity: lead.rarity,
            trait: lead.trainingTrait,
            trainingRank: trainingRank
        )
    }

    private static func v2RewardTitleText(for trait: TrainingTrait) -> String {
        switch trait {
        case .trail:
            return TokenmonL10n.string("now.camp.v2.reward.trail.title")
        case .scout:
            return TokenmonL10n.string("now.camp.v2.reward.scout.title")
        case .capture:
            return TokenmonL10n.string("now.camp.v2.reward.capture.title")
        case .raider:
            return TokenmonL10n.string("now.camp.v2.reward.raider.title")
        }
    }

    private static func v2RewardValueText(for preview: LeaderTraitBonusPreview) -> String {
        guard preview.isActive, preview.bonusAmount > 0 else {
            return TokenmonL10n.string("now.camp.v2.unavailable")
        }

        switch preview.unit {
        case .fieldWeight, .rarityWeightShift, .raidPower:
            return TokenmonL10n.format("now.camp.v2.signed_integer", Int64(preview.bonusAmount.rounded()))
        case .probabilityPoints:
            return TokenmonL10n.format("now.camp.v2.points", Int64((preview.bonusAmount * 100).rounded()))
        }
    }

    private static func v2LeadEffectValueText(current: LeaderTraitBonusPreview) -> String {
        if current.isActive {
            return v2RewardValueText(for: current)
        }
        return TokenmonL10n.string("now.camp.v2.unavailable")
    }

    private static func v2CurrentEffectLine(
        current: LeaderTraitBonusPreview
    ) -> NowCampHeroV2EffectLine {
        NowCampHeroV2EffectLine(
            labelText: TokenmonL10n.string("now.camp.v2.reward.current.label"),
            valueText: current.isActive
                ? v2RewardEffectLineText(for: current)
                : TokenmonL10n.string("now.camp.v2.reward.current.none"),
            isActive: current.isActive
        )
    }

    private static func v2SuccessEffectLine(
        next: LeaderTraitBonusPreview?,
        nextRank: TrainingRank?,
        trainAction: NowCampHeroActionState
    ) -> NowCampHeroV2EffectLine {
        let valueText: String
        let isActive: Bool
        switch trainAction.availability {
        case .rankAtAffinityGate(let current, let required):
            valueText = TokenmonL10n.format("now.camp.action.rank_gate.short", Int64(current), Int64(required))
            isActive = false
        case .rankMaximum:
            valueText = TokenmonL10n.string("now.camp.v2.max")
            isActive = false
        default:
            if nextRank == nil {
                valueText = TokenmonL10n.string("now.camp.v2.max")
                isActive = false
            } else if let next, next.isActive {
                valueText = v2RewardEffectLineText(for: next)
                isActive = true
            } else {
                valueText = TokenmonL10n.string("now.camp.v2.reward.success.none")
                isActive = false
            }
        }

        return NowCampHeroV2EffectLine(
            labelText: TokenmonL10n.string("now.camp.v2.reward.success.label"),
            valueText: valueText,
            isActive: isActive
        )
    }

    private static func v2LeadEffectSummaryDetailText(
        currentLine: NowCampHeroV2EffectLine,
        successLine: NowCampHeroV2EffectLine
    ) -> String {
        TokenmonL10n.format(
            "now.camp.v2.reward.current_success.detail",
            currentLine.valueText,
            successLine.valueText
        )
    }

    private static func v2LeadEffectCompactValueText(
        current: LeaderTraitBonusPreview,
        next: LeaderTraitBonusPreview?,
        nextIsBlocked: Bool
    ) -> String {
        if current.isActive {
            return v2RewardCompactValueText(for: current)
        }

        guard let next,
              next.isActive,
              !nextIsBlocked else {
            if nextIsBlocked {
                return TokenmonL10n.string("now.camp.v2.bond_gate")
            }
            return TokenmonL10n.string("now.camp.v2.reward.inactive")
        }

        return v2RewardCompactValueText(for: next)
    }

    private static func v2LeadEffectCompactDetailText(
        current: LeaderTraitBonusPreview,
        next: LeaderTraitBonusPreview?,
        nextIsBlocked: Bool
    ) -> String {
        if current.isActive {
            let currentDetail = v2RewardCompactDetailText(for: current)
            guard let next,
                  next.isActive,
                  !nextIsBlocked else {
                return currentDetail
            }

            let currentValue = v2RewardValueText(for: current)
            let nextValue = v2RewardValueText(for: next)
            guard currentValue != nextValue else {
                return currentDetail
            }

            return TokenmonL10n.format(
                "now.camp.v2.reward.current_to_next",
                currentDetail,
                nextValue
            )
        }

        guard let next,
              next.isActive,
              !nextIsBlocked else {
            if nextIsBlocked {
                return TokenmonL10n.string("now.camp.v2.bond_gate")
            }
            return TokenmonL10n.string("now.camp.v2.reward.inactive")
        }

        return TokenmonL10n.string("now.camp.v2.reward.unlock_first_success")
    }

    private static func v2RewardCompactValueText(for preview: LeaderTraitBonusPreview) -> String {
        let value = v2RewardValueText(for: preview)
        guard preview.isActive else {
            return value
        }

        switch preview.kind {
        case .trail:
            return TokenmonL10n.format("now.camp.v2.reward.trail.compact_value", preview.field.displayName)
        case .scout:
            return TokenmonL10n.format("now.camp.v2.reward.scout.compact_value", preview.field.displayName)
        case .capture:
            return TokenmonL10n.format("now.camp.v2.reward.capture.compact_value", preview.field.displayName)
        case .raider:
            return TokenmonL10n.format("now.camp.v2.reward.raider.compact_value", preview.field.displayName)
        }
    }

    private static func v2RewardCompactDetailText(for preview: LeaderTraitBonusPreview) -> String {
        guard preview.isActive else {
            return TokenmonL10n.string("now.camp.v2.reward.inactive")
        }

        let value = v2RewardValueText(for: preview)
        switch preview.kind {
        case .trail:
            return TokenmonL10n.format("now.camp.v2.reward.trail.compact_detail", value)
        case .scout:
            return TokenmonL10n.format("now.camp.v2.reward.scout.compact_detail", value)
        case .capture:
            return TokenmonL10n.format("now.camp.v2.reward.capture.compact_detail", value)
        case .raider:
            return TokenmonL10n.format("now.camp.v2.reward.raider.compact_detail", value)
        }
    }

    private static func v2RewardEffectLineText(for preview: LeaderTraitBonusPreview) -> String {
        let value = v2RewardValueText(for: preview)
        switch preview.kind {
        case .trail:
            return TokenmonL10n.format("now.camp.v2.reward.trail.effect_line", preview.field.displayName, value)
        case .scout:
            return TokenmonL10n.format("now.camp.v2.reward.scout.effect_line", preview.field.displayName, value)
        case .capture:
            return TokenmonL10n.format("now.camp.v2.reward.capture.effect_line", preview.field.displayName, value)
        case .raider:
            return TokenmonL10n.format("now.camp.v2.reward.raider.effect_line", preview.field.displayName, value)
        }
    }
}

enum NowCampHeroFeedbackMotion: Equatable {
    case none
    case hop
    case tilt
}

enum NowCampHeroFeedbackEffect: Equatable {
    case none
    case careHearts
    case levelUp(Int)
}

struct NowCampHeroFeedback {
    let message: String
    let systemImage: String
    let tint: Color
    let motion: NowCampHeroFeedbackMotion
    let effect: NowCampHeroFeedbackEffect

    static func careApplied(focusGranted: Int, focusEnergyAfter: Int) -> NowCampHeroFeedback {
        NowCampHeroFeedback(
            message: TokenmonL10n.format(
                "now.camp.feedback.care_applied",
                Int64(focusGranted),
                Int64(focusEnergyAfter)
            ),
            systemImage: "heart.fill",
            tint: .pink,
            motion: .hop,
            effect: .careHearts
        )
    }

    static func trainingAttempt(_ attempt: NowCampTrainingAttemptResult) -> NowCampHeroFeedback {
        switch attempt.resolution.outcome {
        case .success:
            return NowCampHeroFeedback(
                message: TokenmonL10n.format(
                    "now.camp.feedback.train_success",
                    Int64(attempt.resolution.newRank.rawValue)
                ),
                systemImage: "checkmark.seal.fill",
                tint: .green,
                motion: .hop,
                effect: .levelUp(attempt.resolution.newRank.rawValue)
            )
        case .guaranteedSuccess:
            return NowCampHeroFeedback(
                message: TokenmonL10n.format(
                    "now.camp.feedback.train_guaranteed_success",
                    Int64(attempt.resolution.newRank.rawValue)
                ),
                systemImage: "sparkles",
                tint: .yellow,
                motion: .hop,
                effect: .levelUp(attempt.resolution.newRank.rawValue)
            )
        case .failure:
            return NowCampHeroFeedback(
                message: TokenmonL10n.string("now.camp.feedback.train_failure"),
                systemImage: "arrow.triangle.2.circlepath",
                tint: .orange,
                motion: .tilt,
                effect: .none
            )
        }
    }

    static func actionFailed(_ message: String) -> NowCampHeroFeedback {
        NowCampHeroFeedback(
            message: TokenmonL10n.format("now.camp.feedback.action_failed", message),
            systemImage: "exclamationmark.triangle.fill",
            tint: .orange,
            motion: .tilt,
            effect: .none
        )
    }
}

struct TokenmonNowCampHeroCard: View {
    @ObservedObject var model: TokenmonMenuModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let sceneContext: TokenmonSceneContext
    let onScout: () -> Void

    @State private var feedback: NowCampHeroFeedback?
    @State private var feedbackToken = UUID()
    @State private var leadActionPulse = false

    private var partyMembers: [PartyMemberSummary] {
        let runtimeParty = model.raidDashboard?.partyMembers ?? []
        return runtimeParty.isEmpty ? model.partyMembers : runtimeParty
    }

    private var presentation: NowCampHeroPresentation {
        NowCampHeroPresentation.make(
            nowCamp: model.nowCampSummary,
            partyMembers: partyMembers,
            sceneContext: sceneContext
        )
    }

    var body: some View {
        TokenmonNowCampHeroPresentationCard(
            presentation: presentation,
            animates: !reduceMotion,
            feedback: feedback,
            actionPulse: !reduceMotion && leadActionPulse,
            onTrain: handleTrain,
            onCare: handleCare,
            onScout: onScout,
            headerAccessory: {
                leadPicker
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var leadPicker: some View {
        Menu {
            ForEach(partyMembers, id: \.speciesID) { member in
                let status = presentation.leadMenuStatus(for: member.speciesID)
                Button {
                    model.setNowCampLead(member.speciesID)
                } label: {
                    Label(
                        status?.titleText ?? member.displayName,
                        systemImage: status?.systemImage ?? (member.speciesID == presentation.lead?.speciesID ? "crown.fill" : "person.crop.circle")
                    )
                }
            }

            if presentation.lead != nil {
                Divider()

                Button {
                    handleCare()
                } label: {
                    Label(careMenuTitle, systemImage: careMenuSystemImage)
                }
                .disabled(presentation.careAction.isEnabled == false)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: presentation.lead == nil ? "crown" : "crown.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text(headerLeadMenuText)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                    .layoutPriority(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .frame(width: 158, height: 24)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.74))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
        .disabled(partyMembers.isEmpty)
        .help(TokenmonL10n.string("now.camp.lead_picker.help"))
    }

    private var careMenuTitle: String {
        switch presentation.careAction.availability {
        case .enabled:
            return TokenmonL10n.string("now.camp.care.menu.claim")
        case .missingLead:
            return TokenmonL10n.string("now.camp.action.no_lead.short")
        case .insufficientFocus(let current, let required):
            return TokenmonL10n.format("now.camp.care.menu.insufficient_focus", Int64(current), Int64(required))
        case .rankAtAffinityGate(let current, let required):
            return TokenmonL10n.format("now.camp.care.menu.rank_gate", Int64(current), Int64(required))
        case .rankMaximum:
            return TokenmonL10n.string("now.camp.action.rank_max")
        case .careCharging:
            return NowCampHeroPresentation.careDisplayText(for: presentation.careAction)
        case .focusStorageFull:
            return TokenmonL10n.string("now.camp.care.full")
        case .careDailyCapReached:
            return TokenmonL10n.string("now.camp.care.daily_cap")
        }
    }

    private var careMenuSystemImage: String {
        switch presentation.careAction.availability {
        case .enabled:
            return "heart.fill"
        case .careCharging:
            return "hourglass.circle.fill"
        case .focusStorageFull:
            return "bolt.slash.fill"
        case .careDailyCapReached:
            return "calendar.badge.exclamationmark"
        case .insufficientFocus:
            return "bolt.fill"
        case .rankAtAffinityGate:
            return "heart.circle.fill"
        case .rankMaximum:
            return "checkmark.seal.fill"
        case .missingLead:
            return "crown"
        }
    }

    private var headerLeadMenuText: String {
        guard presentation.lead != nil else {
            return presentation.headerLeadTitle
        }
        return "\(presentation.headerLeadTitle) · \(presentation.headerLeadDetail)"
    }

    private var accessibilityLabel: String {
        let energyLabel = TokenmonL10n.string("now.camp.focus.short")
        if let lead = presentation.lead {
            if let careStatusLine = presentation.careStatusLine {
                return "Now Camp, \(lead.displayName), \(presentation.trainingLine), \(careStatusLine), \(energyLabel) \(presentation.focusEnergy)"
            }
            return "Now Camp, \(lead.displayName), \(presentation.trainingLine), \(energyLabel) \(presentation.focusEnergy)"
        }
        return "Now Camp, \(TokenmonL10n.string("now.camp.no_party")), \(energyLabel) \(presentation.focusEnergy)"
    }

    private func handleCare() {
        let result = model.applyNowCampCareToLead()
        switch result {
        case .applied(let care):
            showFeedback(NowCampHeroFeedback.careApplied(focusGranted: care.focusGranted, focusEnergyAfter: care.focusEnergyAfter))
        case .failed(let message):
            showFailure(message)
        }
    }

    private func handleTrain() {
        let result = model.trainNowCampLead()
        switch result {
        case .resolved(let attempt):
            showFeedback(NowCampHeroFeedback.trainingAttempt(attempt))
        case .failed(let message):
            showFailure(message)
        }
    }

    private func showFailure(_ message: String) {
        showFeedback(NowCampHeroFeedback.actionFailed(message))
    }

    private func showFeedback(_ feedback: NowCampHeroFeedback) {
        self.feedback = feedback
        triggerLeadActionPulse()
        let token = UUID()
        feedbackToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard feedbackToken == token else {
                return
            }
            self.feedback = nil
        }
    }

    private func triggerLeadActionPulse() {
        guard let feedback, feedback.motion != .none else {
            return
        }
        leadActionPulse = false
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
                leadActionPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                withAnimation(.easeOut(duration: 0.20)) {
                    leadActionPulse = false
                }
            }
        }
    }
}

struct TokenmonNowCampHeroV2Card: View {
    @ObservedObject var model: TokenmonMenuModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let sceneContext: TokenmonSceneContext
    let onScout: () -> Void

    @State private var feedback: NowCampHeroFeedback?
    @State private var feedbackToken = UUID()
    @State private var leadActionPulse = false

    private var partyMembers: [PartyMemberSummary] {
        let runtimeParty = model.raidDashboard?.partyMembers ?? []
        return runtimeParty.isEmpty ? model.partyMembers : runtimeParty
    }

    private var presentation: NowCampHeroPresentation {
        NowCampHeroPresentation.make(
            nowCamp: model.nowCampSummary,
            partyMembers: partyMembers,
            sceneContext: sceneContext
        )
    }

    var body: some View {
        TokenmonNowCampHeroV2PresentationCard(
            presentation: presentation,
            animates: !reduceMotion,
            feedback: feedback,
            actionPulse: !reduceMotion && leadActionPulse,
            onTrain: handleTrain,
            onCare: handleCare,
            onScout: onScout,
            headerAccessory: {
                leadPicker
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var leadPicker: some View {
        Menu {
            ForEach(partyMembers, id: \.speciesID) { member in
                let status = presentation.leadMenuStatus(for: member.speciesID)
                Button {
                    model.setNowCampLead(member.speciesID)
                } label: {
                    Label(
                        status?.titleText ?? member.displayName,
                        systemImage: status?.systemImage ?? (member.speciesID == presentation.lead?.speciesID ? "crown.fill" : "person.crop.circle")
                    )
                }
            }

            if presentation.lead != nil {
                Divider()

                Button {
                    handleCare()
                } label: {
                    Label(careMenuTitle, systemImage: careMenuSystemImage)
                }
                .disabled(presentation.careAction.isEnabled == false)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: presentation.lead == nil ? "crown" : "crown.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(headerLeadMenuText)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.56)
                    .layoutPriority(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 9)
            .frame(width: 208, height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.76))
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize(horizontal: false, vertical: true)
        .disabled(partyMembers.isEmpty)
        .help(TokenmonL10n.string("now.camp.lead_picker.help"))
    }

    private var careMenuTitle: String {
        switch presentation.careAction.availability {
        case .enabled:
            return TokenmonL10n.string("now.camp.care.menu.claim")
        case .missingLead:
            return TokenmonL10n.string("now.camp.action.no_lead.short")
        case .insufficientFocus(let current, let required):
            return TokenmonL10n.format("now.camp.care.menu.insufficient_focus", Int64(current), Int64(required))
        case .rankAtAffinityGate(let current, let required):
            return TokenmonL10n.format("now.camp.care.menu.rank_gate", Int64(current), Int64(required))
        case .rankMaximum:
            return TokenmonL10n.string("now.camp.action.rank_max")
        case .careCharging:
            return NowCampHeroPresentation.careDisplayText(for: presentation.careAction)
        case .focusStorageFull:
            return TokenmonL10n.string("now.camp.care.full")
        case .careDailyCapReached:
            return TokenmonL10n.string("now.camp.care.daily_cap")
        }
    }

    private var careMenuSystemImage: String {
        switch presentation.careAction.availability {
        case .enabled:
            return "heart.fill"
        case .careCharging:
            return "hourglass.circle.fill"
        case .focusStorageFull:
            return "bolt.slash.fill"
        case .careDailyCapReached:
            return "calendar.badge.exclamationmark"
        case .insufficientFocus:
            return "bolt.fill"
        case .rankAtAffinityGate:
            return "heart.circle.fill"
        case .rankMaximum:
            return "checkmark.seal.fill"
        case .missingLead:
            return "crown"
        }
    }

    private var headerLeadMenuText: String {
        guard presentation.lead != nil else {
            return presentation.headerLeadTitle
        }
        return "\(presentation.headerLeadTitle) · \(presentation.headerLeadDetail)"
    }

    private var accessibilityLabel: String {
        let energyLabel = TokenmonL10n.string("now.camp.focus.short")
        if let lead = presentation.lead {
            return "Now Camp, \(lead.displayName), \(presentation.trainingLine), \(energyLabel) \(presentation.focusEnergy)"
        }
        return "Now Camp, \(TokenmonL10n.string("now.camp.no_party")), \(energyLabel) \(presentation.focusEnergy)"
    }

    private func handleCare() {
        let result = model.applyNowCampCareToLead()
        switch result {
        case .applied(let care):
            showFeedback(NowCampHeroFeedback.careApplied(focusGranted: care.focusGranted, focusEnergyAfter: care.focusEnergyAfter))
        case .failed(let message):
            showFailure(message)
        }
    }

    private func handleTrain() {
        let result = model.trainNowCampLead()
        switch result {
        case .resolved(let attempt):
            showFeedback(NowCampHeroFeedback.trainingAttempt(attempt))
        case .failed(let message):
            showFailure(message)
        }
    }

    private func showFailure(_ message: String) {
        showFeedback(NowCampHeroFeedback.actionFailed(message))
    }

    private func showFeedback(_ feedback: NowCampHeroFeedback) {
        self.feedback = feedback
        triggerLeadActionPulse()
        let token = UUID()
        feedbackToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
            guard feedbackToken == token else {
                return
            }
            self.feedback = nil
        }
    }

    private func triggerLeadActionPulse() {
        guard let feedback, feedback.motion != .none else {
            return
        }
        leadActionPulse = false
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.62)) {
                leadActionPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
                withAnimation(.easeOut(duration: 0.20)) {
                    leadActionPulse = false
                }
            }
        }
    }
}

private struct NowCampHeroCareActionButtonLabel: View {
    let displayText: String
    let detailText: String
    let iconName: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .black))
            VStack(alignment: .leading, spacing: 1) {
                Text(displayText)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
                Text(detailText)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.58)
            }
        }
        .frame(width: 112)
        .frame(minHeight: 46)
    }
}

struct TokenmonNowCampHeroV2PresentationCard<HeaderAccessory: View>: View {
    let presentation: NowCampHeroPresentation
    let animates: Bool
    let feedback: NowCampHeroFeedback?
    let actionPulse: Bool
    let feedbackMotion: NowCampHeroFeedbackMotion
    let onTrain: () -> Void
    let onCare: () -> Void
    let onScout: () -> Void
    let headerAccessory: HeaderAccessory

    @State private var idlePulse = false

    init(
        presentation: NowCampHeroPresentation,
        animates: Bool,
        feedback: NowCampHeroFeedback?,
        actionPulse: Bool = false,
        onTrain: @escaping () -> Void,
        onCare: @escaping () -> Void = {},
        onScout: @escaping () -> Void,
        @ViewBuilder headerAccessory: () -> HeaderAccessory
    ) {
        self.presentation = presentation
        self.animates = animates
        self.feedback = feedback
        self.actionPulse = actionPulse
        self.feedbackMotion = feedback?.motion ?? .none
        self.onTrain = onTrain
        self.onCare = onCare
        self.onScout = onScout
        self.headerAccessory = headerAccessory()
    }

    var body: some View {
        let clipShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        VStack(alignment: .leading, spacing: 9) {
            header

            stage

            summaryPanel

            actionRow

            footerLine
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 552, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.94))
        .clipShape(clipShape)
        .overlay(
            clipShape
                .stroke(presentation.field.nowCampTint.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 5)
        .onAppear(perform: startIdleAnimation)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 9) {
                    Text(TokenmonL10n.string("now.camp.v2.title"))
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                        .lineLimit(1)

                    Label {
                        Text(TokenmonL10n.string("now.camp.v2.subtitle"))
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    } icon: {
                        Image(systemName: presentation.fieldSystemImage)
                            .foregroundStyle(presentation.field.nowCampTint)
                    }
                    .foregroundStyle(.secondary)
                }

                Text(presentation.headerLeadDetail)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)

            headerAccessory
        }
        .frame(height: 44)
    }

    private var stage: some View {
        ZStack {
            TokenmonPopoverHeroFieldStage(
                context: presentation.sceneContext,
                companionAssetKeys: [],
                backgroundDate: nil,
                animates: animates,
                showsAmbientLayer: false
            )

            presentation.field.nowCampTint
                .opacity(0.045)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear,
                    Color.black.opacity(0.18),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            campStage
        }
        .frame(height: 286)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 0.8)
        )
        .allowsHitTesting(false)
    }

    private var campStage: some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack {
                Ellipse()
                    .fill(Color.black.opacity(0.28))
                    .frame(width: 276, height: 20)
                    .blur(radius: 0.4)
                    .position(x: size.width * 0.52, y: 258)

                trainingRing(size: size)

                NowCampEffectSpriteImage(scope: .field(presentation.field), variant: .campMat64)
                    .frame(width: 244, height: 108)
                    .opacity(0.96)
                    .shadow(color: Color.black.opacity(0.18), radius: 4, y: 1)
                    .position(x: size.width * 0.52, y: 242)

                NowCampEffectSpriteImage(scope: .field(presentation.field), variant: .campPropPrimary32)
                    .frame(width: 76, height: 76)
                    .opacity(propOpacity * 0.88)
                    .shadow(color: Color.black.opacity(0.16), radius: 3, y: 1)
                    .position(x: size.width * 0.16, y: 229)

                NowCampEffectSpriteImage(scope: .field(presentation.field), variant: .campPropSecondary32)
                    .frame(width: 76, height: 76)
                    .opacity(propOpacity * 0.84)
                    .shadow(color: Color.black.opacity(0.16), radius: 3, y: 1)
                    .position(x: size.width * 0.84, y: 230)

                ForEach(presentation.supportSlots) { slot in
                    supportSlot(slot)
                        .offset(
                            x: supportIdleXOffset(for: slot.index),
                            y: supportIdleYOffset(for: slot.index)
                        )
                        .rotationEffect(.degrees(supportIdleRotation(for: slot.index)))
                        .position(
                            x: supportX(for: slot.index, width: size.width),
                            y: 176
                        )
                }

                if let lead = presentation.lead {
                    petLifeCues(size: size)

                    leadMarker(lead)
                        .position(x: size.width * 0.50, y: 68)

                    leadSprite(lead)
                        .scaleEffect(actionPulseScale)
                        .offset(x: actionPulseXOffset, y: leadIdleYOffset + actionPulseYOffset)
                        .rotationEffect(.degrees(actionPulseRotation))
                        .position(x: size.width * 0.52, y: 192)
                        .animation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true), value: idlePulse)
                        .animation(.spring(response: 0.22, dampingFraction: 0.62), value: actionPulse)

                    if let feedback {
                        feedbackStageEffect(feedback, size: size)
                    }

                    if feedback == nil {
                        campStatusBubble
                            .position(x: size.width * 0.78, y: 48)
                    }
                } else {
                    emptyLead
                        .position(x: size.width * 0.52, y: 188)

                    if feedback == nil {
                        campStatusBubble
                            .position(x: size.width * 0.78, y: 48)
                    }
                }

                trainingLevelPips
                    .position(x: size.width * 0.78, y: 258)

                if let feedback {
                    feedbackLine(feedback)
                        .position(x: size.width * 0.50, y: 48)
                }
            }
        }
    }

    private func trainingRing(size: CGSize) -> some View {
        ZStack {
            Ellipse()
                .stroke(
                    presentation.field.nowCampTint.opacity(0.28),
                    style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [6, 5])
                )
                .frame(width: 236, height: 56)
                .position(x: size.width * 0.52, y: 222)

            NowCampEffectSpriteImage(scope: .field(presentation.field), variant: .trainFX16)
                .frame(width: 28, height: 28)
                .opacity(animates && idlePulse ? 0.86 : 0.48)
                .position(x: size.width * 0.34, y: 199)

            NowCampEffectSpriteImage(scope: .common, variant: .trainingSuccess16)
                .frame(width: 26, height: 26)
                .opacity(animates && idlePulse ? 0.72 : 0.34)
                .position(x: size.width * 0.70, y: 199)
        }
    }

    private func petLifeCues(size: CGSize) -> some View {
        ZStack {
            NowCampEffectSpriteImage(scope: .field(presentation.field), variant: .careFX16)
                .frame(width: 24, height: 24)
                .opacity(animates && idlePulse ? 0.90 : 0.48)
                .offset(y: animates && idlePulse ? -4 : 1)
                .position(x: size.width * 0.39, y: 146)

            NowCampEffectSpriteImage(scope: .common, variant: .trainingSuccess16)
                .frame(width: 22, height: 22)
                .opacity(animates && idlePulse ? 0.76 : 0.38)
                .offset(y: animates && idlePulse ? -2 : 2)
                .position(x: size.width * 0.64, y: 143)
        }
    }

    @ViewBuilder
    private func feedbackStageEffect(_ feedback: NowCampHeroFeedback, size: CGSize) -> some View {
        switch feedback.effect {
        case .careHearts:
            ForEach(0..<3, id: \.self) { index in
                let xOffsets: [CGFloat] = [-34, 0, 34]
                let yOffsets: [CGFloat] = [0, -8, 2]
                Image(systemName: "heart.fill")
                    .font(.system(size: index == 1 ? 16 : 13, weight: .bold))
                    .foregroundStyle(Color.pink.opacity(0.88))
                    .shadow(color: Color.black.opacity(0.20), radius: 2, y: 1)
                    .offset(
                        x: xOffsets[index],
                        y: (animates && actionPulse ? -24 : -8) + yOffsets[index]
                    )
                    .opacity(animates && actionPulse ? 0.95 : 0.72)
                    .position(x: size.width * 0.52, y: 164)
            }
        case .levelUp(let rank):
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .black))
                Text(TokenmonL10n.format("now.camp.feedback.level_badge", Int64(rank)))
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(Color.white.opacity(0.96))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.green.opacity(0.78))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.42), lineWidth: 0.8)
            )
            .offset(y: animates && actionPulse ? -14 : -4)
            .position(x: size.width * 0.66, y: 146)
        case .none:
            EmptyView()
        }
    }

    private var summaryPanel: some View {
        HStack(spacing: 0) {
            summaryColumn(
                icon: "bolt.fill",
                title: presentation.v2.focusTitleText,
                value: presentation.v2.focusValueText,
                detail: presentation.energySourceLine,
                tint: .green,
                footer: AnyView(focusMeter)
            )

            Divider()
                .padding(.vertical, 4)

            summaryColumn(
                icon: "scope",
                title: presentation.v2.practiceTitleText,
                value: presentation.v2.practiceChanceText,
                detail: TokenmonL10n.format("now.camp.v2.resonance", presentation.v2.resonanceValueText),
                tint: .blue,
                footer: AnyView(resonanceMeter)
            )

            Divider()
                .padding(.vertical, 4)

            summaryColumn(
                icon: presentation.v2.rewardPreview.systemImage,
                title: presentation.v2.rewardTitleText,
                value: "\(presentation.v2.rewardPreview.titleText) \(presentation.v2.rewardPreview.valueText)",
                detail: presentation.v2.rewardPreview.detailText,
                tint: presentation.field.nowCampTint,
                footer: AnyView(EmptyView())
            )
        }
        .frame(height: 96)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.secondary.opacity(0.14), lineWidth: 0.8)
        )
    }

    private func summaryColumn(
        icon: String,
        title: String,
        value: String,
        detail: String,
        tint: Color,
        footer: AnyView
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.56)

            Text(detail.isEmpty ? " " : detail)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .opacity(detail.isEmpty ? 0 : 1)

            footer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var focusMeter: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))
                Capsule()
                    .fill(Color.green.opacity(0.74))
                    .frame(width: geometry.size.width * focusFraction)
            }
        }
        .frame(height: 8)
    }

    private var resonanceMeter: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.16))
                Capsule()
                    .fill(Color.blue.opacity(0.72))
                    .frame(width: geometry.size.width * resonanceFraction)
            }
        }
        .frame(height: 8)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                guard presentation.trainAction.isEnabled else {
                    return
                }
                onTrain()
            } label: {
                Label {
                    Text(TokenmonL10n.string("now.camp.v2.train"))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: practiceIcon(for: presentation.trainAction))
                        .font(.system(size: 16, weight: .black))
                }
                .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.plain)
            .foregroundStyle(presentation.trainAction.isEnabled ? Color.white.opacity(0.96) : Color.white.opacity(0.62))
            .background(actionButtonBackground(for: presentation.trainAction))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(actionButtonStroke(for: presentation.trainAction), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: actionButtonShadow(for: presentation.trainAction), radius: 7, y: 2)
            .help(presentation.attemptHelpText)
            .disabled(!presentation.trainAction.isEnabled)

            Button {
                guard presentation.careAction.isEnabled else {
                    return
                }
                onCare()
            } label: {
                NowCampHeroCareActionButtonLabel(
                    displayText: careActionDisplayText,
                    detailText: careActionDetailText,
                    iconName: careActionIconName
                )
            }
            .buttonStyle(.plain)
            .foregroundStyle(presentation.careAction.isEnabled ? Color.white.opacity(0.96) : Color.secondary.opacity(0.82))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(presentation.careAction.isEnabled ? Color.pink.opacity(0.72) : Color.secondary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(presentation.careAction.isEnabled ? Color.white.opacity(0.42) : Color.secondary.opacity(0.14), lineWidth: 0.9)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .help(careActionDetailText)
            .disabled(!presentation.careAction.isEnabled)

            Button(action: onScout) {
                Label {
                    Text(presentation.v2.scoutActionTitleText)
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                } icon: {
                    Image(systemName: "binoculars.fill")
                        .font(.system(size: 15, weight: .black))
                }
                .frame(maxWidth: .infinity, minHeight: 46)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.30), lineWidth: 0.9)
            )
            .help(presentation.v2.scoutActionHelpText)
        }
    }

    private var footerLine: some View {
        Label {
            Text(footerText)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
        } icon: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 26, alignment: .leading)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.secondary.opacity(0.06))
        )
        .help(presentation.attemptHelpText)
    }

    private var footerText: String {
        if let careStatusLine = presentation.careStatusLine {
            return "\(presentation.trainingLine) · \(careStatusLine)"
        }
        return "\(presentation.trainingLine) · \(presentation.practiceStatusText)"
    }

    private var trainingLevelPips: some View {
        HStack(spacing: 6) {
            Text("\(presentation.trainingLevelPipCount)/\(TrainingRank.rankV.rawValue)")
                .font(.system(size: 9, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.white.opacity(0.86))

            HStack(spacing: 4) {
                ForEach(0..<TrainingRank.rankV.rawValue, id: \.self) { index in
                    trainingPip(isLit: index < presentation.trainingLevelPipCount)
                }
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
        )
        .shadow(color: Color.black.opacity(0.18), radius: 2, y: 1)
        .help(presentation.trainingLevelText)
    }

    private func trainingPip(isLit: Bool) -> some View {
        NowCampEffectSpriteImage(scope: .common, variant: .resonanceOrb16)
            .frame(width: 13, height: 13)
            .saturation(isLit ? 1.0 : 0.0)
            .brightness(isLit ? 0.04 : -0.16)
            .opacity(isLit ? 0.96 : 0.36)
            .shadow(
                color: isLit ? presentation.field.nowCampTint.opacity(0.42) : Color.clear,
                radius: isLit ? 3 : 0
            )
    }

    private var campStatusBubble: some View {
        Text(presentation.campStatusLine)
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white.opacity(0.92))
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.black.opacity(0.42))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.16), lineWidth: 0.7)
            )
            .shadow(color: Color.black.opacity(0.14), radius: 2, y: 1)
    }

    private func leadMarker(_ lead: NowCampHeroMemberPresentation) -> some View {
        VStack(spacing: 2) {
            Text(TokenmonL10n.string("now.camp.lead_badge"))
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundStyle(presentation.field.nowCampTint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Image(systemName: presentation.fieldSystemImage)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.88))
        }
        .frame(width: 52, height: 42)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.black.opacity(0.48))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.20), radius: 3, y: 1)
        .help(lead.displayName)
    }

    private func feedbackLine(_ feedback: NowCampHeroFeedback) -> some View {
        HStack(spacing: 6) {
            Image(systemName: feedback.systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(feedback.tint)
            Text(feedback.message)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .frame(width: 210, height: 26, alignment: .center)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.38))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.7)
        )
    }

    private func supportSlot(_ slot: NowCampHeroSupportSlot) -> some View {
        switch slot {
        case .occupied(let member, _):
            return AnyView(
                TokenmonDexSpritePreview(
                    status: .captured,
                    revealStage: .revealed,
                    field: member.field,
                    rarity: member.rarity,
                    assetKey: member.assetKey,
                    cardSize: 62,
                    spriteSize: 46,
                    showsBackground: false,
                    showsBorder: false
                )
                .opacity(0.66)
                .help(member.displayName)
            )
        case .empty:
            return AnyView(emptySupportSlot)
        }
    }

    private func leadSprite(_ lead: NowCampHeroMemberPresentation) -> some View {
        TokenmonDexSpritePreview(
            status: .captured,
            revealStage: .revealed,
            field: lead.field,
            rarity: lead.rarity,
            assetKey: lead.assetKey,
            cardSize: 138,
            spriteSize: 106,
            showsBackground: false,
            showsBorder: false
        )
        .shadow(color: Color.black.opacity(0.23), radius: 5, y: 2)
        .help(lead.displayName)
    }

    private var emptyLead: some View {
        Image(systemName: "crown")
            .font(.system(size: 30, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.white.opacity(0.40))
            .frame(width: 86, height: 86)
            .background(
                Circle()
                    .fill(Color.black.opacity(0.24))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
            )
    }

    private var emptySupportSlot: some View {
        ZStack(alignment: .topTrailing) {
            Circle()
                .fill(Color.black.opacity(0.20))
                .frame(width: 50, height: 50)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.8)
                )

            Image(systemName: "plus")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(Color.white.opacity(0.88))
                .frame(width: 17, height: 17)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.black.opacity(0.46))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .stroke(Color.white.opacity(0.24), lineWidth: 0.6)
                )
                .offset(x: 3, y: -3)
        }
        .opacity(0.72)
        .help(TokenmonL10n.string("now.camp.lead_picker.help"))
    }

    private func practiceIcon(for state: NowCampHeroActionState) -> String {
        switch state.availability {
        case .enabled:
            return "figure.strengthtraining.traditional"
        case .insufficientFocus:
            return "hourglass.circle.fill"
        case .rankAtAffinityGate:
            return "heart.circle.fill"
        case .rankMaximum:
            return "checkmark.seal.fill"
        case .missingLead:
            return "crown"
        case .careCharging, .focusStorageFull, .careDailyCapReached:
            return "hourglass.circle.fill"
        }
    }

    private func careIcon(for state: NowCampHeroActionState) -> String {
        switch state.availability {
        case .enabled:
            return "heart.fill"
        case .careCharging:
            return "hourglass.circle.fill"
        case .focusStorageFull:
            return "bolt.slash.fill"
        case .careDailyCapReached:
            return "calendar.badge.exclamationmark"
        case .rankAtAffinityGate:
            return "heart.circle.fill"
        case .rankMaximum:
            return "checkmark.seal.fill"
        case .missingLead:
            return "crown"
        case .insufficientFocus:
            return "bolt.fill"
        }
    }

    private func actionButtonBackground(for state: NowCampHeroActionState) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(
                state.isEnabled
                    ? presentation.field.nowCampTint.opacity(0.88)
                    : Color(nsColor: .controlBackgroundColor).opacity(0.82)
            )
    }

    private func actionButtonStroke(for state: NowCampHeroActionState) -> Color {
        state.isEnabled ? Color.white.opacity(0.62) : Color.white.opacity(0.24)
    }

    private func actionButtonShadow(for state: NowCampHeroActionState) -> Color {
        state.isEnabled ? presentation.field.nowCampTint.opacity(0.28) : Color.black.opacity(0.12)
    }

    private var careActionDisplayText: String {
        NowCampHeroPresentation.careDisplayText(for: presentation.careAction)
    }

    private var careActionDetailText: String {
        NowCampHeroPresentation.careDetailText(for: presentation.careAction)
    }

    private var careActionIconName: String {
        careIcon(for: presentation.careAction)
    }

    private var focusFraction: CGFloat {
        CGFloat(min(1.0, max(0.0, Double(presentation.focusEnergy) / Double(NowCampHeroPresentation.focusCapacity))))
    }

    private var resonanceFraction: CGFloat {
        let components = presentation.v2.resonanceValueText.split(separator: "/")
        guard components.count == 2,
              let value = Double(components[0]),
              let total = Double(components[1]),
              total > 0 else {
            return 0
        }
        return CGFloat(min(1.0, max(0.0, value / total)))
    }

    private func supportX(for index: Int, width: CGFloat) -> CGFloat {
        index == 0 ? width * 0.29 : width * 0.72
    }

    private var propOpacity: Double {
        guard animates else {
            return 0.82
        }
        return idlePulse ? 0.92 : 0.74
    }

    private var leadIdleYOffset: CGFloat {
        guard animates else {
            return 0
        }
        return idlePulse ? -3.0 : 1.0
    }

    private var leadIdleRotation: Double {
        guard animates else {
            return 0
        }
        return idlePulse ? -1.0 : 1.0
    }

    private var actionPulseScale: CGFloat {
        guard actionPulse else {
            return 1.0
        }
        switch feedbackMotion {
        case .hop:
            return 1.07
        case .tilt:
            return 1.02
        case .none:
            return 1.0
        }
    }

    private var actionPulseYOffset: CGFloat {
        guard actionPulse else {
            return 0
        }
        switch feedbackMotion {
        case .hop:
            return -7
        case .tilt, .none:
            return 0
        }
    }

    private var actionPulseXOffset: CGFloat {
        guard actionPulse, feedbackMotion == .tilt else {
            return 0
        }
        return 3.0
    }

    private var actionPulseRotation: Double {
        guard actionPulse else {
            return leadIdleRotation
        }
        switch feedbackMotion {
        case .hop:
            return 2.2
        case .tilt:
            return -6.0
        case .none:
            return leadIdleRotation
        }
    }

    private func supportIdleYOffset(for index: Int) -> CGFloat {
        guard animates else {
            return 0
        }
        return idlePulse == index.isMultiple(of: 2) ? -1.8 : 1.3
    }

    private func supportIdleXOffset(for index: Int) -> CGFloat {
        guard animates else {
            return 0
        }
        return idlePulse == index.isMultiple(of: 2) ? -1.4 : 1.4
    }

    private func supportIdleRotation(for index: Int) -> Double {
        guard animates else {
            return 0
        }
        return idlePulse == index.isMultiple(of: 2) ? -2.0 : 2.0
    }

    private func startIdleAnimation() {
        guard animates else {
            return
        }
        idlePulse = false
        withAnimation(.easeInOut(duration: 1.55).repeatForever(autoreverses: true)) {
            idlePulse = true
        }
    }
}

struct TokenmonNowCampHeroPresentationCard<HeaderAccessory: View>: View {
    let presentation: NowCampHeroPresentation
    let animates: Bool
    let feedback: NowCampHeroFeedback?
    let actionPulse: Bool
    let feedbackMotion: NowCampHeroFeedbackMotion
    let onTrain: () -> Void
    let onCare: () -> Void
    let onScout: () -> Void
    let headerAccessory: HeaderAccessory

    @State private var idlePulse = false

    init(
        presentation: NowCampHeroPresentation,
        animates: Bool,
        feedback: NowCampHeroFeedback?,
        actionPulse: Bool = false,
        onTrain: @escaping () -> Void,
        onCare: @escaping () -> Void = {},
        onScout: @escaping () -> Void = {},
        @ViewBuilder headerAccessory: () -> HeaderAccessory
    ) {
        self.presentation = presentation
        self.animates = animates
        self.feedback = feedback
        self.actionPulse = actionPulse
        self.feedbackMotion = feedback?.motion ?? .none
        self.onTrain = onTrain
        self.onCare = onCare
        self.onScout = onScout
        self.headerAccessory = headerAccessory()
    }

    var body: some View {
        let clipShape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        VStack(spacing: 0) {
            header
                .frame(height: 32)

            ZStack {
                TokenmonPopoverHeroFieldStage(
                    context: presentation.sceneContext,
                    companionAssetKeys: [],
                    backgroundDate: nil,
                    animates: animates,
                    showsAmbientLayer: false
                )

                presentation.field.nowCampTint
                    .opacity(0.035)

                LinearGradient(
                    colors: [
                        Color.white.opacity(0.10),
                        Color.clear,
                        Color.black.opacity(0.07),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                campStage
            }
            .frame(height: 214)
            .clipped()

            compactTrainingRow
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .frame(height: 368)
        .background(compactCardBackground)
        .clipShape(clipShape)
        .overlay(
            clipShape
                .stroke(presentation.field.nowCampTint.opacity(0.24), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.10), radius: 8, y: 3)
        .onAppear(perform: startIdleAnimation)
    }

    private var header: some View {
        HStack(spacing: 5) {
            Label {
                Text(TokenmonL10n.string("now.camp.title"))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            } icon: {
                Image(systemName: presentation.fieldSystemImage)
                    .foregroundStyle(presentation.field.nowCampTint)
            }

            Spacer(minLength: 6)

            headerAccessory
        }
        .padding(.horizontal, 8)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .controlBackgroundColor).opacity(0.74),
                    presentation.field.nowCampTint.opacity(0.13),
                    Color.white.opacity(0.035),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var compactCardBackground: some View {
        ZStack {
            Color(nsColor: .controlBackgroundColor).opacity(0.62)
            presentation.field.nowCampTint.opacity(0.055)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.055),
                    Color.clear,
                    Color.black.opacity(0.035),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var campStage: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                campForegroundWash(size: size)

                campFoundation(size: size)

                if let lead = presentation.lead {
                    leadSprite(lead)
                        .scaleEffect(1.02)
                        .scaleEffect(actionPulseScale)
                        .offset(x: actionPulseXOffset, y: leadIdleYOffset + actionPulseYOffset)
                        .rotationEffect(.degrees(actionPulseRotation))
                        .position(x: size.width * 0.52, y: size.height * 0.70)
                        .animation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true), value: idlePulse)
                        .animation(.spring(response: 0.22, dampingFraction: 0.62), value: actionPulse)

                    if let feedback {
                        feedbackStageEffect(feedback, size: size)
                        compactFeedbackLine(feedback)
                            .position(x: size.width * 0.50, y: 38)
                    }
                } else {
                    emptyLead
                        .position(x: size.width * 0.52, y: size.height * 0.70)

                    if let feedback {
                        compactFeedbackLine(feedback)
                            .position(x: size.width * 0.50, y: 38)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func campForegroundWash(size: CGSize) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.07),
                    Color.black.opacity(0.22),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: size.width, height: 70)
            .position(x: size.width * 0.5, y: size.height - 35)

            Capsule(style: .continuous)
                .fill(presentation.field.nowCampTint.opacity(0.11))
                .frame(width: 212, height: 30)
                .blur(radius: 9)
                .position(x: size.width * 0.52, y: size.height - 24)
        }
    }

    private func campFoundation(size: CGSize) -> some View {
        return ZStack {
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.black.opacity(0.26),
                            Color.black.opacity(0.10),
                            Color.clear,
                        ],
                        center: .center,
                        startRadius: 4,
                        endRadius: 78
                    )
                )
                .frame(width: 164, height: 18)
                .blur(radius: 2.2)
                .position(x: size.width * 0.52, y: size.height - 25)

            Ellipse()
                .fill(presentation.field.nowCampTint.opacity(0.16))
                .frame(width: 116, height: 10)
                .blur(radius: 1.4)
                .position(x: size.width * 0.52, y: size.height - 28)
        }
    }

    private func compactFeedbackLine(_ feedback: NowCampHeroFeedback) -> some View {
        HStack(spacing: 5) {
            Image(systemName: feedback.systemImage)
                .font(.system(size: 10, weight: .black))
                .foregroundStyle(feedback.tint)
            Text(feedback.message)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .foregroundStyle(Color.white.opacity(0.94))
        .padding(.horizontal, 9)
        .frame(width: 178, height: 24, alignment: .center)
        .background(
            Capsule(style: .continuous)
                .fill(Color.black.opacity(0.48))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 0.7)
        )
        .shadow(color: Color.black.opacity(0.16), radius: 2, y: 1)
    }

    @ViewBuilder
    private func feedbackStageEffect(_ feedback: NowCampHeroFeedback, size: CGSize) -> some View {
        switch feedback.effect {
        case .careHearts:
            ForEach(0..<3, id: \.self) { index in
                let xOffsets: [CGFloat] = [-24, 0, 24]
                let yOffsets: [CGFloat] = [0, -6, 2]
                Image(systemName: "heart.fill")
                    .font(.system(size: index == 1 ? 13 : 11, weight: .bold))
                    .foregroundStyle(Color.pink.opacity(0.88))
                    .shadow(color: Color.black.opacity(0.20), radius: 2, y: 1)
                    .offset(
                        x: xOffsets[index],
                        y: (animates && actionPulse ? -18 : -6) + yOffsets[index]
                    )
                    .opacity(animates && actionPulse ? 0.94 : 0.72)
                    .position(x: size.width * 0.52, y: size.height * 0.48)
            }
        case .levelUp(let rank):
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .black))
                Text(TokenmonL10n.format("now.camp.feedback.level_badge", Int64(rank)))
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(Color.white.opacity(0.96))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.green.opacity(0.78))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(Color.white.opacity(0.38), lineWidth: 0.7)
            )
            .offset(y: animates && actionPulse ? -11 : -3)
            .position(x: size.width * 0.66, y: size.height * 0.47)
        case .none:
            EmptyView()
        }
    }

    private var compactTrainingRow: some View {
        GeometryReader { geometry in
            let rowWidth = geometry.size.width
            let careWidth = max(104, min(124, rowWidth * 0.34))
            VStack(spacing: 7) {
                HStack(spacing: 8) {
                    compactLeadEffectColumn
                        .frame(maxWidth: .infinity, minHeight: 34, maxHeight: 34)

                    compactCareColumn
                        .frame(width: careWidth)
                        .frame(minHeight: 34, maxHeight: 34)
                }

                compactTrainColumn
                    .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: 93)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.075),
                            presentation.field.nowCampTint.opacity(0.070),
                            Color.white.opacity(0.026),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(presentation.field.nowCampTint.opacity(0.14), lineWidth: 0.8)
        )
    }

    private var compactLeadEffectColumn: some View {
        HStack(alignment: .center, spacing: 7) {
            Image(systemName: presentation.v2.rewardPreview.systemImage)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(presentation.field.nowCampTint.opacity(0.82))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(TokenmonL10n.string("now.camp.v2.reward.compact.title"))
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.58))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                compactEffectLine(presentation.v2.rewardPreview.currentLine)
                compactEffectLine(presentation.v2.rewardPreview.successLine)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func compactEffectLine(_ line: NowCampHeroV2EffectLine) -> some View {
        HStack(spacing: 4) {
            Text(line.labelText)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.54))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(width: 34, alignment: .leading)

            Text(line.valueText)
                .font(.system(size: 9.2, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(line.isActive ? Color.white.opacity(0.90) : Color.white.opacity(0.68))
                .lineLimit(1)
                .minimumScaleFactor(0.42)
        }
    }

    private var compactCareColumn: some View {
        Button {
            guard presentation.careAction.isEnabled else {
                return
            }
            onCare()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: careIcon(for: presentation.careAction))
                        .font(.system(size: 9, weight: .black))
                    Text(NowCampHeroPresentation.careDisplayText(for: presentation.careAction))
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.48)
                }
                Text(NowCampHeroPresentation.careDetailText(for: presentation.careAction))
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(compactActionDetailForeground(for: presentation.careAction))
                    .lineLimit(1)
                    .minimumScaleFactor(0.44)
            }
            .padding(.horizontal, 7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(compactActionForeground(for: presentation.careAction))
        .background(compactActionBackground(for: presentation.careAction))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(compactActionStroke(for: presentation.careAction), lineWidth: 0.9)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shadow(color: compactActionShadow(for: presentation.careAction), radius: 3, y: 1)
        .help(NowCampHeroPresentation.careDetailText(for: presentation.careAction))
        .disabled(!presentation.careAction.isEnabled)
    }

    private var compactTrainColumn: some View {
        Button {
            guard presentation.trainAction.isEnabled else {
                return
            }
            onTrain()
        } label: {
            HStack(spacing: 7) {
                compactTrainIcon(for: presentation.trainAction)

                VStack(alignment: .leading, spacing: 1) {
                    Text(compactTrainPrimaryText)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.56)

                    Text(compactTrainDetailText)
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(compactActionDetailForeground(for: presentation.trainAction))
                        .lineLimit(1)
                        .minimumScaleFactor(0.50)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)

                compactTrainTrailingGlyph(for: presentation.trainAction)
            }
            .padding(.horizontal, 9)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(compactActionForeground(for: presentation.trainAction))
        .background(compactActionBackground(for: presentation.trainAction))
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(compactActionStroke(for: presentation.trainAction), lineWidth: 0.9)
        )
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .shadow(color: compactActionShadow(for: presentation.trainAction), radius: 3, y: 1)
        .help(presentation.attemptHelpText)
        .disabled(!presentation.trainAction.isEnabled)
    }

    private func compactTrainIcon(for state: NowCampHeroActionState) -> some View {
        Image(systemName: practiceIcon(for: state))
            .font(.system(size: 11, weight: .black))
            .foregroundStyle(compactActionIconForeground(for: state))
            .frame(width: 22, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(compactActionIconFill(for: state))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(compactActionIconStroke(for: state), lineWidth: 0.8)
            )
    }

    @ViewBuilder
    private func compactTrainTrailingGlyph(for state: NowCampHeroActionState) -> some View {
        if state.isEnabled {
            Image(systemName: "arrow.up.forward")
                .font(.system(size: 10, weight: .black))
                .frame(width: 16, height: 16)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.18))
                )
        }
    }

    private var compactTrainPrimaryText: String {
        guard presentation.trainAction.isEnabled else {
            return presentation.practiceStatusText
        }
        return TokenmonL10n.string("now.camp.v2.train")
    }

    private var compactTrainDetailText: String {
        guard presentation.trainAction.isEnabled else {
            return presentation.practiceControlDetailText
        }
        return presentation.targetLevelText
    }

    private func compactActionBackground(for state: NowCampHeroActionState) -> some View {
        GeometryReader { geometry in
            let shape = RoundedRectangle(cornerRadius: 9, style: .continuous)
            ZStack(alignment: .leading) {
                shape
                    .fill(actionButtonFill(for: state))

                Rectangle()
                    .fill(compactActionProgressFill(for: state))
                    .frame(width: max(0, geometry.size.width * compactProgress(for: state)))
                    .clipShape(shape)

                LinearGradient(
                    colors: [
                        Color.white.opacity(state.isEnabled ? 0.14 : 0.055),
                        Color.clear,
                        Color.black.opacity(state.isEnabled ? 0.045 : 0.025),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(state.isEnabled ? 0.18 : 0.04), lineWidth: 0.8)
            }
        }
    }

    private func compactActionProgressFill(for state: NowCampHeroActionState) -> LinearGradient {
        if state.kind == .care {
            if state.isEnabled {
                return LinearGradient(
                    colors: [
                        compactCareAccent.opacity(0.16),
                        compactCareAccent.opacity(0.08),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            return LinearGradient(
                colors: [
                    Color.white.opacity(0.055),
                    Color.white.opacity(0.025),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
        if state.isEnabled {
            return LinearGradient(
                colors: [
                    presentation.field.nowCampTint.opacity(0.055),
                    presentation.field.nowCampTint.opacity(0.025),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [
                presentation.field.nowCampTint.opacity(0.075),
                Color.white.opacity(0.025),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func compactProgress(for state: NowCampHeroActionState) -> CGFloat {
        guard state.kind == .care else {
            return CGFloat(presentation.practiceProgressFraction)
        }
        switch state.availability {
        case .enabled, .focusStorageFull, .careDailyCapReached:
            return 1
        case .careCharging(let remainingSeconds):
            let elapsed = max(0, NowCampCarePolicy.intervalSeconds - remainingSeconds)
            return CGFloat(min(1.0, max(0.0, Double(elapsed) / Double(NowCampCarePolicy.intervalSeconds))))
        case .missingLead, .insufficientFocus, .rankAtAffinityGate, .rankMaximum:
            return 0
        }
    }

    private func practiceIcon(for state: NowCampHeroActionState) -> String {
        switch state.availability {
        case .enabled:
            return "figure.play.circle.fill"
        case .insufficientFocus:
            return "hourglass.circle.fill"
        case .rankAtAffinityGate:
            return "heart.circle.fill"
        case .rankMaximum:
            return "checkmark.seal.fill"
        case .missingLead:
            return "crown"
        case .careCharging, .focusStorageFull, .careDailyCapReached:
            return "hourglass.circle.fill"
        }
    }

    private func careIcon(for state: NowCampHeroActionState) -> String {
        switch state.availability {
        case .enabled:
            return "heart.fill"
        case .careCharging:
            return "hourglass.circle.fill"
        case .focusStorageFull:
            return "bolt.slash.fill"
        case .careDailyCapReached:
            return "calendar.badge.exclamationmark"
        case .rankAtAffinityGate:
            return "heart.circle.fill"
        case .rankMaximum:
            return "checkmark.seal.fill"
        case .missingLead:
            return "crown"
        case .insufficientFocus:
            return "bolt.fill"
        }
    }

    private func actionButtonFill(for state: NowCampHeroActionState) -> Color {
        guard state.isEnabled else {
            return Color.white.opacity(0.052)
        }
        if state.kind == .care {
            return compactCareAccent.opacity(0.12)
        }
        return presentation.field.nowCampTint.opacity(0.13)
    }

    private func actionButtonStroke(for state: NowCampHeroActionState) -> Color {
        guard state.isEnabled else {
            return Color.white.opacity(0.10)
        }
        if state.kind == .care {
            return compactCareAccent.opacity(0.50)
        }
        return presentation.field.nowCampTint.opacity(0.38)
    }

    private func actionForeground(for state: NowCampHeroActionState) -> Color {
        state.isEnabled ? Color.white.opacity(0.96) : Color.white.opacity(0.70)
    }

    private func compactActionForeground(for state: NowCampHeroActionState) -> Color {
        state.isEnabled ? Color.white.opacity(0.96) : Color.white.opacity(0.56)
    }

    private func compactActionDetailForeground(for state: NowCampHeroActionState) -> Color {
        if state.isEnabled, state.kind == .care {
            return compactCareAccent.opacity(0.84)
        }
        return state.isEnabled ? Color.white.opacity(0.70) : Color.white.opacity(0.40)
    }

    private func compactActionStroke(for state: NowCampHeroActionState) -> Color {
        actionButtonStroke(for: state)
    }

    private func compactActionShadow(for state: NowCampHeroActionState) -> Color {
        guard state.isEnabled else {
            return Color.clear
        }
        return state.kind == .care ? compactCareAccent.opacity(0.14) : presentation.field.nowCampTint.opacity(0.16)
    }

    private func compactActionIconForeground(for state: NowCampHeroActionState) -> Color {
        if state.isEnabled, state.kind == .care {
            return compactCareAccent.opacity(0.92)
        }
        return state.isEnabled ? Color.white.opacity(0.92) : Color.white.opacity(0.50)
    }

    private func compactActionIconFill(for state: NowCampHeroActionState) -> Color {
        if state.isEnabled, state.kind == .care {
            return compactCareAccent.opacity(0.12)
        }
        return Color.white.opacity(state.isEnabled ? 0.10 : 0.055)
    }

    private func compactActionIconStroke(for state: NowCampHeroActionState) -> Color {
        if state.isEnabled, state.kind == .care {
            return compactCareAccent.opacity(0.34)
        }
        return Color.white.opacity(state.isEnabled ? 0.18 : 0.08)
    }

    private var compactCareAccent: Color {
        Color(red: 1.0, green: 0.43, blue: 0.60)
    }

    private func leadSprite(_ lead: NowCampHeroMemberPresentation) -> some View {
        TokenmonDexSpritePreview(
            status: .captured,
            revealStage: .revealed,
            field: lead.field,
            rarity: lead.rarity,
            assetKey: lead.assetKey,
            cardSize: 90,
            spriteSize: 70,
            showsBackground: false,
            showsBorder: false
        )
        .shadow(color: Color.black.opacity(0.22), radius: 4, y: 2)
        .help(lead.displayName)
    }

    private var emptyLead: some View {
        Image(systemName: "crown")
            .font(.system(size: 23, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.white.opacity(0.38))
            .frame(width: 58, height: 58)
        .background(
            Circle()
                .fill(Color.black.opacity(0.24))
        )
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
        )
    }

    private var leadIdleYOffset: CGFloat {
        guard animates else {
            return 0
        }
        return idlePulse ? -2.0 : 1.0
    }

    private var leadIdleRotation: Double {
        guard animates else {
            return 0
        }
        return idlePulse ? -1.2 : 1.2
    }

    private var actionPulseScale: CGFloat {
        guard actionPulse else {
            return 1.0
        }
        switch feedbackMotion {
        case .hop:
            return 1.07
        case .tilt:
            return 1.02
        case .none:
            return 1.0
        }
    }

    private var actionPulseYOffset: CGFloat {
        guard actionPulse else {
            return 0
        }
        switch feedbackMotion {
        case .hop:
            return -5
        case .tilt, .none:
            return 0
        }
    }

    private var actionPulseXOffset: CGFloat {
        guard actionPulse, feedbackMotion == .tilt else {
            return 0
        }
        return 2.5
    }

    private var actionPulseRotation: Double {
        guard actionPulse else {
            return leadIdleRotation
        }
        switch feedbackMotion {
        case .hop:
            return 2.5
        case .tilt:
            return -7.0
        case .none:
            return leadIdleRotation
        }
    }

    private func startIdleAnimation() {
        guard animates else {
            return
        }
        idlePulse = false
        withAnimation(.easeInOut(duration: 1.55).repeatForever(autoreverses: true)) {
            idlePulse = true
        }
    }

}

struct TokenmonNowCampHeaderLeadLabel: View {
    let presentation: NowCampHeroPresentation

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: presentation.lead == nil ? "crown" : "crown.fill")
                .font(.system(size: 11, weight: .semibold))
            Text(headerText)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.56)
                .layoutPriority(1)
        }
        .padding(.horizontal, 6)
        .frame(width: 158, height: 24)
        .background(
            Capsule(style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.74))
        )
    }

    private var headerText: String {
        guard presentation.lead != nil else {
            return presentation.headerLeadTitle
        }
        return "\(presentation.headerLeadTitle) · \(presentation.headerLeadDetail)"
    }
}

extension FieldType {
    var nowCampTint: Color {
        switch self {
        case .grassland:
            return Color(red: 0.54, green: 0.80, blue: 0.27)
        case .coast:
            return Color(red: 0.31, green: 0.74, blue: 0.96)
        case .ice:
            return Color(red: 0.62, green: 0.86, blue: 1.00)
        case .sky:
            return Color(red: 0.55, green: 0.70, blue: 1.00)
        }
    }
}
