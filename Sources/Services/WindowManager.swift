import AppKit
import ApplicationServices

/// WindowManager handles window manipulation using macOS Accessibility API
/// Provides window tiling functionality (left half, right half, maximize)
final class WindowManager {
    // MARK: - Types

    enum TilingOption: CaseIterable {
        case leftHalf
        case rightHalf
        case maximize

        var title: String {
            switch self {
            case .leftHalf: "Tile Left"
            case .rightHalf: "Tile Right"
            case .maximize: "Maximize"
            }
        }

        var icon: NSImage? {
            switch self {
            case .leftHalf:
                NSImage(systemSymbolName: "rectangle.lefthalf.filled", accessibilityDescription: "Tile Left")
            case .rightHalf:
                NSImage(systemSymbolName: "rectangle.righthalf.filled", accessibilityDescription: "Tile Right")
            case .maximize:
                NSImage(systemSymbolName: "rectangle.fill", accessibilityDescription: "Maximize")
            }
        }
    }

    // MARK: - Window Movement Option

    enum MovementOption: CaseIterable {
        case moveToCenter
        case moveToScreen
        case maximize

        var title: String {
            switch self {
            case .moveToCenter: "Move to Center"
            case .moveToScreen: "Move to Screen"
            case .maximize: "Maximize"
            }
        }

        var icon: NSImage? {
            switch self {
            case .moveToCenter:
                NSImage(systemSymbolName: "arrow.center.all", accessibilityDescription: "Move to Center")
            case .moveToScreen:
                NSImage(systemSymbolName: "display", accessibilityDescription: "Move to Screen")
            case .maximize:
                NSImage(systemSymbolName: "rectangle.fill", accessibilityDescription: "Maximize")
            }
        }
    }

    // MARK: - Singleton

    static let shared: WindowManager = .init()

    private init() {}

    // MARK: - Public API

    /// Checks if the focused window can be tiled (not full-screen)
    func canTileFocusedWindow() -> Bool {
        guard let focusedWindow = getFocusedWindow() else {
            return false
        }

        // Check if window is full-screen
        if isWindowFullScreen(focusedWindow) {
            return false
        }

        return true
    }

    /// Tiles the focused window to the specified position
    /// - Parameter option: The tiling option (leftHalf, rightHalf, maximize)
    /// - Returns: True if tiling was successful, false otherwise
    @discardableResult
    func tileFocusedWindow(_ option: TilingOption) -> Bool {
        // Check if we can tile (not full-screen)
        guard canTileFocusedWindow() else {
            return false
        }

        guard let focusedWindow = getFocusedWindow() else {
            return false
        }

        // Get the screen containing the focused window
        guard let screen = getScreenForWindow(focusedWindow) else {
            return false
        }

        // Calculate the target frame
        let targetFrame = WindowManager.calculateTileFrame(for: option, on: screen.visibleFrame)

        // Apply the new frame
        return setWindowFrame(focusedWindow, frame: targetFrame)
    }

    // MARK: - Frame Calculation (Static for testing)

    /// Calculates the target frame for a tiling option on a given screen
    /// - Parameters:
    ///   - option: The tiling option
    ///   - screen: The screen frame to calculate for
    /// - Returns: The target frame for the window
    static func calculateTileFrame(for option: TilingOption, on screen: CGRect) -> CGRect {
        switch option {
        case .leftHalf:
            CGRect(
                x: screen.origin.x,
                y: screen.origin.y,
                width: screen.width / 2,
                height: screen.height
            )
        case .rightHalf:
            CGRect(
                x: screen.origin.x + screen.width / 2,
                y: screen.origin.y,
                width: screen.width / 2,
                height: screen.height
            )
        case .maximize:
            screen
        }
    }

    /// Finds the screen containing a given point
    /// - Parameter point: The point to check
    /// - Returns: The screen containing the point, or nil
    static func screen(containing point: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(point) {
                return screen
            }
        }
        return NSScreen.main
    }

    // MARK: - Window Movement (Story 5)

    /// Calculates the center position for a window of given size on a screen
    /// - Parameters:
    ///   - windowSize: The size of the window
    ///   - screen: The screen frame to center on
    /// - Returns: The center position (origin point)
    static func calculateCenterPosition(for windowSize: CGSize, on screen: CGRect) -> CGPoint {
        let centerX = screen.origin.x + (screen.width - windowSize.width) / 2
        let centerY = screen.origin.y + (screen.height - windowSize.height) / 2
        return CGPoint(x: centerX, y: centerY)
    }

    /// Calculates the maximize frame (full visible area) for a screen
    /// - Parameter screen: The screen frame to maximize to
    /// - Returns: The maximized frame (visible area)
    static func calculateMaximizeFrame(on screen: CGRect) -> CGRect {
        screen
    }

    /// Gets the visible frame for a screen (excludes menu bar and dock)
    /// - Parameter screen: The screen to get visible frame for
    /// - Returns: The visible frame
    static func getVisibleFrame(for screen: NSScreen) -> CGRect {
        screen.visibleFrame
    }

    /// Checks if a position is off-screen
    /// - Parameters:
    ///   - position: The position to check
    ///   - screen: The screen to check against
    /// - Returns: True if the position is off-screen
    static func isPositionOffScreen(_ position: CGPoint, on screen: NSScreen) -> Bool {
        let screenFrame = screen.frame
        let tolerance: CGFloat = 50 // Allow some tolerance

        // Check if position is completely outside the screen
        return position.x < screenFrame.origin.x - tolerance ||
            position.y < screenFrame.origin.y - tolerance ||
            position.x > screenFrame.maxX + tolerance ||
            position.y > screenFrame.maxY + tolerance
    }

    /// Calculates the recovery position for an off-screen window
    /// - Parameters:
    ///   - position: The current off-screen position
    ///   - visibleFrame: The visible area to fit the window into
    ///   - windowSize: The size of the window (optional, defaults to minimum visible)
    /// - Returns: A position within the visible area
    static func calculateRecoveryPosition(
        from position: CGPoint,
        toFitIn visibleFrame: CGRect,
        windowSize: CGSize = CGSize(width: 200, height: 100)
    ) -> CGPoint {
        var newX = position.x
        var newY = position.y

        // Ensure X is within bounds
        if newX < visibleFrame.origin.x {
            newX = visibleFrame.origin.x
        } else if newX + windowSize.width > visibleFrame.maxX {
            newX = visibleFrame.maxX - windowSize.width
        }

        // Ensure Y is within bounds
        if newY < visibleFrame.origin.y {
            newY = visibleFrame.origin.y
        } else if newY + windowSize.height > visibleFrame.maxY {
            newY = visibleFrame.maxY - windowSize.height
        }

        return CGPoint(x: newX, y: newY)
    }

    /// Calculates a new frame for resizing
    /// - Parameters:
    ///   - targetSize: The target size
    ///   - originalPosition: The original position to maintain
    /// - Returns: The new frame
    static func calculateFrameForResize(to targetSize: CGSize, originalPosition: CGPoint) -> CGRect {
        CGRect(origin: originalPosition, size: targetSize)
    }

    /// Calculates a new frame for resizing while maintaining aspect ratio
    /// - Parameters:
    ///   - targetWidth: The target width
    ///   - maintainingAspectRatio: Whether to maintain aspect ratio
    ///   - originalSize: The original size for aspect ratio calculation
    ///   - originalPosition: The original position to maintain
    /// - Returns: The new frame
    static func calculateFrameForResize(
        to targetWidth: CGFloat,
        maintainingAspectRatio: Bool,
        originalSize: CGSize,
        originalPosition: CGPoint
    ) -> CGRect {
        if maintainingAspectRatio {
            let aspectRatio = originalSize.height / originalSize.width
            let targetHeight = targetWidth * aspectRatio
            return CGRect(x: originalPosition.x, y: originalPosition.y, width: targetWidth, height: targetHeight)
        } else {
            return CGRect(x: originalPosition.x, y: originalPosition.y, width: targetWidth, height: originalSize.height)
        }
    }

    // MARK: - Public Window Movement Actions

    /// Moves the focused window to the center of the current screen
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func moveFocusedWindowToCenter() -> Bool {
        guard let focusedWindow = getFocusedWindow() else {
            return false
        }

        guard let screen = getScreenForWindow(focusedWindow) else {
            return false
        }

        guard let windowSize = getWindowSize(focusedWindow) else {
            return false
        }

        let centerPosition = WindowManager.calculateCenterPosition(for: windowSize, on: screen.visibleFrame)
        let newFrame = CGRect(origin: centerPosition, size: windowSize)

        return setWindowFrame(focusedWindow, frame: newFrame)
    }

    /// Moves the focused window to be visible on screen
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func moveFocusedWindowToScreen() -> Bool {
        guard let focusedWindow = getFocusedWindow() else {
            return false
        }

        guard let screen = getScreenForWindow(focusedWindow) else {
            return false
        }

        let visibleFrame = screen.visibleFrame

        guard let currentFrame = getWindowFrame(focusedWindow) else {
            return false
        }

        // Check if window is off-screen
        if WindowManager.isPositionOffScreen(currentFrame.origin, on: screen) {
            let newPosition = WindowManager.calculateRecoveryPosition(
                from: currentFrame.origin,
                toFitIn: visibleFrame,
                windowSize: currentFrame.size
            )
            let newFrame = CGRect(origin: newPosition, size: currentFrame.size)
            return setWindowFrame(focusedWindow, frame: newFrame)
        }

        return false
    }

    /// Maximizes the focused window to fill the visible area
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func maximizeFocusedWindow() -> Bool {
        guard canTileFocusedWindow() else {
            return false
        }

        guard let focusedWindow = getFocusedWindow() else {
            return false
        }

        guard let screen = getScreenForWindow(focusedWindow) else {
            return false
        }

        let maximizeFrame = WindowManager.calculateMaximizeFrame(on: screen.visibleFrame)
        return setWindowFrame(focusedWindow, frame: maximizeFrame)
    }

    /// Resizes the focused window to specific dimensions
    /// - Parameters:
    ///   - width: Target width
    ///   - height: Target height
    ///   - maintainPosition: Whether to maintain the current position
    /// - Returns: True if successful, false otherwise
    @discardableResult
    func resizeFocusedWindow(to width: CGFloat, height: CGFloat, maintainPosition: Bool = true) -> Bool {
        guard let focusedWindow = getFocusedWindow() else {
            return false
        }

        let targetSize = CGSize(width: width, height: height)

        if maintainPosition {
            guard let currentFrame = getWindowFrame(focusedWindow) else {
                return false
            }
            let newFrame = WindowManager.calculateFrameForResize(to: targetSize, originalPosition: currentFrame.origin)
            return setWindowFrame(focusedWindow, frame: newFrame)
        } else {
            // Center on screen when not maintaining position
            guard let screen = getScreenForWindow(focusedWindow) else {
                return false
            }
            let centerPosition = WindowManager.calculateCenterPosition(for: targetSize, on: screen.visibleFrame)
            let newFrame = CGRect(origin: centerPosition, size: targetSize)
            return setWindowFrame(focusedWindow, frame: newFrame)
        }
    }

    // MARK: - Private: Window Size Helper

    /// Gets the size of a window
    private func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var sizeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

        guard result == .success, let szValue = sizeValue else {
            return nil
        }

        var size = CGSize.zero
        // AXValue is a CFType, we can use it directly
        let axValue = szValue as! AXValue
        AXValueGetValue(axValue, .cgSize, &size)

        return size
    }

    // MARK: - Private: Accessibility API

    /// Gets the currently focused window using Accessibility API
    private func getFocusedWindow() -> AXUIElement? {
        // Get the frontmost application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

        // Get the focused window
        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard result == .success, let window = focusedWindow else {
            return nil
        }

        // AXUIElement is a CFType, we can use it directly
        return window as! AXUIElement
    }

    /// Checks if a window is in full-screen mode
    private func isWindowFullScreen(_ window: AXUIElement) -> Bool {
        // Check for full-screen attribute
        var isFullScreen: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &isFullScreen)

        if result == .success, let fullScreen = isFullScreen as? Bool {
            return fullScreen
        }

        // Also check by comparing window frame to screen frame
        if let windowFrame = getWindowFrame(window),
           let screen = getScreenForWindow(window)
        {
            // If window frame matches screen frame closely, it's likely full-screen
            let tolerance: CGFloat = 5
            return abs(windowFrame.width - screen.frame.width) < tolerance &&
                abs(windowFrame.height - screen.frame.height) < tolerance
        }

        return false
    }

    /// Gets the current frame of a window
    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let posResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

        guard posResult == .success, sizeResult == .success else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        if let posValue = positionValue {
            // AXValue is a CFType, we can use it directly
            let axPosValue = posValue as! AXValue
            AXValueGetValue(axPosValue, .cgPoint, &position)
        }
        if let szValue = sizeValue {
            // AXValue is a CFType, we can use it directly
            let axSizeValue = szValue as! AXValue
            AXValueGetValue(axSizeValue, .cgSize, &size)
        }

        return CGRect(origin: position, size: size)
    }

    /// Sets the frame of a window
    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
        // Set position
        var position = frame.origin
        guard let positionValue = AXValueCreate(.cgPoint, &position) else {
            return false
        }

        let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)

        // Set size
        var size = frame.size
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }

        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)

        return posResult == .success && sizeResult == .success
    }

    /// Gets the screen containing a window
    private func getScreenForWindow(_ window: AXUIElement) -> NSScreen? {
        guard let windowFrame = getWindowFrame(window) else {
            return NSScreen.main
        }

        // Find the screen that contains the center of the window
        let windowCenter = CGPoint(
            x: windowFrame.origin.x + windowFrame.width / 2,
            y: windowFrame.origin.y + windowFrame.height / 2
        )

        return WindowManager.screen(containing: windowCenter)
    }
}
