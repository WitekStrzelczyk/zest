import Testing
@testable import ZestApp

struct CalculatorTests {
    private func answer(_ query: String) -> String? {
        Calculator.shared.search(QueryAnalyzer.shared.analyze(query)).first?.title
    }

    @Test func pastingAUUIDShowsNoAnswerInsteadOfCrashing() {
        #expect(answer("5E647DC2-E504-4656-8AD7-E31F5424B685") == nil)
    }

    @Test func hyphenatedWordsAreNotMaths() {
        #expect(answer("release-notes") == nil)
        #expect(answer("time-zone") == nil)
    }

    @Test func unsupportedOperatorsShowNoAnswerInsteadOfCrashing() {
        #expect(answer("10 % 3") == nil)
        #expect(answer("sin(1)+1") == nil)
    }

    @Test func everydaySumsStillWork() {
        #expect(answer("2+2") == "4")
        #expect(answer("(2+3)*4") == "20")
        #expect(answer("sqrt(16)+1") == "5")
    }

    @Test func piAndEStillWork() {
        #expect(answer("pi*2")?.hasPrefix("6.28") == true)
        #expect(answer("e*1")?.hasPrefix("2.718") == true)
    }
}
