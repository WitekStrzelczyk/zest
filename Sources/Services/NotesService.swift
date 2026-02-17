import AppKit
import Foundation

/// Represents a note from the Notes app
struct Note: Identifiable, Hashable {
    let id: String
    let title: String
    let content: String
    let modifiedDate: Date
    let createdDate: Date

    /// Returns the first line of content as preview
    var preview: String {
        let lines = content.components(separatedBy: .newlines)
        return lines.first ?? ""
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Note, rhs: Note) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages integration with Apple Notes
final class NotesService {
    static let shared: NotesService = .init()

    private init() {}

    // MARK: - Public Methods

    /// Request access to Notes (triggers permission dialog via AppleScript)
    func requestAccess() async -> Bool {
        // AppleScript will prompt for permission automatically
        let script = """
        tell application "Notes"
            get name of notes
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)
            if let error {
                print("Notes access error: \(error)")
                return false
            }
            return true
        }
        return false
    }

    /// Fetch all notes using AppleScript - simplified version
    func fetchNotes() async -> [Note] {
        let script = """
        tell application "Notes"
            set noteList to {}
            repeat with n in notes
                set noteTitle to name of n
                set noteBody to body of n
                set noteId to id of n
                set noteMod to modification date of n
                set noteCre to creation date of n
                set end of noteList to noteTitle & "|||" & noteBody & "|||" & noteId & "|||" & noteMod as string & "|||" & noteCre as string
            end repeat
            return noteList as text
        end tell
        """

        var error: NSDictionary?
        guard let scriptObject = NSAppleScript(source: script) else {
            return []
        }

        let result = scriptObject.executeAndReturnError(&error)

        if let error {
            print("AppleScript error fetching notes: \(error)")
            return []
        }

        // Parse the result - split by newlines
        let resultText = result.stringValue ?? ""
        let lines = resultText.components(separatedBy: "\n")

        var notes: [Note] = []
        for line in lines {
            let parts = line.components(separatedBy: "|||")
            guard parts.count >= 5 else { continue }

            let title = parts[0]
            let content = parts[1]
            let id = parts[2]
            let modifiedDate = Date()
            let createdDate = Date()

            notes.append(Note(
                id: id,
                title: title,
                content: content,
                modifiedDate: modifiedDate,
                createdDate: createdDate
            ))
        }

        return notes
    }

    /// Search notes by query
    func searchNotes(query: String) async -> [Note] {
        let allNotes = await fetchNotes()

        guard !query.isEmpty else { return allNotes }

        let lowercasedQuery = query.lowercased()
        return allNotes.filter { note in
            note.title.lowercased().contains(lowercasedQuery) ||
                note.content.lowercased().contains(lowercasedQuery)
        }
    }

    /// Create a new note using AppleScript
    func createNote(title: String, content: String = "") async -> String? {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedContent = content.replacingOccurrences(of: "\"", with: "\\\"")

        let script = """
        tell application "Notes"
            tell account "iCloud"
                set newNote to make new note at folder "Notes" with properties {name:"\(escapedTitle)", body:"\(escapedContent)"}
                return id of newNote
            end tell
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            let result = scriptObject.executeAndReturnError(&error)
            if let error {
                print("AppleScript error creating note: \(error)")
                return nil
            }
            return result.stringValue ?? UUID().uuidString
        }
        return nil
    }

    /// Open Notes app
    func openNote(id _: String) -> Bool {
        // Open Notes app
        if let notesApp = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Notes") {
            NSWorkspace.shared.openApplication(at: notesApp, configuration: NSWorkspace.OpenConfiguration())
            return true
        }
        return false
    }
}
