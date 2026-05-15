import Foundation
import PostHog
import TokenmonDomain
import TokenmonPersistence

@MainActor
protocol TokenmonAnalyticsTracking: AnyObject {
    func syncConsent(appSettings: AppSettings, localeIdentifier: String)
    func captureAppOpened(
        summary: CurrentRunSummary?,
        latestEncounter: RecentEncounterSummary?,
        providerHealthSummaries: [ProviderHealthSummary]
    )
    func captureSurfaceOpened(
        surface: TokenmonRefreshSurface,
        entrypoint: String,
        settingsPane: TokenmonSettingsPane?
    )
    func captureProviderSetupResult(
        provider: ProviderCode,
        trigger: TokenmonAnalyticsProviderSetupTrigger,
        result: TokenmonAnalyticsProviderSetupResult,
        cliInstalled: Bool,
        isPartial: Bool
    )
    func captureProviderHealthChanged(
        provider: ProviderCode,
        previousHealthState: String,
        sourceMode: String?,
        healthState: String,
        liveGameplayArmed: Bool
    )
    func captureEncounterResolved(
        encounter: RecentEncounterSummary,
        isFirstSeen: Bool,
        isFirstCapture: Bool
    )
    func captureBackfillRunCompleted(_ summary: BackfillRunSummary)
    func captureUpdateStateChanged(
        stage: TokenmonAnalyticsUpdateStage,
        availableVersion: String?,
        feedSource: String?,
        manualTriggered: Bool
    )
    func captureCaptureNotificationOpened(
        speciesID: String,
        provider: ProviderCode?,
        field: FieldType?,
        rarity: RarityTier?
    )
}

enum TokenmonAnalyticsProviderSetupTrigger: String, Sendable {
    case auto
    case manual
}

enum TokenmonAnalyticsProviderSetupResult: String, Sendable {
    case completed
    case failed
}

enum TokenmonAnalyticsUpdateStage: String, Sendable {
    case checkRequested = "check_requested"
    case available
    case notAvailable = "not_available"
    case downloaded
    case downloadFailed = "download_failed"
    case installRequested = "install_requested"
}

@MainActor
final class TokenmonNoopAnalyticsTracker: TokenmonAnalyticsTracking {
    func syncConsent(appSettings: AppSettings, localeIdentifier: String) {
        _ = appSettings
        _ = localeIdentifier
    }

    func captureAppOpened(
        summary: CurrentRunSummary?,
        latestEncounter: RecentEncounterSummary?,
        providerHealthSummaries: [ProviderHealthSummary]
    ) {
        _ = summary
        _ = latestEncounter
        _ = providerHealthSummaries
    }

    func captureSurfaceOpened(
        surface: TokenmonRefreshSurface,
        entrypoint: String,
        settingsPane: TokenmonSettingsPane?
    ) {
        _ = surface
        _ = entrypoint
        _ = settingsPane
    }

    func captureProviderSetupResult(
        provider: ProviderCode,
        trigger: TokenmonAnalyticsProviderSetupTrigger,
        result: TokenmonAnalyticsProviderSetupResult,
        cliInstalled: Bool,
        isPartial: Bool
    ) {
        _ = provider
        _ = trigger
        _ = result
        _ = cliInstalled
        _ = isPartial
    }

    func captureProviderHealthChanged(
        provider: ProviderCode,
        previousHealthState: String,
        sourceMode: String?,
        healthState: String,
        liveGameplayArmed: Bool
    ) {
        _ = provider
        _ = previousHealthState
        _ = sourceMode
        _ = healthState
        _ = liveGameplayArmed
    }

    func captureEncounterResolved(
        encounter: RecentEncounterSummary,
        isFirstSeen: Bool,
        isFirstCapture: Bool
    ) {
        _ = encounter
        _ = isFirstSeen
        _ = isFirstCapture
    }

    func captureBackfillRunCompleted(_ summary: BackfillRunSummary) {
        _ = summary
    }

    func captureUpdateStateChanged(
        stage: TokenmonAnalyticsUpdateStage,
        availableVersion: String?,
        feedSource: String?,
        manualTriggered: Bool
    ) {
        _ = stage
        _ = availableVersion
        _ = feedSource
        _ = manualTriggered
    }

    func captureCaptureNotificationOpened(
        speciesID: String,
        provider: ProviderCode?,
        field: FieldType?,
        rarity: RarityTier?
    ) {
        _ = speciesID
        _ = provider
        _ = field
        _ = rarity
    }
}

private struct TokenmonPostHogConfiguration: Equatable {
    let apiKey: String
    let host: String

    static func resolve(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> TokenmonPostHogConfiguration? {
        let apiKey = normalized(
            processInfo.environment["TOKENMON_POSTHOG_API_KEY"]
                ?? bundle.object(forInfoDictionaryKey: "TokenmonPostHogAPIKey") as? String
        )
        let host = normalized(
            processInfo.environment["TOKENMON_POSTHOG_HOST"]
                ?? bundle.object(forInfoDictionaryKey: "TokenmonPostHogHost") as? String
        ) ?? PostHogConfig.defaultHost

        guard let apiKey else {
            return nil
        }

        return TokenmonPostHogConfiguration(apiKey: apiKey, host: host)
    }

    private static func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

@MainActor
final class TokenmonPostHogAnalyticsTracker: TokenmonAnalyticsTracking {
    private let databasePath: String
    private let supportDirectoryPath: String
    private let buildInfo: TokenmonBuildInfo
    private let bundle: Bundle
    private let processInfo: ProcessInfo
    private let databaseManager: TokenmonDatabaseManager
    private var sdkConfigured = false
    private var consentEnabled = false

    init(
        databasePath: String,
        buildInfo: TokenmonBuildInfo = .current,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) {
        self.databasePath = databasePath
        supportDirectoryPath = TokenmonDatabaseManager.supportDirectory(forDatabasePath: databasePath)
        self.buildInfo = buildInfo
        self.bundle = bundle
        self.processInfo = processInfo
        databaseManager = TokenmonDatabaseManager(path: databasePath)
    }

    func syncConsent(appSettings: AppSettings, localeIdentifier: String) {
        consentEnabled = appSettings.usageAnalyticsEnabled

        guard appSettings.usageAnalyticsEnabled else {
            if sdkConfigured {
                PostHogSDK.shared.optOut()
            }
            return
        }

        guard configureIfNeeded(localeIdentifier: localeIdentifier) else {
            return
        }

        PostHogSDK.shared.optIn()
        registerSharedProperties(localeIdentifier: localeIdentifier)
    }

    func captureAppOpened(
        summary: CurrentRunSummary?,
        latestEncounter: RecentEncounterSummary?,
        providerHealthSummaries: [ProviderHealthSummary]
    ) {
        let claude = providerHealthSummaries.first { $0.provider == .claude }
        let codex = providerHealthSummaries.first { $0.provider == .codex }
        let gemini = providerHealthSummaries.first { $0.provider == .gemini }
        let antigravity = providerHealthSummaries.first { $0.provider == .antigravity }
        capture(
            "tokenmon_app_opened",
            properties: [
                "connected_provider_count": providerHealthSummaries.filter { ["active", "connected"].contains($0.healthState) }.count,
                "seen_species_count": summary?.seenSpeciesCount ?? 0,
                "captured_species_count": summary?.capturedSpeciesCount ?? 0,
                "has_latest_encounter": latestEncounter != nil,
                "claude_connected": Self.isConnected(claude),
                "codex_connected": Self.isConnected(codex),
                "gemini_connected": Self.isConnected(gemini),
                "antigravity_connected": Self.isConnected(antigravity),
                "claude_live_gameplay_armed": claude?.liveGameplayArmed ?? false,
                "codex_live_gameplay_armed": codex?.liveGameplayArmed ?? false,
                "gemini_live_gameplay_armed": gemini?.liveGameplayArmed ?? false,
                "antigravity_live_gameplay_armed": antigravity?.liveGameplayArmed ?? false,
            ]
        )
    }

    func captureSurfaceOpened(
        surface: TokenmonRefreshSurface,
        entrypoint: String,
        settingsPane: TokenmonSettingsPane?
    ) {
        capture(
            "tokenmon_surface_opened",
            properties: [
                "surface": surface.analyticsValue,
                "entrypoint": entrypoint,
                "settings_pane": settingsPane?.rawValue,
            ]
        )
    }

    func captureProviderSetupResult(
        provider: ProviderCode,
        trigger: TokenmonAnalyticsProviderSetupTrigger,
        result: TokenmonAnalyticsProviderSetupResult,
        cliInstalled: Bool,
        isPartial: Bool
    ) {
        capture(
            "tokenmon_provider_setup_result",
            properties: [
                "provider": provider.rawValue,
                "trigger": trigger.rawValue,
                "result": result.rawValue,
                "cli_installed": cliInstalled,
                "is_partial": isPartial,
            ]
        )
    }

    func captureProviderHealthChanged(
        provider: ProviderCode,
        previousHealthState: String,
        sourceMode: String?,
        healthState: String,
        liveGameplayArmed: Bool
    ) {
        capture(
            "tokenmon_provider_health_changed",
            properties: [
                "provider": provider.rawValue,
                "source_mode": sourceMode,
                "previous_health_state": previousHealthState,
                "health_state": healthState,
                "live_gameplay_armed": liveGameplayArmed,
            ]
        )
    }

    func captureEncounterResolved(
        encounter: RecentEncounterSummary,
        isFirstSeen: Bool,
        isFirstCapture: Bool
    ) {
        capture(
            "tokenmon_encounter_resolved",
            properties: [
                "provider": encounter.provider?.rawValue ?? "unknown",
                "field": encounter.field.rawValue,
                "rarity": encounter.rarity.rawValue,
                "outcome": encounter.outcome.rawValue,
                "burst_intensity_band": encounter.burstIntensityBand,
                "is_first_seen": isFirstSeen,
                "is_first_capture": isFirstCapture,
                "encounter_sequence": encounter.encounterSequence,
            ]
        )
    }

    func captureBackfillRunCompleted(_ summary: BackfillRunSummary) {
        capture(
            "tokenmon_backfill_run_completed",
            properties: [
                "provider": summary.provider.rawValue,
                "mode": summary.mode,
                "status": summary.status,
                "samples_created": summary.samplesCreated,
                "duplicates_skipped": summary.duplicatesSkipped,
                "errors_count": summary.errorsCount,
            ]
        )
    }

    func captureUpdateStateChanged(
        stage: TokenmonAnalyticsUpdateStage,
        availableVersion: String?,
        feedSource: String?,
        manualTriggered: Bool
    ) {
        capture(
            "tokenmon_update_state_changed",
            properties: [
                "stage": stage.rawValue,
                "available_version": availableVersion,
                "feed_source": feedSource,
                "manual_triggered": manualTriggered,
            ]
        )
    }

    func captureCaptureNotificationOpened(
        speciesID: String,
        provider: ProviderCode?,
        field: FieldType?,
        rarity: RarityTier?
    ) {
        capture(
            "tokenmon_capture_notification_opened",
            properties: [
                "species_id": speciesID,
                "provider": provider?.rawValue,
                "field": field?.rawValue,
                "rarity": rarity?.rawValue,
            ]
        )
    }

    private func configureIfNeeded(localeIdentifier: String) -> Bool {
        if sdkConfigured {
            return true
        }

        guard let configuration = TokenmonPostHogConfiguration.resolve(bundle: bundle, processInfo: processInfo) else {
            TokenmonAppBehaviorLogger.error(
                category: "analytics",
                event: "posthog_configuration_missing",
                supportDirectoryPath: supportDirectoryPath
            )
            return false
        }

        let config = PostHogConfig(apiKey: configuration.apiKey, host: configuration.host)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.debug = processInfo.environment["TOKENMON_POSTHOG_DEBUG"] == "1"
        config.personProfiles = .never
        config.preloadFeatureFlags = false
        config.sendFeatureFlagEvent = false
        config.setDefaultPersonProperties = false
        config.optOut = false

        PostHogSDK.shared.setup(config)
        let installationID = (try? databaseManager.analyticsInstallationID()) ?? UUID().uuidString.lowercased()
        PostHogSDK.shared.identify("tokenmon:\(installationID)")
        sdkConfigured = true
        registerSharedProperties(localeIdentifier: localeIdentifier)
        return true
    }

    private func registerSharedProperties(localeIdentifier: String) {
        guard sdkConfigured else {
            return
        }

        PostHogSDK.shared.register(
            [
                "app": "tokenmon",
                "platform": "macos",
                "runtime": "native_macos",
                "app_version": appVersion,
                "build_flavor": buildFlavor,
                "developer_tools_visible": buildInfo.developerToolsVisible,
                "locale": localeIdentifier,
            ]
        )
    }

    private func capture(_ event: String, properties: [String: Any?]) {
        guard consentEnabled else {
            return
        }

        guard configureIfNeeded(localeIdentifier: TokenmonL10n.activeLocale.identifier) else {
            return
        }

        let payload = properties.compactMapValues { $0 }
        PostHogSDK.shared.capture(event, properties: payload)
        TokenmonAppBehaviorLogger.info(
            category: "analytics",
            event: event,
            metadata: payload.mapValues(Self.logValue),
            supportDirectoryPath: supportDirectoryPath
        )
    }

    private var appVersion: String {
        if let marketingVersion = normalized(buildInfo.marketingVersion) {
            return marketingVersion
        }
        if let buildNumber = normalized(buildInfo.buildNumber) {
            return buildNumber
        }
        return "workspace"
    }

    private var buildFlavor: String {
        if let explicit = normalized(processInfo.environment["TOKENMON_BUILD_FLAVOR"]) {
            return explicit
        }
        if buildInfo.developerToolsVisible {
            return "internal"
        }
        if normalized(buildInfo.marketingVersion) == nil {
            return "workspace"
        }
        return "release"
    }

    private static func logValue(_ value: Any) -> String {
        switch value {
        case let bool as Bool:
            return bool ? "true" : "false"
        default:
            return String(describing: value)
        }
    }

    private func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func isConnected(_ summary: ProviderHealthSummary?) -> Bool {
        guard let summary else {
            return false
        }

        return ["active", "connected"].contains(summary.healthState)
    }
}

private extension TokenmonRefreshSurface {
    var analyticsValue: String {
        switch self {
        case .now:
            return "now"
        case .raid:
            return "raid"
        case .tokens:
            return "tokens"
        case .stats:
            return "stats"
        case .dex:
            return "dex"
        case .settings:
            return "settings"
        case .onboarding:
            return "onboarding"
        case .developer:
            return "developer"
        }
    }
}
