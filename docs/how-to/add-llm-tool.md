# Adding a New LLM Tool

How to add a new LLM-powered tool to Zest's natural language command system.

---
last_reviewed: 2026-02-28
review_cycle: quarterly
status: current
---

## Quick Start

Add a new LLM tool in 4 steps:

1. **Define parameters struct** in `LLMToolCall.swift`
2. **Add case to enum** in `LLMToolCall.swift`
3. **Update tool schema** in `LLMToolCatalog.swift`
4. **Add execution logic** in `LLMToolExecutor.swift`

## Architecture Overview

```
User types: "=find pdf files"
    ↓
CommandPaletteWindow.handleLLMMode()
    ↓
LLMToolCallingService.parseWithLLM()
    ↓
MLXLLMService.parseToolCall() → FunctionGemma model inference
    ↓
Returns LLMToolCall (parsed with tool name + parameters)
    ↓
LLMToolExecutor.execute() → Actual system action
```

### Key Files

| File | Purpose |
|------|---------|
| `Sources/Models/LLMToolCall.swift` | Data models for tool definitions |
| `Sources/Services/LLMToolCatalog.swift` | Tool schema + parsing logic |
| `Sources/Services/LLMToolExecutor.swift` | Execution implementation |
| `Sources/Services/MLXLLMService.swift` | LLM inference (FunctionGemma) |
| `Sources/Services/LLMToolCallingService.swift` | Orchestration layer |

### Two-Path Parsing Strategy

The system uses **two parsing paths** for reliability:

1. **LLM Path** (preferred) - FunctionGemma model extracts structured tool calls
2. **Fallback Path** (always available) - Deterministic regex parsing when model fails

Both paths must be implemented for each tool.

---

## Step-by-Step: Adding Unit Converter Tool

### Step 1: Define Parameters Struct

In `Sources/Models/LLMToolCall.swift`, add a parameters struct:

```swift
// MARK: - Tool Parameters

/// Parameters for unit conversion
struct UnitConversionParams: Equatable {
    let value: Double
    let fromUnit: String
    let toUnit: String
    let category: String?  // "length", "weight", "temperature", etc.
    
    init(value: Double, fromUnit: String, toUnit: String, category: String? = nil) {
        self.value = value
        self.fromUnit = fromUnit
        self.toUnit = toUnit
        self.category = category
    }
}
```

### Step 2: Add to LLMTool Enum and ToolParameters

Still in `LLMToolCall.swift`:

**2a. Add tool case:**

```swift
enum LLMTool: String, CaseIterable {
    case createCalendarEvent = "create_calendar_event"
    case findFiles = "find_files"
    case convertUnits = "convert_units"  // ← ADD THIS
    
    var description: String {
        switch self {
        case .createCalendarEvent: return "Create a calendar event"
        case .findFiles: return "Search for files"
        case .convertUnits: return "Convert units of measurement"  // ← ADD THIS
        }
    }
    
    var iconName: String {
        switch self {
        case .createCalendarEvent: return "calendar.badge.plus"
        case .findFiles: return "folder.badge.questionmark"
        case .convertUnits: return "ruler"  // ← ADD THIS
        }
    }
}
```

**2b. Add to ToolParameters enum:**

```swift
enum ToolParameters: Equatable {
    case createCalendarEvent(CreateCalendarEventParams)
    case findFiles(FindFilesParams)
    case convertUnits(UnitConversionParams)  // ← ADD THIS
    
    var isComplete: Bool {
        switch self {
        case .createCalendarEvent(let params):
            return !params.title.isEmpty
        case .findFiles(let params):
            return !params.query.isEmpty
        case .convertUnits(let params):  // ← ADD THIS
            return params.value != 0 && !params.fromUnit.isEmpty && !params.toUnit.isEmpty
        }
    }
}
```

**2c. Add static factory method:**

```swift
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
```

### Step 3: Update Tool Schema in LLMToolCatalog.swift

The schema tells the LLM what tools are available and their parameters.

**3a. Add function declaration to `functionGemmaDeclarations`:**

```swift
static let functionGemmaDeclarations: String = """
<start_function_declaration>declaration:create_calendar_event{description:<escape>Create a calendar event.<escape>,parameters:{properties:{title:{description:<escape>Event title.<escape>,type:<escape>STRING<escape>},date:{description:<escape>Date for the event (e.g., "tomorrow", "March 10").<escape>,type:<escape>STRING<escape>},time:{description:<escape>Time for the event (e.g., "4pm", "14:30").<escape>,type:<escape>STRING<escape>},location:{description:<escape>Event location.<escape>,type:<escape>STRING<escape>},contact:{description:<escape>Contact person.<escape>,type:<escape>STRING<escape>}},required:[<escape>title<escape>],type:<escape>OBJECT<escape>}}<end_function_declaration>
<start_function_declaration>declaration:find_files{description:<escape>Search for files.<escape>,parameters:{properties:{query:{description:<escape>Search query.<escape>,type:<escape>STRING<escape>},search_in_content:{description:<escape>Search within file contents.<escape>,type:<escape>BOOLEAN<escape>},file_extension:{description:<escape>File extension without dot, e.g. "pdf".<escape>,type:<escape>STRING<escape>},modified_within:{description:<escape>Modified within the last N hours.<escape>,type:<escape>INTEGER<escape>}},required:[<escape>query<escape>],type:<escape>OBJECT<escape>}}<end_function_declaration>
<start_function_declaration>declaration:convert_units{description:<escape>Convert values between units of measurement.<escape>,parameters:{properties:{value:{description:<escape>Numeric value to convert.<escape>,type:<escape>NUMBER<escape>},from_unit:{description:<escape>Source unit (e.g., "km", "pounds", "celsius").<escape>,type:<escape>STRING<escape>},to_unit:{description:<escape>Target unit (e.g., "miles", "kg", "fahrenheit").<escape>,type:<escape>STRING<escape>},category:{description:<escape>Category hint: "length", "weight", "temperature", "volume".<escape>,type:<escape>STRING<escape>}},required:[<escape>value<escape>,<escape>from_unit<escape>,<escape>to_unit<escape>],type:<escape>OBJECT<escape>}}<end_function_declaration>
"""
```

**3b. Add fallback parsing in `fallbackParse()`:**

```swift
static func fallbackParse(input: String) -> LLMToolCall? {
    let lower = input.lowercased()
    
    // ... existing patterns ...
    
    // Unit conversion patterns
    if lower.contains("convert") || lower.contains("how many") || 
       lower.contains("what is") && (lower.contains("in") || lower.contains("to")) {
        if let params = inferUnitConversionParams(from: input) {
            return LLMToolCall.convertUnits(
                value: params.value,
                fromUnit: params.fromUnit,
                toUnit: params.toUnit,
                category: params.category,
                confidence: 0.55
            )
        }
    }
    
    return nil
}
```

**3c. Add inference helper:**

```swift
private static func inferUnitConversionParams(from input: String) -> (value: Double, fromUnit: String, toUnit: String, category: String?)? {
    // Pattern: "convert 5 km to miles" or "how many pounds is 10 kg"
    let patterns = [
        #"(?i)convert\s+([\d.]+)\s+(\w+)\s+(?:to|in)\s+(\w+)"#,
        #"(?i)how\s+many\s+(\w+)\s+(?:is|are|in)\s+([\d.]+)\s+(\w+)"#,
        #"(?i)([\d.]+)\s+(\w+)\s+(?:to|in)\s+(\w+)"#
    ]
    
    for pattern in patterns {
        if let match = firstRegexMatch(in: input, pattern: pattern, captureGroup: 0),
           let extracted = extractConversionValues(from: match) {
            return extracted
        }
    }
    return nil
}

private static func extractConversionValues(from text: String) -> (value: Double, fromUnit: String, toUnit: String, category: String?)? {
    // Parse the matched text and extract value, fromUnit, toUnit
    // Determine category based on unit types
    // Implementation depends on regex patterns used
    return nil  // Placeholder - implement based on actual parsing needs
}
```

**3d. Add payload mapping in `mapPayloadToToolCall()`:**

```swift
static func mapPayloadToToolCall(toolName: String, fields: [String: Any], originalInput: String) -> LLMToolCall? {
    switch toolName {
    // ... existing cases ...
    
    case "convert_units":
        guard let value = fields["value"] as? Double ?? Double(fields["value"] as? String ?? ""),
              let fromUnit = fields["from_unit"] as? String,
              let toUnit = fields["to_unit"] as? String else {
            // Try fallback inference from original input
            if let params = inferUnitConversionParams(from: originalInput) {
                return LLMToolCall.convertUnits(
                    value: params.value,
                    fromUnit: params.fromUnit,
                    toUnit: params.toUnit,
                    category: params.category,
                    confidence: 0.7
                )
            }
            return nil
        }
        return LLMToolCall.convertUnits(
            value: value,
            fromUnit: fromUnit,
            toUnit: toUnit,
            category: fields["category"] as? String,
            confidence: 0.9
        )
    
    // ... rest of switch ...
    }
}
```

**3e. Add description in `describe()`:**

```swift
static func describe(_ toolCall: LLMToolCall) -> String {
    switch toolCall.parameters {
    // ... existing cases ...
    
    case .convertUnits(let params):
        return "convert_units(value: \(params.value), fromUnit: \(params.fromUnit), toUnit: \(params.toUnit), category: \(params.category ?? "nil"), confidence: \(toolCall.confidence))"
    }
}
```

### Step 4: Add Execution Logic in LLMToolExecutor.swift

**4a. Add error case:**

```swift
enum ToolExecutionError: Error, LocalizedError {
    case calendarAccessDenied
    case eventCreationFailed(String)
    case invalidParameters(String)
    case searchFailed(String)
    case conversionFailed(String)  // ← ADD THIS
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        // ... existing cases ...
        case .conversionFailed(let reason):
            return "Conversion failed: \(reason)"
        // ... existing cases ...
        }
    }
}
```

**4b. Add case to execute() switch:**

```swift
func execute(_ toolCall: LLMToolCall) async -> Result<ToolExecutionResult, Error> {
    logger.debug("Executing tool: \(toolCall.tool.rawValue)")
    
    switch toolCall.parameters {
    case .createCalendarEvent(let params):
        return await executeCalendarEventCreation(params: params)
    case .findFiles(let params):
        return await executeFileSearch(params: params)
    case .convertUnits(let params):  // ← ADD THIS
        return executeUnitConversion(params: params)
    }
}
```

**4c. Implement the execution method:**

```swift
// MARK: - Unit Conversion

private func executeUnitConversion(params: UnitConversionParams) -> Result<ToolExecutionResult, Error> {
    print("📐 LLMToolExecutor: Converting units")
    print("   Value: \(params.value)")
    print("   From: \(params.fromUnit)")
    print("   To: \(params.toUnit)")
    print("   Category: \(params.category ?? "auto")")
    
    // Perform conversion
    guard let result = UnitConverter.convert(
        value: params.value,
        from: params.fromUnit,
        to: params.toUnit,
        category: params.category
    ) else {
        return .failure(ToolExecutionError.conversionFailed(
            "Could not convert \(params.fromUnit) to \(params.toUnit)"
        ))
    }
    
    let message = "\(params.value) \(params.fromUnit) = \(result) \(params.toUnit)"
    
    // Copy result to clipboard for convenience
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(String(result), forType: .string)
    
    let details = "Result copied to clipboard"
    
    print("✅ Unit conversion completed: \(message)")
    return .success(ToolExecutionResult.success(message, details: details))
}
```

---

## Testing Your New Tool

### Unit Tests

Create tests in `Tests/ZestTests/LLMToolCallingTests.swift`:

```swift
func testUnitConversionToolParsing() async throws {
    let service = LLMToolCallingService.shared
    
    // Test LLM path (requires model loaded)
    let result1 = await service.parseWithLLM(input: "convert 5 km to miles")
    XCTAssertNotNil(result1)
    XCTAssertEqual(result1?.tool, .convertUnits)
    
    if case .convertUnits(let params) = result1?.parameters {
        XCTAssertEqual(params.value, 5.0, accuracy: 0.01)
        XCTAssertEqual(params.fromUnit, "km")
        XCTAssertEqual(params.toUnit, "miles")
    } else {
        XCTFail("Wrong parameter type")
    }
}

func testUnitConversionFallbackParsing() {
    // Test fallback path (deterministic, no model needed)
    let result = LLMToolCatalog.fallbackParse(input: "convert 100 celsius to fahrenheit")
    XCTAssertNotNil(result)
    XCTAssertEqual(result?.tool, .convertUnits)
}
```

### Manual Testing

1. **Build and run:**
   ```bash
   swift build && swift run
   ```

2. **Test in app:**
   - Open command palette (Cmd+Shift+Space)
   - Type `=convert 10 km to miles`
   - Verify correct parsing in console logs
   - Verify execution result

3. **Check logs:**
   ```
   🧠 Calling parseWithLLM with: convert 10 km to miles
   🧠 LLMToolCallingService: using model tool call
   🧠 Got LLM toolCall: convert_units(value: 10.0, fromUnit: km, toUnit: miles, ...)
   📐 LLMToolExecutor: Converting units
   ✅ Unit conversion completed: 10 km = 6.2137 miles
   ```

---

## Schema Format Reference

### FunctionGemma Declaration Format

The schema uses FunctionGemma's function calling format:

```
<start_function_declaration>declaration:TOOL_NAME{description:<escape>DESCRIPTION.<escape>,parameters:{properties:{PARAM_NAME:{description:<escape>PARAM DESCRIPTION.<escape>,type:<escape>TYPE<escape>},...},required:[<escape>REQUIRED_PARAM<escape>,...],type:<escape>OBJECT<escape>}}<end_function_declaration>
```

### Parameter Types

| Type | Description |
|------|-------------|
| `STRING` | Text values |
| `NUMBER` | Numeric values (int or float) |
| `BOOLEAN` | true/false |
| `INTEGER` | Whole numbers |

### Naming Conventions

- **Tool names**: `snake_case` (e.g., `convert_units`, `find_files`)
- **Swift enum cases**: `camelCase` (e.g., `convertUnits`, `findFiles`)
- **JSON fields**: `snake_case` (e.g., `from_unit`, `file_extension`)

---

## Best Practices

### Prompt Engineering

1. **Be specific in descriptions** - Help the model understand when to use each parameter
2. **Use examples** - Include example values in parameter descriptions
3. **Keep required params minimal** - Only mark truly required parameters
4. **Provide category hints** - Optional hints help disambiguate units

### Error Handling

```swift
// Good: Graceful degradation
case "convert_units":
    guard let value = fields["value"] as? Double ?? Double(fields["value"] as? String ?? ""),
          let fromUnit = fields["from_unit"] as? String,
          let toUnit = fields["to_unit"] as? String else {
        // Try to infer from original input
        if let params = inferUnitConversionParams(from: originalInput) {
            return LLMToolCall.convertUnits(...)
        }
        return nil  // Tool not applicable
    }
```

### Confidence Levels

| Level | When to Use |
|-------|-------------|
| 0.9+ | LLM extracted all parameters correctly |
| 0.7 | Some parameters inferred from context |
| 0.55 | Fallback parsing, may be wrong |

---

## Troubleshooting

### Model Outputs Garbage

**Symptom**: LLM returns random text instead of structured tool call

**Solutions**:
1. Check model is loaded: Look for `statusMessage = "Ready"` in logs
2. Verify prompt format: Run `MLXLLMService.shared.test_buildFunctionGemmaPrompt("test")`
3. Lower temperature if output is too random (in `MLXLLMService.swift`)

### JSON Parse Failures

**Symptom**: `🧠 MLX parsed JSON payload for tool:` never appears

**Solutions**:
1. Check FunctionGemma format parsing - use `test_extractFunctionGemmaToolPayload()`
2. Add debug logging to see raw model output
3. Verify fallback parsing works with `test_fallbackParse()`

### Tool Not Recognized

**Symptom**: LLM returns `none` or wrong tool

**Solutions**:
1. Add keywords to `fallbackParse()` pattern matching
2. Improve tool description in schema
3. Check for conflicting patterns with other tools

### Build Warnings

**Symptom**: Swift warns about unused variables or incorrect try/await

**Solutions**:
1. Remove unused `let` variables or replace with `_`
2. Remove `try?` from non-throwing functions
3. Remove `await` from synchronous functions

```bash
# Check for warnings
swift build 2>&1 | grep -E "(error:|warning:)"
```

---

## Checklist for New Tools

- [ ] Parameters struct defined in `LLMToolCall.swift`
- [ ] Case added to `LLMTool` enum
- [ ] Case added to `ToolParameters` enum
- [ ] `isComplete` check implemented
- [ ] Static factory method added
- [ ] Schema declaration added to `functionGemmaDeclarations`
- [ ] Fallback pattern added to `fallbackParse()`
- [ ] Payload mapping added to `mapPayloadToToolCall()`
- [ ] Description added to `describe()`
- [ ] Error case added to `ToolExecutionError`
- [ ] Case added to `execute()` switch
- [ ] Execution method implemented
- [ ] Unit tests written
- [ ] Manual testing completed
- [ ] Zero build warnings verified

---

## Related

- [LLMToolCall.swift](/Sources/Models/LLMToolCall.swift) - Data models
- [LLMToolCatalog.swift](/Sources/Services/LLMToolCatalog.swift) - Schema and parsing
- [LLMToolExecutor.swift](/Sources/Services/LLMToolExecutor.swift) - Execution
- [MLXLLMService.swift](/Sources/Services/MLXLLMService.swift) - LLM inference

---
*Last reviewed: 2026-02-28*
