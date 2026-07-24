import Foundation

public enum RaidCatalog {
    public static let allRaids: [RaidDefinition] = [
        tutorialRaid,
    ] + monthlyRewardSpecs.map(\.raidDefinition) + [
        practiceRaid,
    ]

    public static let allRewards: [RaidRewardDefinition] = [
        RaidRewardDefinition(
            rewardID: "reward_first_spark_trophy",
            sourceRaidID: "raid_tutorial_first_spark",
            type: .trophy,
            title: "First Spark Trophy",
            artKey: "reward_first_spark_trophy",
            grantRule: .clear
        ),
    ] + monthlyRewardSpecs.map { raid in
        RaidRewardDefinition(
            rewardID: raid.rewardID,
            sourceRaidID: raid.raidID,
            type: .logoRelic,
            title: raid.rewardTitle,
            artKey: raid.rewardID,
            grantRule: .clear
        )
    }

    private static let tutorialRaid = RaidDefinition(
        raidID: "raid_tutorial_first_spark",
        title: "First Spark Raid",
        targetName: "Training Trophy Cache",
        targetArtKey: "raid_target_training_trophy_cache",
        raidField: .grassland,
        availabilityKind: .tutorialAlways,
        activeStartAt: nil,
        activeEndAt: nil,
        settlementGraceSeconds: 600,
        maxHP: 6,
        axisWeights: RaidAxisWeights(
            planning: 20,
            design: 20,
            frontend: 20,
            backend: 20,
            pm: 10,
            infra: 10
        ),
        preferredTraitTags: [
            "Deep Focus",
            "Clean Coder",
            "Quick Prototyper",
        ],
        difficultyTier: .small,
        rewardIDs: ["reward_first_spark_trophy"]
    )

    private static let practiceRaid = RaidDefinition(
        raidID: "raid_practice_token_vault",
        title: "Token Vault Practice",
        targetName: "Token Vault Sentinel",
        targetArtKey: "raid_target_token_vault_sentinel",
        raidField: .coast,
        availabilityKind: .tutorialAlways,
        activeStartAt: nil,
        activeEndAt: nil,
        settlementGraceSeconds: 600,
        maxHP: 5_000,
        axisWeights: RaidAxisWeights(
            planning: 15,
            design: 20,
            frontend: 25,
            backend: 20,
            pm: 10,
            infra: 10
        ),
        preferredTraitTags: [
            "Deep Focus",
            "Clean Coder",
            "Quick Prototyper",
        ],
        difficultyTier: .standard,
        rewardIDs: []
    )

    private static let monthlyRewardSpecs: [MonthlyRewardRaid] = [
        MonthlyRewardRaid(
            month: 4,
            code: "april",
            title: "April Spark Vault",
            targetName: "Clovercore Sentinel",
            targetArtKey: "raid_target_2026_04_clovercore_sentinel",
            rewardTitle: "April Spark Relic",
            field: .grassland,
            maxHP: 240,
            axisWeights: RaidAxisWeights(planning: 24, design: 16, frontend: 18, backend: 18, pm: 14, infra: 10),
            preferredTraitTags: ["Deep Focus", "Clean Coder", "Early Bird"]
        ),
        MonthlyRewardRaid(
            month: 5,
            code: "may",
            title: "May Bloom Vault",
            targetName: "Petalwarden Sentinel",
            targetArtKey: "raid_target_2026_05_petalwarden_sentinel",
            rewardTitle: "May Bloom Relic",
            field: .grassland,
            maxHP: 1_560,
            axisWeights: RaidAxisWeights(planning: 18, design: 24, frontend: 22, backend: 12, pm: 14, infra: 10),
            preferredTraitTags: ["Pixel Perfect", "Quick Prototyper", "Icon Artist"]
        ),
        MonthlyRewardRaid(
            month: 6,
            code: "june",
            legacyRaidID: "raid_2026_06_logo_vault",
            legacyRewardID: "reward_tokenmon_logo_relic",
            title: "June Logo Vault",
            targetName: "Glyphvault Sentinel",
            targetArtKey: "raid_target_2026_06_glyphvault_sentinel",
            rewardTitle: "June Token Relic",
            field: .coast,
            maxHP: 1_680,
            axisWeights: RaidAxisWeights(planning: 15, design: 30, frontend: 25, backend: 10, pm: 10, infra: 10),
            preferredTraitTags: ["Pixel Perfect", "Quick Prototyper", "Icon Artist"]
        ),
        MonthlyRewardRaid(
            month: 7,
            code: "july",
            title: "July Signal Vault",
            targetName: "Starcall Sentinel",
            targetArtKey: "raid_target_2026_07_starcall_sentinel",
            rewardTitle: "July Signal Relic",
            field: .sky,
            maxHP: 1_800,
            axisWeights: RaidAxisWeights(planning: 16, design: 16, frontend: 24, backend: 18, pm: 10, infra: 16),
            preferredTraitTags: ["Quick Prototyper", "Night Owl", "Clean Coder"]
        ),
        MonthlyRewardRaid(
            month: 8,
            code: "august",
            title: "August Ember Vault",
            targetName: "Emberforge Sentinel",
            targetArtKey: "raid_target_2026_08_emberforge_sentinel",
            rewardTitle: "August Ember Relic",
            field: .coast,
            maxHP: 1_920,
            axisWeights: RaidAxisWeights(planning: 14, design: 18, frontend: 20, backend: 24, pm: 8, infra: 16),
            preferredTraitTags: ["Clean Coder", "Deep Focus", "Bug Hunter"]
        ),
        MonthlyRewardRaid(
            month: 9,
            code: "september",
            title: "September Archive Vault",
            targetName: "Archivist Sentinel",
            targetArtKey: "raid_target_2026_09_archivist_sentinel",
            rewardTitle: "September Archive Relic",
            field: .ice,
            maxHP: 2_040,
            axisWeights: RaidAxisWeights(planning: 24, design: 12, frontend: 14, backend: 24, pm: 10, infra: 16),
            preferredTraitTags: ["Deep Focus", "Bug Hunter", "Clean Coder"]
        ),
        MonthlyRewardRaid(
            month: 10,
            code: "october",
            title: "October Shadow Vault",
            targetName: "Moonmask Sentinel",
            targetArtKey: "raid_target_2026_10_moonmask_sentinel",
            rewardTitle: "October Shadow Relic",
            field: .sky,
            maxHP: 2_160,
            axisWeights: RaidAxisWeights(planning: 18, design: 18, frontend: 16, backend: 18, pm: 12, infra: 18),
            preferredTraitTags: ["Night Owl", "Deep Focus", "Quick Prototyper"]
        ),
        MonthlyRewardRaid(
            month: 11,
            code: "november",
            title: "November Kernel Vault",
            targetName: "Kernelgear Sentinel",
            targetArtKey: "raid_target_2026_11_kernelgear_sentinel",
            rewardTitle: "November Kernel Relic",
            field: .ice,
            maxHP: 2_280,
            axisWeights: RaidAxisWeights(planning: 14, design: 12, frontend: 16, backend: 28, pm: 8, infra: 22),
            preferredTraitTags: ["Bug Hunter", "Clean Coder", "Deep Focus"]
        ),
        MonthlyRewardRaid(
            month: 12,
            code: "december",
            title: "December Aurora Vault",
            targetName: "Auroracrown Sentinel",
            targetArtKey: "raid_target_2026_12_auroracrown_sentinel",
            rewardTitle: "December Aurora Relic",
            field: .ice,
            maxHP: 2_400,
            axisWeights: RaidAxisWeights(planning: 20, design: 20, frontend: 18, backend: 14, pm: 12, infra: 16),
            preferredTraitTags: ["Deep Focus", "Pixel Perfect", "Clean Coder"]
        ),
    ]
}

private struct MonthlyRewardRaid {
    let month: Int
    let code: String
    var legacyRaidID: String? = nil
    var legacyRewardID: String? = nil
    let title: String
    let targetName: String
    let targetArtKey: String
    let rewardTitle: String
    let field: FieldType
    let maxHP: Int64
    let axisWeights: RaidAxisWeights
    let preferredTraitTags: [String]

    var raidID: String {
        if let legacyRaidID {
            return legacyRaidID
        }
        return "raid_2026_\(String(format: "%02d", month))_\(code)_vault"
    }

    var rewardID: String {
        if let legacyRewardID {
            return legacyRewardID
        }
        return "reward_2026_\(String(format: "%02d", month))_\(code)_relic"
    }

    var activeStartAt: String {
        "2026-\(String(format: "%02d", month))-01T00:00:00Z"
    }

    var activeEndAt: String {
        if month == 12 {
            return "2027-01-01T00:00:00Z"
        }
        return "2026-\(String(format: "%02d", month + 1))-01T00:00:00Z"
    }
}

private extension MonthlyRewardRaid {
    var raidDefinition: RaidDefinition {
        RaidDefinition(
            raidID: raidID,
            title: title,
            targetName: targetName,
            targetArtKey: targetArtKey,
            raidField: field,
            availabilityKind: .scheduled,
            activeStartAt: activeStartAt,
            activeEndAt: activeEndAt,
            settlementGraceSeconds: 600,
            maxHP: maxHP,
            axisWeights: axisWeights,
            preferredTraitTags: preferredTraitTags,
            difficultyTier: .standard,
            rewardIDs: [rewardID]
        )
    }
}
