import TokenmonDomain
import TokenmonProviders

public enum TokenmonOtelProvidersModule {
    public static let name = "TokenmonOtelProviders"
    public static let dependsOn = [
        TokenmonDomainModule.name,
        TokenmonProvidersModule.name,
    ]
    public static let summary = "OTel gRPC receiver and inbox writers for Claude and Gemini provider usage"
}
