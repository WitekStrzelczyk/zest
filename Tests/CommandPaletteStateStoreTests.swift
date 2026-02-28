import XCTest
@testable import ZestApp

@MainActor
final class CommandPaletteStateStoreTests: XCTestCase {
    func testSetIntentContextForCalendarCreatesGenericEntities() {
        let store = CommandPaletteStateStore.shared
        store.clearIntent()

        let toolCall = LLMToolCall.createCalendarEvent(
            title: "Meeting with Scott",
            date: "Tomorrow",
            time: "4pm",
            location: "Sunshine Coast Plaza",
            contact: "Scott Mayer",
            confidence: 0.9
        )

        store.setIntentContext(from: toolCall, rawQuery: "meeting tomorrow with Scott")

        let context = store.state.intentContext
        XCTAssertNotNil(context)
        XCTAssertEqual(context?.intent, .createCalendar)
        XCTAssertEqual(context?.entities.first(where: { $0.type == .contact })?.value, "Scott Mayer")
        XCTAssertEqual(context?.entities.first(where: { $0.type == .location })?.value, "Sunshine Coast Plaza")
        XCTAssertEqual(context?.entities.first(where: { $0.type == .date })?.value, "Tomorrow")
        XCTAssertEqual(context?.entities.first(where: { $0.type == .title })?.value, "Meeting with Scott")
    }

    func testSetIntentContextForFindFilesCreatesFilterEntities() {
        let store = CommandPaletteStateStore.shared
        store.clearIntent()

        let toolCall = LLMToolCall.findFiles(
            query: "*",
            searchInContent: false,
            fileExtension: "pdf",
            modifiedWithin: 12,
            confidence: 0.9
        )

        store.setIntentContext(from: toolCall, rawQuery: "pdf files modified today")

        let context = store.state.intentContext
        XCTAssertNotNil(context)
        XCTAssertEqual(context?.intent, .findFiles)
        XCTAssertEqual(context?.entities.first(where: { $0.type == .query })?.value, "*")
        XCTAssertEqual(context?.entities.first(where: { $0.type == .fileExtension })?.value, "pdf")
        XCTAssertEqual(context?.entities.first(where: { $0.type == .modifiedWithinHours })?.value, "12")
    }
}
