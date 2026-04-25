// Sources/TokenmonOtelProviders/GeminiSettingsMerger.swift
import Foundation

public enum GeminiSettingsMerger {
    public enum Result: Equatable {
        case merged(updatedJSON: String)
        case conflict(existingEndpoint: String)
        case alreadyConfigured
    }

    public static func merge(
        existingJSON: String,
        tokenmonHost: String,
        tokenmonPort: Int,
        allowOverride: Bool
    ) throws -> Result {
        // Gemini CLI's telemetry SDK parses the otlpEndpoint with `new URL(...)`,
        // which throws unless the value carries an explicit scheme. Without a
        // scheme it falls back to a Console exporter (writes to stderr) and
        // never opens a TCP connection to our gRPC receiver. Use http:// — the
        // OTLP gRPC client only reads `url.origin` (host:port) so the scheme
        // is cosmetic on the wire but mandatory for `new URL()` to succeed.
        let endpoint = "http://\(tokenmonHost):\(tokenmonPort)"
        var root: [String: Any] = [:]

        if existingJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            guard let data = existingJSON.data(using: .utf8),
                  let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw MergerError.invalidJSON
            }
            root = parsed
        }

        var telemetry = root["telemetry"] as? [String: Any] ?? [:]

        if let currentEndpoint = telemetry["otlpEndpoint"] as? String {
            if currentEndpoint == endpoint {
                let promptLoggingDisabled = (telemetry["logPrompts"] as? Bool) == false
                let telemetryEnabled = (telemetry["enabled"] as? Bool) == true
                let targetLocal = (telemetry["target"] as? String) == "local"
                if promptLoggingDisabled && telemetryEnabled && targetLocal {
                    return .alreadyConfigured
                }
            } else if allowOverride == false {
                return .conflict(existingEndpoint: currentEndpoint)
            }
        }

        telemetry["enabled"] = true
        telemetry["target"] = "local"
        telemetry["otlpEndpoint"] = endpoint
        telemetry["logPrompts"] = false
        root["telemetry"] = telemetry

        let mergedData = try JSONSerialization.data(
            withJSONObject: root,
            options: [.prettyPrinted, .sortedKeys]
        )
        guard let mergedString = String(data: mergedData, encoding: .utf8) else {
            throw MergerError.invalidJSON
        }
        return .merged(updatedJSON: mergedString)
    }

    public static func promptLoggingDisabled(existingJSON: String) -> Bool {
        guard existingJSON.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
              let data = existingJSON.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let telemetry = root["telemetry"] as? [String: Any],
              let logPrompts = telemetry["logPrompts"] as? Bool
        else {
            return false
        }
        return logPrompts == false
    }

    public enum MergerError: Swift.Error {
        case invalidJSON
    }
}
