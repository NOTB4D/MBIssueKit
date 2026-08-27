import Foundation
@testable import MBIssueKit
import Testing

@Suite("Provider-neutral entry persistence")
struct MBIssueEntryProviderMigrationTests {
    @Test("Legacy Jira persistence migrates without losing the external issue")
    func decodesLegacyJiraFields() throws {
        let json = """
        {
          "id": "C7FB2F80-9CF6-4E18-928A-6AE08390DDEC",
          "createdAt": "2023-11-14T22:13:20Z",
          "title": "Legacy report",
          "description": "Created before provider abstraction",
          "severity": "major",
          "screenshotFileNames": [],
          "jiraStatus": "submitted",
          "jiraSubmission": {
            "issueID": "10042",
            "issueKey": "MAD-42",
            "issueURL": "https://mobven.atlassian.net/browse/MAD-42",
            "createdAt": "2023-11-14T22:13:20Z",
            "uploadedFileNames": []
          },
          "jiraMessage": "MAD-42 created in Jira."
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let entry = try decoder.decode(MBIssueEntry.self, from: Data(json.utf8))

        #expect(entry.submissionStatus == .submitted)
        #expect(entry.submission?.providerID == "jira")
        #expect(entry.submission?.providerDisplayName == "Jira")
        #expect(entry.submission?.issueKey == "MAD-42")
        #expect(entry.submissionMessage == "MAD-42 created in Jira.")
    }

    @Test("New persistence contains no provider-specific property names")
    func encodesProviderNeutralFields() throws {
        let entry = try MBIssueEntry(
            id: #require(UUID(uuidString: "C7FB2F80-9CF6-4E18-928A-6AE08390DDEC")),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            title: "Azure-ready report",
            description: "The package does not care which provider receives it.",
            screenshotFileNames: [],
            submissionStatus: .submitted,
            submission: MBIssueSubmissionReceipt(
                providerID: "azure-devops",
                providerDisplayName: "Azure DevOps",
                issueID: "812",
                issueKey: "812",
                issueURL: #require(URL(string: "https://dev.azure.com/example/project/_workitems/edit/812")),
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            submissionMessage: "Work item 812 created."
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(entry)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])

        #expect(object["submissionStatus"] as? String == "submitted")
        #expect(object["submission"] != nil)
        #expect(object["submissionMessage"] as? String == "Work item 812 created.")
        #expect(object["jiraStatus"] == nil)
        #expect(object["jiraSubmission"] == nil)
        #expect(object["jiraMessage"] == nil)
    }
}
