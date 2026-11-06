import Foundation
import Testing
@testable import ZestApp

@Suite(.serialized)
final class AccessoryBatteryTests {
    private static let airPodsInCase = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Bluetooth/airpods-in-case.json")

    private let service = BluetoothBatteryService.shared

    init() throws {
        service.update(fromReport: try Data(contentsOf: Self.airPodsInCase))
    }

    @Test func batterySearchShowsAirPodsBudsAndCase() throws {
        let results = BatteryService.shared.search(query: "battery")

        let airPods = try #require(results.first { $0.title.hasPrefix("Witek’s AirPods Pro 3") })
        #expect(airPods.title == "Witek’s AirPods Pro 3: 96%")
        #expect(airPods.subtitle.contains("Left 96%"))
        #expect(airPods.subtitle.contains("Right 96%"))
        #expect(airPods.subtitle.contains("Case 23%"))
    }

    @Test func airPodsOutOfRangeAreMarkedAsLastKnown() throws {
        let results = BatteryService.shared.search(query: "battery")

        let airPods = try #require(results.first { $0.title.hasPrefix("Witek’s AirPods Pro 3") })
        #expect(airPods.subtitle.contains("Last known"), "Levels of a disconnected device are only the last reading")
    }

    @Test func devicesThatReportNoBatteryAreLeftOut() {
        let titles = BatteryService.shared.search(query: "battery").map(\.title)

        #expect(!titles.contains { $0.hasPrefix("WH-1000XM6") })
        #expect(!titles.contains { $0.hasPrefix("Witold’s iPhone") })
        #expect(!titles.contains { $0.hasPrefix("AirPods Pro:") })
    }

    @Test func theMacBatteryStaysFirst() throws {
        let first = try #require(BatteryService.shared.search(query: "battery").first)

        #expect(first.title.hasPrefix("Battery"))
    }

    @Test func otherQueriesDoNotShowAccessoryBatteries() {
        let results = BatteryService.shared.search(query: "airdrop")

        #expect(results.isEmpty)
    }
}
