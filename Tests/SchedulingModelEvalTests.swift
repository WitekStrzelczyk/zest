import Foundation
import FoundationModels
import Testing

struct SchedulingScenario: Decodable {
    let name: String
    let date: String?
    let time: String?
    let end: String?
    let durationMinutes: Int?
    let place: String?
    let people: [String]?
    let sentences: [String]
}

@Suite(.serialized, .enabled(if: Foundation.ProcessInfo.processInfo.environment["ZEST_MODEL_EVAL"] == "1"))
struct SchedulingModelEvalTests {
    private static let fixtures = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/Scheduling")

    private static let cases = Foundation.ProcessInfo.processInfo.environment["ZEST_MODEL_EVAL_CASES"] ?? "cases.json"

    private static let concurrency = Int(Foundation.ProcessInfo.processInfo.environment["ZEST_MODEL_EVAL_CONCURRENCY"] ?? "") ?? 1

    private static let categoryNames = ["date", "time", "end", "duration", "place", "people"]

    @available(macOS 26.0, *)
    @Test func modelSortsSentencesIntoCalendarCategories() async throws {
        guard case .available = SystemLanguageModel.default.availability else {
            Issue.record("On-device model unavailable: \(SystemLanguageModel.default.availability)")
            return
        }

        let snapshot = try CalendarSnapshot.load(Self.fixtures.appendingPathComponent("calendar.json"))
        let scenarios = try JSONDecoder().decode(
            [SchedulingScenario].self,
            from: Data(contentsOf: Self.fixtures.appendingPathComponent(Self.cases))
        )
        let extraction = CalendarExtraction(snapshot: snapshot)
        guard extraction.calendar.isDate(Date(), inSameDayAs: snapshot.now) else {
            Issue.record("NSDataDetector reads days from the real clock; move the fixture to today")
            return
        }
        let schema = try extraction.schema()
        let options = GenerationOptions(samplingMode: .greedy)
        let instructions = extraction.instructions
        let sentences = scenarios.flatMap(\.sentences)

        print("EVAL instructions:\n\(instructions)\n")
        let wallStarted = Date()
        let replies = try await withThrowingTaskGroup(of: (Int, Double, GeneratedContent).self) { group in
            var replies = [(seconds: Double, content: GeneratedContent)?](repeating: nil, count: sentences.count)
            for (position, sentence) in sentences.enumerated() {
                if position >= Self.concurrency, let (done, seconds, content) = try await group.next() {
                    replies[done] = (seconds, content)
                }
                group.addTask {
                    let session = LanguageModelSession(instructions: instructions)
                    let started = Date()
                    let response = try await session.respond(to: sentence, schema: schema, options: options)
                    return (position, Date().timeIntervalSince(started), response.content)
                }
            }
            for try await (done, seconds, content) in group {
                replies[done] = (seconds, content)
            }
            return replies.compactMap { $0 }
        }
        let wallSeconds = Date().timeIntervalSince(wallStarted)

        var categoryPasses: [String: (passed: Int, total: Int)] = [:]
        var sentencePasses = 0
        var scenarioLines: [String] = []
        var replyIndex = 0

        for scenario in scenarios {
            var scenarioPasses = 0
            var answers: Set<String> = []
            for sentence in scenario.sentences {
                let reply = replies[replyIndex]
                replyIndex += 1
                let draft = try extraction.draft(from: reply.content)
                let categories = extraction.categories(from: draft, sentence: sentence)
                let results = check(categories, against: scenario, calendar: extraction.calendar)
                for (name, problem) in results {
                    let tally = categoryPasses[name] ?? (0, 0)
                    categoryPasses[name] = (tally.passed + (problem == nil ? 1 : 0), tally.total + 1)
                }
                let problems = results.compactMap(\.problem)
                if problems.isEmpty {
                    sentencePasses += 1
                    scenarioPasses += 1
                }
                answers.insert(describe(categories, calendar: extraction.calendar))

                let verdict = problems.isEmpty ? "PASS" : "FAIL \(problems.joined(separator: "; "))"
                print("EVAL [\(String(format: "%.2fs", reply.seconds))] \(verdict) — \(sentence)")
                print("EVAL     → \(categories.title) | \(describe(categories, calendar: extraction.calendar))")
                print("EVAL     \(draft.json)")
                if !problems.isEmpty {
                    Issue.record("\(sentence): \(problems.joined(separator: "; "))")
                }
            }
            scenarioLines.append(
                "\(scenarioPasses)/\(scenario.sentences.count) passed, \(answers.count) distinct answers — \(scenario.name)"
            )
        }

        for line in scenarioLines {
            print("EVAL SCENARIO \(line)")
        }
        for name in Self.categoryNames {
            guard let tally = categoryPasses[name] else { continue }
            print("EVAL CATEGORY \(name): \(tally.passed)/\(tally.total)")
        }
        let sorted = replies.map(\.seconds).sorted()
        print("EVAL SUMMARY sentences: \(sentencePasses)/\(sentences.count) fully right")
        print(
            "EVAL SUMMARY latency median \(String(format: "%.2fs", sorted[sorted.count / 2]))"
                + " max \(String(format: "%.2fs", sorted.last ?? 0))"
                + ", wall \(String(format: "%.0fs", wallSeconds)) with \(Self.concurrency) at once"
        )
    }

    @available(macOS 26.0, *)
    private func check(
        _ categories: CalendarCategories,
        against expected: SchedulingScenario,
        calendar: Calendar
    ) -> [(name: String, problem: String?)] {
        let day = categories.day.map { CalendarExtraction.format($0, "yyyy-MM-dd", calendar) }
        let time = categories.start.map { CalendarExtraction.format($0, "HH:mm", calendar) }
        let end = categories.end.map { CalendarExtraction.format($0, "HH:mm", calendar) }
        var results: [(name: String, problem: String?)] = [
            ("date", compare("date", day, expected.date)),
            ("time", compare("time", time, expected.time)),
            ("duration", compare("duration", categories.durationMinutes.map(String.init), expected.durationMinutes.map(String.init))),
            ("place", placeProblem(categories.place, expected.place)),
        ]
        if let want = expected.end {
            results.append(("end", compare("end", end, want)))
        }
        if let want = expected.people {
            results.append(("people", peopleProblem(categories.people, want)))
        }
        return results
    }

    private func compare(_ name: String, _ got: String?, _ want: String?) -> String? {
        got == want ? nil : "\(name) \(got ?? "missing"), want \(want ?? "missing")"
    }

    private func placeProblem(_ got: String?, _ want: String?) -> String? {
        switch (got, want) {
        case (nil, nil): nil
        case let (got?, want?) where got.localizedCaseInsensitiveContains(want): nil
        default: "place '\(got ?? "")', want '\(want ?? "")'"
        }
    }

    private func peopleProblem(_ got: [String], _ want: [String]) -> String? {
        let missing = want.filter { name in !got.contains { $0.localizedCaseInsensitiveContains(name) } }
        let extra = got.filter { name in !want.contains { name.localizedCaseInsensitiveContains($0) } }
        return missing.isEmpty && extra.isEmpty ? nil : "people \(got), want \(want)"
    }

    @available(macOS 26.0, *)
    private func describe(_ categories: CalendarCategories, calendar: Calendar) -> String {
        let day = categories.day.map { CalendarExtraction.format($0, "EEE d MMM", calendar) } ?? "date?"
        let time = categories.start.map { CalendarExtraction.format($0, "HH:mm", calendar) } ?? "time?"
        let duration = categories.durationMinutes.map { "\($0) min" } ?? "duration?"
        return "\(day) \(time) | \(duration) | place \(categories.place ?? "-")"
            + " | people \(categories.people)"
    }
}
