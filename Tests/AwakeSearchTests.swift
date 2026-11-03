import AppKit
import Testing
@testable import ZestApp

@MainActor
final class AwakeSearchTests {
    init() {
        AwakeService.shared.disable()
    }

    isolated deinit {
        AwakeService.shared.disable()
    }

    @Test func testAwakeModeEnum() {
        #expect(AwakeMode.disabled == .disabled)
        #expect(AwakeMode.system == .system)
        #expect(AwakeMode.full == .full)
    }

    @Test func testAwakeService_stateTransitions() {
        let service = AwakeService.shared
        
        #expect(service.currentMode == .disabled)
        #expect(!service.isActive(mode: .system))
        #expect(!service.isActive(mode: .full))
        
        service.enable(mode: .system)
        #expect(service.currentMode == .system)
        #expect(service.isActive(mode: .system))
        #expect(!service.isActive(mode: .full))
        
        service.enable(mode: .full)
        #expect(service.currentMode == .full)
        #expect(!service.isActive(mode: .system))
        #expect(service.isActive(mode: .full))
        
        service.disable()
        #expect(service.currentMode == .disabled)
        #expect(!service.isActive(mode: .system))
        #expect(!service.isActive(mode: .full))
    }

    @Test func testToggle_behavior() {
        let service = AwakeService.shared
        
        service.toggle(mode: .system)
        #expect(service.currentMode == .system)
        
        service.toggle(mode: .system)
        #expect(service.currentMode == .disabled)
        
        service.toggle(mode: .full)
        #expect(service.currentMode == .full)
        
        service.toggle(mode: .system)
        #expect(service.currentMode == .system)
    }
}
