@testable import MBIssueKit
import Testing

@Suite("Issue draft")
struct MBIssueDraftTests {
    @Test("Title and description are trimmed")
    func trimsUserInput() throws {
        let context = MBIssueTechnicalContext.fixture
        let draft = MBIssueDraft(
            title: "  Checkout button is unresponsive  ",
            description: "  Tapping the button has no effect.\n  ",
            severity: .blocker,
            technicalContext: context
        )

        let validated = try draft.validated()

        #expect(validated.title == "Checkout button is unresponsive")
        #expect(validated.description == "Tapping the button has no effect.")
        #expect(validated.severity == .blocker)
        #expect(validated.technicalContext == context)
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

    @Test("The report title limit is enforced")
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

extension MBIssueTechnicalContext {
    static let fixture = MBIssueTechnicalContext(
        screenName: "Checkout",
        viewControllerName: "CheckoutViewController",
        navigationStack: ["HomeViewController", "CheckoutViewController"],
        appName: "Commerce",
        bundleIdentifier: "com.mobven.commerce",
        appVersion: "100.0.1",
        buildNumber: "8",
        osVersion: "iOS 26.5",
        deviceModel: "iPhone",
        deviceIdentifier: "iPhone18,2",
        architecture: "arm64",
        environment: "development",
        locale: "tr_TR",
        isDarkMode: true,
        screenSize: "402 × 874 pt @3x",
        additional: ["API cluster": "staging-eu"]
    )
}
