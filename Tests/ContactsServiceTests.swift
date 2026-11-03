import AppKit
import Testing
@testable import ZestApp

@MainActor
final class ContactsServiceTests {
    @Test func testContactModelCreation() {
        let contact = Contact(
            identifier: "test-id-123",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@example.com"],
            phones: ["+1-555-1234"]
        )

        #expect(contact.id == "test-id-123")
        #expect(contact.givenName == "John")
        #expect(contact.familyName == "Doe")
        #expect(contact.emails == ["john@example.com"])
        #expect(contact.phones == ["+1-555-1234"])
    }

    @Test func testContactDisplayNameFullName() {
        let contact = Contact(
            identifier: "1",
            givenName: "John",
            familyName: "Doe",
            emails: [],
            phones: []
        )
        #expect(contact.displayName == "John Doe")
    }

    @Test func testContactDisplayNameFamilyNameOnly() {
        let contact = Contact(
            identifier: "2",
            givenName: "",
            familyName: "Doe",
            emails: [],
            phones: []
        )
        #expect(contact.displayName == "Doe")
    }

    @Test func testContactDisplayNameGivenNameOnly() {
        let contact = Contact(
            identifier: "3",
            givenName: "John",
            familyName: "",
            emails: [],
            phones: []
        )
        #expect(contact.displayName == "John")
    }

    @Test func testContactDisplayNameNoName() {
        let contact = Contact(
            identifier: "4",
            givenName: "",
            familyName: "",
            emails: [],
            phones: []
        )
        #expect(contact.displayName == "Unknown Contact")
    }

    @Test func testContactHasContactInfoBoth() {
        let contact = Contact(
            identifier: "1",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@example.com"],
            phones: ["+1-555-1234"]
        )
        #expect(contact.hasContactInfo)
    }

    @Test func testContactHasContactInfoEmailOnly() {
        let contact = Contact(
            identifier: "2",
            givenName: "Jane",
            familyName: "Doe",
            emails: ["jane@example.com"],
            phones: []
        )
        #expect(contact.hasContactInfo)
    }

    @Test func testContactHasContactInfoPhoneOnly() {
        let contact = Contact(
            identifier: "3",
            givenName: "Bob",
            familyName: "Smith",
            emails: [],
            phones: ["+1-555-5678"]
        )
        #expect(contact.hasContactInfo)
    }

    @Test func testContactHasContactInfoNeither() {
        let contact = Contact(
            identifier: "4",
            givenName: "No",
            familyName: "Contact",
            emails: [],
            phones: []
        )
        #expect(!contact.hasContactInfo)
    }

    @Test func testContactHashable() {
        let contact1 = Contact(
            identifier: "same-id",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@example.com"],
            phones: []
        )
        let contact2 = Contact(
            identifier: "same-id",
            givenName: "Jane",
            familyName: "Smith",
            emails: ["jane@example.com"],
            phones: []
        )

        #expect(contact1.hashValue == contact2.hashValue)

        var set = Set<Contact>()
        set.insert(contact1)
        set.insert(contact2)
        #expect(set.count == 1, "Set should contain only one contact with same id")
    }

    @Test func testContactEquatable() {
        let contact1 = Contact(
            identifier: "id-1",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@example.com"],
            phones: []
        )
        let contact2 = Contact(
            identifier: "id-1",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@example.com"],
            phones: []
        )
        let contact3 = Contact(
            identifier: "id-2",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@example.com"],
            phones: []
        )

        #expect(contact1 == contact2, "Contacts with same id should be equal")
        #expect(contact1 != contact3, "Contacts with different id should not be equal")
    }

    @Test func testContactWithMultipleEmails() {
        let contact = Contact(
            identifier: "1",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@work.com", "john@personal.com", "john@example.com"],
            phones: []
        )

        #expect(contact.emails.count == 3)
        #expect(contact.emails.contains("john@work.com"))
        #expect(contact.emails.contains("john@personal.com"))
        #expect(contact.emails.contains("john@example.com"))
    }

    @Test func testContactWithMultiplePhones() {
        let contact = Contact(
            identifier: "1",
            givenName: "John",
            familyName: "Doe",
            emails: [],
            phones: ["+1-555-1234", "+1-555-5678"]
        )

        #expect(contact.phones.count == 2)
        #expect(contact.phones.contains("+1-555-1234"))
        #expect(contact.phones.contains("+1-555-5678"))
    }

    @Test func testContactWithEmptyStrings() {
        let contact = Contact(
            identifier: "",
            givenName: "",
            familyName: "",
            emails: [""],
            phones: [""]
        )

        #expect(contact.id == "")
        #expect(contact.displayName == "Unknown Contact")
        #expect(contact.emails == [""])
        #expect(contact.phones == [""])
    }

    @Test func testContactIdentifiable() {
        let contact = Contact(
            identifier: "unique-id",
            givenName: "Test",
            familyName: "User",
            emails: [],
            phones: []
        )

        #expect(contact.id == "unique-id")
    }
}
