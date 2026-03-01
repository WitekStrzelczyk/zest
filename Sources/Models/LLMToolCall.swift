import Foundation

// MARK: - LLM Tool Definitions

/// Represents a tool that can be called by the LLM parser
enum LLMTool: String, CaseIterable {
    case createCalendarEvent = "create_calendar_event"
    case findFiles = "find_files"
    case convertUnits = "convert_units"
    case translate = "translate"

    /// Human-readable description of the tool
    var description: String {
        switch self {
        case .createCalendarEvent:
            return "Create a calendar event"
        case .findFiles:
            return "Search for files"
        case .convertUnits:
            return "Convert units of measurement"
        case .translate:
            return "Translate text between languages"
        }
    }

    /// SF Symbol icon for the tool
    var iconName: String {
        switch self {
        case .createCalendarEvent:
            return "calendar.badge.plus"
        case .findFiles:
            return "folder.badge.questionmark"
        case .convertUnits:
            return "ruler"
        case .translate:
            return "character.bubble"
        }
    }
}

// MARK: - Tool Parameters

/// Parameters for creating a calendar event
struct CreateCalendarEventParams: Equatable {
    let title: String
    let date: String?
    let time: String?
    let location: String?
    let contact: String?

    init(title: String, date: String? = nil, time: String? = nil, location: String? = nil, contact: String? = nil) {
        self.title = title
        self.date = date
        self.time = time
        self.location = location
        self.contact = contact
    }
}

/// Parameters for finding files
struct FindFilesParams: Equatable {
    let query: String
    let searchInContent: Bool
    let fileExtension: String?
    let modifiedWithin: Int?

    init(query: String, searchInContent: Bool = false, fileExtension: String? = nil, modifiedWithin: Int? = nil) {
        self.query = query
        self.searchInContent = searchInContent
        self.fileExtension = fileExtension
        self.modifiedWithin = modifiedWithin
    }
}

/// Parameters for unit conversion
struct UnitConversionParams: Equatable {
    let value: Double
    let fromUnit: String
    let toUnit: String
    let category: String?

    init(value: Double, fromUnit: String, toUnit: String, category: String? = nil) {
        self.value = value
        self.fromUnit = fromUnit
        self.toUnit = toUnit
        self.category = category
    }
}

/// Parameters for translation
struct TranslationParams: Equatable {
    let text: String
    let targetLanguage: String
    let sourceLanguage: String?  // nil = auto-detect

    init(text: String, targetLanguage: String, sourceLanguage: String? = nil) {
        self.text = text
        self.targetLanguage = targetLanguage
        self.sourceLanguage = sourceLanguage
    }
}

// MARK: - Tool Call Result

/// A parsed tool call with its parameters
struct LLMToolCall: Equatable {
    let tool: LLMTool
    let parameters: ToolParameters
    let confidence: Double // 0.0 to 1.0

    /// Parameters can be one of the supported types
    enum ToolParameters: Equatable {
        case createCalendarEvent(CreateCalendarEventParams)
        case findFiles(FindFilesParams)
        case convertUnits(UnitConversionParams)
        case translate(TranslationParams)

        /// Whether all required parameters are present
        var isComplete: Bool {
            switch self {
            case .createCalendarEvent(let params):
                return !params.title.isEmpty
            case .findFiles(let params):
                return !params.query.isEmpty
            case .convertUnits(let params):
                return params.value != 0 && !params.fromUnit.isEmpty && !params.toUnit.isEmpty
            case .translate(let params):
                return !params.text.isEmpty && !params.targetLanguage.isEmpty
            }
        }
    }

    /// Create a tool call for calendar event
    static func createCalendarEvent(
        title: String,
        date: String? = nil,
        time: String? = nil,
        location: String? = nil,
        contact: String? = nil,
        confidence: Double = 1.0
    ) -> LLMToolCall {
        let params = CreateCalendarEventParams(title: title, date: date, time: time, location: location, contact: contact)
        return LLMToolCall(tool: .createCalendarEvent, parameters: .createCalendarEvent(params), confidence: confidence)
    }

    /// Create a tool call for file search
    static func findFiles(
        query: String,
        searchInContent: Bool = false,
        fileExtension: String? = nil,
        modifiedWithin: Int? = nil,
        confidence: Double = 1.0
    ) -> LLMToolCall {
        let params = FindFilesParams(query: query, searchInContent: searchInContent, fileExtension: fileExtension, modifiedWithin: modifiedWithin)
        return LLMToolCall(tool: .findFiles, parameters: .findFiles(params), confidence: confidence)
    }

    /// Create a tool call for unit conversion
    static func convertUnits(
        value: Double,
        fromUnit: String,
        toUnit: String,
        category: String? = nil,
        confidence: Double = 1.0
    ) -> LLMToolCall {
        let params = UnitConversionParams(value: value, fromUnit: fromUnit, toUnit: toUnit, category: category)
        return LLMToolCall(tool: .convertUnits, parameters: .convertUnits(params), confidence: confidence)
    }

    /// Create a tool call for translation
    static func translate(
        text: String,
        targetLanguage: String,
        sourceLanguage: String? = nil,
        confidence: Double = 1.0
    ) -> LLMToolCall {
        let params = TranslationParams(text: text, targetLanguage: targetLanguage, sourceLanguage: sourceLanguage)
        return LLMToolCall(tool: .translate, parameters: .translate(params), confidence: confidence)
    }
}
