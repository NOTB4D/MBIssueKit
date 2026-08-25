import Foundation
@testable import MBIssueKit
import Testing

@Suite("Issue entry")
struct MBIssueEntryTests {
    @Test("A persisted in-flight submission becomes retryable after relaunch")
    func recoversInterruptedSubmission() throws {
        let entry = MBIssueEntry(
            id: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            title: "Title",
            description: "Description",
            severity: .blocker,
            technicalContext: .fixture,
            screenshotFileNames: ["capture.png"],
            submissionStatus: .submitting
        )
        let data = try JSONEncoder().encode(entry)

        let decoded = try JSONDecoder().decode(MBIssueEntry.self, from: data)

        #expect(decoded.submissionStatus == .failed)
        #expect(decoded.submissionMessage == "The previous submission was interrupted. Try again.")
        #expect(decoded.severity == .blocker)
        #expect(decoded.technicalContext == .fixture)
    }

    @Test("Legacy reports receive safe defaults")
    func decodesLegacyReport() throws {
        let data = Data(#"""
        {
          "id":"7B9262AE-98A7-40F2-91D0-806145FE3D5D",
          "createdAt":721692800,
          "title":"Legacy title",
          "description":"Legacy description",
          "screenshotFileNames":[],
          "jiraStatus":"notSubmitted"
        }
        """#.utf8)

        let decoded = try JSONDecoder().decode(MBIssueEntry.self, from: data)

        #expect(decoded.severity == .major)
        #expect(decoded.technicalContext == nil)
    }
}
