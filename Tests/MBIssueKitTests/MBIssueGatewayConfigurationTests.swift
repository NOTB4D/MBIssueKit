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

    @Test("Reporter authentication uses a custom callback scheme and injected secure storage")
    func configuresProviderNeutralReporterAuthentication() throws {
        let store = InMemoryReporterSessionStore()
        let reporterAuthentication = try MBIssueReporterAuthenticationConfiguration(
            callbackURLScheme: "Sonex-MBIssue",
            sessionStore: store
        )

        #expect(reporterAuthentication.callbackURLScheme == "sonex-mbissue")
        #expect(reporterAuthentication.browserSessionPolicy == .shared)
        #expect(reporterAuthentication.authorizationTimeout == 300)
        #expect(reporterAuthentication.pollingInterval == 1)
    }

    @Test("Web callback schemes cannot collide with ordinary HTTPS navigation")
    func rejectsWebCallbackScheme() throws {
        #expect(throws: MBIssueConfigurationError.invalidCallbackURLScheme) {
            try MBIssueReporterAuthenticationConfiguration(
                callbackURLScheme: "https",
                sessionStore: InMemoryReporterSessionStore()
            )
        }
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

private actor InMemoryReporterSessionStore: MBIssueReporterSessionStoring {
    private var token: String?

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
