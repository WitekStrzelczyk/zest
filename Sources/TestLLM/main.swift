import Foundation
import Hub
import MLX
import MLXLLM
import MLXLMCommon
import MLXNN

// Minimal LLM test using ChatSession like the real app

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("Usage: TestLLM \"phrase to test\"")
    exit(1)
}

let phrase = args[1]

print("🧪 Testing: \"\(phrase)\"")

@MainActor
func run() async {
    print("📦 Loading model...")

    let modelId = "mlx-community/Llama-3.2-3B-Instruct-4bit"

    do {
        let hub = HubApi()

        let config = ModelConfiguration(
            id: modelId
        )
        let context = try await MLXLMCommon.loadModel(hub: hub, configuration: config)

        print("✅ Model loaded!")

        // Create chat session
        var params = GenerateParameters()
        params.temperature = 0.1
        params.maxTokens = 256
        params.repetitionPenalty = 1.0

        let chat = ChatSession(context, generateParameters: params)

        // Build prompt
        let prompt = buildPrompt(for: phrase)
        print("\n📝 Prompt sent to LLM:")
        print(prompt)
        print("\n---")

        print("⏳ Generating response...")

        // Generate
        let response = try await chat.respond(to: prompt)

        print("\n📥 LLM Raw Response:")
        print(response)

        // Check if function call detected
        if response.contains("find_files") {
            print("\n✅ Detected: find_files")
        } else if response.contains("create_calendar_event") {
            print("\n✅ Detected: create_calendar_event")
        } else if response.contains("convert_units") {
            print("\n✅ Detected: convert_units")
        } else if response.contains("translate") {
            print("\n✅ Detected: translate")
        } else {
            print("\n❌ No function call detected!")
        }

    } catch {
        print("❌ Error: \(error)")
    }
}

func buildPrompt(for userInput: String) -> String {
    let functions = """
    <start_function_declaration>declaration:create_calendar_event{description:Create a calendar event.,parameters:{properties:{title:{description:Event title.,type:STRING},date:{description:Date for the event (e.g., "tomorrow", "March 10").,type:STRING},time:{description:Time for the event (e.g., "4pm", "14:30").,type:STRING},location:{description:Event location.,type:STRING},contact:{description:Contact person.,type:STRING}},required:[title],type:OBJECT}}<end_function_declaration>
    <start_function_declaration>declaration:find_files{description:Search for files.,parameters:{properties:{query:{description:Search query.,type:STRING},search_in_content:{description:Search within file contents.,type:BOOLEAN},file_extension:{description:File extension without dot.,type:STRING},modified_within:{description:Modified within the last N hours.,type:INTEGER}},required:[query],type:OBJECT}}<end_function_declaration>
    <start_function_declaration>declaration:convert_units{description:Convert values between units of measurement.,parameters:{properties:{value:{description:Numeric value to convert.,type:NUMBER},from_unit:{description:Source unit (e.g., "km", "pounds", "celsius").,type:STRING},to_unit:{description:Target unit (e.g., "miles", "kg", "fahrenheit").,type:STRING},category:{description:Category hint: "length", "weight", "temperature", "volume".,type:STRING}},required:[value,from_unit,to_unit],type:OBJECT}}<end_function_declaration>
    <start_function_declaration>declaration:translate{description:Translate text between languages.,parameters:{properties:{text:{description:Text to translate.,type:STRING},target_language:{description:Target language (e.g., "spanish", "french", "german").,type:STRING},source_language:{description:Source language (optional, auto-detect if not specified).,type:STRING}},required:[text,target_language],type:OBJECT}}<end_function_declaration>
    """

    let examples = """
    Example 1:
    user: "find pdf files"
    response: <start_function_call>find_files(query:"*",file_extension:"pdf")<end_function_call>

    Example 2:
    user: "meeting tomorrow at 3pm"
    response: <start_function_call>create_calendar_event(title:"Meeting",date:"tomorrow",time:"3pm")<end_function_call>

    Example 3:
    user: "convert 100 fahrenheit to celsius"
    response: <start_function_call>convert_units(value:100,from_unit:"fahrenheit",to_unit:"celsius")<end_function_call>
    """

    return """
    <start_of_turn>developer
    You are a function calling assistant. Your ONLY task is to call one of the available functions with the correct parameters based on user input.
    You MUST respond with a function call in the format <start_function_call>function_name(params)<end_function_call>.
    \(examples)
    Available functions:
    \(functions)
    <end_of_turn>
    <start_of_turn>user
    \(userInput)
    <end_of_turn>
    <start_of_turn>model
    """
}

// Run
await run()
