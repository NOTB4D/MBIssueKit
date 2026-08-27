import Foundation
@testable import MBIssueKit
import Testing

@Suite("Direct Jira provider")
struct MBIssueJiraProviderTests {
    @Test("OAuth callback exchanges credentials and persists the Jira identity")
    func connectsDirectly() async throws {
        let transport = try JiraQueueTransport(responses: [
            json([
                "access_token": "access-1",
                "refresh_token": "refresh-1",
                "expires_in": 3600,
                "scope": "offline_access read:me read:jira-work write:jira-work read:sprint:jira-software report:personal-data",
            ]),
            json([[
                "id": "cloud-1",
                "url": "https://mobven.atlassian.net",
            ]]),
            json([
                "account_id": "account-1",
                "name": "QA User",
                "picture": "https://avatar.example/qa.png",
                "account_status": "active",
            ]),
        ])
        let secureStore = JiraInMemorySecureStore()
        let vault = MBIssueJiraCredentialVault(store: secureStore)
        let provider = try MBIssueJiraProvider(
            configuration: jiraConfiguration(),
            transport: transport,
            vault: vault,
            stateGenerator: { "expected-state" }
        )

        try await provider.prepare()
        let authorizationURL = try await provider.authorizationURL()
        let callbackURL = try #require(URL(
            string: "mbissue-sonex://oauth/callback?code=oauth-code&state=expected-state"
        ))
        let connection = try await provider.completeAuthorization(callbackURL: callbackURL)

        #expect(authorizationURL.host == "auth.atlassian.com")
        #expect(connection.reporter?.accountID == "account-1")
        #expect(connection.reporter?.displayName == "QA User")
        #expect(connection.provider.destinationName == "MAD · Board 1026")
        #expect(try await vault.clientSecret() == "app-client-secret")
        #expect(try await vault.authorization()?.refreshToken == "refresh-1")

        let requests = await transport.requests
        #expect(requests.map { $0.url?.path } == [
            "/oauth/token",
            "/oauth/token/accessible-resources",
            "/me",
        ])
    }

    @Test("OAuth grant accepts Atlassian metadata scope omissions")
    func acceptsMetadataScopeOmissions() async throws {
        let transport = try JiraQueueTransport(responses: [
            json([
                "access_token": "access-1",
                "refresh_token": "refresh-1",
                "expires_in": 3600,
                "scope": "offline_access read:me read:jira-work write:jira-work read:sprint:jira-software",
            ]),
            json([[
                "id": "cloud-1",
                "url": "https://mobven.atlassian.net",
            ]]),
            json([
                "account_id": "account-1",
                "name": "QA User",
                "account_status": "active",
            ]),
        ])
        let provider = try MBIssueJiraProvider(
            configuration: jiraConfiguration(),
            transport: transport,
            vault: MBIssueJiraCredentialVault(store: JiraInMemorySecureStore()),
            stateGenerator: { "expected-state" }
        )

        _ = try await provider.authorizationURL()
        let callbackURL = try #require(URL(
            string: "mbissue-sonex://oauth/callback?code=oauth-code&state=expected-state"
        ))

        let connection = try await provider.completeAuthorization(callbackURL: callbackURL)

        #expect(connection.reporter?.displayName == "QA User")
    }

    @Test("OAuth grant rejects a missing issue submission scope")
    func rejectsMissingSubmissionScope() async throws {
        let transport = try JiraQueueTransport(responses: [
            json([
                "access_token": "access-1",
                "refresh_token": "refresh-1",
                "expires_in": 3600,
                "scope": "offline_access read:me read:jira-work read:sprint:jira-software report:personal-data",
            ]),
        ])
        let provider = try MBIssueJiraProvider(
            configuration: jiraConfiguration(),
            transport: transport,
            vault: MBIssueJiraCredentialVault(store: JiraInMemorySecureStore()),
            stateGenerator: { "expected-state" }
        )

        _ = try await provider.authorizationURL()
        let callbackURL = try #require(URL(
            string: "mbissue-sonex://oauth/callback?code=oauth-code&state=expected-state"
        ))

        await #expect(throws: MBIssueProviderError.permissionDenied) {
            try await provider.completeAuthorization(callbackURL: callbackURL)
        }
    }

    @Test("Issue creation resolves active sprint and uploads every screenshot")
    func createsIssueInActiveSprint() async throws {
        let transport = try JiraQueueTransport(responses: [
            json(["values": [["id": 77, "name": "Sprint 77", "state": "active"]]]),
            json(["id": "10001", "key": "MAD-999"]),
            json([["id": "attachment-1", "filename": "one.png"]]),
            json([["id": "attachment-2", "filename": "two.png"]]),
        ])
        let vault = MBIssueJiraCredentialVault(store: JiraInMemorySecureStore())
        try await vault.bootstrap(clientSecret: "app-client-secret")
        try await vault.saveAuthorization(.fixture())
        let provider = try MBIssueJiraProvider(
            configuration: jiraConfiguration(),
            transport: transport,
            vault: vault
        )
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
        let first = temporaryDirectory.appendingPathComponent("one.png")
        let second = temporaryDirectory.appendingPathComponent("two.png")
        try Data("first".utf8).write(to: first)
        try Data("second".utf8).write(to: second)

        let receipt = try await provider.submit(
            entry: .fixture(),
            screenshotURLs: [first, second]
        )

        #expect(receipt.issueKey == "MAD-999")
        #expect(receipt.issueURL.absoluteString == "https://mobven.atlassian.net/browse/MAD-999")
        #expect(receipt.uploadedFileNames == ["one.png", "two.png"])
        let requests = await transport.requests
        #expect(requests.count == 4)
        #expect(requests[0].url?.path == "/ex/jira/cloud-1/rest/agile/1.0/board/1026/sprint")
        #expect(requests[1].url?.path == "/ex/jira/cloud-1/rest/api/3/issue")
        let createBody = try #require(requests[1].httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: createBody) as? [String: Any])
        let fields = try #require(object["fields"] as? [String: Any])
        #expect(fields["summary"] as? String == "Login button does not respond")
        #expect(fields["customfield_10020"] as? Int == 77)
        #expect((fields["project"] as? [String: String])?["key"] == "MAD")
        #expect(requests[2].value(forHTTPHeaderField: "X-Atlassian-Token") == "no-check")
        #expect(requests[2].httpBody?.isEmpty == false)
    }

    @Test("Expired access is refreshed with the Keychain client secret")
    func refreshesRotatingToken() async throws {
        let transport = try JiraQueueTransport(responses: [
            json([
                "access_token": "access-2",
                "refresh_token": "refresh-2",
                "expires_in": 3600,
                "scope": "offline_access read:me read:jira-work write:jira-work read:sprint:jira-software report:personal-data",
            ]),
            json(["values": [["id": 77, "name": "Sprint", "state": "active"]]]),
            json(["id": "10001", "key": "MAD-1000"]),
        ])
        let vault = MBIssueJiraCredentialVault(store: JiraInMemorySecureStore())
        try await vault.bootstrap(clientSecret: "app-client-secret")
        try await vault.saveAuthorization(.fixture(expiresAt: .distantPast))
        let provider = try MBIssueJiraProvider(
            configuration: jiraConfiguration(),
            transport: transport,
            vault: vault
        )

        _ = try await provider.submit(entry: .fixture(), screenshotURLs: [])

        #expect(try await vault.authorization()?.accessToken == "access-2")
        #expect(try await vault.authorization()?.refreshToken == "refresh-2")
        let firstRequest = try #require(await transport.requests.first)
        let body = try #require(firstRequest.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(object["client_secret"] == "app-client-secret")
        #expect(object["refresh_token"] == "refresh-1")
    }

    @Test("Due personal data is reported once and the next cycle is persisted")
    func reportsStoredPersonalData() async throws {
        let transport = JiraQueueTransport(
            responses: [],
            rawResponses: [MBIssueRawNetworkResponse(
                statusCode: 204,
                data: Data(),
                headers: ["Cycle-Period": "10"]
            )]
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let vault = MBIssueJiraCredentialVault(store: JiraInMemorySecureStore())
        try await vault.bootstrap(clientSecret: "app-client-secret")
        try await vault.saveAuthorization(.fixture(
            expiresAt: .distantFuture,
            personalDataRetrievedAt: now.addingTimeInterval(-86400),
            nextPersonalDataReportAt: now.addingTimeInterval(-1)
        ))
        let provider = try MBIssueJiraProvider(
            configuration: jiraConfiguration(),
            transport: transport,
            vault: vault,
            now: { now }
        )

        _ = try await provider.connection()
        _ = try await provider.connection()

        #expect(await transport.rawRequests.count == 1)
        #expect(try await vault.authorization()?.nextPersonalDataReportAt == now.addingTimeInterval(10 * 86400))
    }

    @Test("Closed-account directive erases the locally stored reporter")
    func erasesClosedReporter() async throws {
        let response = try json([
            "accounts": [["accountId": "account-1", "status": "closed"]],
        ])
        let transport = JiraQueueTransport(
            responses: [],
            rawResponses: [MBIssueRawNetworkResponse(statusCode: 200, data: response, headers: [:])]
        )
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let vault = MBIssueJiraCredentialVault(store: JiraInMemorySecureStore())
        try await vault.bootstrap(clientSecret: "app-client-secret")
        try await vault.saveAuthorization(.fixture(
            personalDataRetrievedAt: now,
            nextPersonalDataReportAt: .distantPast
        ))
        let provider = try MBIssueJiraProvider(
            configuration: jiraConfiguration(),
            transport: transport,
            vault: vault,
            now: { now }
        )

        await #expect(throws: MBIssueProviderError.reporterAuthorizationRequired) {
            try await provider.connection()
        }
        #expect(try await vault.authorization() == nil)
    }

    private func jiraConfiguration() throws -> MBIssueJiraConfiguration {
        try MBIssueJiraConfiguration(
            clientID: "app-client-id",
            clientSecret: "app-client-secret",
            callbackURL: #require(URL(string: "mbissue-sonex://oauth/callback")),
            siteURL: #require(URL(string: "https://mobven.atlassian.net")),
            projectKey: "MAD",
            issueTypeID: "10841",
            boardID: 1026,
            sprintFieldID: "customfield_10020",
            labels: ["ios"],
            priorityNames: [.major: "High"]
        )
    }

    private func json(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

private actor JiraQueueTransport: MBIssueNetworkTransport {
    private var responses: [Data]
    private var queuedRawResponses: [MBIssueRawNetworkResponse]
    private(set) var requests: [URLRequest] = []
    private(set) var rawRequests: [URLRequest] = []

    init(
        responses: [Data],
        rawResponses: [MBIssueRawNetworkResponse] = []
    ) {
        self.responses = responses
        queuedRawResponses = rawResponses
    }

    func send<Response: Decodable & Sendable>(
        _ request: URLRequest,
        decoding _: Response.Type
    ) throws -> Response {
        requests.append(request)
        guard !responses.isEmpty else {
            throw MBIssueProviderError.invalidResponse
        }
        return try JSONDecoder().decode(Response.self, from: responses.removeFirst())
    }

    func sendRaw(_ request: URLRequest) throws -> MBIssueRawNetworkResponse {
        rawRequests.append(request)
        guard !queuedRawResponses.isEmpty else {
            throw MBIssueProviderError.invalidResponse
        }
        return queuedRawResponses.removeFirst()
    }
}

private actor JiraInMemorySecureStore: MBIssueSecureStoring {
    private var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        values[key]
    }

    func setData(_ data: Data, forKey key: String) {
        values[key] = data
    }

    func removeData(forKey key: String) {
        values[key] = nil
    }
}

private extension MBIssueJiraAuthorization {
    static func fixture(
        expiresAt: Date = .distantFuture,
        personalDataRetrievedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        nextPersonalDataReportAt: Date? = .distantFuture
    ) -> Self {
        .init(
            accessToken: "access-1",
            refreshToken: "refresh-1",
            expiresAt: expiresAt,
            scopes: MBIssueJiraConfiguration.defaultScopes,
            cloudID: "cloud-1",
            accountID: "account-1",
            displayName: "QA User",
            avatarURL: nil,
            personalDataRetrievedAt: personalDataRetrievedAt,
            nextPersonalDataReportAt: nextPersonalDataReportAt
        )
    }
}

private extension MBIssueEntry {
    static func fixture() -> Self {
        .init(
            id: UUID(uuidString: "7D106D74-0E1E-41B7-B9DC-C6E455F2D5B0")!,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            title: "Login button does not respond",
            description: "Tapping the primary action has no visible result.",
            severity: .major,
            technicalContext: nil,
            screenshotFileNames: []
        )
    }
}
