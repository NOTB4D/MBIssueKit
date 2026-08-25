import Foundation
@testable import MBIssueKit
import Testing

@Suite("Portable issue report")
struct MBIssueReportBuilderTests {
    @Test("Markdown contains reproducible technical scope without secrets or TCA guidance")
    func createsDetailedMarkdown() throws {
        let entry = try MBIssueEntry(
            id: #require(UUID(uuidString: "7B9262AE-98A7-40F2-91D0-806145FE3D5D")),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            title: "Payment fails",
            description: "Card payment returns to the basket.",
            severity: .major,
            technicalContext: .fixture,
            screenshotFileNames: ["capture.png"],
            jiraStatus: .notSubmitted
        )

        let markdown = MBIssueReportBuilder.markdown(for: [entry])

        #expect(markdown.contains("# MBIssueKit report"))
        #expect(markdown.contains("## Payment fails"))
        #expect(markdown.contains("**Severity:** Major"))
        #expect(markdown.contains("### Technical context"))
        #expect(markdown.contains("CheckoutViewController"))
        #expect(markdown.contains("screenshots/7B9262AE-98A7-40F2-91D0-806145FE3D5D-capture.png"))
        #expect(!markdown.lowercased().contains("api token"))
        #expect(!markdown.lowercased().contains("tca"))
    }
}
