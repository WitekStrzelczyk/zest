import Foundation

/// Manages snippets storage and retrieval
final class SnippetManager {
    static let shared: SnippetManager = {
        let instance = SnippetManager()
        return instance
    }()

    private let fileManager = FileManager.default
    private var snippets: [Snippet] = []

    private var snippetsDirectory: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Zest/Snippets", isDirectory: true)
    }

    private var snippetsFile: URL {
        snippetsDirectory.appendingPathComponent("snippets.json")
    }

    private init() {
        createDirectoryIfNeeded()
        loadSnippets()
        addBuiltInSnippetsIfNeeded()
    }

    // MARK: - Public Methods

    /// Get all snippets
    func getAllSnippets() -> [Snippet] {
        snippets.sorted { ($0.lastUsedAt ?? $0.createdAt) > ($1.lastUsedAt ?? $1.createdAt) }
    }

    /// Search snippets by query
    func searchSnippets(query: String) -> [Snippet] {
        guard !query.isEmpty else { return getAllSnippets() }

        let lowercasedQuery = query.lowercased()
        return snippets.filter { snippet in
            snippet.name.lowercased().contains(lowercasedQuery) ||
            snippet.keywords.contains { $0.lowercased().contains(lowercasedQuery) }
        }
    }

    /// Add a new snippet
    func addSnippet(_ snippet: Snippet) {
        snippets.append(snippet)
        saveSnippets()
    }

    /// Update an existing snippet
    func updateSnippet(_ snippet: Snippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            saveSnippets()
        }
    }

    /// Delete a snippet
    func deleteSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
        saveSnippets()
    }

    /// Mark snippet as used (updates lastUsedAt)
    func markAsUsed(id: UUID) {
        if let index = snippets.firstIndex(where: { $0.id == id }) {
            snippets[index].lastUsedAt = Date()
            saveSnippets()
        }
    }

    /// Get snippet by ID
    func getSnippet(id: UUID) -> Snippet? {
        snippets.first { $0.id == id }
    }

    // MARK: - Private Methods

    private func createDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: snippetsDirectory.path) {
            try? fileManager.createDirectory(at: snippetsDirectory, withIntermediateDirectories: true)
        }
    }

    private func loadSnippets() {
        guard fileManager.fileExists(atPath: snippetsFile.path) else { return }

        do {
            let data = try Data(contentsOf: snippetsFile)
            snippets = try JSONDecoder().decode([Snippet].self, from: data)
        } catch {
            print("Failed to load snippets: \(error)")
            snippets = []
        }
    }

    private func saveSnippets() {
        do {
            let data = try JSONEncoder().encode(snippets)
            try data.write(to: snippetsFile)
        } catch {
            print("Failed to save snippets: \(error)")
        }
    }

    private func addBuiltInSnippetsIfNeeded() {
        // Only add built-in snippets if file doesn't exist
        guard !fileManager.fileExists(atPath: snippetsFile.path) else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short

        let builtInSnippets: [Snippet] = [
            Snippet(
                name: "Current Date",
                content: "{date}",
                keywords: ["date", "today", "current"]
            ),
            Snippet(
                name: "Current Time",
                content: "{time}",
                keywords: ["time", "now", "clock"]
            ),
            Snippet(
                name: "Email Signature",
                content: """
                Best regards,
                {name}

                ---
                Sent from Zest Command Palette
                """,
                keywords: ["signature", "email", "sign"]
            )
        ]

        // Add date/time expansion to snippets
        for i in builtInSnippets.indices {
            var snippet = builtInSnippets[i]
            if snippet.name == "Current Date" {
                snippet = Snippet(
                    name: snippet.name,
                    content: dateFormatter.string(from: Date()),
                    keywords: snippet.keywords
                )
            } else if snippet.name == "Current Time" {
                snippet = Snippet(
                    name: snippet.name,
                    content: timeFormatter.string(from: Date()),
                    keywords: snippet.keywords
                )
            }
            snippets.append(snippet)
        }

        saveSnippets()
    }
}
