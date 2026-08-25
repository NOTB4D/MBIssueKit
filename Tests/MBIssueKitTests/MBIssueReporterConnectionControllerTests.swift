import Foundation
@testable import MBIssueKit
import Testing

@Suite("Reporter connection state")
@MainActor
struct MBIssueReporterConnectionControllerTests {
    @Test("Successful web authorization exposes only the verified reporter")
    func connectsReporter() async {
        let provider = MBIssueTrackerProvider(
            id: "future-provider",
            displayName: "Future Tracker",
            destinationName: "Mobile board",
            requiresReporterAuthorization: true
        )
        let reporter = MBIssueReporterIdentity(accountID: "account-1", displayName: "QA User")
        let gateway = GatewayStub(
            initialConnection: .init(provider: provider, reporter: nil),
            completedConnection: .init(provider: provider, reporter: reporter)
        )
        let webAuthorizer = WebAuthorizerStub(result: .success(()))
        let controller = MBIssueReporterConnectionController(
            gateway: gateway,
            callbackURLScheme: "sonex-mbissue",
            webAuthorizer: webAuthorizer
        )

        await controller.refresh()
        await controller.connect()

        #expect(controller.state == .connected(.init(provider: provider, reporter: reporter)))
        #expect(webAuthorizer.openedURL?.host == "auth.example.com")
        #expect(webAuthorizer.callbackURLScheme == "sonex-mbissue")
        #expect(await gateway.completionCount == 1)
    }

    @Test("Cancelling browser authentication keeps reports disconnected")
    func cancellationIsNotAConnection() async {
        let provider = MBIssueTrackerProvider(
            id: "provider",
            displayName: "Tracker",
            destinationName: "Board",
            requiresReporterAuthorization: true
        )
        let gateway = GatewayStub(
            initialConnection: .init(provider: provider, reporter: nil),
            completedConnection: .init(
                provider: provider,
                reporter: .init(accountID: "must-not-connect", displayName: "Wrong")
            )
        )
        let controller = MBIssueReporterConnectionController(
            gateway: gateway,
            callbackURLScheme: "sonex-mbissue",
            webAuthorizer: WebAuthorizerStub(result: .failure(MBIssueGatewayError.authorizationCancelled))
        )

        await controller.refresh()
        await controller.connect()

        #expect(controller.state == .disconnected(provider))
        #expect(await gateway.completionCount == 0)
    }

    @Test("Disconnect revokes the backend session before clearing UI state")
    func disconnectsReporter() async {
        let provider = MBIssueTrackerProvider(
            id: "provider",
            displayName: "Tracker",
            destinationName: "Board",
            requiresReporterAuthorization: true
        )
        let reporter = MBIssueReporterIdentity(accountID: "account", displayName: "QA User")
        let gateway = GatewayStub(
            initialConnection: .init(provider: provider, reporter: reporter),
            completedConnection: .init(provider: provider, reporter: reporter)
        )
        let controller = MBIssueReporterConnectionController(
            gateway: gateway,
            callbackURLScheme: "sonex-mbissue",
            webAuthorizer: WebAuthorizerStub(result: .success(()))
        )

        await controller.refresh()
        await controller.disconnect()

        #expect(controller.state == .disconnected(provider))
        #expect(await gateway.disconnectCount == 1)
    }
}

private actor GatewayStub: MBIssueReportingGateway {
    let initialConnection: MBIssueReporterConnection
    let completedConnection: MBIssueReporterConnection
    private(set) var completionCount = 0
    private(set) var disconnectCount = 0

    init(
        initialConnection: MBIssueReporterConnection,
        completedConnection: MBIssueReporterConnection
    ) {
        self.initialConnection = initialConnection
        self.completedConnection = completedConnection
    }

    func submit(entry: MBIssueEntry, screenshotURLs: [URL]) async throws -> MBIssueSubmissionReceipt {
        Issue.record("Submission is outside this state-machine test")
        throw MBIssueGatewayError.invalidResponse
    }

    func reporterConnection() async throws -> MBIssueReporterConnection {
        initialConnection
    }

    func startReporterAuthorization() async throws -> MBIssueReporterAuthorizationChallenge {
        .init(
            authorizationID: UUID(uuidString: "18F79FBB-47AF-45E3-9997-E7E2AE4D7AFD")!,
            authorizationURL: URL(string: "https://auth.example.com/authorize")!,
            proof: "memory-only-proof",
            expiresAt: Date().addingTimeInterval(300)
        )
    }

    func completeReporterAuthorization(
        authorizationID: UUID,
        proof: String
    ) async throws -> MBIssueReporterConnection {
        completionCount += 1
        return completedConnection
    }

    func disconnectReporter() async throws {
        disconnectCount += 1
    }
}

@MainActor
private final class WebAuthorizerStub: MBIssueWebAuthorizing {
    let result: Result<Void, Error>
    private(set) var openedURL: URL?
    private(set) var callbackURLScheme: String?

    init(result: Result<Void, Error>) {
        self.result = result
    }

    func authorize(at url: URL, callbackURLScheme: String) async throws {
        openedURL = url
        self.callbackURLScheme = callbackURLScheme
        try result.get()
    }
}
