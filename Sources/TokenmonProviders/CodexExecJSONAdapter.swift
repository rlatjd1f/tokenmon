import CryptoKit
import Foundation
import TokenmonDomain

public struct CodexExecJSONUsage: Decodable, Sendable {
    public let inputTokens: Int64
    public let cachedInputTokens: Int64
    public let outputTokens: Int64
    public let totalTokens: Int64?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case outputTokens = "output_tokens"
        case totalTokens = "total_tokens"
    }
}

public struct CodexExecJSONEvent: Decodable, Sendable {
    public let type: String
    public let threadID: String?
    public let turnID: String?
    public let timestamp: String?
    public let createdAt: String?
    public let cwd: String?
    public let model: String?
    public let usage: CodexExecJSONUsage?

    enum CodingKeys: String, CodingKey {
        case type
        case threadID = "thread_id"
        case turnID = "turn_id"
        case timestamp
        case createdAt = "created_at"
        case cwd
        case model
        case usage
    }
}

public enum CodexExecJSONLineResult: Sendable {
    case ignored
    case duplicateTurn
    case usageSample(ProviderUsageSampleEvent)
}

public struct CodexExecJSONAdapterConfig: Sendable {
    public let workspaceDirOverride: String?
    public let sessionIDFallback: String?
    public let nowProvider: @Sendable () -> String

    public init(
        workspaceDirOverride: String? = nil,
        sessionIDFallback: String? = nil,
        nowProvider: @escaping @Sendable () -> String = {
            ISO8601DateFormatter().string(from: Date())
        }
    ) {
        self.workspaceDirOverride = workspaceDirOverride
        self.sessionIDFallback = sessionIDFallback
        self.nowProvider = nowProvider
    }
}

public struct CodexExecJSONImportResult: Sendable {
    public let sourcePath: String?
    public let outputPath: String?
    public let threadID: String?
    public let linesRead: Int
    public let eventsWritten: Int
    public let duplicateTurnsSkipped: Int
}

private final class CodexExecJSONStreamWriter: @unchecked Sendable {
    private let encoder = JSONEncoder()
    private let fileHandle: FileHandle?

    init(outputPath: String?) throws {
        encoder.outputFormatting = [.sortedKeys]

        guard let outputPath else {
            fileHandle = nil
            return
        }

        let outputURL = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if FileManager.default.fileExists(atPath: outputURL.path) == false {
            FileManager.default.createFile(atPath: outputURL.path, contents: nil)
        }

        let fileHandle = try FileHandle(forWritingTo: outputURL)
        try fileHandle.seekToEnd()
        self.fileHandle = fileHandle
    }

    deinit {
        try? fileHandle?.close()
    }

    func append(_ event: ProviderUsageSampleEvent) throws {
        let eventData = try encoder.encode(event) + Data([0x0A])

        if let fileHandle {
            try fileHandle.write(contentsOf: eventData)
            return
        }

        print(String(decoding: eventData, as: UTF8.self), terminator: "")
    }
}

private final class CodexExecJSONStreamState: @unchecked Sendable {
    let processingQueue = DispatchQueue(label: "TokenmonProviders.CodexExecJSONAdapter.run")
    var bufferedStdout = Data()
    var linesRead = 0
    var eventsWritten = 0
    var duplicateTurnsSkipped = 0
    var stdoutError: Error?
    var stdoutDidReachEOF = false
}

public enum CodexExecJSONAdapterError: Error, LocalizedError {
    case invalidUsageTokens(lineNumber: Int)
    case missingUsage(lineNumber: Int)
    case missingSessionID(lineNumber: Int)
    case codexLaunchFailed(String)
    case codexExitedNonZero(Int32)

    public var errorDescription: String? {
        switch self {
        case .invalidUsageTokens(let lineNumber):
            return "codex exec json line \(lineNumber) has negative usage tokens"
        case .missingUsage(let lineNumber):
            return "codex exec json line \(lineNumber) is turn.completed without usage"
        case .missingSessionID(let lineNumber):
            return "codex exec json line \(lineNumber) does not expose a thread id and no fallback session id was provided"
        case .codexLaunchFailed(let message):
            return "failed to launch codex exec --json: \(message)"
        case .codexExitedNonZero(let status):
            return "codex exec --json exited with status \(status)"
        }
    }
}

public final class CodexExecJSONAdapter: @unchecked Sendable {
    private let config: CodexExecJSONAdapterConfig
    private let decoder = JSONDecoder()
    private var currentThreadID: String?
    private var runningInputTokens: Int64 = 0
    private var runningCachedInputTokens: Int64 = 0
    private var runningOutputTokens: Int64 = 0
    private var runningNormalizedTokens: Int64 = 0
    private var seenFingerprints: Set<String> = []
    private var observedThreadStarted = false

    public init(config: CodexExecJSONAdapterConfig = CodexExecJSONAdapterConfig()) {
        self.config = config
    }

    public func consumeLine(_ rawLine: String, lineNumber: Int) throws -> CodexExecJSONLineResult {
        let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return .ignored
        }

        let event = try decoder.decode(CodexExecJSONEvent.self, from: Data(trimmed.utf8))

        switch event.type {
        case "thread.started":
            currentThreadID = event.threadID ?? currentThreadID
            observedThreadStarted = true
            return .ignored
        case "turn.completed":
            return try consumeTurnCompleted(event: event, rawLine: trimmed, lineNumber: lineNumber)
        default:
            return .ignored
        }
    }

    public static func importJSONL(
        from sourcePath: String,
        outputPath: String? = nil,
        config: CodexExecJSONAdapterConfig = CodexExecJSONAdapterConfig()
    ) throws -> CodexExecJSONImportResult {
        let adapter = CodexExecJSONAdapter(config: config)
        let readResult = try ProviderInboxReader.read(from: sourcePath)
        let events = try adapter.providerEvents(from: readResult.lines)
        try write(events: events, to: outputPath)

        return CodexExecJSONImportResult(
            sourcePath: sourcePath,
            outputPath: outputPath,
            threadID: adapter.currentThreadID,
            linesRead: readResult.lines.count,
            eventsWritten: events.events.count,
            duplicateTurnsSkipped: events.duplicateTurnsSkipped
        )
    }

    public static func runCodexExecJSON(
        prompt: String,
        outputPath: String,
        codexBin: String = "codex",
        model: String? = nil,
        workingDirectory: String? = nil,
        config: CodexExecJSONAdapterConfig = CodexExecJSONAdapterConfig()
    ) throws -> CodexExecJSONImportResult {
        let process = Process()
        process.executableURL = resolvedExecutableURL(for: codexBin)
        process.arguments = resolvedArguments(codexBin: codexBin, prompt: prompt, model: model)
        if let workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw CodexExecJSONAdapterError.codexLaunchFailed(error.localizedDescription)
        }

        let adapter = CodexExecJSONAdapter(config: config)
        let writer = try CodexExecJSONStreamWriter(outputPath: outputPath)
        let stdoutReader = stdoutPipe.fileHandleForReading
        let stderrReader = stderrPipe.fileHandleForReading
        let streamState = CodexExecJSONStreamState()

        let processStdoutChunk: @Sendable (Data, Bool) -> Void = { chunk, flushAtEOF in
            streamState.processingQueue.sync {
                guard streamState.stdoutError == nil else {
                    if flushAtEOF {
                        streamState.stdoutDidReachEOF = true
                    }
                    return
                }
                guard streamState.stdoutDidReachEOF == false else {
                    return
                }

                streamState.bufferedStdout.append(chunk)
                do {
                    try processBufferedLines(
                        from: &streamState.bufferedStdout,
                        flushAtEOF: flushAtEOF,
                        adapter: adapter,
                        writer: writer,
                        linesRead: &streamState.linesRead,
                        eventsWritten: &streamState.eventsWritten,
                        duplicateTurnsSkipped: &streamState.duplicateTurnsSkipped
                    )
                    if flushAtEOF {
                        streamState.stdoutDidReachEOF = true
                    }
                } catch {
                    streamState.stdoutError = error
                    if flushAtEOF {
                        streamState.stdoutDidReachEOF = true
                    }
                }
            }
        }

        stdoutReader.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                processStdoutChunk(Data(), true)
                return
            }

            processStdoutChunk(chunk, false)
        }

        stderrReader.readabilityHandler = { handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }

            try? FileHandle.standardError.write(contentsOf: chunk)
        }

        process.waitUntilExit()

        stdoutReader.readabilityHandler = nil
        stderrReader.readabilityHandler = nil

        let trailingStdout = stdoutReader.readDataToEndOfFile()
        processStdoutChunk(trailingStdout, true)

        let trailingStderr = stderrReader.readDataToEndOfFile()
        if trailingStderr.isEmpty == false {
            try? FileHandle.standardError.write(contentsOf: trailingStderr)
        }

        if let stdoutError = streamState.stdoutError {
            throw stdoutError
        }

        guard process.terminationStatus == 0 else {
            throw CodexExecJSONAdapterError.codexExitedNonZero(process.terminationStatus)
        }

        return CodexExecJSONImportResult(
            sourcePath: nil,
            outputPath: outputPath,
            threadID: adapter.currentThreadID,
            linesRead: streamState.linesRead,
            eventsWritten: streamState.eventsWritten,
            duplicateTurnsSkipped: streamState.duplicateTurnsSkipped
        )
    }

    private func consumeTurnCompleted(
        event: CodexExecJSONEvent,
        rawLine: String,
        lineNumber: Int
    ) throws -> CodexExecJSONLineResult {
        let sessionID = event.threadID ?? currentThreadID ?? config.sessionIDFallback
        guard let sessionID else {
            throw CodexExecJSONAdapterError.missingSessionID(lineNumber: lineNumber)
        }
        currentThreadID = sessionID

        guard let usage = event.usage else {
            throw CodexExecJSONAdapterError.missingUsage(lineNumber: lineNumber)
        }
        guard usage.inputTokens >= 0,
              usage.cachedInputTokens >= 0,
              usage.outputTokens >= 0,
              (usage.totalTokens ?? 0) >= 0 else {
            throw CodexExecJSONAdapterError.invalidUsageTokens(lineNumber: lineNumber)
        }

        let turnKey = event.turnID ?? rawLineFingerprint(rawLine)
        let fingerprint = "codex:\(sessionID):\(turnKey)"
        guard seenFingerprints.insert(fingerprint).inserted else {
            return .duplicateTurn
        }

        let turnAccounting = ProviderTokenAccounting.codex(
            totalInputTokens: usage.inputTokens,
            totalOutputTokens: usage.outputTokens,
            totalCachedInputTokens: usage.cachedInputTokens,
            providerTotalTokens: usage.totalTokens,
            currentInputTokens: usage.inputTokens,
            currentOutputTokens: usage.outputTokens
        )
        runningInputTokens += turnAccounting.totalInputTokens
        runningCachedInputTokens += turnAccounting.totalCachedInputTokens
        runningOutputTokens += turnAccounting.totalOutputTokens
        runningNormalizedTokens += turnAccounting.normalizedTotalTokens
        let accounting = ProviderTokenAccounting.codex(
            totalInputTokens: runningInputTokens,
            totalOutputTokens: runningOutputTokens,
            totalCachedInputTokens: runningCachedInputTokens,
            providerTotalTokens: runningNormalizedTokens,
            currentInputTokens: usage.inputTokens,
            currentOutputTokens: usage.outputTokens
        )

        let observedAt = event.timestamp ?? event.createdAt ?? config.nowProvider()

        let providerEvent = ProviderUsageSampleEvent(
            eventType: "provider_usage_sample",
            provider: .codex,
            sourceMode: "codex_exec_json",
            providerSessionID: sessionID,
            observedAt: observedAt,
            workspaceDir: config.workspaceDirOverride ?? event.cwd,
            modelSlug: event.model,
            transcriptPath: nil,
            totalInputTokens: accounting.totalInputTokens,
            totalOutputTokens: accounting.totalOutputTokens,
            totalCachedInputTokens: accounting.totalCachedInputTokens,
            normalizedTotalTokens: accounting.normalizedTotalTokens,
            providerEventFingerprint: fingerprint,
            rawReference: ProviderRawReference(
                kind: "jsonl",
                offset: String(lineNumber),
                eventName: "turn.completed"
            ),
            currentInputTokens: accounting.currentInputTokens,
            currentOutputTokens: accounting.currentOutputTokens,
            sessionOriginHint: observedThreadStarted ? .startedDuringLiveRuntime : .unknown
        )

        return .usageSample(providerEvent)
    }

    private func providerEvents(from lines: [ProviderInboxLine]) throws -> (events: [ProviderUsageSampleEvent], duplicateTurnsSkipped: Int) {
        var events: [ProviderUsageSampleEvent] = []
        var duplicateTurnsSkipped = 0

        for (index, line) in lines.enumerated() {
            switch try consumeLine(line.rawLine, lineNumber: index + 1) {
            case .ignored:
                continue
            case .duplicateTurn:
                duplicateTurnsSkipped += 1
            case .usageSample(let event):
                events.append(event)
            }
        }

        return (events, duplicateTurnsSkipped)
    }

    private static func write(events: (events: [ProviderUsageSampleEvent], duplicateTurnsSkipped: Int), to outputPath: String?) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let rendered = try events.events
            .map { String(decoding: try encoder.encode($0), as: UTF8.self) }
            .joined(separator: "\n")

        if let outputPath {
            let outputURL = URL(fileURLWithPath: outputPath)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let payload = rendered.isEmpty ? "" : rendered + "\n"
            try payload.write(to: outputURL, atomically: true, encoding: .utf8)
            return
        }

        if rendered.isEmpty == false {
            print(rendered)
        }
    }

    private static func processBufferedLines(
        from buffer: inout Data,
        flushAtEOF: Bool,
        adapter: CodexExecJSONAdapter,
        writer: CodexExecJSONStreamWriter,
        linesRead: inout Int,
        eventsWritten: inout Int,
        duplicateTurnsSkipped: inout Int
    ) throws {
        while let newlineIndex = buffer.firstIndex(of: 0x0A) {
            let lineData = Data(buffer[..<newlineIndex])
            buffer.removeSubrange(...newlineIndex)

            linesRead += 1
            try consumeStreamedLine(
                String(decoding: lineData, as: UTF8.self),
                lineNumber: linesRead,
                adapter: adapter,
                writer: writer,
                eventsWritten: &eventsWritten,
                duplicateTurnsSkipped: &duplicateTurnsSkipped
            )
        }

        if flushAtEOF, buffer.isEmpty == false {
            let lineData = buffer
            buffer.removeAll(keepingCapacity: false)

            linesRead += 1
            try consumeStreamedLine(
                String(decoding: lineData, as: UTF8.self),
                lineNumber: linesRead,
                adapter: adapter,
                writer: writer,
                eventsWritten: &eventsWritten,
                duplicateTurnsSkipped: &duplicateTurnsSkipped
            )
        }
    }

    private static func consumeStreamedLine(
        _ rawLine: String,
        lineNumber: Int,
        adapter: CodexExecJSONAdapter,
        writer: CodexExecJSONStreamWriter,
        eventsWritten: inout Int,
        duplicateTurnsSkipped: inout Int
    ) throws {
        switch try adapter.consumeLine(rawLine, lineNumber: lineNumber) {
        case .ignored:
            return
        case .duplicateTurn:
            duplicateTurnsSkipped += 1
        case .usageSample(let event):
            try writer.append(event)
            eventsWritten += 1
        }
    }

    private static func resolvedExecutableURL(for codexBin: String) -> URL {
        if codexBin.contains("/") {
            return URL(fileURLWithPath: codexBin)
        }
        return URL(fileURLWithPath: "/usr/bin/env")
    }

    private static func resolvedArguments(codexBin: String, prompt: String, model: String?) -> [String] {
        var arguments: [String] = []
        if codexBin.contains("/") == false {
            arguments.append(codexBin)
        }

        arguments.append(contentsOf: ["exec", "--json"])
        if let model, model.isEmpty == false {
            arguments.append(contentsOf: ["--model", model])
        }
        arguments.append(prompt)
        return arguments
    }

    private func rawLineFingerprint(_ rawLine: String) -> String {
        let digest = SHA256.hash(data: Data(rawLine.utf8))
        return digest.prefix(8).map { String(format: "%02x", $0) }.joined()
    }
}
