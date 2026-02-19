import Foundation

/// Represents the current awake/sleep prevention mode
enum AwakeMode: Equatable {
    case disabled
    case system  // caffeinate system - display can sleep
    case full   // caffeinate - both display and system prevented
}
