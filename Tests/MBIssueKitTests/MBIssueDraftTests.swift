import Testing
@testable import MBIssueKit

@Suite("Issue draft")
struct MBIssueDraftTests {
    @Test("Title and description are trimmed")
    func trimsUserInput() throws {
        let draft = MBIssueDraft(
            title: "  Checkout button is unresponsive  ",
            description: "  Tapping the button has no effect.\n  "
        )

        let validated = try draft.validated()

        #expect(validated.title == "Checkout button is unresponsive")
        #expect(validated.description == "Tapping the button has no effect.")
    }

    @Test("A title is required")
    func requiresTitle() {
        let draft = MBIssueDraft(title: " \n ", description: "Description")

        #expect(throws: MBIssueValidationError.titleRequired) {
            try draft.validated()
        }
    }

    @Test("A description is required")
    func requiresDescription() {
        let draft = MBIssueDraft(title: "Title", description: " \n ")

        #expect(throws: MBIssueValidationError.descriptionRequired) {
            try draft.validated()
        }
    }

    @Test("Jira's summary limit is enforced")
    func enforcesTitleLimit() {
        let draft = MBIssueDraft(
            title: String(repeating: "a", count: MBIssueDraft.maximumTitleLength + 1),
            description: "Description"
        )

        #expect(throws: MBIssueValidationError.titleTooLong) {
            try draft.validated()
        }
    }
}
