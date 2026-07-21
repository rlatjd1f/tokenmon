import Foundation

public enum AppAppearancePreference: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark
}

public enum AppLanguagePreference: String, CaseIterable, Codable, Sendable {
    case system
    case english
    case korean

    public var localeIdentifier: String? {
        switch self {
        case .system:
            return nil
        case .english:
            return "en"
        case .korean:
            return "ko"
        }
    }
}

public enum AppSurfacePresentationMode: String, CaseIterable, Codable, Sendable {
    case popover
    case floatingPanel
}

public struct AppSettings: Equatable, Sendable {
    public var launchAtLogin: Bool
    public var notificationsEnabled: Bool
    public var updateNotificationsEnabled: Bool
    public var firstRunSetupPromptShown: Bool
    public var providerStatusVisibility: Bool
    public var fieldBackplateEnabled: Bool
    public var usageAnalyticsEnabled: Bool
    public var usageAnalyticsPromptDismissed: Bool
    public var appearancePreference: AppAppearancePreference
    public var languagePreference: AppLanguagePreference
    public var surfacePresentationMode: AppSurfacePresentationMode
    public var floatingPanelAlwaysOnTop: Bool
    public var floatingPanelOriginX: Double?
    public var floatingPanelOriginY: Double?

    public init(
        launchAtLogin: Bool = false,
        notificationsEnabled: Bool = false,
        updateNotificationsEnabled: Bool = false,
        firstRunSetupPromptShown: Bool = false,
        providerStatusVisibility: Bool = true,
        fieldBackplateEnabled: Bool = true,
        usageAnalyticsEnabled: Bool = false,
        usageAnalyticsPromptDismissed: Bool = false,
        appearancePreference: AppAppearancePreference = .system,
        languagePreference: AppLanguagePreference = .system,
        surfacePresentationMode: AppSurfacePresentationMode = .popover,
        floatingPanelAlwaysOnTop: Bool = true,
        floatingPanelOriginX: Double? = nil,
        floatingPanelOriginY: Double? = nil
    ) {
        self.launchAtLogin = launchAtLogin
        self.notificationsEnabled = notificationsEnabled
        self.updateNotificationsEnabled = updateNotificationsEnabled
        self.firstRunSetupPromptShown = firstRunSetupPromptShown
        self.providerStatusVisibility = providerStatusVisibility
        self.fieldBackplateEnabled = fieldBackplateEnabled
        self.usageAnalyticsEnabled = usageAnalyticsEnabled
        self.usageAnalyticsPromptDismissed = usageAnalyticsPromptDismissed
        self.appearancePreference = appearancePreference
        self.languagePreference = languagePreference
        self.surfacePresentationMode = surfacePresentationMode
        self.floatingPanelAlwaysOnTop = floatingPanelAlwaysOnTop
        self.floatingPanelOriginX = floatingPanelOriginX
        self.floatingPanelOriginY = floatingPanelOriginY
    }
}

public extension TokenmonDatabaseManager {
    func appSettings(database providedDatabase: SQLiteDatabase? = nil) throws -> AppSettings {
        let database = try providedDatabase ?? open()
        let settingsRows = try database.fetchAll(
            """
            SELECT setting_key, setting_value_json
            FROM settings;
            """
        ) { statement in
            (
                key: SQLiteDatabase.columnText(statement, index: 0),
                valueJSON: SQLiteDatabase.columnText(statement, index: 1)
            )
        }

        let decoder = JSONDecoder()
        var settings = AppSettings()

        for row in settingsRows {
            switch row.key {
            case "launch_at_login":
                settings.launchAtLogin = try decodeBool(from: row.valueJSON, decoder: decoder)
            case "notifications_enabled":
                settings.notificationsEnabled = try decodeBool(from: row.valueJSON, decoder: decoder)
            case "update_notifications_enabled":
                settings.updateNotificationsEnabled = try decodeBool(from: row.valueJSON, decoder: decoder)
            case "first_run_setup_prompt_shown":
                settings.firstRunSetupPromptShown = try decodeBool(from: row.valueJSON, decoder: decoder)
            case "provider_status_visibility":
                settings.providerStatusVisibility = try decodeBool(from: row.valueJSON, decoder: decoder)
            case "field_backplate_enabled":
                settings.fieldBackplateEnabled = try decodeBool(from: row.valueJSON, decoder: decoder)
            case "usage_analytics_enabled":
                settings.usageAnalyticsEnabled = try decodeBool(from: row.valueJSON, decoder: decoder)
            case "usage_analytics_prompt_dismissed":
                settings.usageAnalyticsPromptDismissed = try decodeBool(from: row.valueJSON, decoder: decoder)
            case "appearance_preference":
                settings.appearancePreference = try decoder.decode(AppAppearancePreference.self, from: Data(row.valueJSON.utf8))
            case "language_preference":
                settings.languagePreference = try decoder.decode(AppLanguagePreference.self, from: Data(row.valueJSON.utf8))
            case "surface_presentation_mode":
                settings.surfacePresentationMode = try decoder.decode(AppSurfacePresentationMode.self, from: Data(row.valueJSON.utf8))
            case "floating_panel_always_on_top":
                settings.floatingPanelAlwaysOnTop = try decodeBool(from: row.valueJSON, decoder: decoder)
            case "floating_panel_origin_x":
                settings.floatingPanelOriginX = try decoder.decode(Double.self, from: Data(row.valueJSON.utf8))
            case "floating_panel_origin_y":
                settings.floatingPanelOriginY = try decoder.decode(Double.self, from: Data(row.valueJSON.utf8))
            default:
                continue
            }
        }

        return settings
    }

    func saveAppSettings(_ settings: AppSettings) throws {
        let database = try open()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let updatedAt = ISO8601DateFormatter().string(from: Date())

        try database.inTransaction {
            try upsertSetting(
                key: "launch_at_login",
                encodedValue: try String(decoding: encoder.encode(settings.launchAtLogin), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "notifications_enabled",
                encodedValue: try String(decoding: encoder.encode(settings.notificationsEnabled), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "update_notifications_enabled",
                encodedValue: try String(decoding: encoder.encode(settings.updateNotificationsEnabled), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "first_run_setup_prompt_shown",
                encodedValue: try String(decoding: encoder.encode(settings.firstRunSetupPromptShown), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "provider_status_visibility",
                encodedValue: try String(decoding: encoder.encode(settings.providerStatusVisibility), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "field_backplate_enabled",
                encodedValue: try String(decoding: encoder.encode(settings.fieldBackplateEnabled), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "usage_analytics_enabled",
                encodedValue: try String(decoding: encoder.encode(settings.usageAnalyticsEnabled), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "usage_analytics_prompt_dismissed",
                encodedValue: try String(decoding: encoder.encode(settings.usageAnalyticsPromptDismissed), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "appearance_preference",
                encodedValue: try String(decoding: encoder.encode(settings.appearancePreference), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "language_preference",
                encodedValue: try String(decoding: encoder.encode(settings.languagePreference), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "surface_presentation_mode",
                encodedValue: try String(decoding: encoder.encode(settings.surfacePresentationMode), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            try upsertSetting(
                key: "floating_panel_always_on_top",
                encodedValue: try String(decoding: encoder.encode(settings.floatingPanelAlwaysOnTop), as: UTF8.self),
                updatedAt: updatedAt,
                database: database
            )
            if let originX = settings.floatingPanelOriginX {
                try upsertSetting(
                    key: "floating_panel_origin_x",
                    encodedValue: try String(decoding: encoder.encode(originX), as: UTF8.self),
                    updatedAt: updatedAt,
                    database: database
                )
            } else {
                try deleteSetting(key: "floating_panel_origin_x", database: database)
            }
            if let originY = settings.floatingPanelOriginY {
                try upsertSetting(
                    key: "floating_panel_origin_y",
                    encodedValue: try String(decoding: encoder.encode(originY), as: UTF8.self),
                    updatedAt: updatedAt,
                    database: database
                )
            } else {
                try deleteSetting(key: "floating_panel_origin_y", database: database)
            }
        }
    }

    private func deleteSetting(key: String, database: SQLiteDatabase) throws {
        try database.execute("DELETE FROM settings WHERE setting_key = ?;", bindings: [.text(key)])
    }

    private func upsertSetting(
        key: String,
        encodedValue: String,
        updatedAt: String,
        database: SQLiteDatabase
    ) throws {
        try database.execute(
            """
            INSERT INTO settings (
                setting_key,
                setting_value_json,
                updated_at
            ) VALUES (?, ?, ?)
            ON CONFLICT(setting_key) DO UPDATE SET
                setting_value_json = excluded.setting_value_json,
                updated_at = excluded.updated_at;
            """,
            bindings: [
                .text(key),
                .text(encodedValue),
                .text(updatedAt),
            ]
        )
    }

    private func decodeBool(from rawJSON: String, decoder: JSONDecoder) throws -> Bool {
        try decoder.decode(Bool.self, from: Data(rawJSON.utf8))
    }

    func analyticsInstallationID() throws -> String {
        let database = try open()
        let decoder = JSONDecoder()

        if let rawJSON = try database.fetchOne(
            """
            SELECT setting_value_json
            FROM settings
            WHERE setting_key = 'analytics_installation_id'
            LIMIT 1;
            """,
            map: { statement in
                SQLiteDatabase.columnText(statement, index: 0)
            }
        ) {
            return try decoder.decode(String.self, from: Data(rawJSON.utf8))
        }

        let installationID = UUID().uuidString.lowercased()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try upsertSetting(
            key: "analytics_installation_id",
            encodedValue: String(decoding: try encoder.encode(installationID), as: UTF8.self),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            database: database
        )
        return installationID
    }
}
