import Foundation
import TokenmonDomain
import TokenmonGameEngine
import TokenmonPersistence

struct TokenmonDexCollectionProgress: Equatable {
    let total: Int
    let seen: Int
    let captured: Int
    let hidden: Int

    var completionFraction: Double {
        guard total > 0 else { return 0 }
        return Double(captured) / Double(total)
    }

    var summaryLine: String {
        TokenmonL10n.format("dex.progress.summary", captured, seen, hidden)
    }

    var progressLine: String {
        let percent = Int((completionFraction * 100).rounded())
        return TokenmonL10n.format("dex.progress.line", percent)
    }
}

struct TokenmonDexMetricValue: Equatable {
    let title: String
    let value: String
}

enum TokenmonSpeciesNameStyle {
    case compact
    case sentence
}

enum TokenmonSpeciesArtRevealStage: Equatable {
    case silhouette
    case heavyBlur
    case mediumBlur
    case lightBlur
    case revealed
}

struct TokenmonDexActivitySummary: Equatable {
    let capturedCount: Int
    let revealedCount: Int

    var headline: String {
        if capturedCount == 0 && revealedCount == 0 {
            return TokenmonL10n.string("dex.activity.quiet.headline")
        }

        var parts: [String] = []
        if capturedCount > 0 {
            parts.append(TokenmonL10n.format("dex.activity.count.captured", capturedCount))
        }
        if revealedCount > 0 {
            parts.append(TokenmonL10n.format("dex.activity.count.revealed", revealedCount))
        }
        return parts.joined(separator: " · ")
    }

    var detail: String {
        if capturedCount == 0 && revealedCount == 0 {
            return TokenmonL10n.string("dex.activity.detail.next_encounter")
        }
        if capturedCount > 0 && revealedCount > 0 {
            return TokenmonL10n.string("dex.activity.detail.session_moved")
        }
        if capturedCount > 0 {
            return TokenmonL10n.string("dex.activity.detail.new_capture")
        }
        return TokenmonL10n.string("dex.activity.detail.new_species")
    }
}

enum TokenmonDexActivityKind: Equatable {
    case captured
    case revealed

    var title: String {
        switch self {
        case .captured:
            return TokenmonL10n.string("dex.activity.kind.captured")
        case .revealed:
            return TokenmonL10n.string("dex.activity.kind.revealed")
        }
    }
}

struct TokenmonDexActivityItem: Equatable {
    let speciesID: String
    let encounterID: String
    let sortOrder: Int
    let speciesName: String
    let assetKey: String
    let field: FieldType
    let rarity: RarityTier
    let status: DexEntryStatus
    let seenCount: Int64
    let capturedCount: Int64
    let kind: TokenmonDexActivityKind
    let occurredAt: String
}

enum TokenmonDexPresentation {
    static func visibleSpeciesName(
        for entry: DexEntrySummary,
        style: TokenmonSpeciesNameStyle = .compact
    ) -> String {
        visibleSpeciesName(
            speciesName: entry.speciesName,
            capturedCount: entry.capturedCount,
            style: style
        )
    }

    static func visibleSpeciesName(
        for encounter: RecentEncounterSummary,
        style: TokenmonSpeciesNameStyle = .sentence
    ) -> String {
        visibleSpeciesName(
            speciesName: encounter.speciesName,
            capturedCount: encounter.capturedCount,
            style: style
        )
    }

    static func visibleSpeciesName(
        for item: TokenmonDexActivityItem,
        style: TokenmonSpeciesNameStyle = .sentence
    ) -> String {
        visibleSpeciesName(
            speciesName: item.speciesName,
            capturedCount: item.capturedCount,
            style: style
        )
    }

    static func revealStage(for entry: DexEntrySummary) -> TokenmonSpeciesArtRevealStage {
        revealStage(seenCount: entry.seenCount, capturedCount: entry.capturedCount)
    }

    static func revealStage(for encounter: RecentEncounterSummary) -> TokenmonSpeciesArtRevealStage {
        revealStage(seenCount: encounter.seenCount, capturedCount: encounter.capturedCount)
    }

    static func revealStage(for item: TokenmonDexActivityItem) -> TokenmonSpeciesArtRevealStage {
        revealStage(seenCount: item.seenCount, capturedCount: item.capturedCount)
    }

    static func isFlavorTextUnlocked(for entry: DexEntrySummary) -> Bool {
        entry.capturedCount > 0
    }

    static func isNameUnlocked(capturedCount: Int64) -> Bool {
        capturedCount > 0
    }

    static func progress(for entries: [DexEntrySummary]) -> TokenmonDexCollectionProgress {
        let total = entries.count
        let seen = entries.filter { $0.status != .unknown }.count
        let captured = entries.filter { $0.status == .captured }.count
        return TokenmonDexCollectionProgress(
            total: total,
            seen: seen,
            captured: captured,
            hidden: max(0, total - seen)
        )
    }

    static func numberedEntries(from entries: [DexEntrySummary]) -> [DexEntrySummary] {
        entries.sorted { lhs, rhs in
            if lhs.sortOrder != rhs.sortOrder {
                return lhs.sortOrder < rhs.sortOrder
            }
            return lhs.speciesID < rhs.speciesID
        }
    }

    static func recentFinds(from entries: [DexEntrySummary], limit: Int = 6) -> [DexEntrySummary] {
        guard limit > 0 else { return [] }

        return entries
            .filter { $0.status != .unknown }
            .sorted { lhs, rhs in
                let lhsDate = latestActivityDate(for: lhs) ?? .distantPast
                let rhsDate = latestActivityDate(for: rhs) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                if lhs.status != rhs.status {
                    return statusRank(lhs.status) < statusRank(rhs.status)
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .prefix(limit)
            .map { $0 }
    }

    static func hiddenSlots(from entries: [DexEntrySummary], limit: Int = 6) -> [DexEntrySummary] {
        guard limit > 0 else { return [] }

        return entries
            .filter { $0.status == .unknown }
            .sorted { $0.sortOrder < $1.sortOrder }
            .prefix(limit)
            .map { $0 }
    }

    static func activityItems(
        from records: [PersistedDomainEventRecord],
        entries: [DexEntrySummary],
        limit: Int = 4
    ) -> [TokenmonDexActivityItem] {
        guard limit > 0 else { return [] }

        let entryBySpeciesID = Dictionary(uniqueKeysWithValues: entries.map { ($0.speciesID, $0) })
        var itemsByEncounterID: [String: TokenmonDexActivityItem] = [:]

        for record in records {
            guard let eventType = TokenmonDomainEventType(rawValue: record.eventType) else {
                continue
            }

            switch eventType {
            case .capturedDexUpdated:
                guard let payload = decodePayload(CapturedDexUpdatedEventPayload.self, from: record.payloadJSON),
                      let entry = entryBySpeciesID[payload.speciesID]
                else {
                    continue
                }
                itemsByEncounterID[payload.encounterID] = TokenmonDexActivityItem(
                    speciesID: payload.speciesID,
                    encounterID: payload.encounterID,
                    sortOrder: entry.sortOrder,
                    speciesName: entry.speciesName,
                    assetKey: entry.assetKey,
                    field: entry.field,
                    rarity: entry.rarity,
                    status: entry.status,
                    seenCount: entry.seenCount,
                    capturedCount: entry.capturedCount,
                    kind: .captured,
                    occurredAt: record.occurredAt
                )
            case .seenDexUpdated:
                guard let payload = decodePayload(SeenDexUpdatedEventPayload.self, from: record.payloadJSON),
                      let entry = entryBySpeciesID[payload.speciesID]
                else {
                    continue
                }
                if itemsByEncounterID[payload.encounterID] != nil {
                    continue
                }
                itemsByEncounterID[payload.encounterID] = TokenmonDexActivityItem(
                    speciesID: payload.speciesID,
                    encounterID: payload.encounterID,
                    sortOrder: entry.sortOrder,
                    speciesName: entry.speciesName,
                    assetKey: entry.assetKey,
                    field: entry.field,
                    rarity: entry.rarity,
                    status: entry.status,
                    seenCount: entry.seenCount,
                    capturedCount: entry.capturedCount,
                    kind: .revealed,
                    occurredAt: record.occurredAt
                )
            default:
                continue
            }
        }

        return itemsByEncounterID.values
            .sorted { lhs, rhs in
                let lhsDate = parseDate(lhs.occurredAt) ?? .distantPast
                let rhsDate = parseDate(rhs.occurredAt) ?? .distantPast
                if lhsDate != rhsDate {
                    return lhsDate > rhsDate
                }
                if lhs.kind != rhs.kind {
                    return activityRank(lhs.kind) < activityRank(rhs.kind)
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            .prefix(limit)
            .map { $0 }
    }

    static func activitySummary(from items: [TokenmonDexActivityItem]) -> TokenmonDexActivitySummary {
        let captured = items.filter { $0.kind == .captured }.count
        let revealed = items.filter { $0.kind == .revealed }.count
        return TokenmonDexActivitySummary(capturedCount: captured, revealedCount: revealed)
    }

    static func metadataLine(for entry: DexEntrySummary) -> String {
        var parts = [entry.field.displayName, entry.rarity.displayName]
        if let affinityLabel = affinityLevelLabel(for: entry, compact: false) {
            parts.append(affinityLabel)
            let bonus = affinityRaidBonus(for: affinityLevelNumber(for: entry))
            if bonus > 0 {
                parts.append(TokenmonL10n.format("affinity.raid_bonus_short", bonus))
            }
        }
        return parts.joined(separator: " · ")
    }

    static func affinityLevelLabel(for entry: DexEntrySummary, compact: Bool = false) -> String? {
        guard entry.status == .captured else { return nil }
        return affinityLevelLabel(level: normalizedAffinityLevel(entry.affinityLevel, capturedCount: entry.capturedCount), compact: compact)
    }

    static func affinityLevelLabel(for encounter: RecentEncounterSummary, compact: Bool = false) -> String? {
        guard encounter.outcome == .captured else { return nil }
        return affinityLevelLabel(level: normalizedAffinityLevel(encounter.affinityLevel, capturedCount: encounter.capturedCount), compact: compact)
    }

    static func affinityLevelNumber(for encounter: RecentEncounterSummary) -> Int64 {
        normalizedAffinityLevel(encounter.affinityLevel, capturedCount: encounter.capturedCount)
    }

    static func affinityLevelLabel(level: Int64, compact _: Bool = false) -> String {
        TokenmonL10n.format("affinity.level", SpeciesAffinityResolver.romanLevel(Int(level)))
    }

    static func affinityRomanLabel(level: Int64) -> String {
        SpeciesAffinityResolver.romanLevel(Int(max(1, min(5, level))))
    }

    static func affinityLevelNumber(for entry: DexEntrySummary) -> Int64 {
        normalizedAffinityLevel(entry.affinityLevel, capturedCount: entry.capturedCount)
    }

    static func affinityRaidBonus(for level: Int64) -> Int {
        RaidDamageCalculator.captureBondBonus(affinityLevel: max(1, level))
    }

    static func affinityRaidBonusValueLabel(level: Int64) -> String {
        let bonus = affinityRaidBonus(for: level)
        return bonus > 0 ? "+\(bonus)" : "+0"
    }

    static func affinityRaidBonusShortLabel(level: Int64) -> String {
        TokenmonL10n.format("affinity.raid_bonus_short", affinityRaidBonus(for: level))
    }

    static func affinityNextTargetLabel(for entry: DexEntrySummary) -> String {
        let level = affinityLevelNumber(for: entry)
        guard level > 0, level < 5 else {
            return TokenmonL10n.string("affinity.max")
        }
        return affinityLevelLabel(level: level + 1)
    }

    static func affinityCeilingLabel(for entry: DexEntrySummary) -> String? {
        guard entry.status == .captured else { return nil }
        let level = affinityLevelNumber(for: entry)
        guard level > 0, level < 5 else {
            return TokenmonL10n.string("affinity.max")
        }
        let ceiling = affinityCeilingFailures(
            rarity: entry.rarity,
            currentLevel: Int(level),
            probability: entry.affinityLastProbability
        )
        return TokenmonL10n.format("affinity.resonance", entry.affinityPityCount, Int64(ceiling))
    }

    static func affinityResonanceFraction(for entry: DexEntrySummary) -> Double {
        guard entry.status == .captured else { return 0 }
        let level = affinityLevelNumber(for: entry)
        guard level > 0, level < 5 else { return 1 }
        let ceiling = affinityCeilingFailures(
            rarity: entry.rarity,
            currentLevel: Int(level),
            probability: entry.affinityLastProbability
        )
        guard ceiling > 0 else { return 0 }
        return min(1, max(0, Double(entry.affinityPityCount) / Double(ceiling)))
    }

    static func affinityResultLine(for encounter: RecentEncounterSummary) -> String? {
        guard encounter.outcome == .captured else { return nil }

        let level = normalizedAffinityLevel(encounter.affinityLevel, capturedCount: encounter.capturedCount)
        if level >= 5 {
            return TokenmonL10n.string("affinity.max")
        }

        guard let outcomeValue = encounter.affinityLastOutcome,
              let outcome = SpeciesAffinityOutcome(rawValue: outcomeValue)
        else {
            return nil
        }

        switch outcome {
        case .initialized, .success, .guaranteedSuccess:
            return TokenmonL10n.format("affinity.level.reached", SpeciesAffinityResolver.romanLevel(Int(level)))
        case .failure:
            let ceiling = affinityCeilingFailures(
                rarity: encounter.rarity,
                currentLevel: Int(level),
                probability: encounter.affinityLastProbability
            )
            return TokenmonL10n.format("affinity.resonance", encounter.affinityPityCount, Int64(ceiling))
        case .maxLevel:
            return TokenmonL10n.string("affinity.max")
        }
    }

    static func affinitySuccessChanceLabel(for entry: DexEntrySummary) -> String? {
        guard entry.status == .captured else { return nil }
        let level = normalizedAffinityLevel(entry.affinityLevel, capturedCount: entry.capturedCount)
        guard level < 5 else {
            return TokenmonL10n.string("affinity.max")
        }
        let nextLevel = Int(level + 1)
        let probability = (try? SpeciesAffinityResolver().successProbability(rarity: entry.rarity, targetLevel: nextLevel)) ?? 0
        return percentLabel(probability)
    }

    static func affinityResonanceLabel(for entry: DexEntrySummary) -> String? {
        guard entry.status == .captured else { return nil }
        let level = normalizedAffinityLevel(entry.affinityLevel, capturedCount: entry.capturedCount)
        guard level < 5 else {
            return TokenmonL10n.string("affinity.max")
        }
        let ceiling = affinityCeilingFailures(
            rarity: entry.rarity,
            currentLevel: Int(level),
            probability: entry.affinityLastProbability
        )
        return TokenmonL10n.format("affinity.resonance", entry.affinityPityCount, Int64(ceiling))
    }

    static func hiddenHint(for entry: DexEntrySummary) -> String {
        TokenmonL10n.format("dex.hidden.hint", entry.rarity.displayName.lowercased(), entry.field.displayName)
    }

    static func showsStatTotal(for entry: DexEntrySummary) -> Bool {
        entry.status != .unknown
    }

    static func showsFullStatPlate(for entry: DexEntrySummary) -> Bool {
        showsFullStatPlate(status: entry.status)
    }

    static func showsFullStatPlate(status: DexEntryStatus) -> Bool {
        status == .captured
    }

    static func showsTraitTags(for entry: DexEntrySummary) -> Bool {
        entry.status == .captured && entry.stats.traits.isEmpty == false
    }

    static func statsPlateFootnote(for status: DexEntryStatus) -> String? {
        switch status {
        case .captured, .unknown:
            return nil
        case .seenUncaptured:
            return TokenmonL10n.string("dex.stats.footnote.capture_to_reveal")
        }
    }

    static func progressPanelTitle(for entry: DexEntrySummary) -> String {
        entry.status == .unknown
            ? TokenmonL10n.string("dex.progress_panel.reveal_conditions")
            : TokenmonL10n.string("dex.progress_panel.progress")
    }

    static func progressPanelFootnote(for entry: DexEntrySummary) -> String? {
        switch entry.status {
        case .captured:
            return nil
        case .seenUncaptured:
            return TokenmonL10n.string("dex.progress_panel.footnote.seen_uncaptured")
        case .unknown:
            return nil
        }
    }

    static func fieldNotesPlaceholder(for entry: DexEntrySummary) -> String? {
        switch entry.status {
        case .captured:
            return nil
        case .seenUncaptured:
            return TokenmonL10n.string("dex.field_notes.placeholder.seen_uncaptured")
        case .unknown:
            return TokenmonL10n.string("dex.field_notes.placeholder.unknown")
        }
    }

    static func metricRows(
        for entry: DexEntrySummary,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = TokenmonL10n.activeLocale,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> [TokenmonDexMetricValue] {
        switch entry.status {
        case .captured:
            return [
                TokenmonDexMetricValue(title: TokenmonL10n.string("dex.metric.captured"), value: countLabel(entry.capturedCount, singularKey: "dex.count.time.one", pluralKey: "dex.count.time.other")),
                TokenmonDexMetricValue(title: TokenmonL10n.string("dex.metric.seen"), value: countLabel(entry.seenCount, singularKey: "dex.count.encounter.one", pluralKey: "dex.count.encounter.other")),
                TokenmonDexMetricValue(title: TokenmonL10n.string("dex.metric.first_seen"), value: formattedTimestamp(entry.firstSeenAt, relativeTo: now, calendar: calendar, locale: locale, timeZone: timeZone) ?? TokenmonL10n.string("common.unknown")),
                TokenmonDexMetricValue(title: TokenmonL10n.string("dex.metric.last_encountered"), value: formattedTimestamp(entry.lastSeenAt, relativeTo: now, calendar: calendar, locale: locale, timeZone: timeZone) ?? TokenmonL10n.string("common.unknown")),
                TokenmonDexMetricValue(title: TokenmonL10n.string("dex.metric.first_captured"), value: formattedTimestamp(entry.firstCapturedAt, relativeTo: now, calendar: calendar, locale: locale, timeZone: timeZone) ?? TokenmonL10n.string("common.unknown")),
                TokenmonDexMetricValue(title: TokenmonL10n.string("dex.metric.last_captured"), value: formattedTimestamp(entry.lastCapturedAt, relativeTo: now, calendar: calendar, locale: locale, timeZone: timeZone) ?? TokenmonL10n.string("common.unknown")),
            ]
        case .seenUncaptured:
            return [
                TokenmonDexMetricValue(title: TokenmonL10n.string("dex.metric.seen"), value: countLabel(entry.seenCount, singularKey: "dex.count.encounter.one", pluralKey: "dex.count.encounter.other")),
                TokenmonDexMetricValue(title: TokenmonL10n.string("dex.metric.first_seen"), value: formattedTimestamp(entry.firstSeenAt, relativeTo: now, calendar: calendar, locale: locale, timeZone: timeZone) ?? TokenmonL10n.string("common.unknown")),
                TokenmonDexMetricValue(title: TokenmonL10n.string("dex.metric.last_encountered"), value: formattedTimestamp(entry.lastSeenAt, relativeTo: now, calendar: calendar, locale: locale, timeZone: timeZone) ?? TokenmonL10n.string("common.unknown")),
            ]
        case .unknown:
            return []
        }
    }

    static func raidAffinityBonusLabel(affinityLevel: Int64, bonus: Int) -> String {
        TokenmonL10n.format("raid.party.affinity_bonus", affinityLevelLabel(level: max(1, affinityLevel)), bonus)
    }

    private static func visibleSpeciesName(
        speciesName: String,
        capturedCount: Int64,
        style: TokenmonSpeciesNameStyle
    ) -> String {
        guard isNameUnlocked(capturedCount: capturedCount) else {
            switch style {
            case .compact:
                return "???"
            case .sentence:
                return TokenmonL10n.string("common.unknown_species")
            }
        }

        return speciesName
    }

    private static func revealStage(
        seenCount: Int64,
        capturedCount: Int64
    ) -> TokenmonSpeciesArtRevealStage {
        if capturedCount > 0 {
            return .revealed
        }
        if seenCount >= 4 {
            return .lightBlur
        }
        if seenCount >= 2 {
            return .mediumBlur
        }
        if seenCount >= 1 {
            return .heavyBlur
        }
        return .silhouette
    }

    static func formattedTimestamp(
        _ iso: String?,
        relativeTo now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = TokenmonL10n.activeLocale,
        timeZone: TimeZone = .autoupdatingCurrent
    ) -> String? {
        guard let iso, let date = parseDate(iso) else {
            return nil
        }

        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone

        if calendar.isDate(date, inSameDayAs: now) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return TokenmonL10n.format("date.relative.today", formatter.string(from: date))
        }

        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            return TokenmonL10n.format("date.relative.yesterday", formatter.string(from: date))
        }

        if calendar.isDate(date, equalTo: now, toGranularity: .year) {
            formatter.setLocalizedDateFormatFromTemplate("MMM d h:mm a")
            return formatter.string(from: date)
        }

        formatter.setLocalizedDateFormatFromTemplate("MMM d yyyy h:mm a")
        return formatter.string(from: date)
    }

    static func latestActivityDate(for entry: DexEntrySummary) -> Date? {
        let captureDate = parseDate(entry.lastCapturedAt)
        let seenDate = parseDate(entry.lastSeenAt)
        switch (captureDate, seenDate) {
        case let (lhs?, rhs?):
            return max(lhs, rhs)
        case let (lhs?, nil):
            return lhs
        case let (nil, rhs?):
            return rhs
        case (nil, nil):
            return nil
        }
    }

    private static func countLabel(_ count: Int64, singularKey: StaticString, pluralKey: StaticString) -> String {
        let key = count == 1 ? singularKey : pluralKey
        return TokenmonL10n.format(key, count)
    }

    private static func normalizedAffinityLevel(_ level: Int64, capturedCount: Int64) -> Int64 {
        guard capturedCount > 0 else { return 0 }
        return min(5, max(1, level))
    }

    private static func affinityCeilingFailures(
        rarity: RarityTier,
        currentLevel: Int,
        probability: Double?
    ) -> Int {
        let resolver = SpeciesAffinityResolver()
        if let probability,
           let ceiling = try? resolver.ceilingFailures(probability: probability) {
            return ceiling
        }
        let targetLevel = min(5, max(2, currentLevel + 1))
        if let computedProbability = try? resolver.successProbability(rarity: rarity, targetLevel: targetLevel),
           let ceiling = try? resolver.ceilingFailures(probability: computedProbability) {
            return ceiling
        }
        return 10
    }

    private static func percentLabel(_ probability: Double) -> String {
        let percent = Int((probability * 100).rounded())
        return "\(percent)%"
    }

    private static func statusRank(_ status: DexEntryStatus) -> Int {
        switch status {
        case .captured:
            return 0
        case .seenUncaptured:
            return 1
        case .unknown:
            return 2
        }
    }

    private static func activityRank(_ kind: TokenmonDexActivityKind) -> Int {
        switch kind {
        case .captured:
            return 0
        case .revealed:
            return 1
        }
    }

    private static func decodePayload<Payload: Decodable>(_ type: Payload.Type, from json: String) -> Payload? {
        try? JSONDecoder().decode(Payload.self, from: Data(json.utf8))
    }

    private static func parseDate(_ iso: String?) -> Date? {
        guard let iso else {
            return nil
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: iso) {
            return date
        }

        let standardFormatter = ISO8601DateFormatter()
        standardFormatter.formatOptions = [.withInternetDateTime]
        return standardFormatter.date(from: iso)
    }
}
