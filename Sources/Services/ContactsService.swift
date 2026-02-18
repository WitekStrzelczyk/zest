import AppKit
import Contacts
import Foundation
import os.log

/// Represents a contact from the Contacts app
struct Contact: Identifiable, Hashable {
    let id: String
    let givenName: String
    let familyName: String
    let emails: [String]
    let phones: [String]

    var displayName: String {
        let name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Unknown Contact" : name
    }

    var hasContactInfo: Bool {
        !emails.isEmpty || !phones.isEmpty
    }

    init(
        identifier: String,
        givenName: String,
        familyName: String,
        emails: [String],
        phones: [String]
    ) {
        id = identifier
        self.givenName = givenName
        self.familyName = familyName
        self.emails = emails
        self.phones = phones
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Contact, rhs: Contact) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages integration with macOS Contacts
final class ContactsService {
    static let shared: ContactsService = .init()

    private let store = CNContactStore()
    private var accessChecked = false
    private var _hasAccess = false

    /// Flag to disable contacts access (useful for testing)
    static var isDisabled = false

    /// Whether the app has access to contacts
    /// Lazily checks authorization status on first access
    private(set) var hasAccess: Bool {
        get {
            guard !Self.isDisabled else { return false }

            if !accessChecked {
                let status = CNContactStore.authorizationStatus(for: .contacts)
                _hasAccess = status == .authorized
                accessChecked = true
            }
            return _hasAccess
        }
        set {
            _hasAccess = newValue
        }
    }

    private init() {
        // Don't check authorization status here to avoid
        // triggering Contacts framework in unit tests
    }

    // MARK: - Public Methods

    /// Request access to Contacts
    /// - Returns: true if access was granted
    @discardableResult
    func requestAccess() async -> Bool {
        let status = CNContactStore.authorizationStatus(for: .contacts)

        switch status {
        case .authorized:
            hasAccess = true
            return true
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                store.requestAccess(for: .contacts) { granted, error in
                    if let error {
                        Logger.contacts.error("Contacts access error: \(error.localizedDescription)")
                    }
                    continuation.resume(returning: granted)
                }
            }
            hasAccess = granted
            return granted
        case .denied, .restricted:
            Logger.contacts.warning("Contacts access denied or restricted")
            hasAccess = false
            return false
        @unknown default:
            hasAccess = false
            return false
        }
    }

    /// Search contacts by name
    /// - Parameter query: Search query (name to search for)
    /// - Returns: Array of SearchResult objects with copy actions
    func search(query: String) -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)

        guard hasAccess, !trimmedQuery.isEmpty else {
            return []
        }

        let contacts = fetchContacts(matchingName: trimmedQuery)
        return contacts.compactMap { contact -> [SearchResult] in
            buildSearchResults(for: contact)
        }.flatMap { $0 }
    }

    /// Fetch contacts matching a name
    /// - Parameter name: Name to search for
    /// - Returns: Array of Contact objects
    func fetchContacts(matchingName name: String) -> [Contact] {
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
        ]

        let request = CNContactFetchRequest(keysToFetch: keys)
        request.predicate = CNContact.predicateForContacts(matchingName: name)

        var contacts: [Contact] = []

        do {
            try store.enumerateContacts(with: request) { cnContact, _ in
                let contact = Contact(
                    identifier: cnContact.identifier,
                    givenName: cnContact.givenName,
                    familyName: cnContact.familyName,
                    emails: cnContact.emailAddresses.map { $0.value as String },
                    phones: cnContact.phoneNumbers.map(\.value.stringValue)
                )
                contacts.append(contact)
            }
        } catch {
            Logger.contacts.error("Failed to fetch contacts: \(error.localizedDescription)")
        }

        return contacts
    }

    // MARK: - Private Methods

    /// Build SearchResult objects for a contact
    /// Creates separate results for each email and phone number
    private func buildSearchResults(for contact: Contact) -> [SearchResult] {
        var results: [SearchResult] = []

        let icon = NSImage(systemSymbolName: "person.circle", accessibilityDescription: "Contact")

        // Add result for each email
        for email in contact.emails {
            let result = SearchResult(
                title: contact.displayName,
                subtitle: "Email: \(email)",
                icon: icon,
                action: { [email] in
                    Self.copyToClipboardStatic(email)
                }
            )
            results.append(result)
        }

        // Add result for each phone number
        for phone in contact.phones {
            let result = SearchResult(
                title: contact.displayName,
                subtitle: "Phone: \(phone)",
                icon: icon,
                action: { [phone] in
                    Self.copyToClipboardStatic(phone)
                }
            )
            results.append(result)
        }

        // If contact has no contact info, add a result that just shows the name
        if !contact.hasContactInfo {
            let displayName = contact.displayName
            let result = SearchResult(
                title: displayName,
                subtitle: "Contact (no contact info)",
                icon: icon,
                action: {
                    // Copy the name as fallback
                    Self.copyToClipboardStatic(displayName)
                }
            )
            results.append(result)
        }

        return results
    }

    /// Static method to copy text to clipboard (for use in closures)
    private static func copyToClipboardStatic(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

// MARK: - Logger Extension

private extension Logger {
    static let contacts = Logger(subsystem: "com.zest.app", category: "Contacts")
}
