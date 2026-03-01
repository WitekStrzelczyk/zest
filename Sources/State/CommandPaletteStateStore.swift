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
        let context: ParsedIntentContext
        switch toolCall.parameters {
        case .createCalendarEvent(let params):
            var entities = [ContextEntity(type: .title, value: params.title)]
            if let contact = params.contact { entities.append(ContextEntity(type: .contact, value: contact)) }
            if let location = params.location { entities.append(ContextEntity(type: .location, value: location)) }
            if let date = params.date { entities.append(ContextEntity(type: .date, value: date)) }
            if let time = params.time { entities.append(ContextEntity(type: .time, value: time)) }
            context = ParsedIntentContext(
                intent: .createCalendar,
                entities: entities,
                confidence: toolCall.confidence,
                rawQuery: rawQuery
            )
        case .findFiles(let params):
            var entities = [ContextEntity(type: .query, value: params.query)]
            if let fileExtension = params.fileExtension {
                entities.append(ContextEntity(type: .fileExtension, value: fileExtension))
            }
            if let modifiedWithin = params.modifiedWithin {
                entities.append(ContextEntity(type: .modifiedWithinHours, value: String(modifiedWithin)))
            }
            context = ParsedIntentContext(
                intent: .findFiles,
                entities: entities,
                confidence: toolCall.confidence,
                rawQuery: rawQuery
            )
        case .convertUnits(let params):
            var entities = [
                ContextEntity(type: .value, value: String(params.value)),
                ContextEntity(type: .fromUnit, value: params.fromUnit),
                ContextEntity(type: .toUnit, value: params.toUnit)
            ]
            if let category = params.category {
                entities.append(ContextEntity(type: .category, value: category))
            }
            context = ParsedIntentContext(
                intent: .convertUnits,
                entities: entities,
                confidence: toolCall.confidence,
                rawQuery: rawQuery
            )
        case .translate(let params):
            var entities = [
                ContextEntity(type: .sourceText, value: params.text),
                ContextEntity(type: .targetLanguage, value: params.targetLanguage)
            ]
            if let sourceLanguage = params.sourceLanguage {
                entities.append(ContextEntity(type: .sourceLanguage, value: sourceLanguage))
            }
            context = ParsedIntentContext(
                intent: .translate,
                entities: entities,
                confidence: toolCall.confidence,
                rawQuery: rawQuery
            )
        }
        state.intentContext = context
        notify()
    }

    private func notify() {
        NotificationCenter.default.post(
            name: .commandPaletteStateDidChange,
            object: self,
            userInfo: [commandPaletteStateUserInfoKey: state]
        )
    }
}
