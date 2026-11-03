import AppKit
import Testing
@testable import ZestApp

@MainActor
final class AwakeServiceTests {
    init() {
        AwakeService.shared.disable()
    }

    isolated deinit {
        AwakeService.shared.disable()
    }

    @Test func testAwakeServiceCreation() {
        _ = AwakeService.shared
    }

    @Test func testSingleton() {
        let service1 = AwakeService.shared
        let service2 = AwakeService.shared
        #expect(service1 === service2)
    }

    @Test func testInitialStateIsDisabled() {
        let service = AwakeService.shared
        #expect(service.currentMode == .disabled)
    }

    @Test func testToggleSystemAwake_turnsOn() {
        let service = AwakeService.shared
        #expect(service.currentMode == .disabled)
        
        service.toggle(mode: .system)
        
        #expect(service.currentMode == .system)
    }

    @Test func testToggleSystemAwake_turnsOff() {
        let service = AwakeService.shared
        service.toggle(mode: .system)
        #expect(service.currentMode == .system)
        
        service.toggle(mode: .system)
        
        #expect(service.currentMode == .disabled)
    }

    @Test func testToggleFullAwake_turnsOn() {
        let service = AwakeService.shared
        #expect(service.currentMode == .disabled)
        
        service.toggle(mode: .full)
        
        #expect(service.currentMode == .full)
    }

    @Test func testToggleFullAwake_turnsOff() {
        let service = AwakeService.shared
        service.toggle(mode: .full)
        #expect(service.currentMode == .full)
        
        service.toggle(mode: .full)
        
        #expect(service.currentMode == .disabled)
    }

    @Test func testSwitchFromSystemToFull() {
        let service = AwakeService.shared
        service.toggle(mode: .system)
        #expect(service.currentMode == .system)
        
        service.toggle(mode: .full)
        
        #expect(service.currentMode == .full)
    }

    @Test func testSwitchFromFullToSystem() {
        let service = AwakeService.shared
        service.toggle(mode: .full)
        #expect(service.currentMode == .full)
        
        service.toggle(mode: .system)
        
        #expect(service.currentMode == .system)
    }

    @Test func testDisable_turnsOffActiveMode() {
        let service = AwakeService.shared
        service.toggle(mode: .full)
        #expect(service.currentMode == .full)
        
        service.disable()
        
        #expect(service.currentMode == .disabled)
    }

    @Test func testIsActive_returnsCorrectState() {
        let service = AwakeService.shared
        
        #expect(!service.isActive(mode: .system))
        #expect(!service.isActive(mode: .full))
        
        service.toggle(mode: .system)
        #expect(service.isActive(mode: .system))
        #expect(!service.isActive(mode: .full))
        
        service.toggle(mode: .full)
        #expect(!service.isActive(mode: .system))
        #expect(service.isActive(mode: .full))
    }
}
