import Foundation

public enum SpeciesCatalog {
    private static func entry(
        id: String,
        name: String,
        field: FieldType,
        rarity: RarityTier,
        assetKey: String,
        sortOrder: Int,
        stats: SpeciesStatBlock = SpeciesStatBlock(
            planning: 1, design: 1, frontend: 1,
            backend: 1, pm: 1, infra: 1
        )
    ) -> SpeciesDefinition {
        SpeciesDefinition(
            id: id,
            name: SpeciesKoreanLocalization.names[id] ?? name,
            field: field,
            rarity: rarity,
            assetKey: assetKey,
            flavorText: SpeciesKoreanLocalization.flavorText[id] ?? SpeciesFlavorText.byID[id],
            sortOrder: sortOrder,
            stats: stats,
            trainingTrait: authoredTrainingTrait(id: id, field: field, rarity: rarity)
        )
    }

    private static func authoredTrainingTrait(
        id: String,
        field: FieldType,
        rarity: RarityTier
    ) -> TrainingTrait {
        let traits: [TrainingTrait] = [.trail, .scout, .capture, .raider]
        let numericID = Int(id.split(separator: "_").last ?? "") ?? 1
        let groupStart = switch rarity {
        case .common: 1
        case .uncommon: 11
        case .rare: 21
        case .epic: 29
        case .legendary: 35
        }
        let fieldOffset = FieldType.allCases.firstIndex(of: field) ?? 0
        let rarityOffset = RarityTier.allCases.firstIndex(of: rarity) ?? 0
        let positionInGroup = max(0, numericID - groupStart)
        return traits[(positionInGroup + fieldOffset + rarityOffset) % traits.count]
    }

    // swiftlint:disable function_body_length
    public static let all: [SpeciesDefinition] = [
        // =====================================================================
        // GRASSLAND — 38 species
        // Field tendency: balanced spread
        // =====================================================================

        // --- Grassland Common (10) — total 12–18, 1 style tag ---
        entry(id: "GRS_001", name: "Mossbun", field: .grassland, rarity: .common, assetKey: "grs_001_mossbun", sortOrder: 1,
              stats: SpeciesStatBlock(planning: 2, design: 3, frontend: 2, backend: 2, pm: 2, infra: 2, traits: ["Early Bird"])),
        entry(id: "GRS_002", name: "Pebblequail", field: .grassland, rarity: .common, assetKey: "grs_002_pebblequail", sortOrder: 2,
              stats: SpeciesStatBlock(planning: 3, design: 2, frontend: 2, backend: 2, pm: 3, infra: 2, traits: ["Deep Focus"])),
        entry(id: "GRS_003", name: "Seedkit", field: .grassland, rarity: .common, assetKey: "grs_003_seedkit", sortOrder: 3,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 3, backend: 2, pm: 2, infra: 2, traits: ["Fast Typer"])),
        entry(id: "GRS_004", name: "Fernfawn", field: .grassland, rarity: .common, assetKey: "grs_004_fernfawn", sortOrder: 4,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 2, backend: 3, pm: 2, infra: 2, traits: ["Solo Worker"])),
        entry(id: "GRS_005", name: "Sprigmouse", field: .grassland, rarity: .common, assetKey: "grs_005_sprigmouse", sortOrder: 5,
              stats: SpeciesStatBlock(planning: 1, design: 1, frontend: 1, backend: 8, pm: 1, infra: 1, traits: ["Night Owl"])),
        entry(id: "GRS_006", name: "Pollenpup", field: .grassland, rarity: .common, assetKey: "grs_006_pollenpup", sortOrder: 6,
              stats: SpeciesStatBlock(planning: 3, design: 2, frontend: 3, backend: 2, pm: 2, infra: 3, traits: ["Multitasker"])),
        entry(id: "GRS_007", name: "Twiglet", field: .grassland, rarity: .common, assetKey: "grs_007_twiglet", sortOrder: 7,
              stats: SpeciesStatBlock(planning: 2, design: 3, frontend: 2, backend: 2, pm: 2, infra: 3, traits: ["Clean Coder"])),
        entry(id: "GRS_008", name: "Acornip", field: .grassland, rarity: .common, assetKey: "grs_008_acornip", sortOrder: 8,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 2, backend: 2, pm: 3, infra: 3, traits: ["Coffee Addict"])),
        entry(id: "GRS_009", name: "Clovercub", field: .grassland, rarity: .common, assetKey: "grs_009_clovercub", sortOrder: 9,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 2, backend: 2, pm: 2, infra: 2, traits: ["Rubber Ducker"])),
        entry(id: "GRS_010", name: "Bramblefinch", field: .grassland, rarity: .common, assetKey: "grs_010_bramblefinch", sortOrder: 10,
              stats: SpeciesStatBlock(planning: 1, design: 1, frontend: 8, backend: 1, pm: 1, infra: 1, traits: ["Speed Runner"])),

        // --- Grassland Uncommon (10) — total 20–26, 1 domain + 1 style tag ---
        entry(id: "GRS_011", name: "Brushfox", field: .grassland, rarity: .uncommon, assetKey: "grs_011_brushfox", sortOrder: 11,
              stats: SpeciesStatBlock(planning: 3, design: 6, frontend: 4, backend: 3, pm: 3, infra: 3, traits: ["Layout Genius", "Deep Focus"])),
        entry(id: "GRS_012", name: "Cloverboar", field: .grassland, rarity: .uncommon, assetKey: "grs_012_cloverboar", sortOrder: 12,
              stats: SpeciesStatBlock(planning: 4, design: 3, frontend: 3, backend: 4, pm: 5, infra: 3, traits: ["Sprint Leader", "Early Bird"])),
        entry(id: "GRS_013", name: "Reedram", field: .grassland, rarity: .uncommon, assetKey: "grs_013_reedram", sortOrder: 13,
              stats: SpeciesStatBlock(planning: 5, design: 3, frontend: 3, backend: 4, pm: 4, infra: 3, traits: ["Visionary", "Night Owl"])),
        entry(id: "GRS_014", name: "Sapstoat", field: .grassland, rarity: .uncommon, assetKey: "grs_014_sapstoat", sortOrder: 14,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 5, backend: 4, pm: 3, infra: 4, traits: ["Quick Prototyper", "Fast Typer"])),
        entry(id: "GRS_015", name: "Tanglemole", field: .grassland, rarity: .uncommon, assetKey: "grs_015_tanglemole", sortOrder: 15,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 5, pm: 3, infra: 5, traits: ["Debug Master", "Solo Worker"])),
        entry(id: "GRS_016", name: "Bloomhare", field: .grassland, rarity: .uncommon, assetKey: "grs_016_bloomhare", sortOrder: 16,
              stats: SpeciesStatBlock(planning: 4, design: 5, frontend: 4, backend: 3, pm: 3, infra: 3, traits: ["Color Whisperer", "Perfectionist"])),
        entry(id: "GRS_017", name: "Barkbat", field: .grassland, rarity: .uncommon, assetKey: "grs_017_barkbat", sortOrder: 17,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 4, pm: 4, infra: 5, traits: ["Pipeline Builder", "Night Owl"])),
        entry(id: "GRS_018", name: "Petalynx", field: .grassland, rarity: .uncommon, assetKey: "grs_018_petalynx", sortOrder: 18,
              stats: SpeciesStatBlock(planning: 4, design: 5, frontend: 3, backend: 3, pm: 4, infra: 3, traits: ["Pixel Perfect", "Clean Coder"])),
        entry(id: "GRS_019", name: "Loamguin", field: .grassland, rarity: .uncommon, assetKey: "grs_019_loamguin", sortOrder: 19,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 4, backend: 3, pm: 5, infra: 4, traits: ["Stakeholder Whisperer", "Multitasker"])),
        entry(id: "GRS_020", name: "Vinekip", field: .grassland, rarity: .uncommon, assetKey: "grs_020_vinekip", sortOrder: 20,
              stats: SpeciesStatBlock(planning: 4, design: 4, frontend: 4, backend: 4, pm: 3, infra: 3, traits: ["Strategist", "Experimenter"])),

        // --- Grassland Rare (8) — total 28–34, 1 domain + 2 style tags ---
        entry(id: "GRS_021", name: "Thornlynx", field: .grassland, rarity: .rare, assetKey: "grs_021_thornlynx", sortOrder: 21,
              stats: SpeciesStatBlock(planning: 5, design: 4, frontend: 5, backend: 6, pm: 5, infra: 5, traits: ["Debug Master", "Night Owl", "Deep Focus"])),
        entry(id: "GRS_022", name: "Grovehart", field: .grassland, rarity: .rare, assetKey: "grs_022_grovehart", sortOrder: 22,
              stats: SpeciesStatBlock(planning: 6, design: 5, frontend: 5, backend: 4, pm: 5, infra: 5, traits: ["Visionary", "Early Bird", "Mentor"])),
        entry(id: "GRS_023", name: "Canopuma", field: .grassland, rarity: .rare, assetKey: "grs_023_canopuma", sortOrder: 23,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 6, backend: 5, pm: 4, infra: 5, traits: ["Quick Prototyper", "Fast Typer", "Speed Runner"])),
        entry(id: "GRS_024", name: "Briarbuck", field: .grassland, rarity: .rare, assetKey: "grs_024_briarbuck", sortOrder: 24,
              stats: SpeciesStatBlock(planning: 4, design: 5, frontend: 5, backend: 5, pm: 6, infra: 5, traits: ["Sprint Leader", "Coffee Addict", "Multitasker"])),
        entry(id: "GRS_025", name: "Rootwing", field: .grassland, rarity: .rare, assetKey: "grs_025_rootwing", sortOrder: 25,
              stats: SpeciesStatBlock(planning: 5, design: 6, frontend: 5, backend: 5, pm: 5, infra: 4, traits: ["Pixel Perfect", "Clean Coder", "Perfectionist"])),
        entry(id: "GRS_026", name: "Mossmane", field: .grassland, rarity: .rare, assetKey: "grs_026_mossmane", sortOrder: 26,
              stats: SpeciesStatBlock(planning: 5, design: 4, frontend: 5, backend: 5, pm: 5, infra: 6, traits: ["Pipeline Builder", "Solo Worker", "Terminal Lover"])),
        entry(id: "GRS_027", name: "Wildbloom", field: .grassland, rarity: .rare, assetKey: "grs_027_wildbloom", sortOrder: 27,
              stats: SpeciesStatBlock(planning: 5, design: 7, frontend: 5, backend: 4, pm: 5, infra: 4, traits: ["Color Whisperer", "Experimenter", "Rubber Ducker"])),
        entry(id: "GRS_028", name: "Verdhound", field: .grassland, rarity: .rare, assetKey: "grs_028_verdhound", sortOrder: 28,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 5, backend: 5, pm: 5, infra: 5, traits: ["Strategist", "Pair Programmer", "Documentation Lover"])),

        // --- Grassland Epic (6) — total 36–42, 2 domain + 2 style tags ---
        entry(id: "GRS_029", name: "Elderstag", field: .grassland, rarity: .epic, assetKey: "grs_029_elderstag", sortOrder: 29,
              stats: SpeciesStatBlock(planning: 8, design: 6, frontend: 6, backend: 6, pm: 7, infra: 5, traits: ["Visionary", "Sprint Leader", "Deep Focus", "Mentor"])),
        entry(id: "GRS_030", name: "Bloomdrake", field: .grassland, rarity: .epic, assetKey: "grs_030_bloomdrake", sortOrder: 30,
              stats: SpeciesStatBlock(planning: 6, design: 8, frontend: 7, backend: 5, pm: 6, infra: 6, traits: ["Pixel Perfect", "Quick Prototyper", "Perfectionist", "Clean Coder"])),
        entry(id: "GRS_031", name: "Crownelk", field: .grassland, rarity: .epic, assetKey: "grs_031_crownelk", sortOrder: 31,
              stats: SpeciesStatBlock(planning: 7, design: 6, frontend: 6, backend: 6, pm: 8, infra: 5, traits: ["Strategist", "Team Builder", "Early Bird", "Coffee Addict"])),
        entry(id: "GRS_032", name: "Solbriar", field: .grassland, rarity: .epic, assetKey: "grs_032_solbriar", sortOrder: 32,
              stats: SpeciesStatBlock(planning: 6, design: 7, frontend: 6, backend: 7, pm: 6, infra: 6, traits: ["Color Whisperer", "Debug Master", "Night Owl", "Experimenter"])),
        entry(id: "GRS_033", name: "Verdant Wyvern", field: .grassland, rarity: .epic, assetKey: "grs_033_verdant_wyvern", sortOrder: 33,
              stats: SpeciesStatBlock(planning: 6, design: 6, frontend: 7, backend: 7, pm: 6, infra: 6, traits: ["Component Builder", "API Architect", "Fast Typer", "Multitasker"])),
        entry(id: "GRS_034", name: "Bloomwarden", field: .grassland, rarity: .epic, assetKey: "grs_034_bloomwarden", sortOrder: 34,
              stats: SpeciesStatBlock(planning: 7, design: 7, frontend: 6, backend: 5, pm: 7, infra: 6, traits: ["Scope Master", "Layout Genius", "Pair Programmer", "Rubber Ducker"])),

        // --- Grassland Legendary (4) — total 44–52, 2 domain + 3 style tags ---
        entry(id: "GRS_035", name: "Verdant Kirin", field: .grassland, rarity: .legendary, assetKey: "grs_035_verdant_kirin", sortOrder: 35,
              stats: SpeciesStatBlock(planning: 9, design: 8, frontend: 7, backend: 8, pm: 9, infra: 7, traits: ["Visionary", "Team Builder", "Deep Focus", "Mentor", "Perfectionist"])),
        entry(id: "GRS_036", name: "Worldroot Seraph", field: .grassland, rarity: .legendary, assetKey: "grs_036_worldroot_seraph", sortOrder: 36,
              stats: SpeciesStatBlock(planning: 8, design: 9, frontend: 8, backend: 7, pm: 8, infra: 8, traits: ["Pixel Perfect", "Strategist", "Clean Coder", "Early Bird", "Documentation Lover"])),
        entry(id: "GRS_037", name: "Sunseed Levi", field: .grassland, rarity: .legendary, assetKey: "grs_037_sunseed_levi", sortOrder: 37,
              stats: SpeciesStatBlock(planning: 8, design: 7, frontend: 9, backend: 8, pm: 8, infra: 8, traits: ["Quick Prototyper", "Sprint Leader", "Night Owl", "Experimenter", "Speed Runner"])),
        entry(id: "GRS_038", name: "Evergreen Sovereign", field: .grassland, rarity: .legendary, assetKey: "grs_038_evergreen_sovereign", sortOrder: 38,
              stats: SpeciesStatBlock(planning: 9, design: 8, frontend: 8, backend: 8, pm: 9, infra: 6, traits: ["Scope Master", "Blocker Breaker", "Coffee Addict", "Multitasker", "Git Historian"])),

        // =====================================================================
        // SKY — 38 species
        // Field tendency: planning + pm boosted
        // =====================================================================

        // --- Sky Common (10) — total 12–18, 1 style tag ---
        entry(id: "SKY_001", name: "Puffowl", field: .sky, rarity: .common, assetKey: "sky_001_puffowl", sortOrder: 39,
              stats: SpeciesStatBlock(planning: 3, design: 2, frontend: 2, backend: 1, pm: 3, infra: 2, traits: ["Early Bird"])),
        entry(id: "SKY_002", name: "Kitemoth", field: .sky, rarity: .common, assetKey: "sky_002_kitemoth", sortOrder: 40,
              stats: SpeciesStatBlock(planning: 3, design: 2, frontend: 2, backend: 2, pm: 2, infra: 2, traits: ["Night Owl"])),
        entry(id: "SKY_003", name: "Breezesparrow", field: .sky, rarity: .common, assetKey: "sky_003_breezesparrow", sortOrder: 41,
              stats: SpeciesStatBlock(planning: 3, design: 1, frontend: 2, backend: 2, pm: 3, infra: 2, traits: ["Fast Typer"])),
        entry(id: "SKY_004", name: "Driftbat", field: .sky, rarity: .common, assetKey: "sky_004_driftbat", sortOrder: 42,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 2, backend: 2, pm: 3, infra: 2, traits: ["Night Owl"])),
        entry(id: "SKY_005", name: "Cirrofinch", field: .sky, rarity: .common, assetKey: "sky_005_cirrofinch", sortOrder: 43,
              stats: SpeciesStatBlock(planning: 3, design: 2, frontend: 1, backend: 2, pm: 3, infra: 3, traits: ["Deep Focus"])),
        entry(id: "SKY_006", name: "Cloudlet", field: .sky, rarity: .common, assetKey: "sky_006_cloudlet", sortOrder: 44,
              stats: SpeciesStatBlock(planning: 1, design: 1, frontend: 1, backend: 1, pm: 8, infra: 1, traits: ["Multitasker"])),
        entry(id: "SKY_007", name: "Gustling", field: .sky, rarity: .common, assetKey: "sky_007_gustling", sortOrder: 45,
              stats: SpeciesStatBlock(planning: 3, design: 2, frontend: 2, backend: 2, pm: 3, infra: 3, traits: ["Speed Runner"])),
        entry(id: "SKY_008", name: "Flittern", field: .sky, rarity: .common, assetKey: "sky_008_flittern", sortOrder: 46,
              stats: SpeciesStatBlock(planning: 4, design: 2, frontend: 2, backend: 1, pm: 3, infra: 2, traits: ["Coffee Addict"])),
        entry(id: "SKY_009", name: "Hushkite", field: .sky, rarity: .common, assetKey: "sky_009_hushkite", sortOrder: 47,
              stats: SpeciesStatBlock(planning: 3, design: 2, frontend: 2, backend: 2, pm: 3, infra: 2, traits: ["Solo Worker"])),
        entry(id: "SKY_010", name: "Skydart", field: .sky, rarity: .common, assetKey: "sky_010_skydart", sortOrder: 48,
              stats: SpeciesStatBlock(planning: 1, design: 1, frontend: 1, backend: 1, pm: 1, infra: 8, traits: ["Terminal Lover"])),

        // --- Sky Uncommon (10) — total 20–26, 1 domain + 1 style tag ---
        entry(id: "SKY_011", name: "Galefinch", field: .sky, rarity: .uncommon, assetKey: "sky_011_galefinch", sortOrder: 49,
              stats: SpeciesStatBlock(planning: 5, design: 3, frontend: 3, backend: 3, pm: 5, infra: 3, traits: ["Visionary", "Deep Focus"])),
        entry(id: "SKY_012", name: "Nimbusray", field: .sky, rarity: .uncommon, assetKey: "sky_012_nimbusray", sortOrder: 50,
              stats: SpeciesStatBlock(planning: 4, design: 4, frontend: 3, backend: 3, pm: 5, infra: 3, traits: ["Sprint Leader", "Fast Typer"])),
        entry(id: "SKY_013", name: "Zephyhare", field: .sky, rarity: .uncommon, assetKey: "sky_013_zephyhare", sortOrder: 51,
              stats: SpeciesStatBlock(planning: 5, design: 3, frontend: 4, backend: 3, pm: 4, infra: 3, traits: ["Strategist", "Speed Runner"])),
        entry(id: "SKY_014", name: "Aerowisp", field: .sky, rarity: .uncommon, assetKey: "sky_014_aerowisp", sortOrder: 52,
              stats: SpeciesStatBlock(planning: 4, design: 3, frontend: 3, backend: 4, pm: 5, infra: 3, traits: ["Deadline Keeper", "Night Owl"])),
        entry(id: "SKY_015", name: "Glideroo", field: .sky, rarity: .uncommon, assetKey: "sky_015_glideroo", sortOrder: 53,
              stats: SpeciesStatBlock(planning: 5, design: 3, frontend: 3, backend: 3, pm: 4, infra: 4, traits: ["Roadmap Guru", "Multitasker"])),
        entry(id: "SKY_016", name: "Stormlark", field: .sky, rarity: .uncommon, assetKey: "sky_016_stormlark", sortOrder: 54,
              stats: SpeciesStatBlock(planning: 4, design: 3, frontend: 3, backend: 3, pm: 6, infra: 3, traits: ["Risk Spotter", "Coffee Addict"])),
        entry(id: "SKY_017", name: "Nimbuscat", field: .sky, rarity: .uncommon, assetKey: "sky_017_nimbuscat", sortOrder: 55,
              stats: SpeciesStatBlock(planning: 5, design: 4, frontend: 3, backend: 3, pm: 4, infra: 3, traits: ["Scope Master", "Clean Coder"])),
        entry(id: "SKY_018", name: "Kestrelot", field: .sky, rarity: .uncommon, assetKey: "sky_018_kestrelot", sortOrder: 56,
              stats: SpeciesStatBlock(planning: 4, design: 3, frontend: 4, backend: 3, pm: 5, infra: 3, traits: ["Team Builder", "Early Bird"])),
        entry(id: "SKY_019", name: "Vaporwing", field: .sky, rarity: .uncommon, assetKey: "sky_019_vaporwing", sortOrder: 57,
              stats: SpeciesStatBlock(planning: 5, design: 3, frontend: 3, backend: 3, pm: 5, infra: 3, traits: ["Visionary", "Experimenter"])),
        entry(id: "SKY_020", name: "Swoopcub", field: .sky, rarity: .uncommon, assetKey: "sky_020_swoopcub", sortOrder: 58,
              stats: SpeciesStatBlock(planning: 4, design: 4, frontend: 3, backend: 3, pm: 5, infra: 3, traits: ["Stakeholder Whisperer", "Rubber Ducker"])),

        // --- Sky Rare (8) — total 28–34, 1 domain + 2 style tags ---
        entry(id: "SKY_021", name: "Stormheron", field: .sky, rarity: .rare, assetKey: "sky_021_stormheron", sortOrder: 59,
              stats: SpeciesStatBlock(planning: 6, design: 4, frontend: 5, backend: 4, pm: 6, infra: 5, traits: ["Visionary", "Deep Focus", "Mentor"])),
        entry(id: "SKY_022", name: "Skyviper", field: .sky, rarity: .rare, assetKey: "sky_022_skyviper", sortOrder: 60,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 4, backend: 5, pm: 6, infra: 5, traits: ["Sprint Leader", "Night Owl", "Fast Typer"])),
        entry(id: "SKY_023", name: "Tempestail", field: .sky, rarity: .rare, assetKey: "sky_023_tempestail", sortOrder: 61,
              stats: SpeciesStatBlock(planning: 6, design: 4, frontend: 5, backend: 5, pm: 5, infra: 5, traits: ["Strategist", "Speed Runner", "Coffee Addict"])),
        entry(id: "SKY_024", name: "Windserpent", field: .sky, rarity: .rare, assetKey: "sky_024_windserpent", sortOrder: 62,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 5, backend: 4, pm: 6, infra: 5, traits: ["Risk Spotter", "Perfectionist", "Clean Coder"])),
        entry(id: "SKY_025", name: "Galehart", field: .sky, rarity: .rare, assetKey: "sky_025_galehart", sortOrder: 63,
              stats: SpeciesStatBlock(planning: 7, design: 4, frontend: 4, backend: 5, pm: 5, infra: 5, traits: ["Roadmap Guru", "Early Bird", "Pair Programmer"])),
        entry(id: "SKY_026", name: "Hailjack", field: .sky, rarity: .rare, assetKey: "sky_026_hailjack", sortOrder: 64,
              stats: SpeciesStatBlock(planning: 5, design: 4, frontend: 5, backend: 5, pm: 7, infra: 4, traits: ["Blocker Breaker", "Multitasker", "Solo Worker"])),
        entry(id: "SKY_027", name: "Stratosfang", field: .sky, rarity: .rare, assetKey: "sky_027_stratosfang", sortOrder: 65,
              stats: SpeciesStatBlock(planning: 6, design: 5, frontend: 4, backend: 5, pm: 5, infra: 5, traits: ["Scope Master", "Terminal Lover", "Experimenter"])),
        entry(id: "SKY_028", name: "Cloudmantis", field: .sky, rarity: .rare, assetKey: "sky_028_cloudmantis", sortOrder: 66,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 5, backend: 5, pm: 6, infra: 4, traits: ["Deadline Keeper", "Documentation Lover", "Rubber Ducker"])),

        // --- Sky Epic (6) — total 36–42, 2 domain + 2 style tags ---
        entry(id: "SKY_029", name: "Halo Roc", field: .sky, rarity: .epic, assetKey: "sky_029_halo_roc", sortOrder: 67,
              stats: SpeciesStatBlock(planning: 8, design: 6, frontend: 5, backend: 6, pm: 8, infra: 5, traits: ["Visionary", "Team Builder", "Deep Focus", "Mentor"])),
        entry(id: "SKY_030", name: "Dawnalbat", field: .sky, rarity: .epic, assetKey: "sky_030_dawnalbat", sortOrder: 68,
              stats: SpeciesStatBlock(planning: 7, design: 6, frontend: 6, backend: 5, pm: 7, infra: 7, traits: ["Strategist", "Sprint Leader", "Early Bird", "Clean Coder"])),
        entry(id: "SKY_031", name: "Prismwing", field: .sky, rarity: .epic, assetKey: "sky_031_prismwing", sortOrder: 69,
              stats: SpeciesStatBlock(planning: 7, design: 7, frontend: 6, backend: 5, pm: 7, infra: 6, traits: ["Scope Master", "Pixel Perfect", "Perfectionist", "Experimenter"])),
        entry(id: "SKY_032", name: "Cyclonarch", field: .sky, rarity: .epic, assetKey: "sky_032_cyclonarch", sortOrder: 70,
              stats: SpeciesStatBlock(planning: 8, design: 5, frontend: 6, backend: 6, pm: 7, infra: 6, traits: ["Roadmap Guru", "Risk Spotter", "Night Owl", "Coffee Addict"])),
        entry(id: "SKY_033", name: "Starfeather", field: .sky, rarity: .epic, assetKey: "sky_033_starfeather", sortOrder: 71,
              stats: SpeciesStatBlock(planning: 7, design: 6, frontend: 6, backend: 6, pm: 8, infra: 5, traits: ["Visionary", "Deadline Keeper", "Fast Typer", "Multitasker"])),
        entry(id: "SKY_034", name: "Skylight Seraph", field: .sky, rarity: .epic, assetKey: "sky_034_skylight_seraph", sortOrder: 72,
              stats: SpeciesStatBlock(planning: 7, design: 6, frontend: 7, backend: 5, pm: 7, infra: 6, traits: ["Strategist", "Blocker Breaker", "Pair Programmer", "Speed Runner"])),

        // --- Sky Legendary (4) — total 44–52, 2 domain + 3 style tags ---
        entry(id: "SKY_035", name: "Aurora Seraphowl", field: .sky, rarity: .legendary, assetKey: "sky_035_aurora_seraphowl", sortOrder: 73,
              stats: SpeciesStatBlock(planning: 9, design: 7, frontend: 7, backend: 7, pm: 10, infra: 7, traits: ["Visionary", "Team Builder", "Deep Focus", "Mentor", "Perfectionist"])),
        entry(id: "SKY_036", name: "Celestalon", field: .sky, rarity: .legendary, assetKey: "sky_036_celestalon", sortOrder: 74,
              stats: SpeciesStatBlock(planning: 10, design: 7, frontend: 8, backend: 7, pm: 8, infra: 7, traits: ["Roadmap Guru", "Sprint Leader", "Night Owl", "Clean Coder", "Documentation Lover"])),
        entry(id: "SKY_037", name: "Firmament Wyrm", field: .sky, rarity: .legendary, assetKey: "sky_037_firmament_wyrm", sortOrder: 75,
              stats: SpeciesStatBlock(planning: 8, design: 8, frontend: 7, backend: 8, pm: 9, infra: 8, traits: ["Scope Master", "Risk Spotter", "Coffee Addict", "Experimenter", "Git Historian"])),
        entry(id: "SKY_038", name: "Horizon Phoenix", field: .sky, rarity: .legendary, assetKey: "sky_038_horizon_phoenix", sortOrder: 76,
              stats: SpeciesStatBlock(planning: 9, design: 7, frontend: 8, backend: 7, pm: 9, infra: 8, traits: ["Strategist", "Blocker Breaker", "Early Bird", "Speed Runner", "Shortcut Master"])),

        // =====================================================================
        // COAST — 38 species
        // Field tendency: frontend + design boosted
        // =====================================================================

        // --- Coast Common (10) — total 12–18, 1 style tag ---
        entry(id: "CST_001", name: "Foamcrab", field: .coast, rarity: .common, assetKey: "cst_001_foamcrab", sortOrder: 77,
              stats: SpeciesStatBlock(planning: 2, design: 3, frontend: 3, backend: 2, pm: 2, infra: 1, traits: ["Fast Typer"])),
        entry(id: "CST_002", name: "Shellpup", field: .coast, rarity: .common, assetKey: "cst_002_shellpup", sortOrder: 78,
              stats: SpeciesStatBlock(planning: 2, design: 3, frontend: 3, backend: 2, pm: 2, infra: 2, traits: ["Deep Focus"])),
        entry(id: "CST_003", name: "Driftminnow", field: .coast, rarity: .common, assetKey: "cst_003_driftminnow", sortOrder: 79,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 3, backend: 2, pm: 2, infra: 2, traits: ["Night Owl"])),
        entry(id: "CST_004", name: "Tideling", field: .coast, rarity: .common, assetKey: "cst_004_tideling", sortOrder: 80,
              stats: SpeciesStatBlock(planning: 2, design: 3, frontend: 2, backend: 2, pm: 2, infra: 3, traits: ["Clean Coder"])),
        entry(id: "CST_005", name: "Coralmouse", field: .coast, rarity: .common, assetKey: "cst_005_coralmouse", sortOrder: 81,
              stats: SpeciesStatBlock(planning: 1, design: 8, frontend: 1, backend: 1, pm: 1, infra: 1, traits: ["Perfectionist"])),
        entry(id: "CST_006", name: "Brinekit", field: .coast, rarity: .common, assetKey: "cst_006_brinekit", sortOrder: 82,
              stats: SpeciesStatBlock(planning: 2, design: 3, frontend: 3, backend: 2, pm: 2, infra: 2, traits: ["Multitasker"])),
        entry(id: "CST_007", name: "Pebbleclam", field: .coast, rarity: .common, assetKey: "cst_007_pebbleclam", sortOrder: 83,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 3, backend: 3, pm: 2, infra: 2, traits: ["Solo Worker"])),
        entry(id: "CST_008", name: "Surftern", field: .coast, rarity: .common, assetKey: "cst_008_surftern", sortOrder: 84,
              stats: SpeciesStatBlock(planning: 2, design: 3, frontend: 4, backend: 2, pm: 2, infra: 2, traits: ["Speed Runner"])),
        entry(id: "CST_009", name: "Ripplepup", field: .coast, rarity: .common, assetKey: "cst_009_ripplepup", sortOrder: 85,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 2, backend: 2, pm: 2, infra: 2, traits: ["Coffee Addict"])),
        entry(id: "CST_010", name: "Kelpfin", field: .coast, rarity: .common, assetKey: "cst_010_kelpfin", sortOrder: 86,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 3, backend: 2, pm: 2, infra: 2, traits: ["Early Bird"])),

        // --- Coast Uncommon (10) — total 20–26, 1 domain + 1 style tag ---
        entry(id: "CST_011", name: "Driftotter", field: .coast, rarity: .uncommon, assetKey: "cst_011_driftotter", sortOrder: 87,
              stats: SpeciesStatBlock(planning: 3, design: 5, frontend: 5, backend: 3, pm: 3, infra: 3, traits: ["Layout Genius", "Deep Focus"])),
        entry(id: "CST_012", name: "Coralwhisk", field: .coast, rarity: .uncommon, assetKey: "cst_012_coralwhisk", sortOrder: 88,
              stats: SpeciesStatBlock(planning: 3, design: 6, frontend: 4, backend: 3, pm: 3, infra: 3, traits: ["Color Whisperer", "Perfectionist"])),
        entry(id: "CST_013", name: "Wavehog", field: .coast, rarity: .uncommon, assetKey: "cst_013_wavehog", sortOrder: 89,
              stats: SpeciesStatBlock(planning: 3, design: 4, frontend: 5, backend: 4, pm: 3, infra: 3, traits: ["Quick Prototyper", "Fast Typer"])),
        entry(id: "CST_014", name: "Marinaff", field: .coast, rarity: .uncommon, assetKey: "cst_014_marinaff", sortOrder: 90,
              stats: SpeciesStatBlock(planning: 4, design: 5, frontend: 4, backend: 3, pm: 4, infra: 3, traits: ["Pixel Perfect", "Clean Coder"])),
        entry(id: "CST_015", name: "Saltstoat", field: .coast, rarity: .uncommon, assetKey: "cst_015_saltstoat", sortOrder: 91,
              stats: SpeciesStatBlock(planning: 3, design: 4, frontend: 5, backend: 4, pm: 3, infra: 3, traits: ["CSS Wizard", "Night Owl"])),
        entry(id: "CST_016", name: "Reefrunner", field: .coast, rarity: .uncommon, assetKey: "cst_016_reefrunner", sortOrder: 92,
              stats: SpeciesStatBlock(planning: 3, design: 4, frontend: 5, backend: 3, pm: 4, infra: 3, traits: ["Animation Pro", "Speed Runner"])),
        entry(id: "CST_017", name: "Pearlmink", field: .coast, rarity: .uncommon, assetKey: "cst_017_pearlmink", sortOrder: 93,
              stats: SpeciesStatBlock(planning: 3, design: 6, frontend: 4, backend: 3, pm: 3, infra: 3, traits: ["Minimalist", "Early Bird"])),
        entry(id: "CST_018", name: "Tidehopper", field: .coast, rarity: .uncommon, assetKey: "cst_018_tidehopper", sortOrder: 94,
              stats: SpeciesStatBlock(planning: 3, design: 4, frontend: 5, backend: 3, pm: 4, infra: 3, traits: ["Responsive Guru", "Multitasker"])),
        entry(id: "CST_019", name: "Harborseal", field: .coast, rarity: .uncommon, assetKey: "cst_019_harborseal", sortOrder: 95,
              stats: SpeciesStatBlock(planning: 4, design: 4, frontend: 4, backend: 4, pm: 4, infra: 4, traits: ["Motion Crafter", "Rubber Ducker"])),
        entry(id: "CST_020", name: "Spraytail", field: .coast, rarity: .uncommon, assetKey: "cst_020_spraytail", sortOrder: 96,
              stats: SpeciesStatBlock(planning: 3, design: 5, frontend: 5, backend: 3, pm: 3, infra: 3, traits: ["Brand Guardian", "Experimenter"])),

        // --- Coast Rare (8) — total 28–34, 1 domain + 2 style tags ---
        entry(id: "CST_021", name: "Tidefang", field: .coast, rarity: .rare, assetKey: "cst_021_tidefang", sortOrder: 97,
              stats: SpeciesStatBlock(planning: 4, design: 6, frontend: 6, backend: 5, pm: 4, infra: 5, traits: ["Layout Genius", "Deep Focus", "Night Owl"])),
        entry(id: "CST_022", name: "Ripturtle", field: .coast, rarity: .rare, assetKey: "cst_022_ripturtle", sortOrder: 98,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 6, backend: 5, pm: 5, infra: 4, traits: ["Quick Prototyper", "Clean Coder", "Solo Worker"])),
        entry(id: "CST_023", name: "Reefstalker", field: .coast, rarity: .rare, assetKey: "cst_023_reefstalker", sortOrder: 99,
              stats: SpeciesStatBlock(planning: 4, design: 7, frontend: 5, backend: 5, pm: 4, infra: 5, traits: ["Pixel Perfect", "Perfectionist", "Fast Typer"])),
        entry(id: "CST_024", name: "Brinehorn", field: .coast, rarity: .rare, assetKey: "cst_024_brinehorn", sortOrder: 100,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 7, backend: 4, pm: 5, infra: 4, traits: ["Component Builder", "Coffee Addict", "Speed Runner"])),
        entry(id: "CST_025", name: "Currentcobra", field: .coast, rarity: .rare, assetKey: "cst_025_currentcobra", sortOrder: 101,
              stats: SpeciesStatBlock(planning: 4, design: 6, frontend: 5, backend: 5, pm: 5, infra: 5, traits: ["Color Whisperer", "Multitasker", "Experimenter"])),
        entry(id: "CST_026", name: "Duskdolph", field: .coast, rarity: .rare, assetKey: "cst_026_duskdolph", sortOrder: 102,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 6, backend: 5, pm: 5, infra: 4, traits: ["CSS Wizard", "Early Bird", "Pair Programmer"])),
        entry(id: "CST_027", name: "Seaflare", field: .coast, rarity: .rare, assetKey: "cst_027_seaflare", sortOrder: 103,
              stats: SpeciesStatBlock(planning: 4, design: 6, frontend: 6, backend: 4, pm: 5, infra: 5, traits: ["Motion Crafter", "Night Owl", "Terminal Lover"])),
        entry(id: "CST_028", name: "Gullfang", field: .coast, rarity: .rare, assetKey: "cst_028_gullfang", sortOrder: 104,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 6, backend: 5, pm: 5, infra: 4, traits: ["Animation Pro", "Rubber Ducker", "Documentation Lover"])),

        // --- Coast Epic (6) — total 36–42, 2 domain + 2 style tags ---
        entry(id: "CST_029", name: "Moonfin Levi", field: .coast, rarity: .epic, assetKey: "cst_029_moonfin_levi", sortOrder: 105,
              stats: SpeciesStatBlock(planning: 5, design: 8, frontend: 7, backend: 6, pm: 6, infra: 6, traits: ["Pixel Perfect", "Quick Prototyper", "Deep Focus", "Perfectionist"])),
        entry(id: "CST_030", name: "Coral Regent", field: .coast, rarity: .epic, assetKey: "cst_030_coral_regent", sortOrder: 106,
              stats: SpeciesStatBlock(planning: 6, design: 7, frontend: 7, backend: 5, pm: 6, infra: 7, traits: ["Layout Genius", "Component Builder", "Clean Coder", "Mentor"])),
        entry(id: "CST_031", name: "Maelstrom Eel", field: .coast, rarity: .epic, assetKey: "cst_031_maelstrom_eel", sortOrder: 107,
              stats: SpeciesStatBlock(planning: 6, design: 6, frontend: 8, backend: 6, pm: 6, infra: 6, traits: ["CSS Wizard", "Animation Pro", "Night Owl", "Fast Typer"])),
        entry(id: "CST_032", name: "Tidemaw", field: .coast, rarity: .epic, assetKey: "cst_032_tidemaw", sortOrder: 108,
              stats: SpeciesStatBlock(planning: 6, design: 7, frontend: 6, backend: 7, pm: 6, infra: 6, traits: ["Color Whisperer", "API Architect", "Coffee Addict", "Multitasker"])),
        entry(id: "CST_033", name: "Luminray", field: .coast, rarity: .epic, assetKey: "cst_033_luminray", sortOrder: 109,
              stats: SpeciesStatBlock(planning: 6, design: 8, frontend: 7, backend: 5, pm: 6, infra: 6, traits: ["Minimalist", "Responsive Guru", "Experimenter", "Speed Runner"])),
        entry(id: "CST_034", name: "Abyssnarwhal", field: .coast, rarity: .epic, assetKey: "cst_034_abyssnarwhal", sortOrder: 110,
              stats: SpeciesStatBlock(planning: 6, design: 6, frontend: 7, backend: 7, pm: 6, infra: 6, traits: ["Brand Guardian", "Debug Master", "Solo Worker", "Terminal Lover"])),

        // --- Coast Legendary (4) — total 44–52, 2 domain + 3 style tags ---
        entry(id: "CST_035", name: "Abyss Pearlwyrm", field: .coast, rarity: .legendary, assetKey: "cst_035_abyss_pearlwyrm", sortOrder: 111,
              stats: SpeciesStatBlock(planning: 7, design: 9, frontend: 9, backend: 7, pm: 7, infra: 7, traits: ["Pixel Perfect", "Quick Prototyper", "Deep Focus", "Perfectionist", "Clean Coder"])),
        entry(id: "CST_036", name: "Trench Sovereign", field: .coast, rarity: .legendary, assetKey: "cst_036_trench_sovereign", sortOrder: 112,
              stats: SpeciesStatBlock(planning: 8, design: 9, frontend: 8, backend: 7, pm: 8, infra: 8, traits: ["Layout Genius", "Color Whisperer", "Mentor", "Night Owl", "Documentation Lover"])),
        entry(id: "CST_037", name: "Ocean Halo Whale", field: .coast, rarity: .legendary, assetKey: "cst_037_ocean_halo_whale", sortOrder: 113,
              stats: SpeciesStatBlock(planning: 7, design: 8, frontend: 10, backend: 7, pm: 8, infra: 7, traits: ["CSS Wizard", "Component Builder", "Coffee Addict", "Experimenter", "Speed Runner"])),
        entry(id: "CST_038", name: "Stormtide Basilisk", field: .coast, rarity: .legendary, assetKey: "cst_038_stormtide_basilisk", sortOrder: 114,
              stats: SpeciesStatBlock(planning: 8, design: 8, frontend: 8, backend: 8, pm: 8, infra: 8, traits: ["Motion Crafter", "Brand Guardian", "Early Bird", "Multitasker", "Git Historian"])),

        // =====================================================================
        // ICE — 37 species
        // Field tendency: backend + infra boosted
        // =====================================================================

        // --- Ice Common (10) — total 12–18, 1 style tag ---
        entry(id: "ICE_001", name: "Snowmole", field: .ice, rarity: .common, assetKey: "ice_001_snowmole", sortOrder: 115,
              stats: SpeciesStatBlock(planning: 2, design: 1, frontend: 2, backend: 3, pm: 2, infra: 3, traits: ["Night Owl"])),
        entry(id: "ICE_002", name: "Glintbeet", field: .ice, rarity: .common, assetKey: "ice_002_glintbeet", sortOrder: 116,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 2, backend: 3, pm: 2, infra: 3, traits: ["Terminal Lover"])),
        entry(id: "ICE_003", name: "Driftpup", field: .ice, rarity: .common, assetKey: "ice_003_driftpup", sortOrder: 117,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 2, backend: 2, pm: 2, infra: 3, traits: ["Deep Focus"])),
        entry(id: "ICE_004", name: "Icemouse", field: .ice, rarity: .common, assetKey: "ice_004_icemouse", sortOrder: 118,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 1, backend: 3, pm: 2, infra: 3, traits: ["Solo Worker"])),
        entry(id: "ICE_005", name: "Snowrat", field: .ice, rarity: .common, assetKey: "ice_005_snowrat", sortOrder: 119,
              stats: SpeciesStatBlock(planning: 2, design: 1, frontend: 2, backend: 3, pm: 2, infra: 3, traits: ["Coffee Addict"])),
        entry(id: "ICE_006", name: "Crystalbug", field: .ice, rarity: .common, assetKey: "ice_006_crystalbug", sortOrder: 120,
              stats: SpeciesStatBlock(planning: 1, design: 1, frontend: 1, backend: 1, pm: 1, infra: 8, traits: ["Clean Coder"])),
        entry(id: "ICE_007", name: "Sleetstoat", field: .ice, rarity: .common, assetKey: "ice_007_sleetstoat", sortOrder: 121,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 2, backend: 3, pm: 2, infra: 3, traits: ["Fast Typer"])),
        entry(id: "ICE_008", name: "Hailhopper", field: .ice, rarity: .common, assetKey: "ice_008_hailhopper", sortOrder: 122,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 2, backend: 4, pm: 2, infra: 3, traits: ["Speed Runner"])),
        entry(id: "ICE_009", name: "Snowbat", field: .ice, rarity: .common, assetKey: "ice_009_snowbat", sortOrder: 123,
              stats: SpeciesStatBlock(planning: 1, design: 1, frontend: 1, backend: 8, pm: 1, infra: 1, traits: ["Night Owl"])),
        entry(id: "ICE_010", name: "Iceslug", field: .ice, rarity: .common, assetKey: "ice_010_iceslug", sortOrder: 124,
              stats: SpeciesStatBlock(planning: 2, design: 2, frontend: 2, backend: 3, pm: 2, infra: 3, traits: ["Rubber Ducker"])),

        // --- Ice Uncommon (10) — total 20–26, 1 domain + 1 style tag ---
        entry(id: "ICE_011", name: "Glintferret", field: .ice, rarity: .uncommon, assetKey: "ice_011_glintferret", sortOrder: 125,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 5, pm: 3, infra: 5, traits: ["Debug Master", "Terminal Lover"])),
        entry(id: "ICE_012", name: "Hailtoad", field: .ice, rarity: .uncommon, assetKey: "ice_012_hailtoad", sortOrder: 126,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 4, pm: 3, infra: 6, traits: ["Pipeline Builder", "Night Owl"])),
        entry(id: "ICE_013", name: "Snowbadger", field: .ice, rarity: .uncommon, assetKey: "ice_013_snowbadger", sortOrder: 127,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 5, pm: 4, infra: 4, traits: ["API Architect", "Deep Focus"])),
        entry(id: "ICE_014", name: "Glaciercat", field: .ice, rarity: .uncommon, assetKey: "ice_014_glaciercat", sortOrder: 128,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 4, pm: 3, infra: 6, traits: ["Cloud Native", "Solo Worker"])),
        entry(id: "ICE_015", name: "Snowlark", field: .ice, rarity: .uncommon, assetKey: "ice_015_snowlark", sortOrder: 129,
              stats: SpeciesStatBlock(planning: 4, design: 3, frontend: 3, backend: 5, pm: 3, infra: 4, traits: ["Query Optimizer", "Coffee Addict"])),
        entry(id: "ICE_016", name: "Crystalmole", field: .ice, rarity: .uncommon, assetKey: "ice_016_crystalmole", sortOrder: 130,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 4, pm: 3, infra: 6, traits: ["Security Guard", "Clean Coder"])),
        entry(id: "ICE_017", name: "Shardhog", field: .ice, rarity: .uncommon, assetKey: "ice_017_shardhog", sortOrder: 131,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 6, pm: 3, infra: 4, traits: ["Data Modeler", "Fast Typer"])),
        entry(id: "ICE_018", name: "Shardrat", field: .ice, rarity: .uncommon, assetKey: "ice_018_shardrat", sortOrder: 132,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 5, pm: 3, infra: 5, traits: ["Cache Wizard", "Multitasker"])),
        entry(id: "ICE_019", name: "Hailwren", field: .ice, rarity: .uncommon, assetKey: "ice_019_hailwren", sortOrder: 133,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 4, backend: 4, pm: 3, infra: 5, traits: ["Scale Master", "Experimenter"])),
        entry(id: "ICE_020", name: "Glaciercub", field: .ice, rarity: .uncommon, assetKey: "ice_020_glaciercub", sortOrder: 134,
              stats: SpeciesStatBlock(planning: 3, design: 3, frontend: 3, backend: 5, pm: 3, infra: 5, traits: ["Error Handler", "Early Bird"])),

        // --- Ice Rare (8) — total 28–34, 1 domain + 2 style tags ---
        entry(id: "ICE_021", name: "Aurora Lynx", field: .ice, rarity: .rare, assetKey: "ice_021_aurora_lynx", sortOrder: 135,
              stats: SpeciesStatBlock(planning: 4, design: 4, frontend: 4, backend: 6, pm: 5, infra: 7, traits: ["Pipeline Builder", "Night Owl", "Deep Focus"])),
        entry(id: "ICE_022", name: "Bergmole", field: .ice, rarity: .rare, assetKey: "ice_022_bergmole", sortOrder: 136,
              stats: SpeciesStatBlock(planning: 5, design: 4, frontend: 4, backend: 7, pm: 5, infra: 5, traits: ["Debug Master", "Terminal Lover", "Solo Worker"])),
        entry(id: "ICE_023", name: "Icemaw", field: .ice, rarity: .rare, assetKey: "ice_023_icemaw", sortOrder: 137,
              stats: SpeciesStatBlock(planning: 4, design: 5, frontend: 4, backend: 5, pm: 5, infra: 7, traits: ["Cloud Native", "Coffee Addict", "Clean Coder"])),
        entry(id: "ICE_024", name: "Glacier Ram", field: .ice, rarity: .rare, assetKey: "ice_024_glacier_ram", sortOrder: 138,
              stats: SpeciesStatBlock(planning: 5, design: 4, frontend: 5, backend: 6, pm: 4, infra: 6, traits: ["API Architect", "Fast Typer", "Speed Runner"])),
        entry(id: "ICE_025", name: "Snowfang", field: .ice, rarity: .rare, assetKey: "ice_025_snowfang", sortOrder: 139,
              stats: SpeciesStatBlock(planning: 4, design: 5, frontend: 5, backend: 5, pm: 5, infra: 6, traits: ["Security Guard", "Perfectionist", "Multitasker"])),
        entry(id: "ICE_026", name: "Crystaladder", field: .ice, rarity: .rare, assetKey: "ice_026_crystaladder", sortOrder: 140,
              stats: SpeciesStatBlock(planning: 5, design: 4, frontend: 4, backend: 6, pm: 5, infra: 6, traits: ["Scale Master", "Early Bird", "Pair Programmer"])),
        entry(id: "ICE_027", name: "Snowburrow", field: .ice, rarity: .rare, assetKey: "ice_027_snowburrow", sortOrder: 141,
              stats: SpeciesStatBlock(planning: 5, design: 4, frontend: 5, backend: 6, pm: 4, infra: 6, traits: ["Concurrency Pro", "Rubber Ducker", "Documentation Lover"])),
        entry(id: "ICE_028", name: "Glacier Hydra", field: .ice, rarity: .rare, assetKey: "ice_028_glacier_hydra", sortOrder: 142,
              stats: SpeciesStatBlock(planning: 4, design: 5, frontend: 4, backend: 7, pm: 5, infra: 5, traits: ["Query Optimizer", "Night Owl", "Experimenter"])),

        // --- Ice Epic (6) — total 36–42, 2 domain + 2 style tags ---
        entry(id: "ICE_029", name: "Whiteout Wyrm", field: .ice, rarity: .epic, assetKey: "ice_029_whiteout_wyrm", sortOrder: 143,
              stats: SpeciesStatBlock(planning: 5, design: 5, frontend: 6, backend: 8, pm: 6, infra: 8, traits: ["Debug Master", "Pipeline Builder", "Deep Focus", "Terminal Lover"])),
        entry(id: "ICE_030", name: "Hail Coloss", field: .ice, rarity: .epic, assetKey: "ice_030_hail_coloss", sortOrder: 144,
              stats: SpeciesStatBlock(planning: 6, design: 5, frontend: 5, backend: 7, pm: 6, infra: 8, traits: ["Cloud Native", "Scale Master", "Night Owl", "Solo Worker"])),
        entry(id: "ICE_031", name: "Glacier Drake", field: .ice, rarity: .epic, assetKey: "ice_031_glacier_drake", sortOrder: 145,
              stats: SpeciesStatBlock(planning: 6, design: 6, frontend: 5, backend: 8, pm: 5, infra: 7, traits: ["API Architect", "Security Guard", "Coffee Addict", "Clean Coder"])),
        entry(id: "ICE_032", name: "Aurora Chimera", field: .ice, rarity: .epic, assetKey: "ice_032_aurora_chimera", sortOrder: 146,
              stats: SpeciesStatBlock(planning: 6, design: 6, frontend: 6, backend: 7, pm: 6, infra: 7, traits: ["Data Modeler", "Container Wizard", "Experimenter", "Fast Typer"])),
        entry(id: "ICE_033", name: "Crystal Molem", field: .ice, rarity: .epic, assetKey: "ice_033_crystal_molem", sortOrder: 147,
              stats: SpeciesStatBlock(planning: 5, design: 6, frontend: 6, backend: 7, pm: 6, infra: 8, traits: ["Monitoring Hawk", "Cache Wizard", "Perfectionist", "Multitasker"])),
        entry(id: "ICE_034", name: "Ice Basilisk", field: .ice, rarity: .epic, assetKey: "ice_034_ice_basilisk", sortOrder: 148,
              stats: SpeciesStatBlock(planning: 6, design: 5, frontend: 6, backend: 8, pm: 6, infra: 7, traits: ["Concurrency Pro", "SRE Soul", "Early Bird", "Speed Runner"])),

        // --- Ice Legendary (3) — total 44–52, 2 domain + 3 style tags ---
        entry(id: "ICE_035", name: "Polarcore Golem", field: .ice, rarity: .legendary, assetKey: "ice_035_polarcore_golem", sortOrder: 149,
              stats: SpeciesStatBlock(planning: 7, design: 7, frontend: 7, backend: 9, pm: 7, infra: 9, traits: ["Debug Master", "Pipeline Builder", "Deep Focus", "Terminal Lover", "Clean Coder"])),
        entry(id: "ICE_036", name: "Aurora Drake", field: .ice, rarity: .legendary, assetKey: "ice_036_aurora_drake", sortOrder: 150,
              stats: SpeciesStatBlock(planning: 8, design: 7, frontend: 7, backend: 10, pm: 7, infra: 8, traits: ["API Architect", "Cloud Native", "Night Owl", "Experimenter", "Git Historian"])),
        entry(id: "ICE_037", name: "Whiteout Titan", field: .ice, rarity: .legendary, assetKey: "ice_037_whiteout_titan", sortOrder: 151,
              stats: SpeciesStatBlock(planning: 7, design: 7, frontend: 8, backend: 9, pm: 8, infra: 9, traits: ["Scale Master", "Security Guard", "Coffee Addict", "Solo Worker", "Shortcut Master"])),
    ]
    // swiftlint:enable function_body_length

    public static var expectedCount: Int { all.count }

    public static func validationIssues() -> [String] {
        var issues: [String] = []

        let duplicateIDs = Dictionary(grouping: all, by: \.id)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        if !duplicateIDs.isEmpty {
            issues.append("duplicate species ids: \(duplicateIDs.joined(separator: ", "))")
        }

        let duplicateAssetKeys = Dictionary(grouping: all, by: \.assetKey)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        if !duplicateAssetKeys.isEmpty {
            issues.append("duplicate asset keys: \(duplicateAssetKeys.joined(separator: ", "))")
        }

        let duplicateSortOrders = Dictionary(grouping: all, by: \.sortOrder)
            .filter { $0.value.count > 1 }
            .keys
            .sorted()
        if !duplicateSortOrders.isEmpty {
            issues.append("duplicate species sort orders: \(duplicateSortOrders.map(String.init).joined(separator: ", "))")
        }

        let missingFields = all.filter { $0.id.isEmpty || $0.name.isEmpty || $0.assetKey.isEmpty }
        if !missingFields.isEmpty {
            issues.append("species definitions contain empty ids/names/asset keys")
        }

        for field in FieldType.allCases {
            let traits = Set(all.filter { $0.field == field }.map(\.trainingTrait))
            let missingTraits = TrainingTrait.allCases.filter { traits.contains($0) == false }
            if missingTraits.isEmpty == false {
                issues.append(
                    "field \(field.rawValue) missing training traits: \(missingTraits.map(\.rawValue).joined(separator: ", "))"
                )
            }
        }

        for field in FieldType.allCases {
            for rarity in RarityTier.allCases {
                let entries = all.filter { $0.field == field && $0.rarity == rarity }
                guard entries.isEmpty == false else { continue }
                let counts = TrainingTrait.allCases.map { trait in
                    entries.filter { $0.trainingTrait == trait }.count
                }
                if let minCount = counts.min(),
                   let maxCount = counts.max(),
                   maxCount - minCount > 1 {
                    issues.append(
                        "field \(field.rawValue) rarity \(rarity.rawValue) has imbalanced training traits"
                    )
                }
            }
        }

        return issues
    }
}
