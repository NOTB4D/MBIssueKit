import Foundation
@testable import MBIssueKit
import Testing

@Suite("Jira OAuth requests")
struct MBIssueJiraOAuthRequestTests {
    @Test("Authorization URL carries app configuration and anti-forgery state")
    func buildsAuthorizationURL() throws {
        let configuration = try jiraConfiguration()
        let url = try MBIssueJiraRequestBuilder.authorizationURL(
            configuration: configuration,
            state: "one-time-state"
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        #expect(components.host == "auth.atlassian.com")
        #expect(items["client_id"] == "client-id")
        #expect(items["redirect_uri"] == "mbissue-sonex://oauth/callback")
        #expect(items["state"] == "one-time-state")
        #expect(items["audience"] == "api.atlassian.com")
        #expect(items["scope"]?.contains("offline_access") == true)
        #expect(items["scope"]?.contains("report:personal-data") == true)
    }

    @Test("Token exchange body contains the secret loaded at runtime")
    func buildsTokenExchangeRequest() throws {
        let configuration = try jiraConfiguration()
        let request = try MBIssueJiraRequestBuilder.tokenExchange(
            configuration: configuration,
            clientSecret: "keychain-secret",
            code: "authorization-code"
        )
        let body = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])

        #expect(request.url?.absoluteString == "https://auth.atlassian.com/oauth/token")
        #expect(request.httpMethod == "POST")
        #expect(json["client_secret"] == "keychain-secret")
        #expect(json["grant_type"] == "authorization_code")
        #expect(json["code"] == "authorization-code")
    }

    @Test("OAuth callback must match both callback URL and state")
    func validatesCallback() throws {
        let configuration = try jiraConfiguration()
        let valid = try #require(URL(string: "mbissue-sonex://oauth/callback?code=abc&state=expected"))
        let wrongState = try #require(URL(string: "mbissue-sonex://oauth/callback?code=abc&state=other"))

        #expect(try MBIssueJiraOAuthCallbackParser.code(
            from: valid,
            expectedCallbackURL: configuration.callbackURL,
            expectedState: "expected"
        ) == "abc")
        #expect(throws: MBIssueProviderError.invalidAuthorizationCallback) {
            try MBIssueJiraOAuthCallbackParser.code(
                from: wrongState,
                expectedCallbackURL: configuration.callbackURL,
                expectedState: "expected"
            )
        }
    }

    @Test("Personal data report carries the stored profile age")
    func buildsPersonalDataRequest() throws {
        let updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let request = try MBIssueJiraRequestBuilder.personalDataReport(
            accountID: "account-1",
            updatedAt: updatedAt,
            accessToken: "access-token"
        )
        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let accounts = try #require(object["accounts"] as? [[String: String]])

        #expect(request.url?.absoluteString == "https://api.atlassian.com/app/report-accounts/")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer access-token")
        #expect(accounts.first?["accountId"] == "account-1")
        #expect(accounts.first?["updatedAt"]?.hasPrefix("2023-11-14T22:13:20") == true)
    }

    private func jiraConfiguration() throws -> MBIssueJiraConfiguration {
        try MBIssueJiraConfiguration(
            clientID: "client-id",
            clientSecret: "client-secret",
            callbackURL: #require(URL(string: "mbissue-sonex://oauth/callback")),
            siteURL: #require(URL(string: "https://mobven.atlassian.net")),
            projectKey: "MAD",
            issueTypeID: "10841",
            boardID: 1026,
            sprintFieldID: "customfield_10020"
        )
    }
}
