import AppKit
import ApplicationServices

final class WindowManager {
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

    static let shared: WindowManager = .init()

    private init() {}

    func canTileFocusedWindow() -> Bool {
        guard let focusedWindow = getFocusedWindow() else {
            return false
        }

        if isWindowFullScreen(focusedWindow) {
            return false
        }

        return true
    }

    @discardableResult
    func tileFocusedWindow(_ option: TilingOption) -> Bool {
        guard canTileFocusedWindow() else {
            return false
        }

        guard let focusedWindow = getFocusedWindow() else {
            return false
        }

        guard let screen = getScreenForWindow(focusedWindow) else {
            return false
        }

        let targetFrame = WindowManager.calculateTileFrame(for: option, on: screen.visibleFrame)

        return setWindowFrame(focusedWindow, frame: targetFrame)
    }

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

    static func screen(containing point: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens where screen.frame.contains(point) {
            return screen
        }
        return NSScreen.main
    }

    static func calculateCenterPosition(for windowSize: CGSize, on screen: CGRect) -> CGPoint {
        let centerX = screen.origin.x + (screen.width - windowSize.width) / 2
        let centerY = screen.origin.y + (screen.height - windowSize.height) / 2
        return CGPoint(x: centerX, y: centerY)
    }

    static func calculateMaximizeFrame(on screen: CGRect) -> CGRect {
        screen
    }

    static func getVisibleFrame(for screen: NSScreen) -> CGRect {
        screen.visibleFrame
    }

    static func isPositionOffScreen(_ position: CGPoint, on screen: NSScreen) -> Bool {
        let screenFrame = screen.frame
        let tolerance: CGFloat = 50

        return position.x < screenFrame.origin.x - tolerance ||
            position.y < screenFrame.origin.y - tolerance ||
            position.x > screenFrame.maxX + tolerance ||
            position.y > screenFrame.maxY + tolerance
    }

    static func calculateRecoveryPosition(
        from position: CGPoint,
        toFitIn visibleFrame: CGRect,
        windowSize: CGSize = CGSize(width: 200, height: 100)
    ) -> CGPoint {
        var newX = position.x
        var newY = position.y

        if newX < visibleFrame.origin.x {
            newX = visibleFrame.origin.x
        } else if newX + windowSize.width > visibleFrame.maxX {
            newX = visibleFrame.maxX - windowSize.width
        }

        if newY < visibleFrame.origin.y {
            newY = visibleFrame.origin.y
        } else if newY + windowSize.height > visibleFrame.maxY {
            newY = visibleFrame.maxY - windowSize.height
        }

        return CGPoint(x: newX, y: newY)
    }

    static func calculateFrameForResize(to targetSize: CGSize, originalPosition: CGPoint) -> CGRect {
        CGRect(origin: originalPosition, size: targetSize)
    }

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
            guard let screen = getScreenForWindow(focusedWindow) else {
                return false
            }
            let centerPosition = WindowManager.calculateCenterPosition(for: targetSize, on: screen.visibleFrame)
            let newFrame = CGRect(origin: centerPosition, size: targetSize)
            return setWindowFrame(focusedWindow, frame: newFrame)
        }
    }

    private func getWindowSize(_ window: AXUIElement) -> CGSize? {
        var sizeValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

        guard result == .success, let szValue = sizeValue else {
            return nil
        }

        var size = CGSize.zero
        let axValue = szValue as! AXValue
        AXValueGetValue(axValue, .cgSize, &size)

        return size
    }

    private func getFocusedWindow() -> AXUIElement? {
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmostApp.processIdentifier)

        var focusedWindow: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow)

        guard result == .success, let window = focusedWindow else {
            return nil
        }

        return (window as! AXUIElement)
    }

    private func isWindowFullScreen(_ window: AXUIElement) -> Bool {
        var isFullScreen: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &isFullScreen)

        if result == .success, let fullScreen = isFullScreen as? Bool {
            return fullScreen
        }

        if let windowFrame = getWindowFrame(window),
           let screen = getScreenForWindow(window)
        {
            let tolerance: CGFloat = 5
            return abs(windowFrame.width - screen.frame.width) < tolerance &&
                abs(windowFrame.height - screen.frame.height) < tolerance
        }

        return false
    }

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
            let axPosValue = posValue as! AXValue
            AXValueGetValue(axPosValue, .cgPoint, &position)
        }
        if let szValue = sizeValue {
            let axSizeValue = szValue as! AXValue
            AXValueGetValue(axSizeValue, .cgSize, &size)
        }

        return CGRect(origin: position, size: size)
    }

    private func setWindowFrame(_ window: AXUIElement, frame: CGRect) -> Bool {
        var position = frame.origin
        guard let positionValue = AXValueCreate(.cgPoint, &position) else {
            return false
        }

        let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionValue)

        var size = frame.size
        guard let sizeValue = AXValueCreate(.cgSize, &size) else {
            return false
        }

        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)

        return posResult == .success && sizeResult == .success
    }

    private func getScreenForWindow(_ window: AXUIElement) -> NSScreen? {
        guard let windowFrame = getWindowFrame(window) else {
            return NSScreen.main
        }

        let windowCenter = CGPoint(
            x: windowFrame.origin.x + windowFrame.width / 2,
            y: windowFrame.origin.y + windowFrame.height / 2
        )

        return WindowManager.screen(containing: windowCenter)
    }
}
