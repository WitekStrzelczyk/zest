import Foundation
import os.log

// MARK: - LLM Service (Foundation Models)

/// Service that uses Apple's Foundation Models framework for natural language tool calling.
/// Requires macOS 26 (Tahoe) with Apple Intelligence enabled.
/// Falls back gracefully on older systems.
@MainActor
final class LLMService: ObservableObject {
    // MARK: - Singleton
    
    static let shared = LLMService()
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.zest.app", category: "LLM")
    
    @Published var isAvailable = false
    @Published var statusMessage = "Checking availability..."
    
    // MARK: - Availability
    
    /// Check if Foundation Models is available on this device
    var availabilityStatus: LMAvailabilityStatus {
        // Check if we're on macOS 26+
        if #available(macOS 26.0, *) {
            return .available
        } else {
            return .unavailable(reason: "Requires macOS 26 (Tahoe) or later")
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        checkAvailability()
    }
    
    private func checkAvailability() {
        if #available(macOS 26.0, *) {
            isAvailable = true
            statusMessage = "Foundation Models ready"
            logger.info("Foundation Models available")
        } else {
            isAvailable = false
            statusMessage = "Requires macOS 26+ with Apple Intelligence"
            logger.info("Foundation Models not available - requires macOS 26")
        }
    }
    
    // MARK: - Tool Calling
    
    /// Parse natural language input using Foundation Models (macOS 26+)
    /// - Parameter input: User's natural language input
    /// - Returns: Parsed tool call, or nil if no tool detected
    func parseToolCall(_ input: String) async -> LLMToolCall? {
        logger.info("parseToolCall called with: \(input)")
        
        // On macOS 26+, use Foundation Models
        if #available(macOS 26.0, *) {
            return await parseWithFoundationModels(input)
        } else {
            // Fallback to pattern matching for older macOS
            logger.info("Using pattern matching fallback")
            return nil // Pattern matching is handled by LLMToolCallingService
        }
    }
    
    // MARK: - Foundation Models Integration (macOS 26+)
    
    @available(macOS 26.0, *)
    private func parseWithFoundationModels(_ input: String) async -> LLMToolCall? {
        // This will be implemented with actual Foundation Models API
        // For now, return nil to fall back to pattern matching
        // The actual implementation requires:
        // 1. Import FoundationModels
        // 2. Create a LanguageModelSession with tools
        // 3. Define CreateCalendarEventTool and FindFilesTool
        // 4. Call session.respond() with the input
        
        logger.info("Foundation Models integration pending - using pattern matching")
        return nil
    }
}

// MARK: - Availability Status

enum LMAvailabilityStatus: Equatable {
    case available
    case unavailable(reason: String)
}
