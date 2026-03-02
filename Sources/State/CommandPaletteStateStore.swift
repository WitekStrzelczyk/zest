import Foundation

enum ContextEntityType: String {
    case title
    case contact
    case location
    case date
    case time
    case query
    case fileExtension
    case modifiedWithinHours
    case value
    case fromUnit
    case toUnit
    case category
    case sourceLanguage
    case targetLanguage
    case sourceText
    case translatedText
}

struct ContextEntity {
    let type: ContextEntityType
    let value: String
}

enum IntentType: String {
    case createCalendar
    case findFiles
    case convertUnits
    case translate
}

struct ParsedIntentContext {
    let intent: IntentType
    let entities: [ContextEntity]
    let confidence: Double
    let rawQuery: String
}

struct CommandPaletteState {
    var query: String = ""
    var isLLMMode: Bool = false
    var results: [SearchResult] = []
    var intentContext: ParsedIntentContext?
}

extension Notification.Name {
    static let commandPaletteStateDidChange = Notification.Name("commandPaletteStateDidChange")
}

let commandPaletteStateUserInfoKey = "commandPaletteState"

@MainActor
final class CommandPaletteStateStore {
    static let shared = CommandPaletteStateStore()

    private(set) var state = CommandPaletteState()

    private init() {}

    func updateQuery(_ query: String, isLLMMode: Bool) {
        state.query = query
        state.isLLMMode = isLLMMode
        notify()
    }

    func updateResults(_ results: [SearchResult]) {
        state.results = results
        notify()
    }

    func clearIntent() {
        state.intentContext = nil
        notify()
    }

    func setIntentContext(from toolCall: LLMToolCall, rawQuery: String) {
        let context = buildIntentContext(from: toolCall, rawQuery: rawQuery)
        state.intentContext = context
        notify()
    }

    private func buildIntentContext(from toolCall: LLMToolCall, rawQuery: String) -> ParsedIntentContext {
        switch toolCall.parameters {
        case .createCalendarEvent(let params):
            buildCalendarEventContext(params: params, toolCall: toolCall, rawQuery: rawQuery)
        case .findFiles(let params):
            buildFindFilesContext(params: params, toolCall: toolCall, rawQuery: rawQuery)
        case .convertUnits(let params):
            buildConvertUnitsContext(params: params, toolCall: toolCall, rawQuery: rawQuery)
        case .translate(let params):
            buildTranslateContext(params: params, toolCall: toolCall, rawQuery: rawQuery)
        }
    }

    private func buildCalendarEventContext(
        params: CreateCalendarEventParams,
        toolCall: LLMToolCall,
        rawQuery: String
    ) -> ParsedIntentContext {
        var entities = [ContextEntity(type: .title, value: params.title)]
        addOptionalEntity(value: params.contact, type: .contact, to: &entities)
        addOptionalEntity(value: params.location, type: .location, to: &entities)
        addOptionalEntity(value: params.date, type: .date, to: &entities)
        addOptionalEntity(value: params.time, type: .time, to: &entities)

        return ParsedIntentContext(
            intent: .createCalendar,
            entities: entities,
            confidence: toolCall.confidence,
            rawQuery: rawQuery
        )
    }

    private func buildFindFilesContext(
        params: FindFilesParams,
        toolCall: LLMToolCall,
        rawQuery: String
    ) -> ParsedIntentContext {
        var entities = [ContextEntity(type: .query, value: params.query)]
        addOptionalEntity(value: params.fileExtension, type: .fileExtension, to: &entities)
        addOptionalEntity(value: params.modifiedWithin.map(String.init), type: .modifiedWithinHours, to: &entities)

        return ParsedIntentContext(
            intent: .findFiles,
            entities: entities,
            confidence: toolCall.confidence,
            rawQuery: rawQuery
        )
    }

    private func buildConvertUnitsContext(
        params: UnitConversionParams,
        toolCall: LLMToolCall,
        rawQuery: String
    ) -> ParsedIntentContext {
        var entities = [
            ContextEntity(type: .value, value: String(params.value)),
            ContextEntity(type: .fromUnit, value: params.fromUnit),
            ContextEntity(type: .toUnit, value: params.toUnit),
        ]
        addOptionalEntity(value: params.category, type: .category, to: &entities)

        return ParsedIntentContext(
            intent: .convertUnits,
            entities: entities,
            confidence: toolCall.confidence,
            rawQuery: rawQuery
        )
    }

    private func buildTranslateContext(
        params: TranslationParams,
        toolCall: LLMToolCall,
        rawQuery: String
    ) -> ParsedIntentContext {
        var entities = [
            ContextEntity(type: .sourceText, value: params.text),
            ContextEntity(type: .targetLanguage, value: params.targetLanguage),
        ]
        addOptionalEntity(value: params.sourceLanguage, type: .sourceLanguage, to: &entities)

        return ParsedIntentContext(
            intent: .translate,
            entities: entities,
            confidence: toolCall.confidence,
            rawQuery: rawQuery
        )
    }

    private func addOptionalEntity(value: String?, type: ContextEntityType, to entities: inout [ContextEntity]) {
        if let value {
            entities.append(ContextEntity(type: type, value: value))
        }
    }

    private func notify() {
        NotificationCenter.default.post(
            name: .commandPaletteStateDidChange,
            object: self,
            userInfo: [commandPaletteStateUserInfoKey: state]
        )
    }
}
