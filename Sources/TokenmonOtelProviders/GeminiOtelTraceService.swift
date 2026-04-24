import GRPC
import NIOCore

/// OTLP TraceService implementation. Tokenmon does not consume trace data
/// from Gemini, but the OTel SDK still exports spans. We accept the
/// requests and discard them so the SDK does not enter retry loops.
public final class GeminiOtelTraceService {
    public init() {}
}

extension GeminiOtelTraceService: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceProvider {
    public var interceptors: Opentelemetry_Proto_Collector_Trace_V1_TraceServiceServerInterceptorFactoryProtocol? {
        nil
    }

    public func export(
        request: Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceRequest,
        context: StatusOnlyCallContext
    ) -> EventLoopFuture<Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse> {
        context.eventLoop.makeSucceededFuture(
            Opentelemetry_Proto_Collector_Trace_V1_ExportTraceServiceResponse()
        )
    }
}
