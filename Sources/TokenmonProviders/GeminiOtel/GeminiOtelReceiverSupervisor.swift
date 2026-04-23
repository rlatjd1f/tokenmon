import Foundation
import Combine
import TokenmonDomain

protocol GeminiOtelReceiverServer: AnyObject, Sendable {
    func start() async throws
    func stop() async throws
}

extension GeminiOtelGrpcServer: GeminiOtelReceiverServer {}

/// A dependency interface that supplies the supervisor with the data it needs
/// from the persistence layer without creating a circular dependency between
/// `TokenmonProviders` and `TokenmonPersistence`.
public protocol GeminiOtelReceiverDataSource: AnyObject {
    /// Returns the per-session cumulative totals used to seed the tracker on
    /// startup so that a process restart does not produce a downward token jump.
    func latestGeminiSessionTotals() throws -> [String: GeminiSessionRunningTotals]

    /// Returns Claude session totals used to continue OTel cumulative values
    /// across app restarts or a status-line-to-OTel transition.
    func latestClaudeSessionTotals() throws -> [String: GeminiSessionRunningTotals]
}

@MainActor
public final class GeminiOtelReceiverSupervisor: ObservableObject {
    public enum State: Equatable {
        case stopped
        case starting
        case running(host: String, port: Int)
        case failed(message: String)
    }

    @Published public private(set) var state: State = .stopped

    private let dataSource: GeminiOtelReceiverDataSource
    private let inboxPath: String
    private let claudeInboxPath: String?
    private let configuration: GeminiOtelGrpcServer.Configuration
    private let makeServer: (
        GeminiOtelGrpcServer.Configuration,
        GeminiOtelLogsService,
        GeminiOtelTraceService
    ) -> any GeminiOtelReceiverServer
    private var server: (any GeminiOtelReceiverServer)?

    public convenience init(
        dataSource: GeminiOtelReceiverDataSource,
        inboxPath: String,
        claudeInboxPath: String? = nil,
        configuration: GeminiOtelGrpcServer.Configuration = .default
    ) {
        self.init(
            dataSource: dataSource,
            inboxPath: inboxPath,
            claudeInboxPath: claudeInboxPath,
            configuration: configuration,
            makeServer: { configuration, logs, trace in
                GeminiOtelGrpcServer(configuration: configuration, logsService: logs, traceService: trace)
            }
        )
    }

    init(
        dataSource: GeminiOtelReceiverDataSource,
        inboxPath: String,
        claudeInboxPath: String? = nil,
        configuration: GeminiOtelGrpcServer.Configuration = .default,
        makeServer: @escaping (
            GeminiOtelGrpcServer.Configuration,
            GeminiOtelLogsService,
            GeminiOtelTraceService
        ) -> any GeminiOtelReceiverServer
    ) {
        self.dataSource = dataSource
        self.inboxPath = inboxPath
        self.claudeInboxPath = claudeInboxPath
        self.configuration = configuration
        self.makeServer = makeServer
    }

    public func start() async {
        guard server == nil else {
            return
        }
        state = .starting

        let writer = GeminiOtelInboxWriter(inboxPath: inboxPath)
        let seed: [String: GeminiSessionRunningTotals]
        let claudeSeed: [String: GeminiSessionRunningTotals]
        do {
            seed = try dataSource.latestGeminiSessionTotals()
            claudeSeed = try dataSource.latestClaudeSessionTotals()
        } catch {
            state = .failed(message: "Could not seed OTel session totals: \(error.localizedDescription)")
            return
        }
        let tracker = GeminiCumulativeTracker(seed: seed)
        let claudeWriter = claudeInboxPath.map(ClaudeOtelInboxWriter.init(inboxPath:))
        let claudeTracker = claudeWriter == nil ? nil : ClaudeOtelCumulativeTracker(seed: claudeSeed)
        let logs = GeminiOtelLogsService(
            writer: writer,
            tracker: tracker,
            claudeWriter: claudeWriter,
            claudeTracker: claudeTracker
        )
        let trace = GeminiOtelTraceService()
        let server = makeServer(configuration, logs, trace)

        do {
            try await server.start()
            self.server = server
            state = .running(
                host: configuration.host,
                port: configuration.port
            )
        } catch {
            state = .failed(message: error.localizedDescription)
        }
    }

    public func stop() async {
        guard let server else {
            return
        }
        // Capture in a local constant so the MainActor-isolated property is not
        // accessed across the suspension point, satisfying Swift 6 data-race checks.
        let serverToStop = server
        do {
            try await serverToStop.stop()
            self.server = nil
            state = .stopped
        } catch {
            state = .failed(message: "Could not stop gemini receiver: \(error.localizedDescription)")
        }
    }
}
