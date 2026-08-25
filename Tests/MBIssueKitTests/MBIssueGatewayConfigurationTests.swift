import Foundation
@testable import MBIssueKit
import Testing

@Suite("Issue gateway configuration")
struct MBIssueGatewayConfigurationTests {
    @Test("Only the backend endpoint and access-token provider are configured on iOS")
    func normalizesBackendConfiguration() throws {
        let gateway = try MBIssueGatewayConfiguration(
            baseURL: #require(URL(string: "https://api.sonex.example/")),
            displayName: "  Sonex issue reporting  ",
            accessTokenProvider: { "session-token" }
        )

        #expect(gateway.baseURL.absoluteString == "https://api.sonex.example")
        #expect(gateway.displayName == "Sonex issue reporting")
    }

    @Test("Insecure backend endpoints are rejected")
    func rejectsHTTP() throws {
        #expect(throws: MBIssueConfigurationError.insecureBaseURL) {
            try MBIssueGatewayConfiguration(
                baseURL: #require(URL(string: "http://api.sonex.example")),
                accessTokenProvider: { "session-token" }
            )
        }
    }
}
