# Search Pipeline Architecture

This document describes the unified search pipeline in Zest, focusing on how queries are processed from input to results, including the multi-intent routing and performance auditing systems.

## 1. Input & Debouncing
Every keystroke in the search bar is handled by the `CommandPaletteController`. To prevent UI lag and redundant processing:
- **Debounce**: A 100ms delay is applied. If the user types another character within 100ms, the previous `Task` is cancelled.
- **Asynchronicity**: Once debounced, the search is offloaded to a detached background task (`Task.detached`) via `SearchEngine.shared.searchAsync`.

## 2. Intent Routing (Multi-Intent)
Zest uses a **Multi-Intent** approach, meaning a single phrase can trigger multiple tools simultaneously.

### Naive Bayes Classifier
The `CommandRouter` uses a custom `NaiveBayesClassifier` trained on common command patterns.
- **Lemmatization**: Using the `NaturalLanguage` framework, words are reduced to their root form (e.g., "meetings" -> "meeting"). This allows the router to understand concepts rather than just keywords.
- **Thread Safety**: Each classification task uses a **local instance** of `NLTagger` to avoid concurrent access crashes.
- **Thresholds**: Domains are matched if their log-probability score exceeds a confidence threshold (default `-40.0`).

### Heuristic Overrides
While the probabilistic model handles most cases, rigid triggers (like "at", "in", or "meeting") act as heuristic overrides to ensure high-priority tools like Maps or Calendar always trigger when explicit keywords are present.

## 3. Tool Execution Logic

### Calendar & Map Integration
When a query like `meeting with john today at 10am at Perigian Digital Hub` is processed:
1. **Calendar Worker**: 
   - Uses `NSDataDetector` to extract date ("today at 10am").
   - Uses `NLTagger` (Place Recognition) to extract the location ("Perigian Digital Hub").
2. **Map Search**: 
   - If the Calendar intent includes a location, the Map tool automatically creates a "Search Map" result using that location.
   - If no location was extracted but the `mapLocation` domain was matched, it falls back to searching the whole query on maps.

### File Search (Native Spotlight)
File search uses the native `NSMetadataQuery` for maximum performance and index coverage.
- **Main RunLoop Synchronization**: Queries are started and observed on the Main RunLoop to ensure macOS delivers Spotlight notifications reliably.
- **Predicate Construction**: The `FileSearchWorker` builds optimized `NSPredicate` objects (e.g., using `kMDItemContentModificationDate`).
- **Crash Protection**: Simple predicates are used for single filters to prevent `NSMetadataQuery` from rejecting malformed compound structures.

## 4. Search Audit System
Performance is tracked automatically for every search via `SearchTracer`.

### Spans & Metrics
- **SearchSpan**: Each tool execution is wrapped in a "span" that tracks start/end time and result counts.
- **SearchAudit**: Upon completion, the trace is transformed into a structured `SearchAudit` object containing:
  - The original search phrase.
  - Total end-to-end duration.
  - A tool-by-tool breakdown of latency and result contributions.

This data is logged to the console for real-time performance monitoring and serves as the foundation for future optimizations.

## 5. Merging & Ranking
Results from all tools (Apps, Files, Tools, NL intents) are gathered into a single list:
- **Deduplication**: Results with the same title are merged.
- **Scoring**: NL intents are boosted (e.g., score 2500-3000) to appear at the top.
- **Limit**: The final list is capped at 80 results for UI performance.
