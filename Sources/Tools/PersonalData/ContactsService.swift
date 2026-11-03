import AppKit
import Contacts
import Foundation
import os.log

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

final class ContactsService: @unchecked Sendable {
    static let shared: ContactsService = .init()

    static var isDisabled = false

    private static let icon = NSImage(systemSymbolName: "person.circle", accessibilityDescription: "Contact")

    private let lock = NSLock()
    private var contactStore: CNContactStore?
    private let accessKeywords = ["contact", "contacts"]
    private let minimumQueryLength = 2

    private init() {}

    var hasAccess: Bool {
        !Self.isDisabled && CNContactStore.authorizationStatus(for: .contacts) == .authorized
    }

    func requestAccess() async {
        do {
            _ = try await store().requestAccess(for: .contacts)
        } catch {
            Logger.contacts.error("Contacts access error: \(error.localizedDescription)")
        }
    }

    func search(query: String) -> [SearchResult] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard trimmedQuery.count >= minimumQueryLength else { return [] }

        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized:
            return contactResults(for: trimmedQuery)
        case .notDetermined:
            guard asksForContacts(trimmedQuery) else { return [] }
            return [PersonalDataAccess.requestResult(
                source: "Contacts",
                reason: "Zest searches your contacts by name to copy an email or phone number",
                category: .contact,
                request: { await self.requestAccess() }
            )]
        default:
            guard asksForContacts(trimmedQuery) else { return [] }
            return [PersonalDataAccess.deniedResult(
                source: "Contacts",
                settingsAnchor: "Privacy_Contacts",
                category: .contact
            )]
        }
    }

    private func asksForContacts(_ query: String) -> Bool {
        let padded = " \(query.lowercased()) "
        return accessKeywords.contains { padded.contains(" \($0) ") }
    }

    private func store() -> CNContactStore {
        lock.withLock {
            if let contactStore { return contactStore }
            let created = CNContactStore()
            contactStore = created
            return created
        }
    }

    private func contactResults(for query: String) -> [SearchResult] {
        fetchContacts(matchingName: query)
            .flatMap(buildSearchResults)
            .map { result in
                var scored = result
                scored.score = SearchScoreCalculator.shared.calculateScore(
                    query: query,
                    title: result.title,
                    subtitle: result.subtitle,
                    category: result.category
                )
                return scored
            }
            .sorted { $0.score > $1.score }
    }

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
            try store().enumerateContacts(with: request) { cnContact, _ in
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

    private func buildSearchResults(for contact: Contact) -> [SearchResult] {
        var results: [SearchResult] = []
        let icon = Self.icon

        for email in contact.emails {
            let result = SearchResult(
                title: contact.displayName,
                subtitle: "Email: \(email)",
                icon: icon,
                category: .contact,
                action: { [email] in
                    Self.copyToClipboardStatic(email)
                }
            )
            results.append(result)
        }

        for phone in contact.phones {
            let result = SearchResult(
                title: contact.displayName,
                subtitle: "Phone: \(phone)",
                icon: icon,
                category: .contact,
                action: { [phone] in
                    Self.copyToClipboardStatic(phone)
                }
            )
            results.append(result)
        }

        if !contact.hasContactInfo {
            let displayName = contact.displayName
            let result = SearchResult(
                title: displayName,
                subtitle: "Contact (no contact info)",
                icon: icon,
                category: .contact,
                action: {
                    Self.copyToClipboardStatic(displayName)
                }
            )
            results.append(result)
        }

        return results
    }

    private static func copyToClipboardStatic(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

private extension Logger {
    static let contacts = Logger(subsystem: "com.zest.app", category: "Contacts")
}

extension ContactsService: SearchTool {
    var name: String { "Contacts" }

    func search(_ context: QueryContext) -> [SearchResult] {
        guard !Self.isDisabled else { return [] }
        return search(query: context.normalized)
    }
}
