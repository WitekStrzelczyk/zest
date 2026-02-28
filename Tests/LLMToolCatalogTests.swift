import XCTest
@testable import ZestApp

final class LLMToolCatalogTests: XCTestCase {
    func testFallbackParseCalendarIntent() {
        let input = "meeting tomorrow with Witek at 4pm in the Cinema"
        let toolCall = LLMToolCatalog.fallbackParse(input: input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .createCalendarEvent)
    }

    func testFallbackParseFileIntentWithHoursAgo() {
        let input = "files modified 2 hours ago"
        let toolCall = LLMToolCatalog.fallbackParse(input: input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .findFiles)
        guard case .findFiles(let params) = toolCall?.parameters else {
            XCTFail("Expected file params")
            return
        }
        XCTAssertEqual(params.query, "*")
        XCTAssertEqual(params.modifiedWithin, 2)
    }

    func testMapPayloadToToolCallForFindFiles() {
        let payload: [String: Any] = [
            "query": "report",
            "search_in_content": true,
            "file_extension": "pdf",
            "modified_within": 6,
        ]
        let toolCall = LLMToolCatalog.mapPayloadToToolCall(
            toolName: "find_files",
            fields: payload,
            originalInput: "find recent report files"
        )

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .findFiles)
        guard case .findFiles(let params) = toolCall?.parameters else {
            XCTFail("Expected file params")
            return
        }
        XCTAssertEqual(params.query, "report")
        XCTAssertEqual(params.searchInContent, true)
        XCTAssertEqual(params.fileExtension, "pdf")
        XCTAssertEqual(params.modifiedWithin, 6)
    }

    func testFunctionGemmaDeclarationsContainKnownTools() {
        let declarations = LLMToolCatalog.functionGemmaDeclarations
        XCTAssertTrue(declarations.contains("declaration:create_calendar_event"))
        XCTAssertTrue(declarations.contains("declaration:find_files"))
    }

    // MARK: - Unit Conversion Fallback Parsing Tests

    func testFallbackParseUnitConversionKmToMiles() {
        let input = "100 km to miles"
        let toolCall = LLMToolCatalog.fallbackParse(input: input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .convertUnits)
        guard case .convertUnits(let params) = toolCall?.parameters else {
            XCTFail("Expected unit conversion params")
            return
        }
        XCTAssertEqual(params.value, 100.0, accuracy: 0.01)
        XCTAssertEqual(params.fromUnit, "km")
        XCTAssertEqual(params.toUnit, "miles")
    }

    func testFallbackParseUnitConversionFahrenheitToCelsius() {
        let input = "72 f to c"
        let toolCall = LLMToolCatalog.fallbackParse(input: input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .convertUnits)
        guard case .convertUnits(let params) = toolCall?.parameters else {
            XCTFail("Expected unit conversion params")
            return
        }
        XCTAssertEqual(params.value, 72.0, accuracy: 0.01)
        XCTAssertEqual(params.fromUnit, "f")
        XCTAssertEqual(params.toUnit, "c")
    }

    func testFallbackParseUnitConversionConvertKeyword() {
        let input = "convert 50 kg to lbs"
        let toolCall = LLMToolCatalog.fallbackParse(input: input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .convertUnits)
        guard case .convertUnits(let params) = toolCall?.parameters else {
            XCTFail("Expected unit conversion params")
            return
        }
        XCTAssertEqual(params.value, 50.0, accuracy: 0.01)
        XCTAssertEqual(params.fromUnit, "kg")
        XCTAssertEqual(params.toUnit, "lbs")
    }

    func testFallbackParseUnitConversionHowMany() {
        let input = "how many miles in 100 km"
        let toolCall = LLMToolCatalog.fallbackParse(input: input)

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .convertUnits)
        guard case .convertUnits(let params) = toolCall?.parameters else {
            XCTFail("Expected unit conversion params")
            return
        }
        XCTAssertEqual(params.value, 100.0, accuracy: 0.01)
        XCTAssertEqual(params.fromUnit, "km")
        XCTAssertEqual(params.toUnit, "miles")
    }

    func testFallbackParseUnitConversionDoesNotMatchUnknownUnits() {
        let input = "4 pm in the cinema"
        let toolCall = LLMToolCatalog.fallbackParse(input: input)

        // Should NOT match as unit conversion since "pm" and "cinema" are not known units
        // Should return nil since there are no calendar keywords either
        XCTAssertNil(toolCall, "Should not match '4 pm in the cinema' as unit conversion")
    }

    func testMapPayloadToToolCallForConvertUnits() {
        let payload: [String: Any] = [
            "value": 100.0,
            "from_unit": "km",
            "to_unit": "miles",
            "category": "length"
        ]
        let toolCall = LLMToolCatalog.mapPayloadToToolCall(
            toolName: "convert_units",
            fields: payload,
            originalInput: "100 km to miles"
        )

        XCTAssertNotNil(toolCall)
        XCTAssertEqual(toolCall?.tool, .convertUnits)
        guard case .convertUnits(let params) = toolCall?.parameters else {
            XCTFail("Expected unit conversion params")
            return
        }
        XCTAssertEqual(params.value, 100.0, accuracy: 0.01)
        XCTAssertEqual(params.fromUnit, "km")
        XCTAssertEqual(params.toUnit, "miles")
        XCTAssertEqual(params.category, "length")
    }

    func testFunctionGemmaDeclarationsContainConvertUnits() {
        let declarations = LLMToolCatalog.functionGemmaDeclarations
        XCTAssertTrue(declarations.contains("declaration:convert_units"))
    }
}

