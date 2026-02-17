import XCTest
@testable import ZestApp

/// Tests for ContactsService functionality
/// Note: Contacts framework requires XPC access to the contacts daemon,
/// which is not available in unit test environment. Tests focus on:
/// - Model logic (Contact struct) - fully testable
/// - Service initialization - tested in UI/integration tests
final class ContactsServiceTests: XCTestCase {

    // MARK: - Contact Model Tests

    /// Test Contact model initialization
    func testContactModelCreation() {
        let contact = Contact(
            identifier: "test-id-123",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@example.com"],
            phones: ["+1-555-1234"]
        )

        XCTAssertEqual(contact.id, "test-id-123")
        XCTAssertEqual(contact.givenName, "John")
        XCTAssertEqual(contact.familyName, "Doe")
        XCTAssertEqual(contact.emails, ["john@example.com"])
        XCTAssertEqual(contact.phones, ["+1-555-1234"])
    }

    /// Test Contact displayName with full name
    func testContactDisplayNameFullName() {
        let contact = Contact(
            identifier: "1",
            givenName: "John",
            familyName: "Doe",
            emails: [],
            phones: []
        )
        XCTAssertEqual(contact.displayName, "John Doe")
    }

    /// Test Contact displayName with family name only
    func testContactDisplayNameFamilyNameOnly() {
        let contact = Contact(
            identifier: "2",
            givenName: "",
            familyName: "Doe",
            emails: [],
            phones: []
        )
        XCTAssertEqual(contact.displayName, "Doe")
    }

    /// Test Contact displayName with given name only
    func testContactDisplayNameGivenNameOnly() {
        let contact = Contact(
            identifier: "3",
            givenName: "John",
            familyName: "",
            emails: [],
            phones: []
        )
        XCTAssertEqual(contact.displayName, "John")
    }

    /// Test Contact displayName with no name
    func testContactDisplayNameNoName() {
        let contact = Contact(
            identifier: "4",
            givenName: "",
            familyName: "",
            emails: [],
            phones: []
        )
        XCTAssertEqual(contact.displayName, "Unknown Contact")
    }

    /// Test Contact hasContactInfo with both email and phone
    func testContactHasContactInfoBoth() {
        let contact = Contact(
            identifier: "1",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@example.com"],
            phones: ["+1-555-1234"]
        )
        XCTAssertTrue(contact.hasContactInfo)
    }

    /// Test Contact hasContactInfo with email only
    func testContactHasContactInfoEmailOnly() {
        let contact = Contact(
            identifier: "2",
            givenName: "Jane",
            familyName: "Doe",
            emails: ["jane@example.com"],
            phones: []
        )
        XCTAssertTrue(contact.hasContactInfo)
    }

    /// Test Contact hasContactInfo with phone only
    func testContactHasContactInfoPhoneOnly() {
        let contact = Contact(
            identifier: "3",
            givenName: "Bob",
            familyName: "Smith",
            emails: [],
            phones: ["+1-555-5678"]
        )
        XCTAssertTrue(contact.hasContactInfo)
    }

    /// Test Contact hasContactInfo with neither
    func testContactHasContactInfoNeither() {
        let contact = Contact(
            identifier: "4",
            givenName: "No",
            familyName: "Contact",
            emails: [],
            phones: []
        )
        XCTAssertFalse(contact.hasContactInfo)
    }

    /// Test Contact Hashable conformance
    func testContactHashable() {
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

        // Same identifier should have same hash
        XCTAssertEqual(contact1.hashValue, contact2.hashValue)

        // Set should deduplicate by id
        var set = Set<Contact>()
        set.insert(contact1)
        set.insert(contact2)
        XCTAssertEqual(set.count, 1, "Set should contain only one contact with same id")
    }

    /// Test Contact Equatable conformance
    func testContactEquatable() {
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

        XCTAssertEqual(contact1, contact2, "Contacts with same id should be equal")
        XCTAssertNotEqual(contact1, contact3, "Contacts with different id should not be equal")
    }

    /// Test Contact with multiple emails
    func testContactWithMultipleEmails() {
        let contact = Contact(
            identifier: "1",
            givenName: "John",
            familyName: "Doe",
            emails: ["john@work.com", "john@personal.com", "john@example.com"],
            phones: []
        )

        XCTAssertEqual(contact.emails.count, 3)
        XCTAssertTrue(contact.emails.contains("john@work.com"))
        XCTAssertTrue(contact.emails.contains("john@personal.com"))
        XCTAssertTrue(contact.emails.contains("john@example.com"))
    }

    /// Test Contact with multiple phones
    func testContactWithMultiplePhones() {
        let contact = Contact(
            identifier: "1",
            givenName: "John",
            familyName: "Doe",
            emails: [],
            phones: ["+1-555-1234", "+1-555-5678"]
        )

        XCTAssertEqual(contact.phones.count, 2)
        XCTAssertTrue(contact.phones.contains("+1-555-1234"))
        XCTAssertTrue(contact.phones.contains("+1-555-5678"))
    }

    /// Test Contact with empty strings
    func testContactWithEmptyStrings() {
        let contact = Contact(
            identifier: "",
            givenName: "",
            familyName: "",
            emails: [""],
            phones: [""]
        )

        XCTAssertEqual(contact.id, "")
        XCTAssertEqual(contact.displayName, "Unknown Contact")
        XCTAssertEqual(contact.emails, [""])
        XCTAssertEqual(contact.phones, [""])
    }

    /// Test Contact Identifiable conformance
    func testContactIdentifiable() {
        let contact = Contact(
            identifier: "unique-id",
            givenName: "Test",
            familyName: "User",
            emails: [],
            phones: []
        )

        // The id property should match the identifier passed in init
        XCTAssertEqual(contact.id, "unique-id")
    }
}
