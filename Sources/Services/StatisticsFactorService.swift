import Foundation

/// Service for calculating statistics-based boost factors
/// Currently returns 1.0 for all items (stub implementation)
/// Future: Will track user selections and boost frequently used items
final class StatisticsFactorService {
    static let shared = StatisticsFactorService()
    
    private init() {}
    
    /// Calculate statistics factor for a search result
    /// - Parameters:
    ///   - category: The category of the result
    ///   - identifier: Unique identifier for the result (e.g., bundle ID for apps, URL for quicklinks)
    /// - Returns: Boost factor (currently always 1.0)
    ///
    /// Future implementation will:
    /// - Track how often each item is selected
    /// - Boost frequently selected items
    /// - Decay old selections over time
    /// - Consider time-of-day patterns (e.g., Slack selected more during work hours)
    func factor(category: SearchResultCategory, identifier: String) -> Double {
        // Stub implementation - always return 1.0
        return 1.0
    }
    
    /// Record that an item was selected
    /// - Parameters:
    ///   - category: The category of the selected item
    ///   - identifier: Unique identifier for the selected item
    ///
    /// Call this when a user selects a result to track usage patterns
    func recordSelection(category: SearchResultCategory, identifier: String) {
        // TODO: Store selection in persistent storage
        // TODO: Include timestamp for time-based analysis
    }
}
