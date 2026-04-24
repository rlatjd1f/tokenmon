import Foundation

public struct TokenmonAsyncProcessResult: Sendable, Equatable {
    public let stdout: Data
    public let stderr: Data
    public let terminationStatus: Int32

    public var stdoutString: String {
        String(decoding: stdout, as: UTF8.self)
    }

    public var stderrString: String {
        String(decoding: stderr, as: UTF8.self)
    }
}

public enum TokenmonAsyncProcessError: Error, LocalizedError, Equatable {
    case launchFailed(String)
    case timedOut(TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            return "process launch failed: \(message)"
        case .timedOut(let timeout):
            return "process timed out after \(timeout) seconds"
        }
    }
}

public struct TokenmonAsyncProcessRequest: Sendable, Equatable {
    public let executableURL: URL
    public let arguments: [String]
    public let currentDirectoryURL: URL?
    public let environment: [String: String]?
    public let timeout: TimeInterval?

    public init(
        executableURL: URL,
        arguments: [String] = [],
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval? = nil
    ) {
        self.executableURL = executableURL
        self.arguments = arguments
        self.currentDirectoryURL = currentDirectoryURL
        self.environment = environment
        self.timeout = timeout
    }
}

public enum TokenmonAsyncProcessRunner {
    public static func run(_ request: TokenmonAsyncProcessRequest) async throws -> TokenmonAsyncProcessResult {
        if let timeout = request.timeout {
            return try await withThrowingTaskGroup(of: TokenmonAsyncProcessResult.self) { group in
                group.addTask {
                    try await runWithoutTimeout(request)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(max(0, timeout) * 1_000_000_000))
                    throw TokenmonAsyncProcessError.timedOut(timeout)
                }

                guard let result = try await group.next() else {
                    throw CancellationError()
                }
                group.cancelAll()
                return result
            }
        }

        return try await runWithoutTimeout(request)
    }

    private static func runWithoutTimeout(_ request: TokenmonAsyncProcessRequest) async throws -> TokenmonAsyncProcessResult {
        let process = Process()
        process.executableURL = request.executableURL
        process.arguments = request.arguments
        process.currentDirectoryURL = request.currentDirectoryURL
        if let environment = request.environment {
            process.environment = environment
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdout = ProcessOutputBuffer()
        let stderr = ProcessOutputBuffer()
        let state = RunningProcessState(process: process)

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                stdoutPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                    } else {
                        stdout.append(chunk)
                    }
                }
                stderrPipe.fileHandleForReading.readabilityHandler = { handle in
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        handle.readabilityHandler = nil
                    } else {
                        stderr.append(chunk)
                    }
                }

                process.terminationHandler = { process in
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    stdout.append(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
                    stderr.append(stderrPipe.fileHandleForReading.readDataToEndOfFile())
                    continuation.resume(
                        returning: TokenmonAsyncProcessResult(
                            stdout: stdout.data(),
                            stderr: stderr.data(),
                            terminationStatus: process.terminationStatus
                        )
                    )
                }

                do {
                    try process.run()
                } catch {
                    stdoutPipe.fileHandleForReading.readabilityHandler = nil
                    stderrPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(
                        throwing: TokenmonAsyncProcessError.launchFailed(error.localizedDescription)
                    )
                }
            }
        } onCancel: {
            state.terminate()
        }
    }
}

private final class ProcessOutputBuffer: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()

    func append(_ data: Data) {
        guard data.isEmpty == false else {
            return
        }
        lock.withLock {
            storage.append(data)
        }
    }

    func data() -> Data {
        lock.withLock {
            storage
        }
    }
}

private final class RunningProcessState: @unchecked Sendable {
    private let lock = NSLock()
    private let process: Process

    init(process: Process) {
        self.process = process
    }

    func terminate() {
        lock.withLock {
            guard process.isRunning else {
                return
            }
            process.terminate()
        }
    }
}
