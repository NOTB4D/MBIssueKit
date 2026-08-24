import Foundation
import Testing
@testable import MBIssueKit

@Suite("Jira requests")
struct MBIssueJiraRequestBuilderTests {
    @Test("Create issue request contains only host configuration and user-authored content")
    func createsTaskPayload() throws {
        let configuration = try fixtureConfiguration()
        let draft = try MBIssueDraft(
            title: "Payment fails",
            description: "Card payment returns to the basket.\nPlease keep the form state."
        ).validated()

        let request = try MBIssueJiraRequestBuilder.createIssue(
            draft: draft,
            configuration: configuration
        )
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let fields = try #require(json["fields"] as? [String: Any])
        let project = try #require(fields["project"] as? [String: String])
        let issueType = try #require(fields["issuetype"] as? [String: String])
        let description = try #require(fields["description"] as? [String: Any])

        #expect(request.url?.absoluteString == "https://example.atlassian.net/rest/api/3/issue")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == basicAuthorization())
        #expect(project["key"] == "MOB")
        #expect(issueType["name"] == "Task")
        #expect(fields["summary"] as? String == draft.title)
        #expect(fields["labels"] as? [String] == ["mbissuekit", "ios"])
        #expect(description["type"] as? String == "doc")
        #expect(description["version"] as? Int == 1)
        #expect(extractText(from: description) == draft.description)

        #expect(fields["environment"] == nil)
        #expect(fields["context"] == nil)
        #expect(fields["logs"] == nil)
        #expect(fields["severity"] == nil)
    }

    @Test("Attachment request uses Jira's required multipart contract")
    func createsAttachmentPayload() throws {
        let request = try MBIssueJiraRequestBuilder.addAttachment(
            issueKey: "MOB-42",
            fileName: "capture.png",
            mimeType: "image/png",
            data: Data("image-data".utf8),
            boundary: "Boundary-42",
            configuration: fixtureConfiguration()
        )
        let body = try #require(request.httpBody)
        let bodyText = try #require(String(data: body, encoding: .utf8))

        #expect(request.url?.absoluteString == "https://example.atlassian.net/rest/api/3/issue/MOB-42/attachments")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "X-Atlassian-Token") == "no-check")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=Boundary-42")
        #expect(bodyText.contains("name=\"file\"; filename=\"capture.png\""))
        #expect(bodyText.contains("Content-Type: image/png"))
        #expect(bodyText.contains("image-data"))
    }

    private func fixtureConfiguration() throws -> MBIssueJiraConfiguration {
        try MBIssueJiraConfiguration(
            baseURL: #require(URL(string: "https://example.atlassian.net")),
            email: "developer@example.com",
            apiToken: "secret-token",
            projectKey: "MOB",
            issueType: "Task",
            labels: ["mbissuekit", "ios"]
        )
    }

    private func basicAuthorization() -> String {
        let value = Data("developer@example.com:secret-token".utf8).base64EncodedString()
        return "Basic \(value)"
    }

    private func extractText(from document: [String: Any]) -> String {
        guard let blocks = document["content"] as? [[String: Any]] else {
            return ""
        }
        return blocks.compactMap { block in
            guard let content = block["content"] as? [[String: Any]] else {
                return ""
            }
            return content.compactMap { $0["text"] as? String }.joined()
        }
        .joined(separator: "\n")
    }
}
