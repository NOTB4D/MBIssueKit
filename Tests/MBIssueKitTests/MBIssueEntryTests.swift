import Foundation
import Testing
@testable import MBIssueKit

@Suite("Issue entry")
struct MBIssueEntryTests {
    @Test("A persisted in-flight submission becomes retryable after relaunch")
    func recoversInterruptedSubmission() throws {
        let entry = MBIssueEntry(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            title: "Title",
            description: "Description",
            screenshotFileNames: ["capture.png"],
            jiraStatus: .submitting
        )
        let data = try JSONEncoder().encode(entry)

        let decoded = try JSONDecoder().decode(MBIssueEntry.self, from: data)

        #expect(decoded.jiraStatus == .failed)
        #expect(decoded.jiraMessage == "The previous submission was interrupted. Try again.")
    }
}
