import Foundation
@testable import TokenmonApp
@testable import TokenmonPersistence
import TokenmonDomain

@MainActor
final class TokenmonAnalyticsTrackerSpy: TokenmonAnalyticsTracking {
    struct Event: Equatable {
        let name: String
        let properties: [String: String]
    }

    private(set) var events: [Event] = []
    private(set) var latestConsentSettings = AppSettings()
    private(set) var latestLocaleIdentifier = "en"

    func syncConsent(appSettings: AppSettings, localeIdentifier: String) {
        latestConsentSettings = appSettings
        latestLocaleIdentifier = localeIdentifier
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
        append(
            "tokenmon_app_opened",
            [
                "connected_provider_count": "\(providerHealthSummaries.filter { ["active", "connected"].contains($0.healthState) }.count)",
                "seen_species_count": "\(summary?.seenSpeciesCount ?? 0)",
                "captured_species_count": "\(summary?.capturedSpeciesCount ?? 0)",
                "has_latest_encounter": latestEncounter != nil ? "true" : "false",
                "claude_connected": Self.isConnected(claude),
                "codex_connected": Self.isConnected(codex),
                "gemini_connected": Self.isConnected(gemini),
                "antigravity_connected": Self.isConnected(antigravity),
                "claude_live_gameplay_armed": (claude?.liveGameplayArmed ?? false) ? "true" : "false",
                "codex_live_gameplay_armed": (codex?.liveGameplayArmed ?? false) ? "true" : "false",
                "gemini_live_gameplay_armed": (gemini?.liveGameplayArmed ?? false) ? "true" : "false",
                "antigravity_live_gameplay_armed": (antigravity?.liveGameplayArmed ?? false) ? "true" : "false",
            ]
        )
    }

    func captureSurfaceOpened(
        surface: TokenmonRefreshSurface,
        entrypoint: String,
        settingsPane: TokenmonSettingsPane?
    ) {
        append(
            "tokenmon_surface_opened",
            [
                "surface": String(describing: surface),
                "entrypoint": entrypoint,
                "settings_pane": settingsPane?.rawValue ?? "",
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
        append(
            "tokenmon_provider_setup_result",
            [
                "provider": provider.rawValue,
                "trigger": trigger.rawValue,
                "result": result.rawValue,
                "cli_installed": cliInstalled ? "true" : "false",
                "is_partial": isPartial ? "true" : "false",
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
        append(
            "tokenmon_provider_health_changed",
            [
                "provider": provider.rawValue,
                "previous_health_state": previousHealthState,
                "source_mode": sourceMode ?? "",
                "health_state": healthState,
                "live_gameplay_armed": liveGameplayArmed ? "true" : "false",
            ]
        )
    }

    func captureEncounterResolved(
        encounter: RecentEncounterSummary,
        isFirstSeen: Bool,
        isFirstCapture: Bool
    ) {
        append(
            "tokenmon_encounter_resolved",
            [
                "provider": encounter.provider?.rawValue ?? "unknown",
                "field": encounter.field.rawValue,
                "rarity": encounter.rarity.rawValue,
                "outcome": encounter.outcome.rawValue,
                "is_first_seen": isFirstSeen ? "true" : "false",
                "is_first_capture": isFirstCapture ? "true" : "false",
                "encounter_sequence": "\(encounter.encounterSequence)",
            ]
        )
    }

    func captureBackfillRunCompleted(_ summary: BackfillRunSummary) {
        append(
            "tokenmon_backfill_run_completed",
            [
                "provider": summary.provider.rawValue,
                "mode": summary.mode,
                "status": summary.status,
                "samples_created": "\(summary.samplesCreated)",
                "duplicates_skipped": "\(summary.duplicatesSkipped)",
                "errors_count": "\(summary.errorsCount)",
            ]
        )
    }

    func captureUpdateStateChanged(
        stage: TokenmonAnalyticsUpdateStage,
        availableVersion: String?,
        feedSource: String?,
        manualTriggered: Bool
    ) {
        append(
            "tokenmon_update_state_changed",
            [
                "stage": stage.rawValue,
                "available_version": availableVersion ?? "",
                "feed_source": feedSource ?? "",
                "manual_triggered": manualTriggered ? "true" : "false",
            ]
        )
    }

    func captureCaptureNotificationOpened(
        speciesID: String,
        provider: ProviderCode?,
        field: FieldType?,
        rarity: RarityTier?
    ) {
        append(
            "tokenmon_capture_notification_opened",
            [
                "species_id": speciesID,
                "provider": provider?.rawValue ?? "",
                "field": field?.rawValue ?? "",
                "rarity": rarity?.rawValue ?? "",
            ]
        )
    }

    func events(named name: String) -> [Event] {
        events.filter { $0.name == name }
    }

    private func append(_ name: String, _ properties: [String: String]) {
        events.append(Event(name: name, properties: properties))
    }

    private static func isConnected(_ summary: ProviderHealthSummary?) -> String {
        guard let summary else {
            return "false"
        }

        return ["active", "connected"].contains(summary.healthState) ? "true" : "false"
    }
}
