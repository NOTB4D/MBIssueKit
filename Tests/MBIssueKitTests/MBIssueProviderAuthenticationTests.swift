import Foundation
@testable import MBIssueKit
import Testing

@Suite("Provider authentication gateway")
struct MBIssueProviderAuthenticationTests {
    @Test("Authorization starts through the provider-neutral gateway endpoint")
    func buildsAuthorizationStartRequest() throws {
        let configuration = try gatewayConfiguration()

        let request = try MBIssueGatewayRequestBuilder.startReporterAuthorization(
            configuration: configuration,
            accessToken: "host-session"
        )

        #expect(request.url?.absoluteString == "https://api.sonex.example/issue-reporting/api/v1/reporter/authorization")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer host-session")
        #expect(request.httpBody == nil)
    }

    @Test("Authorization completion sends only the one-time proof")
    func buildsAuthorizationCompletionRequest() throws {
        let configuration = try gatewayConfiguration()
        let authorizationID = try #require(UUID(uuidString: "25F72590-BFFE-487B-B3A3-02DEDBF6A8AF"))

        let request = try MBIssueGatewayRequestBuilder.completeReporterAuthorization(
            authorizationID: authorizationID,
            proof: "one-time-proof",
            configuration: configuration,
            accessToken: "host-session"
        )

        #expect(request.url?.absoluteString == "https://api.sonex.example/issue-reporting/api/v1/reporter/authorization/25F72590-BFFE-487B-B3A3-02DEDBF6A8AF/complete")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer host-session")

        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(object == ["proof": "one-time-proof"])
        #expect(!String(decoding: body, as: UTF8.self).localizedCaseInsensitiveContains("jira"))
    }

    @Test("Reporter session status is provider neutral")
    func buildsReporterStatusRequest() throws {
        let configuration = try gatewayConfiguration()

        let request = try MBIssueGatewayRequestBuilder.reporterConnection(
            configuration: configuration,
            accessToken: "host-session",
            reporterSessionToken: "reporter-session"
        )

        #expect(request.url?.absoluteString == "https://api.sonex.example/issue-reporting/api/v1/reporter")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "X-MBIssue-Reporter-Session") == "Bearer reporter-session")
    }

    @Test("Reporter session renewal relies only on the authenticated host session")
    func buildsReporterSessionRenewalRequest() throws {
        let configuration = try gatewayConfiguration()

        let request = try MBIssueGatewayRequestBuilder.renewReporterSession(
            configuration: configuration,
            accessToken: "host-session"
        )

        #expect(request.url?.absoluteString == "https://api.sonex.example/issue-reporting/api/v1/reporter/session")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer host-session")
        #expect(request.value(forHTTPHeaderField: "X-MBIssue-Reporter-Session") == nil)
        #expect(request.httpBody == nil)
    }

    @Test("Reporter disconnect revokes the server binding without trusting a reporter token")
    func buildsReporterDisconnectRequest() throws {
        let configuration = try gatewayConfiguration()

        let request = try MBIssueGatewayRequestBuilder.disconnectReporter(
            configuration: configuration,
            accessToken: "host-session"
        )

        #expect(request.url?.absoluteString == "https://api.sonex.example/issue-reporting/api/v1/reporter")
        #expect(request.httpMethod == "DELETE")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer host-session")
        #expect(request.value(forHTTPHeaderField: "X-MBIssue-Reporter-Session") == nil)
    }

    private func gatewayConfiguration() throws -> MBIssueGatewayConfiguration {
        try MBIssueGatewayConfiguration(
            baseURL: #require(URL(string: "https://api.sonex.example")),
            accessTokenProvider: { "host-session" }
        )
    }
}
