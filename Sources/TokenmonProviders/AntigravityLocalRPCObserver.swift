import CryptoKit
import Foundation
import TokenmonDomain

public struct AntigravityProcessCandidate: Equatable, Sendable {
    public let pid: Int32
    public let ppid: Int32
    public let arguments: String
    public let csrfToken: String
    public let extensionServerPort: Int?

    public init(
        pid: Int32,
        ppid: Int32,
        arguments: String,
        csrfToken: String,
        extensionServerPort: Int?
    ) {
        self.pid = pid
        self.ppid = ppid
        self.arguments = arguments
        self.csrfToken = csrfToken
        self.extensionServerPort = extensionServerPort
    }
}

public struct AntigravityRPCConnection: Equatable, Sendable {
    public let pid: Int32
    public let port: Int
    public let csrfToken: String

    public init(pid: Int32, port: Int, csrfToken: String) {
        self.pid = pid
        self.port = port
        self.csrfToken = csrfToken
    }
}

public enum AntigravityProcessLocator {
    public static func parseProcessCandidates(psOutput: String) -> [AntigravityProcessCandidate] {
        var candidatesByPID: [Int32: AntigravityProcessCandidate] = [:]

        for line in psOutput.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count == 3,
                  let pid = Int32(parts[0]),
                  let ppid = Int32(parts[1])
            else {
                continue
            }

            let arguments = String(parts[2])
            guard isAntigravityLanguageServer(arguments) else {
                continue
            }
            guard let csrfToken = firstCapture(
                pattern: #"--csrf_token(?:=|\s+)([^\s]+)"#,
                in: arguments
            ) else {
                continue
            }

            let port = firstCapture(
                pattern: #"--extension_server_port(?:=|\s+)(\d+)"#,
                in: arguments
            ).flatMap(Int.init)

            candidatesByPID[pid] = AntigravityProcessCandidate(
                pid: pid,
                ppid: ppid,
                arguments: arguments,
                csrfToken: csrfToken,
                extensionServerPort: port
            )
        }

        return candidatesByPID.values.sorted { $0.pid > $1.pid }
    }

    public static func parseListeningPorts(lsofOutput: String) -> [Int] {
        var ports = Set<Int>()
        let patterns = [
            #"127\.0\.0\.1:(\d+).*(?:LISTEN|\(LISTEN\))"#,
            #"localhost:(\d+).*(?:LISTEN|\(LISTEN\))"#,
            #"\*:(\d+).*(?:LISTEN|\(LISTEN\))"#,
            #"LISTEN\s+\d+\s+\d+\s+(?:127\.0\.0\.1|\*|::1|::):(\d+)"#,
        ]

        for line in lsofOutput.split(whereSeparator: \.isNewline) {
            let text = String(line)
            for pattern in patterns {
                if let match = firstCapture(pattern: pattern, in: text),
                   let port = Int(match),
                   port > 0 {
                    ports.insert(port)
                }
            }
        }

        return ports.sorted()
    }

    public static func detectCandidates() -> [AntigravityProcessCandidate] {
        parseProcessCandidates(psOutput: runCommand(
            executable: "/bin/ps",
            arguments: ["-ww", "-eo", "pid,ppid,args"]
        ))
    }

    public static func listeningPorts(for pid: Int32) -> [Int] {
        var ports = parseListeningPorts(lsofOutput: runCommand(
            executable: "/usr/sbin/lsof",
            arguments: ["-Pan", "-p", "\(pid)", "-iTCP", "-sTCP:LISTEN"]
        ))
        if ports.isEmpty {
            ports = parseListeningPorts(lsofOutput: runCommand(
                executable: "/usr/sbin/lsof",
                arguments: ["-Pan", "-p", "\(pid)", "-i"]
            ))
        }
        return ports
    }

    private static func isAntigravityLanguageServer(_ arguments: String) -> Bool {
        let lowercased = arguments.lowercased()
        guard lowercased.contains("language_server") else {
            return false
        }
        return lowercased.contains("antigravity")
            || lowercased.contains("--app_data_dir antigravity")
            || lowercased.contains("--app_data_dir=antigravity")
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange])
    }

    static func runCommand(executable: String, arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                return ""
            }
            return String(decoding: output, as: UTF8.self)
        } catch {
            return ""
        }
    }
}

public struct AntigravityTokenTotals: Equatable, Sendable {
    public let inputTokens: Int64
    public let outputTokens: Int64
    public let cachedInputTokens: Int64

    public init(inputTokens: Int64, outputTokens: Int64, cachedInputTokens: Int64) {
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
        self.cachedInputTokens = cachedInputTokens
    }

    public var normalizedTotalTokens: Int64 {
        inputTokens + outputTokens + cachedInputTokens
    }

    func subtracting(_ baseline: AntigravityTokenTotals) -> AntigravityTokenTotals {
        AntigravityTokenTotals(
            inputTokens: max(0, inputTokens - baseline.inputTokens),
            outputTokens: max(0, outputTokens - baseline.outputTokens),
            cachedInputTokens: max(0, cachedInputTokens - baseline.cachedInputTokens)
        )
    }
}

public struct AntigravityUsageSnapshot: Equatable, Sendable {
    public let sessionID: String
    public let observedAt: String
    public let modelSlug: String?
    public let metadataIndex: Int
    public let retryIndex: Int
    public let responseID: String?
    public let currentInputTokens: Int64
    public let currentOutputTokens: Int64
    public let totals: AntigravityTokenTotals
    public let providerEventFingerprint: String

    public var rawReferenceOffset: String {
        responseID ?? "\(metadataIndex):\(retryIndex)"
    }

    public func providerEvent(
        sourceMode: String,
        sessionOriginHint: ProviderSessionOriginHint,
        baseline: AntigravityTokenTotals = AntigravityTokenTotals(inputTokens: 0, outputTokens: 0, cachedInputTokens: 0)
    ) -> ProviderUsageSampleEvent? {
        let adjustedTotals = totals.subtracting(baseline)
        guard adjustedTotals.normalizedTotalTokens > 0 else {
            return nil
        }

        let accounting = ProviderTokenAccounting.antigravityRPCMetadata(
            totalInputTokens: adjustedTotals.inputTokens,
            totalOutputTokens: adjustedTotals.outputTokens,
            totalCachedInputTokens: adjustedTotals.cachedInputTokens,
            currentInputTokens: currentInputTokens,
            currentOutputTokens: currentOutputTokens
        )

        return ProviderUsageSampleEvent(
            eventType: "provider_usage_sample",
            provider: .antigravity,
            sourceMode: sourceMode,
            providerSessionID: sessionID,
            observedAt: observedAt,
            workspaceDir: nil,
            modelSlug: modelSlug,
            transcriptPath: nil,
            totalInputTokens: accounting.totalInputTokens,
            totalOutputTokens: accounting.totalOutputTokens,
            totalCachedInputTokens: accounting.totalCachedInputTokens,
            normalizedTotalTokens: accounting.normalizedTotalTokens,
            providerEventFingerprint: providerEventFingerprint,
            rawReference: ProviderRawReference(
                kind: "antigravity-rpc",
                offset: rawReferenceOffset,
                eventName: "GetCascadeTrajectoryGeneratorMetadata"
            ),
            currentInputTokens: accounting.currentInputTokens,
            currentOutputTokens: accounting.currentOutputTokens,
            sessionOriginHint: sessionOriginHint
        )
    }
}

public enum AntigravityRPCMetadataAdapter {
    public static func usageSnapshots(
        fromMetadataResponseData data: Data,
        sessionID: String,
        nowProvider: @Sendable () -> String = { ISO8601DateFormatter().string(from: Date()) }
    ) throws -> [AntigravityUsageSnapshot] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            return []
        }
        let metadataRows = arrayValue(dictionary["generatorMetadata"])
            ?? arrayValue(dictionary["metadata"])
            ?? []
        return usageSnapshots(
            fromMetadataRows: metadataRows,
            sessionID: sessionID,
            nowProvider: nowProvider
        )
    }

    public static func usageEvents(
        fromMetadataRows metadataRows: [Any],
        sessionID: String,
        sourceMode: String = "antigravity_rpc_metadata_live",
        sessionOriginHint: ProviderSessionOriginHint = .startedDuringLiveRuntime,
        nowProvider: @Sendable () -> String = { ISO8601DateFormatter().string(from: Date()) }
    ) -> [ProviderUsageSampleEvent] {
        usageSnapshots(
            fromMetadataRows: metadataRows,
            sessionID: sessionID,
            nowProvider: nowProvider
        ).compactMap {
            $0.providerEvent(sourceMode: sourceMode, sessionOriginHint: sessionOriginHint)
        }
    }

    public static func usageSnapshots(
        fromMetadataRows metadataRows: [Any],
        sessionID: String,
        nowProvider: @Sendable () -> String = { ISO8601DateFormatter().string(from: Date()) }
    ) -> [AntigravityUsageSnapshot] {
        var snapshots: [AntigravityUsageSnapshot] = []
        var seenFingerprints = Set<String>()
        var runningTotals = AntigravityTokenTotals(inputTokens: 0, outputTokens: 0, cachedInputTokens: 0)

        for (metadataIndex, rawRow) in metadataRows.enumerated() {
            guard let row = dictionaryValue(rawRow) else {
                continue
            }

            let retryRows: [(Int, [String: Any])] = {
                if let retryInfos = arrayValue(row["retryInfos"]) ?? arrayValue(row["retryInfo"]) {
                    return retryInfos.enumerated().compactMap { index, rawRetry in
                        dictionaryValue(rawRetry).map { (index, $0) }
                    }
                }
                return [(0, row)]
            }()

            for (retryIndex, retry) in retryRows {
                guard let extracted = extractUsage(row: row, retry: retry) else {
                    continue
                }

                let responseID = firstString(
                    retry["responseId"],
                    retry["responseID"],
                    retry["id"],
                    row["responseId"],
                    row["responseID"],
                    row["id"],
                    extracted.usage["responseId"],
                    extracted.usage["responseID"]
                )
                let modelSlug = preferredModel(row: row, retry: retry, usage: extracted.usage)
                let observedAt = isoTimestamp(
                    firstValue(
                        retry["timestamp"],
                        retry["createdAt"],
                        retry["lastModifiedTime"],
                        row["timestamp"],
                        row["createdAt"],
                        row["lastModifiedTime"]
                    )
                ) ?? nowProvider()

                let fingerprint = fingerprint(
                    sessionID: sessionID,
                    responseID: responseID,
                    modelSlug: modelSlug,
                    observedAt: observedAt,
                    inputTokens: extracted.inputTokens,
                    outputTokens: extracted.outputTokens,
                    cachedInputTokens: extracted.cachedInputTokens,
                    metadataIndex: metadataIndex,
                    retryIndex: retryIndex
                )
                guard seenFingerprints.insert(fingerprint).inserted else {
                    continue
                }

                runningTotals = AntigravityTokenTotals(
                    inputTokens: runningTotals.inputTokens + extracted.inputTokens,
                    outputTokens: runningTotals.outputTokens + extracted.outputTokens,
                    cachedInputTokens: runningTotals.cachedInputTokens + extracted.cachedInputTokens
                )

                snapshots.append(AntigravityUsageSnapshot(
                    sessionID: sessionID,
                    observedAt: observedAt,
                    modelSlug: modelSlug,
                    metadataIndex: metadataIndex,
                    retryIndex: retryIndex,
                    responseID: responseID,
                    currentInputTokens: extracted.inputTokens,
                    currentOutputTokens: extracted.outputTokens,
                    totals: runningTotals,
                    providerEventFingerprint: fingerprint
                ))
            }
        }

        return snapshots
    }

    private struct ExtractedUsage {
        let usage: [String: Any]
        let inputTokens: Int64
        let outputTokens: Int64
        let cachedInputTokens: Int64
    }

    private static func extractUsage(row: [String: Any], retry: [String: Any]) -> ExtractedUsage? {
        guard let usage = usageDictionary(row: row, retry: retry) else {
            return nil
        }

        let input = tokenValue(in: usage, keys: ["inputTokens", "input_tokens", "promptTokens", "prompt_tokens"])
        let output = tokenValue(in: usage, keys: [
            "outputTokens",
            "output_tokens",
            "responseOutputTokens",
            "response_output_tokens",
            "completionTokens",
            "completion_tokens",
        ])
        let thinking = tokenValue(in: usage, keys: ["thinkingOutputTokens", "thinking_output_tokens", "reasoningTokens", "reasoning_tokens"])
        let cacheRead = tokenValue(in: usage, keys: ["cacheReadTokens", "cache_read_tokens", "cachedInputTokens", "cached_input_tokens"])

        guard case .valid(let inputTokens) = input,
              case .valid(let outputTokens) = output,
              case .valid(let thinkingTokens) = thinking,
              case .valid(let cachedInputTokens) = cacheRead
        else {
            return nil
        }

        let foldedOutputTokens = outputTokens + thinkingTokens
        guard inputTokens >= 0,
              foldedOutputTokens >= 0,
              cachedInputTokens >= 0,
              inputTokens + foldedOutputTokens + cachedInputTokens > 0
        else {
            return nil
        }

        return ExtractedUsage(
            usage: usage,
            inputTokens: inputTokens,
            outputTokens: foldedOutputTokens,
            cachedInputTokens: cachedInputTokens
        )
    }

    private enum TokenValue {
        case valid(Int64)
        case invalid
    }

    private static func tokenValue(in dictionary: [String: Any], keys: [String]) -> TokenValue {
        for key in keys {
            guard let rawValue = dictionary[key] else {
                continue
            }
            if let value = int64Value(rawValue) {
                return .valid(value)
            }
            return .invalid
        }
        return .valid(0)
    }

    private static func usageDictionary(row: [String: Any], retry: [String: Any]) -> [String: Any]? {
        if let usage = dictionaryValue(retry["usage"]) {
            return usage
        }
        if let chatModel = dictionaryValue(retry["chatModel"]),
           let usage = dictionaryValue(chatModel["usage"]) {
            return usage
        }
        if let usage = dictionaryValue(row["usage"]) {
            return usage
        }
        if let chatModel = dictionaryValue(row["chatModel"]),
           let usage = dictionaryValue(chatModel["usage"]) {
            return usage
        }
        return nil
    }

    private static func preferredModel(row: [String: Any], retry: [String: Any], usage: [String: Any]) -> String? {
        let retryChatModel = dictionaryValue(retry["chatModel"])
        let rowChatModel = dictionaryValue(row["chatModel"])
        return firstString(
            retry["responseModel"],
            retry["model"],
            retry["modelName"],
            retry["modelId"],
            retryChatModel?["responseModel"],
            retryChatModel?["model"],
            retryChatModel?["modelName"],
            retryChatModel?["modelId"],
            row["responseModel"],
            row["model"],
            row["modelName"],
            row["modelId"],
            rowChatModel?["responseModel"],
            rowChatModel?["model"],
            rowChatModel?["modelName"],
            rowChatModel?["modelId"],
            usage["responseModel"],
            usage["model"],
            usage["modelName"],
            usage["modelId"]
        )
    }

    private static func fingerprint(
        sessionID: String,
        responseID: String?,
        modelSlug: String?,
        observedAt: String,
        inputTokens: Int64,
        outputTokens: Int64,
        cachedInputTokens: Int64,
        metadataIndex: Int,
        retryIndex: Int
    ) -> String {
        if let responseID, responseID.isEmpty == false {
            return "antigravity-rpc:\(sessionID):\(responseID)"
        }

        let raw = [
            sessionID,
            modelSlug ?? "",
            observedAt,
            "\(inputTokens)",
            "\(outputTokens)",
            "\(cachedInputTokens)",
            "\(metadataIndex)",
            "\(retryIndex)",
        ].joined(separator: "\u{0}")
        let digest = SHA256.hash(data: Data(raw.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return "antigravity-rpc:\(digest)"
    }

    private static func firstValue(_ values: Any?...) -> Any? {
        for value in values {
            if value != nil {
                return value
            }
        }
        return nil
    }

    private static func firstString(_ values: Any?...) -> String? {
        for value in values {
            if let string = value as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func isoTimestamp(_ value: Any?) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else {
                return nil
            }
            if ISO8601DateFormatter().date(from: trimmed) != nil {
                return trimmed
            }
            if let milliseconds = Double(trimmed), milliseconds.isFinite {
                return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: milliseconds / 1000))
            }
        }
        if let number = value as? NSNumber {
            return ISO8601DateFormatter().string(from: Date(timeIntervalSince1970: number.doubleValue / 1000))
        }
        return nil
    }

    private static func arrayValue(_ value: Any?) -> [Any]? {
        if let array = value as? [Any] {
            return array
        }
        if let dictionary = value as? [String: Any] {
            return dictionary
                .sorted { $0.key < $1.key }
                .map(\.value)
        }
        return nil
    }

    private static func dictionaryValue(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let int = value as? Int {
            return Int64(int)
        }
        if let int64 = value as? Int64 {
            return int64
        }
        if let string = value as? String,
           let parsed = Int64(string.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return parsed
        }
        return nil
    }
}

public struct AntigravityTrajectorySummary: Equatable, Sendable {
    public let sessionID: String
    public let lastModifiedMilliseconds: Int64?
    public let stepCount: Int64?

    public init(sessionID: String, lastModifiedMilliseconds: Int64?, stepCount: Int64?) {
        self.sessionID = sessionID
        self.lastModifiedMilliseconds = lastModifiedMilliseconds
        self.stepCount = stepCount
    }
}

public enum AntigravityRPCResponseAdapter {
    public static func trajectorySummaries(from data: Data) throws -> [AntigravityTrajectorySummary] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            return []
        }

        let rawItems = arrayValue(dictionary["trajectorySummaries"])
            ?? arrayValue(dictionary["cascadeTrajectories"])
            ?? []

        return rawItems.compactMap { rawItem -> AntigravityTrajectorySummary? in
            guard let item = dictionaryValue(rawItem),
                  let sessionID = firstString(
                    item["cascadeId"],
                    item["trajectoryId"],
                    item["id"],
                    item["sessionId"]
                  )
            else {
                return nil
            }
            return AntigravityTrajectorySummary(
                sessionID: sessionID,
                lastModifiedMilliseconds: milliseconds(item["lastModifiedTime"])
                    ?? milliseconds(item["lastModified"])
                    ?? milliseconds(item["updatedAt"])
                    ?? milliseconds(item["modifiedAt"]),
                stepCount: int64Value(item["stepCount"])
                    ?? int64Value(item["numSteps"])
                    ?? int64Value(item["totalSteps"])
            )
        }
    }

    private static func arrayValue(_ value: Any?) -> [Any]? {
        if let array = value as? [Any] {
            return array
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.map { key, value in
                if var record = value as? [String: Any] {
                    record["cascadeId"] = record["cascadeId"] ?? key
                    return record
                }
                return value
            }
        }
        return nil
    }

    private static func dictionaryValue(_ value: Any?) -> [String: Any]? {
        value as? [String: Any]
    }

    private static func firstString(_ values: Any?...) -> String? {
        for value in values {
            if let string = value as? String {
                let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty == false {
                    return trimmed
                }
            }
        }
        return nil
    }

    private static func milliseconds(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let string = value as? String {
            if let parsed = Int64(string) {
                return parsed
            }
            if let date = ISO8601DateFormatter().date(from: string) {
                return Int64(date.timeIntervalSince1970 * 1000)
            }
        }
        return nil
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        if let number = value as? NSNumber {
            return number.int64Value
        }
        if let string = value as? String, let parsed = Int64(string) {
            return parsed
        }
        return nil
    }
}

public struct AntigravityLocalRPCHealth: Equatable, Sendable {
    public let sourceMode: String
    public let healthState: String
    public let message: String
    public let lastSuccessAt: String?
    public let lastErrorAt: String?
    public let lastErrorCode: String?
    public let lastErrorSummary: String?

    public init(
        sourceMode: String,
        healthState: String,
        message: String,
        lastSuccessAt: String?,
        lastErrorAt: String?,
        lastErrorCode: String?,
        lastErrorSummary: String?
    ) {
        self.sourceMode = sourceMode
        self.healthState = healthState
        self.message = message
        self.lastSuccessAt = lastSuccessAt
        self.lastErrorAt = lastErrorAt
        self.lastErrorCode = lastErrorCode
        self.lastErrorSummary = lastErrorSummary
    }
}

public struct AntigravityLocalRPCObserverConfig: Sendable {
    public let outputPath: String
    public let pollIntervalNanoseconds: UInt64
    public let requestTimeoutSeconds: TimeInterval
    public let sourceMode: String
    public let nowProvider: @Sendable () -> String
    public let onHealthChange: (@Sendable (AntigravityLocalRPCHealth) -> Void)?
    public let onActivityPulse: (@Sendable () -> Void)?

    public init(
        outputPath: String,
        pollIntervalNanoseconds: UInt64 = 10_000_000_000,
        requestTimeoutSeconds: TimeInterval = 3,
        sourceMode: String = "antigravity_rpc_metadata_live",
        nowProvider: @escaping @Sendable () -> String = {
            ISO8601DateFormatter().string(from: Date())
        },
        onHealthChange: (@Sendable (AntigravityLocalRPCHealth) -> Void)? = nil,
        onActivityPulse: (@Sendable () -> Void)? = nil
    ) {
        self.outputPath = outputPath
        self.pollIntervalNanoseconds = pollIntervalNanoseconds
        self.requestTimeoutSeconds = requestTimeoutSeconds
        self.sourceMode = sourceMode
        self.nowProvider = nowProvider
        self.onHealthChange = onHealthChange
        self.onActivityPulse = onActivityPulse
    }
}

public final class AntigravityLocalRPCObserver: @unchecked Sendable {
    private let config: AntigravityLocalRPCObserverConfig
    private let stateQueue = DispatchQueue(label: "TokenmonProviders.AntigravityLocalRPCObserver")
    private var pollTask: Task<Void, Never>?
    private var baselineEstablished = false
    private var seenFingerprints = Set<String>()
    private var sessionBaselines: [String: AntigravityTokenTotals] = [:]

    public init(config: AntigravityLocalRPCObserverConfig) {
        self.config = config
    }

    deinit {
        stop()
    }

    public func startAsync() {
        stateQueue.sync {
            guard pollTask == nil else {
                return
            }
            pollTask = Task.detached(priority: .utility) { [weak self] in
                await self?.runLoop()
            }
        }
    }

    public func stop() {
        let task = stateQueue.sync { () -> Task<Void, Never>? in
            let task = pollTask
            pollTask = nil
            return task
        }
        task?.cancel()
    }

    private func runLoop() async {
        let client = AntigravityRPCClient(timeout: config.requestTimeoutSeconds)
        while Task.isCancelled == false {
            await pollOnce(client: client)
            do {
                try await Task.sleep(nanoseconds: config.pollIntervalNanoseconds)
            } catch {
                return
            }
        }
    }

    private func pollOnce(client: AntigravityRPCClient) async {
        let now = config.nowProvider()
        do {
            let connections = await client.detectConnections()
            guard connections.isEmpty == false else {
                if baselineEstablished == false {
                    baselineEstablished = true
                }
                emitHealth(AntigravityLocalRPCHealth(
                    sourceMode: config.sourceMode,
                    healthState: "missing_configuration",
                    message: "Google Antigravity is not running; Tokenmon observes it only while the local app is open",
                    lastSuccessAt: nil,
                    lastErrorAt: nil,
                    lastErrorCode: "antigravity_not_running",
                    lastErrorSummary: nil
                ))
                return
            }

            var snapshotsBySession: [String: [AntigravityUsageSnapshot]] = [:]
            var seenSessions = Set<String>()
            for connection in connections {
                let summaries = try await client.listTrajectories(connection: connection)
                for summary in summaries where seenSessions.insert(summary.sessionID).inserted {
                    let metadataData = try await client.getTrajectoryMetadata(sessionID: summary.sessionID, connection: connection)
                    let snapshots = try AntigravityRPCMetadataAdapter.usageSnapshots(
                        fromMetadataResponseData: metadataData,
                        sessionID: summary.sessionID,
                        nowProvider: config.nowProvider
                    )
                    snapshotsBySession[summary.sessionID] = snapshots
                }
            }

            if baselineEstablished == false {
                for (sessionID, snapshots) in snapshotsBySession {
                    seenFingerprints.formUnion(snapshots.map(\.providerEventFingerprint))
                    if let last = snapshots.last {
                        sessionBaselines[sessionID] = last.totals
                    } else {
                        sessionBaselines[sessionID] = AntigravityTokenTotals(inputTokens: 0, outputTokens: 0, cachedInputTokens: 0)
                    }
                }
                baselineEstablished = true
                emitHealth(AntigravityLocalRPCHealth(
                    sourceMode: config.sourceMode,
                    healthState: "connected",
                    message: "Google Antigravity local RPC connected; existing RPC metadata is baseline-only",
                    lastSuccessAt: now,
                    lastErrorAt: nil,
                    lastErrorCode: nil,
                    lastErrorSummary: nil
                ))
                return
            }

            var newEvents: [ProviderUsageSampleEvent] = []
            for (sessionID, snapshots) in snapshotsBySession {
                let baseline = sessionBaselines[sessionID] ?? AntigravityTokenTotals(
                    inputTokens: 0,
                    outputTokens: 0,
                    cachedInputTokens: 0
                )

                for snapshot in snapshots where seenFingerprints.insert(snapshot.providerEventFingerprint).inserted {
                    if let event = snapshot.providerEvent(
                        sourceMode: config.sourceMode,
                        sessionOriginHint: .startedDuringLiveRuntime,
                        baseline: baseline
                    ) {
                        newEvents.append(event)
                    }
                }
            }

            if newEvents.isEmpty == false {
                try append(events: newEvents)
                config.onActivityPulse?()
            }

            emitHealth(AntigravityLocalRPCHealth(
                sourceMode: config.sourceMode,
                healthState: newEvents.isEmpty ? "connected" : "active",
                message: newEvents.isEmpty
                    ? "Google Antigravity local RPC is connected; waiting for new token metadata"
                    : "Google Antigravity local RPC observed \(newEvents.count) new token metadata row(s)",
                lastSuccessAt: now,
                lastErrorAt: nil,
                lastErrorCode: nil,
                lastErrorSummary: nil
            ))
        } catch {
            emitHealth(AntigravityLocalRPCHealth(
                sourceMode: config.sourceMode,
                healthState: "degraded",
                message: "Google Antigravity local RPC metadata is temporarily unavailable",
                lastSuccessAt: nil,
                lastErrorAt: now,
                lastErrorCode: "antigravity_rpc_error",
                lastErrorSummary: error.localizedDescription
            ))
        }
    }

    private func emitHealth(_ health: AntigravityLocalRPCHealth) {
        config.onHealthChange?(health)
    }

    private func append(events: [ProviderUsageSampleEvent]) throws {
        guard events.isEmpty == false else {
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let rendered = try events
            .map { String(decoding: try encoder.encode($0), as: UTF8.self) }
            .joined(separator: "\n") + "\n"

        let outputURL = URL(fileURLWithPath: config.outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: config.outputPath) {
            let handle = try FileHandle(forWritingTo: outputURL)
            defer { try? handle.close() }
            try handle.seekToEnd()
            try handle.write(contentsOf: Data(rendered.utf8))
        } else {
            try rendered.write(to: outputURL, atomically: true, encoding: .utf8)
        }
    }
}

private final class AntigravityLoopbackTrustDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              ["127.0.0.1", "localhost", "::1"].contains(challenge.protectionSpace.host),
              let serverTrust = challenge.protectionSpace.serverTrust
        else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: serverTrust))
    }
}

private final class AntigravityRPCClient: @unchecked Sendable {
    private let timeout: TimeInterval
    private let session: URLSession

    init(timeout: TimeInterval) {
        self.timeout = timeout
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        session = URLSession(configuration: configuration, delegate: AntigravityLoopbackTrustDelegate(), delegateQueue: nil)
    }

    func detectConnections() async -> [AntigravityRPCConnection] {
        let candidates = AntigravityProcessLocator.detectCandidates()
        var connections: [AntigravityRPCConnection] = []
        for candidate in candidates {
            var ports = Set<Int>()
            if let port = candidate.extensionServerPort {
                ports.insert(port)
            }
            ports.formUnion(AntigravityProcessLocator.listeningPorts(for: candidate.pid))

            for port in ports.sorted() {
                let connection = AntigravityRPCConnection(
                    pid: candidate.pid,
                    port: port,
                    csrfToken: candidate.csrfToken
                )
                if await heartbeat(connection: connection) {
                    connections.append(connection)
                }
            }
        }
        return connections
    }

    func listTrajectories(connection: AntigravityRPCConnection) async throws -> [AntigravityTrajectorySummary] {
        let data = try await request(method: "GetAllCascadeTrajectories", body: [:], connection: connection)
        return try AntigravityRPCResponseAdapter.trajectorySummaries(from: data)
    }

    func getTrajectoryMetadata(sessionID: String, connection: AntigravityRPCConnection) async throws -> Data {
        try await request(
            method: "GetCascadeTrajectoryGeneratorMetadata",
            body: ["cascadeId": sessionID],
            connection: connection
        )
    }

    private func heartbeat(connection: AntigravityRPCConnection) async -> Bool {
        do {
            _ = try await request(
                method: "Heartbeat",
                body: ["uuid": "00000000-0000-0000-0000-000000000000"],
                connection: connection
            )
            return true
        } catch {
            return false
        }
    }

    private func request(method: String, body: [String: Any], connection: AntigravityRPCConnection) async throws -> Data {
        let url = URL(string: "https://127.0.0.1:\(connection.port)/exa.language_server_pb.LanguageServerService/\(method)")!
        let requestBody = try JSONSerialization.data(withJSONObject: body)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.httpBody = requestBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(requestBody.count)", forHTTPHeaderField: "Content-Length")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(connection.csrfToken, forHTTPHeaderField: "X-Codeium-Csrf-Token")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            let body = String(decoding: data, as: UTF8.self)
            throw AntigravityRPCError.nonSuccessStatus(method: method, statusCode: statusCode, body: body)
        }
        return data
    }
}

private enum AntigravityRPCError: Error, LocalizedError {
    case nonSuccessStatus(method: String, statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .nonSuccessStatus(let method, let statusCode, let body):
            return "Antigravity RPC \(method) failed with status \(statusCode): \(body)"
        }
    }
}
