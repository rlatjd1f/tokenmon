import Foundation
import TokenmonDomain

public struct ClaudeStatusLineModel: Decodable, Sendable {
    public let id: String?
    public let displayName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }

    public init(id: String?, displayName: String?) {
        self.id = id
        self.displayName = displayName
    }

    // Claude Code emits `model` either as an object (`{id, display_name}`,
    // e.g. the statusline payload) or as a bare slug string (e.g. the
    // SessionStart hook payload, which sends `"model": "claude-opus-4-7[1m]"`).
    // Decode both shapes so neither call site rejects the payload.
    public init(from decoder: Decoder) throws {
        if let single = try? decoder.singleValueContainer(),
           let slug = try? single.decode(String.self) {
            self.id = slug
            self.displayName = nil
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try keyed.decodeIfPresent(String.self, forKey: .id)
        self.displayName = try keyed.decodeIfPresent(String.self, forKey: .displayName)
    }
}

public struct ClaudeStatusLineWorkspace: Decodable, Sendable {
    public let currentDir: String?

    enum CodingKeys: String, CodingKey {
        case currentDir = "current_dir"
    }
}

public struct ClaudeStatusLineCost: Decodable, Sendable {
    public let totalCostUSD: Double?

    enum CodingKeys: String, CodingKey {
        case totalCostUSD = "total_cost_usd"
    }
}

public struct ClaudeStatusLineCurrentUsage: Decodable, Sendable {
    public let inputTokens: Int64?
    public let outputTokens: Int64?
    public let cacheCreationInputTokens: Int64?
    public let cacheReadInputTokens: Int64?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
    }
}

public struct ClaudeStatusLineContextWindow: Decodable, Sendable {
    public let totalInputTokens: Int64
    public let totalOutputTokens: Int64
    public let currentUsage: ClaudeStatusLineCurrentUsage?

    enum CodingKeys: String, CodingKey {
        case totalInputTokens = "total_input_tokens"
        case totalOutputTokens = "total_output_tokens"
        case currentUsage = "current_usage"
    }
}

public struct ClaudeStatusLinePayload: Decodable, Sendable {
    public let cwd: String?
    public let sessionID: String
    public let transcriptPath: String?
    public let model: ClaudeStatusLineModel?
    public let workspace: ClaudeStatusLineWorkspace?
    public let cost: ClaudeStatusLineCost?
    public let contextWindow: ClaudeStatusLineContextWindow

    enum CodingKeys: String, CodingKey {
        case cwd
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
        case model
        case workspace
        case cost
        case contextWindow = "context_window"
    }
}

public struct ClaudeStatusLineAdapterConfig: Sendable {
    public let nowProvider: @Sendable () -> String

    public init(
        nowProvider: @escaping @Sendable () -> String = {
            ISO8601DateFormatter().string(from: Date())
        }
    ) {
        self.nowProvider = nowProvider
    }
}

public struct ClaudeStatusLineImportResult: Sendable {
    public let outputPath: String?
    public let sessionID: String
    public let transcriptPath: String?
    public let normalizedTotalTokens: Int64
    public let providerEventFingerprint: String
    public let renderedStatusLine: String
}

public enum ClaudeStatusLineAdapterError: Error, LocalizedError {
    case invalidTotalTokens
    case invalidCurrentUsageTokens

    public var errorDescription: String? {
        switch self {
        case .invalidTotalTokens:
            return "claude statusline payload has negative cumulative totals"
        case .invalidCurrentUsageTokens:
            return "claude statusline payload has negative current usage totals"
        }
    }
}

public enum ClaudeStatusLineAdapter {
    public static func importPayload(
        json: String,
        outputPath: String? = nil,
        config: ClaudeStatusLineAdapterConfig = ClaudeStatusLineAdapterConfig()
    ) throws -> ClaudeStatusLineImportResult {
        let decoder = JSONDecoder()
        let payload = try decoder.decode(ClaudeStatusLinePayload.self, from: Data(json.utf8))

        guard payload.contextWindow.totalInputTokens >= 0,
              payload.contextWindow.totalOutputTokens >= 0 else {
            throw ClaudeStatusLineAdapterError.invalidTotalTokens
        }

        let currentInputTokens = payload.contextWindow.currentUsage?.inputTokens
        let currentOutputTokens = payload.contextWindow.currentUsage?.outputTokens
        let currentCacheCreation = payload.contextWindow.currentUsage?.cacheCreationInputTokens
        let currentCacheRead = payload.contextWindow.currentUsage?.cacheReadInputTokens

        if let currentInputTokens, currentInputTokens < 0 {
            throw ClaudeStatusLineAdapterError.invalidCurrentUsageTokens
        }
        if let currentOutputTokens, currentOutputTokens < 0 {
            throw ClaudeStatusLineAdapterError.invalidCurrentUsageTokens
        }
        if let currentCacheCreation, currentCacheCreation < 0 {
            throw ClaudeStatusLineAdapterError.invalidCurrentUsageTokens
        }
        if let currentCacheRead, currentCacheRead < 0 {
            throw ClaudeStatusLineAdapterError.invalidCurrentUsageTokens
        }

        let workspaceDir = payload.workspace?.currentDir ?? payload.cwd
        let modelSlug = payload.model?.id ?? payload.model?.displayName
        let accounting = ProviderTokenAccounting.claudeStatusLine(
            totalInputTokens: payload.contextWindow.totalInputTokens,
            totalOutputTokens: payload.contextWindow.totalOutputTokens,
            currentInputTokens: currentInputTokens,
            currentOutputTokens: currentOutputTokens
        )
        let providerEventFingerprint = "claude:\(payload.sessionID):\(payload.contextWindow.totalInputTokens):\(payload.contextWindow.totalOutputTokens)"
        let renderedStatusLine = renderStatusLine(payload: payload, normalizedTotalTokens: accounting.normalizedTotalTokens)

        let providerEvent = ProviderUsageSampleEvent(
            eventType: "provider_usage_sample",
            provider: .claude,
            sourceMode: "claude_statusline_live",
            providerSessionID: payload.sessionID,
            observedAt: config.nowProvider(),
            workspaceDir: workspaceDir,
            modelSlug: modelSlug,
            transcriptPath: payload.transcriptPath,
            totalInputTokens: accounting.totalInputTokens,
            totalOutputTokens: accounting.totalOutputTokens,
            totalCachedInputTokens: accounting.totalCachedInputTokens,
            normalizedTotalTokens: accounting.normalizedTotalTokens,
            providerEventFingerprint: providerEventFingerprint,
            rawReference: ProviderRawReference(kind: "statusline", offset: nil, eventName: nil),
            currentInputTokens: accounting.currentInputTokens,
            currentOutputTokens: accounting.currentOutputTokens
        )

        try append(event: providerEvent, to: outputPath)

        return ClaudeStatusLineImportResult(
            outputPath: outputPath,
            sessionID: payload.sessionID,
            transcriptPath: payload.transcriptPath,
            normalizedTotalTokens: accounting.normalizedTotalTokens,
            providerEventFingerprint: providerEventFingerprint,
            renderedStatusLine: renderedStatusLine
        )
    }

    private static func append(event: ProviderUsageSampleEvent, to outputPath: String?) throws {
        guard let outputPath else {
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let rendered = String(decoding: try encoder.encode(event), as: UTF8.self) + "\n"
        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: outputPath) {
            let handle = try FileHandle(forWritingTo: outputURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(rendered.utf8))
        } else {
            try rendered.write(to: outputURL, atomically: true, encoding: .utf8)
        }
    }

    private static func renderStatusLine(
        payload: ClaudeStatusLinePayload,
        normalizedTotalTokens: Int64
    ) -> String {
        let modelName = payload.model?.displayName ?? payload.model?.id ?? "Claude"
        let costText = String(format: "$%.2f", payload.cost?.totalCostUSD ?? 0)
        return "[\(modelName)] \(costText) | \(normalizedTotalTokens) tok"
    }
}
