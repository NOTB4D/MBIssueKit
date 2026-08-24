import Foundation
import Testing
@testable import MBIssueKit

@Suite("Jira configuration")
struct MBIssueJiraConfigurationTests {
    @Test("Configuration normalizes values supplied by the host app")
    func normalizesValues() throws {
        let configuration = try MBIssueJiraConfiguration(
            baseURL: #require(URL(string: "https://example.atlassian.net/")),
            email: " developer@example.com ",
            apiToken: " secret-token ",
            projectKey: " mob ",
            issueType: " Task ",
            labels: [" mbissuekit ", "", "ios"]
        )

        #expect(configuration.baseURL.absoluteString == "https://example.atlassian.net")
        #expect(configuration.email == "developer@example.com")
        #expect(configuration.apiToken == "secret-token")
        #expect(configuration.projectKey == "MOB")
        #expect(configuration.issueType == "Task")
        #expect(configuration.labels == ["mbissuekit", "ios"])
    }

    @Test("Only HTTPS Jira endpoints are accepted")
    func rejectsInsecureEndpoint() throws {
        let url = try #require(URL(string: "http://example.atlassian.net"))

        #expect(throws: MBIssueConfigurationError.insecureBaseURL) {
            try MBIssueJiraConfiguration(
                baseURL: url,
                email: "developer@example.com",
                apiToken: "token",
                projectKey: "MOB"
            )
        }
    }

    @Test("Required values cannot be empty")
    func rejectsMissingProjectKey() throws {
        let url = try #require(URL(string: "https://example.atlassian.net"))

        #expect(throws: MBIssueConfigurationError.missingValue("projectKey")) {
            try MBIssueJiraConfiguration(
                baseURL: url,
                email: "developer@example.com",
                apiToken: "token",
                projectKey: " "
            )
        }
    }

    @Test("Host apps can build configuration from injected environment values")
    func readsEnvironmentValues() throws {
        let configuration = try MBIssueJiraConfiguration(environment: [
            "MBISSUEKIT_JIRA_BASE_URL": "https://example.atlassian.net",
            "MBISSUEKIT_JIRA_EMAIL": "developer@example.com",
            "MBISSUEKIT_JIRA_API_TOKEN": "secret-token",
            "MBISSUEKIT_JIRA_PROJECT_KEY": "MOB",
            "MBISSUEKIT_JIRA_ISSUE_TYPE": "Task",
            "MBISSUEKIT_JIRA_LABELS": "mbissuekit, ios,qa"
        ])

        #expect(configuration.projectKey == "MOB")
        #expect(configuration.issueType == "Task")
        #expect(configuration.labels == ["mbissuekit", "ios", "qa"])
    }
}
