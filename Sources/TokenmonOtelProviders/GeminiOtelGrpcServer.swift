import Foundation
import GRPC
import NIOCore
import NIOPosix

public final class GeminiOtelGrpcServer: @unchecked Sendable {
    public struct Configuration: Sendable {
        public let host: String
        public let port: Int

        public static let `default` = Configuration(host: "127.0.0.1", port: 4317)

        public init(host: String, port: Int) {
            self.host = host
            self.port = port
        }
    }

    public enum Error: Swift.Error, LocalizedError {
        case alreadyRunning
        case notRunning
        case bindFailed(underlying: Swift.Error)

        public var errorDescription: String? {
            switch self {
            case .alreadyRunning:
                return "The Gemini OTLP receiver is already running."
            case .notRunning:
                return "The Gemini OTLP receiver is not running."
            case .bindFailed(let underlying):
                return "Failed to bind the Gemini OTLP receiver: \(underlying.localizedDescription)"
            }
        }
    }

    private let configuration: Configuration
    private let logsService: GeminiOtelLogsService
    private let traceService: GeminiOtelTraceService
    private var group: MultiThreadedEventLoopGroup?
    private var server: Server?

    public init(
        configuration: Configuration = .default,
        logsService: GeminiOtelLogsService,
        traceService: GeminiOtelTraceService
    ) {
        self.configuration = configuration
        self.logsService = logsService
        self.traceService = traceService
    }

    public func start() async throws {
        guard server == nil else {
            throw Error.alreadyRunning
        }

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        do {
            // Gemini CLI sends OTel payloads compressed with gzip. grpc-swift's
            // server defaults to compression disabled, which silently rejects
            // gzipped requests at the framing layer (the handler is never
            // invoked). Enable gzip + deflate decoding so the receiver actually
            // sees the data.
            // Gemini CLI sends OTel payloads compressed with gzip. grpc-swift's
            // server defaults to compression disabled, which silently rejects
            // gzipped requests at the framing layer (the handler is never
            // invoked). Enable gzip + deflate decoding so the receiver actually
            // sees the data.
            let server = try await Server.insecure(group: group)
                .withMessageCompression(.enabled(.init(decompressionLimit: .ratio(40))))
                .withServiceProviders([logsService, traceService])
                .bind(host: configuration.host, port: configuration.port)
                .get()
            self.group = group
            self.server = server
        } catch {
            try? await group.shutdownGracefully()
            throw Error.bindFailed(underlying: error)
        }
    }

    public func stop() async throws {
        guard let server else {
            throw Error.notRunning
        }
        try? await server.close().get()
        self.server = nil
        try? await group?.shutdownGracefully()
        self.group = nil
    }
}
