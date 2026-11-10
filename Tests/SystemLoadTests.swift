import Foundation
import Testing
@testable import ZestApp

@Suite(.serialized)
struct SystemLoadTests {
    private let tool = SystemLoadTool.shared
    private let totalGB = Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824).rounded())

    private func results(_ query: String) -> [SearchResult] {
        tool.search(QueryAnalyzer.shared.analyze(query))
    }

    private func measured(_ query: String) -> [SearchResult] {
        SystemLoadService.shared.measure()
        return results(query)
    }

    @Test func memoryShowsHowMuchOfTheMacsRAMIsUsed() throws {
        let memory = try #require(results("memory").first)

        #expect(memory.title.wholeMatch(of: #/Memory: \d{1,3}% used/#) != nil, "\(memory.title)")
        #expect(memory.subtitle.contains("of \(totalGB) GB"), "\(memory.subtitle)")
        #expect(memory.subtitle.contains("Pressure"), "\(memory.subtitle)")
    }

    @Test func ramAndShortPrefixesAlsoShowMemory() {
        #expect(results("ram").first?.title.hasPrefix("Memory:") == true)
        #expect(results("mem").first?.title.hasPrefix("Memory:") == true)
    }

    @Test func wordsThatOnlyContainRamOrCpuShowNothing() {
        for query in ["program", "ramen", "grammar", "cpus are cool"] {
            #expect(results(query).isEmpty, "\(query) should not wake the memory or CPU overview")
        }
    }

    @Test func cpuShowsHowBusyTheMacIsAndItsCores() throws {
        let cpu = try #require(measured("cpu").first)

        #expect(cpu.title.wholeMatch(of: #/CPU: \d{1,3}%/#) != nil, "\(cpu.title)")
        #expect(cpu.subtitle.contains("\(ProcessInfo.processInfo.activeProcessorCount) cores"), "\(cpu.subtitle)")
        #expect(cpu.subtitle.contains("Load"), "\(cpu.subtitle)")
    }

    @Test func loadAndCpuUsageAlsoShowCPU() {
        #expect(results("cpu usage").first?.title.hasPrefix("CPU:") == true)
        #expect(results("load").first?.title.hasPrefix("CPU:") == true)
    }

    @Test func cpuListsTheBusiestAppsBusiestFirst() throws {
        let apps = Array(measured("cpu").dropFirst())

        #expect((1...3).contains(apps.count), "\(apps.map(\.title))")
        let percents = try apps.map { app in
            let match = try #require(app.title.firstMatch(of: #/: (\d+)% CPU$/#), "\(app.title)")
            return try #require(Int(match.1))
        }
        #expect(percents == percents.sorted(by: >))
        #expect(apps.allSatisfy { $0.subtitle.contains("process") })
    }

    @Test func memoryListsTheAppsUsingTheMostMemoryBiggestFirst() throws {
        let apps = Array(measured("memory").dropFirst().filter { !$0.title.hasPrefix("⚠️") })

        #expect((1...3).contains(apps.count), "\(apps.map(\.title))")
        let sizes = try apps.map { app in
            let match = try #require(app.title.firstMatch(of: #/: ([\d.]+) (GB|MB)$/#), "\(app.title)")
            let value = try #require(Double(match.1))
            return match.2 == "GB" ? value * 1024 : value
        }
        #expect(sizes == sizes.sorted(by: >))
        #expect(apps.allSatisfy { $0.subtitle.contains("% of memory") })
    }

    @Test func helperProcessesCountTowardsTheirApp() {
        let titles = measured("memory").map(\.title) + results("cpu").map(\.title)

        #expect(!titles.contains { $0.localizedCaseInsensitiveContains("helper") }, "\(titles)")
    }

    @Test func otherUsersProcessesAreNeverListed() {
        let titles = measured("memory").map(\.title) + results("cpu").map(\.title)

        for systemProcess in ["kernel_task", "WindowServer", "launchd", "mds_stores"] {
            #expect(!titles.contains { $0.hasPrefix("\(systemProcess):") }, "\(titles)")
        }
    }
}
