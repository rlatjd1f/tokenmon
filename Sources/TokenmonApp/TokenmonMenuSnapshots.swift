import Foundation
import TokenmonDomain
import TokenmonPersistence

typealias TokenmonProviderInspector = @Sendable (
    _ databasePath: String,
    _ executablePath: String,
    _ preferences: ProviderInstallationPreferences
) -> [TokenmonProviderOnboardingStatus]

enum TokenmonRefreshSurface: Sendable {
    case now
    case raid
    case tokens
    case stats
    case dex
    case settings
    case onboarding
    case developer
}

enum TokenmonRefreshReason: Sendable {
    case initial
    case hotPath
    case inboxEvent
    case surfaceOpened(TokenmonRefreshSurface)
    case manual
    case partyChanged
}

struct TokenmonRefreshScopes: OptionSet, Sendable {
    let rawValue: Int

    static let runtime = TokenmonRefreshScopes(rawValue: 1 << 0)
    static let insights = TokenmonRefreshScopes(rawValue: 1 << 1)
    static let diagnostics = TokenmonRefreshScopes(rawValue: 1 << 2)
    static let all: TokenmonRefreshScopes = [.runtime, .insights, .diagnostics]
}

extension TokenmonRefreshScopes {
    var logLabel: String {
        var parts: [String] = []
        if contains(.runtime) { parts.append("runtime") }
        if contains(.insights) { parts.append("insights") }
        if contains(.diagnostics) { parts.append("diagnostics") }
        return parts.isEmpty ? "none" : parts.joined(separator: ",")
    }
}

extension TokenmonRefreshReason {
    func resolvedScopes(insightsLoaded: Bool) -> TokenmonRefreshScopes {
        switch self {
        case .initial:
            return .runtime
        case .manual:
            return .all
        case .hotPath:
            return .runtime
        case .inboxEvent:
            return insightsLoaded ? [.runtime, .insights] : .runtime
        case .surfaceOpened(.now):
            return .runtime
        case .surfaceOpened(.raid):
            return [.runtime, .insights]
        case .surfaceOpened(.tokens), .surfaceOpened(.stats), .surfaceOpened(.dex):
            return .insights
        case .surfaceOpened(.settings), .surfaceOpened(.onboarding):
            return .diagnostics
        case .surfaceOpened(.developer):
            return .all
        case .partyChanged:
            return [.runtime, .insights]
        }
    }
}

struct TokenmonRuntimeSnapshot: Equatable, Sendable {
    var isLoaded = false
    var summary: CurrentRunSummary?
    var latestEncounter: RecentEncounterSummary?
    var recentEncounterFeed: [RecentEncounterSummary] = []
    var todayActivity: TodayActivitySummary?
    var providerHealthSummaries: [ProviderHealthSummary] = []
    var ambientCompanionRoster: AmbientCompanionRoster = .byField([:])
    var raidDashboard: RaidDashboardSummary?
}

struct TokenmonInsightsSnapshot: Equatable, Sendable {
    var isLoaded = false
    var dexEntries: [DexEntrySummary] = []
    var recentCaptures: [DexEntrySummary] = []
    var fieldDistribution: [FieldType: Int] = [:]
    var dailyTrend: [DailyEncounterBucket] = []
    var tokenTotals: TokenUsageTotals?
    var tokenUsageSourceSummary = TokenUsageSourceSummary(
        hasAccountUsage: false,
        hasLocalUsage: false,
        accountBackedProvidersToday: [],
        localOnlyProvidersToday: []
    )
    var tokenByProviderToday: [ProviderCode: Int64] = [:]
    var tokenHourlyRolling: [HourTokenBucket] = []
    var recentSessions: [ProviderSessionTokens] = []
    var recentDomainEventRecords: [PersistedDomainEventRecord] = []
    var partyMembers: [PartyMemberSummary] = []
    var partySpeciesIDs: Set<String> = []
}

struct TokenmonDiagnosticsSnapshot: Equatable, Sendable {
    var isLoaded = false
    var databaseSummary: TokenmonDatabaseSummary?
    var appUpdaterDiagnostics = TokenmonAppUpdaterDiagnosticsSnapshot.resolve()
    var recentAppLogEntries: [TokenmonAppLogEntry] = []
    var providerHealthSummaries: [ProviderHealthSummary] = []
    var recentDomainEventRecords: [PersistedDomainEventRecord] = []
    var recentProviderSessionSummaries: [ProviderSessionSummary] = []
    var recentProviderIngestEventSummaries: [ProviderIngestEventSummary] = []
    var recentBackfillRunSummaries: [BackfillRunSummary] = []
    var onboardingStatuses: [TokenmonProviderOnboardingStatus] = []
    var providerInstallationPreferences = ProviderInstallationPreferences()
    var appSettings = AppSettings()
    var launchAtLoginState = TokenmonLaunchAtLoginState.unsupported(
        reason: "Launch at login is available only from an installed app bundle."
    )
}

struct TokenmonMenuRefreshResult: Sendable {
    let runtime: TokenmonRuntimeSnapshot?
    let insights: TokenmonInsightsSnapshot?
    let diagnostics: TokenmonDiagnosticsSnapshot?
}

enum TokenmonEncounterDeltaResolver {
    static func newEncounters(
        previous: TokenmonRuntimeSnapshot,
        current: TokenmonRuntimeSnapshot
    ) -> [RecentEncounterSummary] {
        guard previous.isLoaded, current.isLoaded else {
            return []
        }

        let previousSequence = previous.latestEncounter?.encounterSequence ?? 0
        return current.recentEncounterFeed
            .filter { $0.encounterSequence > previousSequence }
            .sorted { $0.encounterSequence < $1.encounterSequence }
    }
}

enum TokenmonMenuSnapshotLoader {
    static func load(
        databasePath: String,
        executablePath: String,
        scopes: TokenmonRefreshScopes,
        providerInspector: @escaping TokenmonProviderInspector,
        launchAtLoginState: TokenmonLaunchAtLoginState?
    ) async throws -> TokenmonMenuRefreshResult {
        let task = Task.detached(priority: scopes.contains(.diagnostics) ? .userInitiated : .utility) {
            try loadSync(
                databasePath: databasePath,
                executablePath: executablePath,
                scopes: scopes,
                providerInspector: providerInspector,
                launchAtLoginState: launchAtLoginState
            )
        }

        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    private static func loadSync(
        databasePath: String,
        executablePath: String,
        scopes: TokenmonRefreshScopes,
        providerInspector: TokenmonProviderInspector,
        launchAtLoginState: TokenmonLaunchAtLoginState?
    ) throws -> TokenmonMenuRefreshResult {
        try Task.checkCancellation()

        let manager = TokenmonDatabaseManager(path: databasePath)
        let database = try manager.open()
        let supportDirectoryPath = TokenmonDatabaseManager.supportDirectory(forDatabasePath: databasePath)
        let loadStartedAt = Date()
        var runtime: TokenmonRuntimeSnapshot?
        var insights: TokenmonInsightsSnapshot?
        var diagnostics: TokenmonDiagnosticsSnapshot?

        func logSection(_ section: String, startedAt: Date, metadata: [String: String] = [:]) {
            var combined = metadata
            combined["section"] = section
            combined["scopes"] = scopes.logLabel
            combined["duration_ms"] = TokenmonAppBehaviorLogger.durationMillisecondsString(since: startedAt)
            TokenmonAppBehaviorLogger.debug(
                category: "refresh",
                event: "snapshot_section_completed",
                metadata: combined,
                supportDirectoryPath: supportDirectoryPath
            )
        }

        TokenmonAppBehaviorLogger.debug(
            category: "refresh",
            event: "snapshot_load_started",
            metadata: ["scopes": scopes.logLabel],
            supportDirectoryPath: supportDirectoryPath
        )

        let needsProviderHealth = scopes.contains(.runtime) || scopes.contains(.diagnostics)
        let providerHealthStartedAt = Date()
        let providerHealth = try (needsProviderHealth ? manager.providerHealthSummaries(database: database) : [])
        if needsProviderHealth {
            logSection(
                "provider_health",
                startedAt: providerHealthStartedAt,
                metadata: ["count": "\(providerHealth.count)"]
            )
        }

        if scopes.contains(.runtime) {
            let runtimeStartedAt = Date()
            let summary = try manager.currentRunSummary(database: database)
            let recentEncounterFeed = try manager.recentEncounterSummaries(limit: 5, database: database)
            let ambientRoster = try manager.ambientCompanionRoster(database: database)
            runtime = TokenmonRuntimeSnapshot(
                isLoaded: true,
                summary: summary,
                latestEncounter: recentEncounterFeed.first,
                recentEncounterFeed: recentEncounterFeed,
                todayActivity: try manager.todayActivitySummary(database: database),
                providerHealthSummaries: providerHealth,
                ambientCompanionRoster: ambientRoster,
                raidDashboard: try manager.raidDashboardSummary(database: database)
            )
            let rosterMetric: String = {
                switch ambientRoster {
                case .byField(let map): return "by_field:\(map.count)"
                case .partyOverride(let keys): return "party_override:\(keys.count)"
                }
            }()
            logSection(
                "runtime",
                startedAt: runtimeStartedAt,
                metadata: [
                    "encounter_feed_count": "\(recentEncounterFeed.count)",
                    "provider_health_count": "\(providerHealth.count)",
                    "ambient_companion_roster": rosterMetric,
                ]
            )
        }

        if scopes.contains(.insights) {
            let insightsStartedAt = Date()
            let dexEntries = try manager.dexEntrySummaries(database: database)
            let recentDomainEvents = try manager.recentDomainEvents(limit: 24, database: database)
            let partyMembers = try manager.partyMemberSummaries(database: database)
            let partySpeciesIDs = Set(partyMembers.map(\.speciesID))
            insights = TokenmonInsightsSnapshot(
                isLoaded: true,
                dexEntries: dexEntries,
                recentCaptures: Array(
                    dexEntries
                        .filter { $0.status == .captured }
                        .sorted { ($0.lastCapturedAt ?? "") > ($1.lastCapturedAt ?? "") }
                        .prefix(16)
                ),
                fieldDistribution: try manager.encounterFieldDistribution(database: database),
                dailyTrend: try manager.encounterDailyTrend(days: 7, database: database),
                tokenTotals: try manager.tokenUsageTotals(database: database),
                tokenUsageSourceSummary: try manager.tokenUsageSourceSummary(database: database),
                tokenByProviderToday: try manager.tokenByProviderToday(database: database),
                tokenHourlyRolling: try manager.tokenHourlyRolling24(database: database),
                recentSessions: try manager.recentProviderSessions(limit: 30, database: database),
                recentDomainEventRecords: recentDomainEvents,
                partyMembers: partyMembers,
                partySpeciesIDs: partySpeciesIDs
            )
            logSection(
                "insights",
                startedAt: insightsStartedAt,
                metadata: [
                    "dex_entry_count": "\(dexEntries.count)",
                    "recent_domain_event_count": "\(recentDomainEvents.count)",
                    "party_member_count": "\(partyMembers.count)",
                ]
            )
        }

        if scopes.contains(.diagnostics) {
            let diagnosticsStartedAt = Date()
            let preferences = try manager.providerInstallationPreferences(database: database)
            diagnostics = TokenmonDiagnosticsSnapshot(
                isLoaded: true,
                databaseSummary: try manager.summary(database: database),
                appUpdaterDiagnostics: TokenmonAppUpdaterDiagnosticsSnapshot.resolve(databasePath: databasePath),
                recentAppLogEntries: TokenmonAppBehaviorLogger.recentEntries(
                    supportDirectoryPath: supportDirectoryPath
                ),
                providerHealthSummaries: providerHealth.isEmpty ? try manager.providerHealthSummaries(database: database) : providerHealth,
                recentDomainEventRecords: try manager.recentDomainEvents(limit: 24, database: database),
                recentProviderSessionSummaries: try manager.recentProviderSessionSummaries(limit: 16, database: database),
                recentProviderIngestEventSummaries: try manager.recentProviderIngestEventSummaries(limit: 24, database: database),
                recentBackfillRunSummaries: try manager.recentBackfillRunSummaries(limit: 12, database: database),
                onboardingStatuses: providerInspector(databasePath, executablePath, preferences),
                providerInstallationPreferences: preferences,
                appSettings: try manager.appSettings(database: database),
                launchAtLoginState: launchAtLoginState ?? .unsupported(
                    reason: "Launch at login is available only from an installed app bundle."
                )
            )
            logSection(
                "diagnostics",
                startedAt: diagnosticsStartedAt,
                metadata: [
                    "provider_health_count": "\(diagnostics?.providerHealthSummaries.count ?? 0)",
                    "recent_log_entry_count": "\(diagnostics?.recentAppLogEntries.count ?? 0)",
                ]
            )
        }

        TokenmonAppBehaviorLogger.debug(
            category: "refresh",
            event: "snapshot_load_completed",
            metadata: [
                "scopes": scopes.logLabel,
                "duration_ms": TokenmonAppBehaviorLogger.durationMillisecondsString(since: loadStartedAt),
            ],
            supportDirectoryPath: supportDirectoryPath
        )

        return TokenmonMenuRefreshResult(runtime: runtime, insights: insights, diagnostics: diagnostics)
    }
}
