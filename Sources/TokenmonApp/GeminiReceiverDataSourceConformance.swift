import Foundation
import TokenmonDomain
import TokenmonOtelProviders
import TokenmonPersistence
import TokenmonProviders

// MARK: - GeminiOtelReceiverDataSource conformance

// This conformance lives in TokenmonApp because TokenmonOtelProviders must not
// import TokenmonPersistence (that would create a circular dependency).
// TokenmonApp already imports both targets, so it is the correct seam.
extension TokenmonDatabaseManager: GeminiOtelReceiverDataSource {
    // The persistence implementation has extra defaulted parameters
    // (`activeWithinHours` and `asOf`). Swift cannot automatically satisfy a
    // protocol with a method that has a different label set, so we add a thin
    // forwarding witness that calls through with the defaults.
    public func latestGeminiSessionTotals() throws -> [String: GeminiSessionRunningTotals] {
        try latestGeminiSessionTotals(activeWithinHours: 24, asOf: Date())
    }

    public func latestClaudeSessionTotals() throws -> [String: GeminiSessionRunningTotals] {
        try latestClaudeSessionTotals(activeWithinHours: 24, asOf: Date())
    }
}
