import Foundation
@testable import MBIssueKit
import Testing

@Suite("Reporter connection state")
@MainActor
struct MBIssueReporterConnectionControllerTests {
    @Test("Direct provider login completes with the browser callback")
    func connectsReporter() async throws {
        let provider = DirectProviderStub()
        let callback = try #require(URL(string: "mbissue://oauth/callback?code=abc&state=state"))
        let webAuthorizer = WebAuthorizerStub(result: .success(callback))
        let controller = MBIssueReporterConnectionController(
            provider: provider,
            webAuthorizer: webAuthorizer
        )

        await controller.refresh()
        await controller.connect()

        #expect(controller.state == .connected(await provider.connectedConnection))
        #expect(webAuthorizer.openedURL?.host == "auth.example.com")
        #expect(webAuthorizer.callbackURLScheme == "mbissue")
        #expect(await provider.completedCallback == callback)
    }

    @Test("Cancelling browser login leaves Jira disconnected")
    func cancellationIsNotAConnection() async {
        let provider = DirectProviderStub()
        let controller = MBIssueReporterConnectionController(
            provider: provider,
            webAuthorizer: WebAuthorizerStub(
                result: .failure(MBIssueProviderError.authorizationCancelled)
            )
        )

        await controller.refresh()
        await controller.connect()

        #expect(controller.state == .disconnected(provider.descriptor))
        #expect(await provider.completedCallback == nil)
    }

    @Test("Disconnect clears provider credentials before updating UI")
    func disconnectsReporter() async throws {
        let provider = DirectProviderStub(initiallyConnected: true)
        let controller = try MBIssueReporterConnectionController(
            provider: provider,
            webAuthorizer: WebAuthorizerStub(
                result: .success(#require(URL(string: "mbissue://oauth/callback")))
            )
        )

        await controller.refresh()
        await controller.disconnect()

        #expect(controller.state == .disconnected(provider.descriptor))
        #expect(await provider.disconnectCount == 1)
    }

    @Test("A callback delivered to the host app resumes the same browser session")
    func handlesHostCallback() async throws {
        let provider = DirectProviderStub()
        let webAuthorizer = CallbackDrivenWebAuthorizerStub()
        let controller = MBIssueReporterConnectionController(
            provider: provider,
            webAuthorizer: webAuthorizer
        )

        await controller.refresh()
        let connectionTask = Task { await controller.connect() }
        while !webAuthorizer.isAwaitingCallback {
            await Task.yield()
        }
        let callback = try #require(URL(string: "mbissue://oauth/callback?code=abc&state=state"))

        #expect(controller.handleOpenURL(callback))
        await connectionTask.value

        #expect(controller.state == .connected(await provider.connectedConnection))
        #expect(await provider.completedCallback == callback)
    }
}

private actor DirectProviderStub: MBIssueProvider {
    nonisolated let descriptor = MBIssueTrackerProvider(
        id: "stub",
        displayName: "Tracker",
        destinationName: "Mobile board",
        requiresReporterAuthorization: true
    )
    nonisolated let callbackURLScheme = "mbissue"
    private var isConnected: Bool
    private(set) var completedCallback: URL?
    private(set) var disconnectCount = 0

    init(initiallyConnected: Bool = false) {
        isConnected = initiallyConnected
    }

    var connectedConnection: MBIssueReporterConnection {
        MBIssueReporterConnection(
            provider: descriptor,
            reporter: .init(accountID: "account", displayName: "QA User")
        )
    }

    func prepare() {}

    func connection() -> MBIssueReporterConnection {
        MBIssueReporterConnection(
            provider: descriptor,
            reporter: isConnected ? .init(accountID: "account", displayName: "QA User") : nil
        )
    }

    func authorizationURL() -> URL {
        URL(string: "https://auth.example.com/authorize")!
    }

    func completeAuthorization(callbackURL: URL) -> MBIssueReporterConnection {
        completedCallback = callbackURL
        isConnected = true
        return connectedConnection
    }

    func disconnect() {
        disconnectCount += 1
        isConnected = false
    }

    func submit(entry _: MBIssueEntry, screenshotURLs _: [URL]) throws -> MBIssueSubmissionReceipt {
        throw MBIssueProviderError.invalidResponse
    }
}

@MainActor
private final class WebAuthorizerStub: MBIssueWebAuthorizing {
    let result: Result<URL, Error>
    private(set) var openedURL: URL?
    private(set) var callbackURLScheme: String?

    init(result: Result<URL, Error>) {
        self.result = result
    }

    func authorize(at url: URL, callbackURLScheme: String) async throws -> URL {
        openedURL = url
        self.callbackURLScheme = callbackURLScheme
        return try result.get()
    }

    func handleOpenURL(_: URL) -> Bool {
        false
    }
}

@MainActor
private final class CallbackDrivenWebAuthorizerStub: MBIssueWebAuthorizing {
    private var continuation: CheckedContinuation<URL, Error>?

    var isAwaitingCallback: Bool {
        continuation != nil
    }

    func authorize(at _: URL, callbackURLScheme _: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        guard let continuation else { return false }
        self.continuation = nil
        continuation.resume(returning: url)
        return true
    }
}
