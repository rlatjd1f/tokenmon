import Foundation
import TokenmonPersistence

enum TokenmonL10n {
    private static let tableName = "Localizable"
    private static let bundle = TokenmonAppResourceBundle.current
    private static let lock = NSLock()
    nonisolated(unsafe) private static var localeOverrideIdentifier: String?

    static func text(_ key: StaticString) -> LocalizedStringResource {
        let keyString = String(describing: key)
        let fallback = fallbackEnglish(forKey: keyString)
        return LocalizedStringResource(key, defaultValue: String.LocalizationValue(fallback), table: tableName, bundle: bundle)
    }

    static func string(_ key: StaticString) -> String {
        let keyString = String(describing: key)
        if let localized = activeLocalizedString(forKey: keyString) {
            return localized
        }
        return fallbackEnglish(forKey: keyString)
    }

    static func string(forKey key: String) -> String {
        if let localized = activeLocalizedString(forKey: key) {
            return localized
        }
        return fallbackEnglish(forKey: key)
    }

    static func format(_ key: StaticString, _ arguments: CVarArg...) -> String {
        let keyString = String(describing: key)
        let format = activeLocalizedString(forKey: keyString) ?? keyString
        if format == keyString {
            return fallbackFormattedString(forKey: keyString, arguments: arguments)
        }
        return String(format: format, locale: activeLocale, arguments: arguments)
    }

    static var activeLocale: Locale {
        if let localizationIdentifier = currentLocalizationIdentifier {
            return Locale(identifier: localizationIdentifier)
        }
        return .autoupdatingCurrent
    }

    static func setLocaleOverride(_ localeIdentifier: String?) {
        lock.lock()
        localeOverrideIdentifier = localeIdentifier
        lock.unlock()
    }

    static func localizedValue(forKey key: String, localeIdentifier: String) -> String {
        let localizedBundle = resolvedBundle(forPreferences: [localeIdentifier]) ?? bundle
        return localizedBundle.localizedString(forKey: key, value: key, table: tableName)
    }

    private static func localizedBundle(for localeIdentifier: String) -> Bundle? {
        guard let path = bundle.path(forResource: localeIdentifier, ofType: "lproj") else {
            return nil
        }
        return Bundle(path: path)
    }

    private static var currentLocaleOverrideIdentifier: String? {
        lock.lock()
        defer { lock.unlock() }
        return localeOverrideIdentifier
    }

    private static var currentLocalizationIdentifier: String? {
        if let overrideIdentifier = currentLocaleOverrideIdentifier {
            return resolvedLocalizationIdentifier(forPreferences: [overrideIdentifier])
        }

        let preferredLanguages = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String])
            ?? [Locale.autoupdatingCurrent.identifier]
        return resolvedLocalizationIdentifier(forPreferences: preferredLanguages)
    }

    private static func activeLocalizedString(forKey key: String) -> String? {
        guard let localizedBundle = resolvedBundle(forPreferences: effectiveLanguagePreferences)
        else {
            return nil
        }

        let localized = localizedBundle.localizedString(forKey: key, value: key, table: tableName)
        return localized == key ? nil : localized
    }

    private static var effectiveLanguagePreferences: [String] {
        if let overrideIdentifier = currentLocaleOverrideIdentifier {
            return [overrideIdentifier]
        }

        let preferredLanguages = (UserDefaults.standard.array(forKey: "AppleLanguages") as? [String]) ?? []
        if preferredLanguages.isEmpty == false {
            return preferredLanguages
        }
        return [Locale.autoupdatingCurrent.identifier]
    }

    private static func resolvedLocalizationIdentifier(forPreferences preferences: [String]) -> String? {
        let supportedLocalizations = bundle.localizations.filter { $0 != "Base" }
        let preferred = Bundle.preferredLocalizations(from: supportedLocalizations, forPreferences: preferences)
        return preferred.first
    }

    private static func resolvedBundle(forPreferences preferences: [String]) -> Bundle? {
        guard let localizationIdentifier = resolvedLocalizationIdentifier(forPreferences: preferences) else {
            return nil
        }
        return localizedBundle(for: localizationIdentifier)
    }

    static func diagnosticSnapshot() -> [String: String] {
        let preferences = effectiveLanguagePreferences
        let resolvedLocalization = resolvedLocalizationIdentifier(forPreferences: preferences) ?? "none"
        return [
            "locale_override_identifier": currentLocaleOverrideIdentifier ?? "none",
            "effective_language_preferences": preferences.joined(separator: ","),
            "bundle_localizations": bundle.localizations.joined(separator: ","),
            "resolved_localization_identifier": resolvedLocalization,
            "active_locale_identifier": activeLocale.identifier,
            "sample_settings_title": string("settings.pane.general.title"),
            "sample_system_option": AppLanguagePreference.system.displayName,
        ]
    }

    private static func fallbackFormattedString(forKey key: String, arguments: [CVarArg]) -> String {
        guard arguments.isEmpty == false else {
            return fallbackEnglish(forKey: key)
        }

        let suffix = arguments.map { String(describing: $0) }.joined(separator: " ")
        return "\(fallbackEnglish(forKey: key)) \(suffix)"
    }

    private static func fallbackEnglish(forKey key: String) -> String {
        let ignorableSuffixes = Set([
            "title",
            "subtitle",
            "description",
            "note",
            "helper",
            "label",
            "prompt",
            "action",
            "button",
            "empty",
            "message",
        ])

        var parts = key.split(separator: ".").map(String.init)
        while let first = parts.first,
              [
                  "common", "menu", "now", "dex", "settings", "provider", "providers",
                  "tokens", "stats", "trend", "progress", "developer", "popover",
                  "capture", "date", "time", "window", "field", "rarity", "outcome",
                  "headline", "detail", "section", "pane", "feedback", "status",
                  "metric", "filter", "sort", "overview",
              ].contains(first)
        {
            parts.removeFirst()
        }

        while let last = parts.last,
              ignorableSuffixes.contains(last) || Int(last) != nil
        {
            parts.removeLast()
        }

        let fallback = parts.isEmpty ? key : parts.joined(separator: " ")
        return fallback
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}
