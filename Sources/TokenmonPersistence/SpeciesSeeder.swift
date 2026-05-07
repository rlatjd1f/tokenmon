import Foundation
import TokenmonDomain

public struct SpeciesSeedResult: Sendable {
    public let totalSpecies: Int
    public let insertedSpecies: Int
}

public enum SpeciesSeedError: Error, LocalizedError {
    case invalidCatalog([String])

    public var errorDescription: String? {
        switch self {
        case .invalidCatalog(let issues):
            return "species catalog validation failed: \(issues.joined(separator: "; "))"
        }
    }
}

public enum SpeciesSeeder {
    public static func seed(databasePath: String) throws -> SpeciesSeedResult {
        let database = try TokenmonDatabaseManager(path: databasePath).open()
        return try seed(database: database)
    }

    public static func seed(database: SQLiteDatabase) throws -> SpeciesSeedResult {
        let issues = SpeciesCatalog.validationIssues()
        guard issues.isEmpty else {
            throw SpeciesSeedError.invalidCatalog(issues)
        }

        let beforeCount = Int(try database.fetchOne("SELECT COUNT(*) FROM species;") { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0)

        let now = ISO8601DateFormatter().string(from: Date())

        try database.inTransaction {
            for species in SpeciesCatalog.all {
                try database.execute(
                    """
                    INSERT INTO species (
                        species_id,
                        name,
                        field_code,
                        rarity_tier,
                        is_active,
                        sort_order,
                        asset_key,
                        flavor_text,
                        introduced_in_version,
                        created_at,
                        stat_planning,
                        stat_design,
                        stat_frontend,
                        stat_backend,
                        stat_pm,
                        stat_infra,
                        traits_json,
                        training_trait
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    ON CONFLICT(species_id) DO UPDATE SET
                        name = excluded.name,
                        field_code = excluded.field_code,
                        rarity_tier = excluded.rarity_tier,
                        is_active = excluded.is_active,
                        sort_order = excluded.sort_order,
                        asset_key = excluded.asset_key,
                        flavor_text = excluded.flavor_text,
                        introduced_in_version = excluded.introduced_in_version,
                        stat_planning = excluded.stat_planning,
                        stat_design = excluded.stat_design,
                        stat_frontend = excluded.stat_frontend,
                        stat_backend = excluded.stat_backend,
                        stat_pm = excluded.stat_pm,
                        stat_infra = excluded.stat_infra,
                        traits_json = excluded.traits_json,
                        training_trait = excluded.training_trait;
                    """,
                    bindings: [
                        .text(species.id),
                        .text(species.name),
                        .text(species.field.rawValue),
                        .text(species.rarity.rawValue),
                        .integer(species.isActive ? 1 : 0),
                        .integer(Int64(species.sortOrder)),
                        .text(species.assetKey),
                        species.flavorText.map(SQLiteValue.text) ?? .null,
                        .text(species.introducedInVersion),
                        .text(now),
                        .integer(Int64(species.stats.planning)),
                        .integer(Int64(species.stats.design)),
                        .integer(Int64(species.stats.frontend)),
                        .integer(Int64(species.stats.backend)),
                        .integer(Int64(species.stats.pm)),
                        .integer(Int64(species.stats.infra)),
                        .text(traitsJSON(species.stats.traits)),
                        .text(species.trainingTrait.rawValue),
                    ]
                )
            }
        }

        let afterCount = Int(try database.fetchOne("SELECT COUNT(*) FROM species;") { statement in
            SQLiteDatabase.columnInt64(statement, index: 0)
        } ?? 0)

        return SpeciesSeedResult(
            totalSpecies: SpeciesCatalog.expectedCount,
            insertedSpecies: max(0, afterCount - beforeCount)
        )
    }

    private static func traitsJSON(_ traits: [String]) -> String {
        guard let data = try? JSONEncoder().encode(traits),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return string
    }
}
