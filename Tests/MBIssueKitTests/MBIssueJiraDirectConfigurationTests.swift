import Foundation
@testable import MBIssueKit
import Testing

@Suite("Direct Jira configuration")
struct MBIssueJiraDirectConfigurationTests {
    @Test("Host supplied Jira values are normalized without hardcoded routing")
    func normalizesConfiguration() throws {
        let configuration = try MBIssueJiraConfiguration(
            clientID: "  client-id  ",
            clientSecret: "  client-secret  ",
            callbackURL: #require(URL(string: "mbissue-sonex://oauth/callback")),
            siteURL: #require(URL(string: "https://mobven.atlassian.net/jira/")),
            projectKey: " mad ",
            issueTypeID: " 10841 ",
            boardID: 1026,
            sprintFieldID: " customfield_10020 ",
            labels: ["PhilIA_Backend", " PhilIA_Backend ", "ios"],
            priorityNames: [.blocker: " Highest ", .major: "High"]
        )

        #expect(configuration.clientID == "client-id")
        #expect(configuration.callbackURL.absoluteString == "mbissue-sonex://oauth/callback")
        #expect(configuration.siteURL.absoluteString == "https://mobven.atlassian.net")
        #expect(configuration.projectKey == "MAD")
        #expect(configuration.issueTypeID == "10841")
        #expect(configuration.boardID == 1026)
        #expect(configuration.sprintFieldID == "customfield_10020")
        #expect(configuration.labels == ["PhilIA_Backend", "ios"])
        #expect(configuration.priorityNames[.blocker] == "Highest")
        #expect(configuration.scopes.contains("offline_access"))
        #expect(configuration.scopes.contains("write:jira-work"))
        #expect(configuration.scopes.contains("report:personal-data"))
    }

    @Test("Invalid direct Jira values fail before SDK startup")
    func rejectsInvalidConfiguration() throws {
        #expect(throws: MBIssueConfigurationError.missingJiraValue("clientSecret")) {
            try MBIssueJiraConfiguration(
                clientID: "client-id",
                clientSecret: "  ",
                callbackURL: #require(URL(string: "mbissue://oauth/callback")),
                siteURL: #require(URL(string: "https://mobven.atlassian.net")),
                projectKey: "MAD",
                issueTypeID: "10841",
                boardID: 1026,
                sprintFieldID: "customfield_10020"
            )
        }

        #expect(throws: MBIssueConfigurationError.invalidJiraCallbackURL) {
            try MBIssueJiraConfiguration(
                clientID: "client-id",
                clientSecret: "secret",
                callbackURL: #require(URL(string: "https://example.com/callback")),
                siteURL: #require(URL(string: "https://mobven.atlassian.net")),
                projectKey: "MAD",
                issueTypeID: "10841",
                boardID: 1026,
                sprintFieldID: "customfield_10020"
            )
        }
    }
}

@Suite("Jira credential bootstrap")
struct MBIssueJiraCredentialBootstrapTests {
    @Test("SDK startup moves the supplied client secret into secure storage")
    func storesClientSecret() async throws {
        let store = InMemorySecureStore()
        let vault = MBIssueJiraCredentialVault(store: store)

        try await vault.bootstrap(clientSecret: "  app-specific-secret  ")

        #expect(try await vault.clientSecret() == "app-specific-secret")
        #expect(await store.writeCount == 1)
    }

    @Test("A changed host secret replaces the previous Keychain value")
    func rotatesClientSecret() async throws {
        let store = InMemorySecureStore()
        let vault = MBIssueJiraCredentialVault(store: store)

        try await vault.bootstrap(clientSecret: "old-secret")
        try await vault.bootstrap(clientSecret: "new-secret")

        #expect(try await vault.clientSecret() == "new-secret")
        #expect(await store.writeCount == 2)
    }
}

private actor InMemorySecureStore: MBIssueSecureStoring {
    private var values: [String: Data] = [:]
    private(set) var writeCount = 0

    func data(forKey key: String) -> Data? {
        values[key]
    }

    func setData(_ data: Data, forKey key: String) {
        values[key] = data
        writeCount += 1
    }

    func removeData(forKey key: String) {
        values[key] = nil
    }
}
