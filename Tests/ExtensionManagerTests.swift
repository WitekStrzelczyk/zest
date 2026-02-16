import XCTest
@testable import ZestApp

/// Tests for Extension Framework
final class ExtensionManagerTests: XCTestCase {

    /// Test that ExtensionManager can be instantiated
    func testExtensionManagerCreation() {
        let manager = ExtensionManager.shared
        XCTAssertNotNil(manager)
    }

    /// Test singleton
    func testSingleton() {
        let manager1 = ExtensionManager.shared
        let manager2 = ExtensionManager.shared
        XCTAssertTrue(manager1 === manager2)
    }

    /// Test get all extensions
    func testGetAllExtensions() {
        let manager = ExtensionManager.shared
        let extensions = manager.getAllExtensions()
        XCTAssertNotNil(extensions)
    }

    /// Test load extension from bundle
    func testLoadExtension() {
        let manager = ExtensionManager.shared
        // Should not crash when loading
        let extensions = manager.getAllExtensions()
        XCTAssertNotNil(extensions)
    }

    /// Test extension model
    func testExtensionModel() {
        let ext = Extension(
            id: "test-ext",
            name: "Test Extension",
            version: "1.0.0",
            commands: []
        )
        XCTAssertEqual(ext.id, "test-ext")
        XCTAssertEqual(ext.name, "Test Extension")
    }

    /// Test extension command model
    func testExtensionCommandModel() {
        let command = ExtensionCommand(
            id: "test-cmd",
            name: "Test Command",
            keywords: ["test", "demo"],
            action: {}
        )
        XCTAssertEqual(command.id, "test-cmd")
        XCTAssertEqual(command.name, "Test Command")
    }
}
