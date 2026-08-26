import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
@testable import MBIssueKit
import Testing

@Suite("Reporter session silent renewal")
struct MBIssueReporterSessionRenewalTests {
    @Test("An expired reporter session is replaced without starting web authorization")
    func renewsExpiredSession() async throws {
        let store = InMemoryReporterSessionStore(token: "expired-reporter-session")
        let authentication = try MBIssueReporterAuthenticationConfiguration(
            callbackURLScheme: "sonex-mbissue",
            sessionStore: store
        )
        let configuration = try MBIssueGatewayConfiguration(
            baseURL: #require(URL(string: "https://api.sonex.example")),
            reporterAuthentication: authentication,
            accessTokenProvider: { "host-session" }
        )
        let transport = ScriptedHTTPTransport(responses: [
            .init(
                statusCode: 428,
                body: #"{"code":"reporter_authorization_required","reason":"Reporter authorization is required"}"#
            ),
            .init(statusCode: 200, body: Self.renewalResponse),
        ])
        let client = MBIssueGatewayClient(configuration: configuration, transport: transport)

        let connection = try await client.reporterConnection()

        #expect(connection.reporter?.accountID == "qa-account")
        #expect(await store.loadToken() == "renewed-reporter-session")
        let requests = await transport.requests
        #expect(requests.map(\.httpMethod) == ["GET", "POST"])
        #expect(requests[0].value(forHTTPHeaderField: "X-MBIssue-Reporter-Session") == "Bearer expired-reporter-session")
        #expect(requests[1].url?.path == "/issue-reporting/api/v1/reporter/session")
        #expect(requests[1].value(forHTTPHeaderField: "X-MBIssue-Reporter-Session") == nil)
    }

    @Test("A report rejected for an expired session renews and retries exactly once")
    func retriesSubmissionAfterRenewal() async throws {
        let store = InMemoryReporterSessionStore(token: "expired-reporter-session")
        let authentication = try MBIssueReporterAuthenticationConfiguration(
            callbackURLScheme: "sonex-mbissue",
            sessionStore: store
        )
        let configuration = try MBIssueGatewayConfiguration(
            baseURL: #require(URL(string: "https://api.sonex.example")),
            reporterAuthentication: authentication,
            accessTokenProvider: { "host-session" }
        )
        let transport = ScriptedHTTPTransport(responses: [
            .init(
                statusCode: 428,
                body: #"{"code":"reporter_authorization_required","reason":"Reporter authorization is required"}"#
            ),
            .init(statusCode: 200, body: Self.renewalResponse),
            .init(
                statusCode: 200,
                body: #"{"providerID":"jira","providerDisplayName":"Jira","issueID":"10001","issueKey":"MAD-42","issueURL":"https://mobven.atlassian.net/browse/MAD-42"}"#
            ),
        ])
        let client = MBIssueGatewayClient(configuration: configuration, transport: transport)
        let entry = try MBIssueEntry(
            id: #require(UUID(uuidString: "1D89EE0E-07D0-49DD-BA4A-E18C41E5513C")),
            createdAt: Date(),
            title: "Silent renewal",
            description: "Retry the report without showing Jira login.",
            screenshotFileNames: []
        )

        let receipt = try await client.submit(entry: entry, screenshotURLs: [])

        #expect(receipt.issueKey == "MAD-42")
        let requests = await transport.requests
        #expect(requests.map(\.url?.path) == [
            "/issue-reporting/api/v1/reports",
            "/issue-reporting/api/v1/reporter/session",
            "/issue-reporting/api/v1/reports",
        ])
        #expect(requests[0].value(forHTTPHeaderField: "X-MBIssue-Reporter-Session") == "Bearer expired-reporter-session")
        #expect(requests[2].value(forHTTPHeaderField: "X-MBIssue-Reporter-Session") == "Bearer renewed-reporter-session")
        #expect(requests[0].value(forHTTPHeaderField: "Idempotency-Key") == requests[2].value(forHTTPHeaderField: "Idempotency-Key"))
    }

    @Test("A renewed report is never retried more than once")
    func doesNotLoopAfterRenewedSessionIsRejected() async throws {
        let store = InMemoryReporterSessionStore(token: "expired-reporter-session")
        let authentication = try MBIssueReporterAuthenticationConfiguration(
            callbackURLScheme: "sonex-mbissue",
            sessionStore: store
        )
        let configuration = try MBIssueGatewayConfiguration(
            baseURL: #require(URL(string: "https://api.sonex.example")),
            reporterAuthentication: authentication,
            accessTokenProvider: { "host-session" }
        )
        let transport = ScriptedHTTPTransport(responses: [
            .init(
                statusCode: 428,
                body: #"{"code":"reporter_authorization_required","reason":"Reporter authorization is required"}"#
            ),
            .init(statusCode: 200, body: Self.renewalResponse),
            .init(
                statusCode: 428,
                body: #"{"code":"reporter_authorization_required","reason":"Reporter authorization is required"}"#
            ),
        ])
        let client = MBIssueGatewayClient(configuration: configuration, transport: transport)
        let entry = MBIssueEntry(
            id: UUID(),
            createdAt: Date(),
            title: "Rejected renewed session",
            description: "Do not enter an automatic retry loop.",
            screenshotFileNames: []
        )

        await #expect(throws: MBIssueGatewayError.reporterAuthorizationRequired) {
            try await client.submit(entry: entry, screenshotURLs: [])
        }
        #expect(await transport.requests.count == 3)
    }

    private static let renewalResponse = #"""
    {
      "reporterSessionToken":"renewed-reporter-session",
      "connection":{
        "provider":{
          "id":"jira",
          "displayName":"Jira",
          "destinationName":"MAD · Board 1026",
          "requiresReporterAuthorization":true
        },
        "reporter":{
          "accountID":"qa-account",
          "displayName":"QA User",
          "avatarURL":null
        },
        "expiresAt":"2026-08-27T12:00:00Z"
      }
    }
    """#
}

private actor InMemoryReporterSessionStore: MBIssueReporterSessionStoring {
    private var token: String?

    init(token: String? = nil) {
        self.token = token
    }

    func loadToken() -> String? {
        token
    }

    func saveToken(_ token: String) {
        self.token = token
    }

    func deleteToken() {
        token = nil
    }
}

private actor ScriptedHTTPTransport: MBIssueHTTPTransport {
    struct StubResponse: Sendable {
        let statusCode: Int
        let body: String
    }

    private var responses: [StubResponse]
    private(set) var requests: [URLRequest] = []

    init(responses: [StubResponse]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = responses.removeFirst()
        let url = try #require(request.url)
        let httpResponse = try #require(HTTPURLResponse(
            url: url,
            statusCode: response.statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        ))
        return (Data(response.body.utf8), httpResponse)
    }
}
