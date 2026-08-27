import Combine
import Foundation

@MainActor
protocol MBIssueWebAuthorizing: AnyObject {
    func authorize(at url: URL, callbackURLScheme: String) async throws -> URL
    func handleOpenURL(_ url: URL) -> Bool
}

enum MBIssueReporterConnectionState: Equatable {
    case idle
    case loading
    case disconnected(MBIssueTrackerProvider)
    case authorizing(MBIssueTrackerProvider?)
    case connected(MBIssueReporterConnection)
    case failed(MBIssueTrackerProvider?, String)

    var provider: MBIssueTrackerProvider? {
        switch self {
        case .idle, .loading:
            nil
        case let .disconnected(provider):
            provider
        case let .authorizing(provider), let .failed(provider, _):
            provider
        case let .connected(connection):
            connection.provider
        }
    }

    var canSubmit: Bool {
        if case .connected = self {
            return true
        }
        return false
    }
}

@MainActor
final class MBIssueReporterConnectionController: ObservableObject {
    @Published private(set) var state: MBIssueReporterConnectionState = .idle

    private let provider: any MBIssueProvider
    private let webAuthorizer: any MBIssueWebAuthorizing

    init(
        provider: any MBIssueProvider,
        webAuthorizer: any MBIssueWebAuthorizing
    ) {
        self.provider = provider
        self.webAuthorizer = webAuthorizer
    }

    #if DEBUG
        init(previewProviderDisplayName: String) {
            let provider = MBIssuePreviewProvider(displayName: previewProviderDisplayName)
            self.provider = provider
            webAuthorizer = MBIssuePreviewWebAuthorizer()
            state = .disconnected(provider.descriptor)
        }
    #endif

    func refresh() async {
        guard !isBusy else { return }
        state = .loading
        do {
            state = try state(for: await provider.connection())
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(provider.descriptor, error.localizedDescription)
        }
    }

    func connect() async {
        guard !isBusy else { return }
        let previousProvider = state.provider ?? provider.descriptor
        state = .authorizing(previousProvider)
        do {
            let authorizationURL = try await provider.authorizationURL()
            let callbackURL = try await webAuthorizer.authorize(
                at: authorizationURL,
                callbackURLScheme: provider.callbackURLScheme
            )
            state = try state(for: await provider.completeAuthorization(callbackURL: callbackURL))
        } catch MBIssueProviderError.authorizationCancelled {
            state = .disconnected(previousProvider)
        } catch is CancellationError {
            state = .disconnected(previousProvider)
        } catch {
            state = .failed(previousProvider, error.localizedDescription)
        }
    }

    func disconnect() async {
        guard !isBusy else { return }
        let descriptor = state.provider ?? provider.descriptor
        state = .loading
        do {
            try await provider.disconnect()
            state = .disconnected(descriptor)
        } catch {
            state = .failed(descriptor, error.localizedDescription)
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        webAuthorizer.handleOpenURL(url)
    }

    private var isBusy: Bool {
        switch state {
        case .loading, .authorizing:
            true
        case .idle, .disconnected, .connected, .failed:
            false
        }
    }

    private func state(for connection: MBIssueReporterConnection) -> MBIssueReporterConnectionState {
        connection.reporter == nil ? .disconnected(connection.provider) : .connected(connection)
    }
}

#if DEBUG
    private struct MBIssuePreviewProvider: MBIssueProvider {
        let descriptor: MBIssueTrackerProvider
        let callbackURLScheme = "mbissue-preview"

        init(displayName: String) {
            descriptor = MBIssueTrackerProvider(
                id: "preview",
                displayName: displayName,
                destinationName: displayName,
                requiresReporterAuthorization: true
            )
        }

        func prepare() async throws {}

        func connection() async throws -> MBIssueReporterConnection {
            MBIssueReporterConnection(provider: descriptor, reporter: nil)
        }

        func authorizationURL() async throws -> URL {
            throw MBIssueProviderError.authorizationCouldNotStart
        }

        func completeAuthorization(callbackURL _: URL) async throws -> MBIssueReporterConnection {
            throw MBIssueProviderError.authorizationFailed
        }

        func disconnect() async throws {}

        func submit(
            entry _: MBIssueEntry,
            screenshotURLs _: [URL]
        ) async throws -> MBIssueSubmissionReceipt {
            throw MBIssueProviderError.authorizationFailed
        }
    }

    @MainActor
    private final class MBIssuePreviewWebAuthorizer: MBIssueWebAuthorizing {
        func authorize(at _: URL, callbackURLScheme _: String) async throws -> URL {
            throw MBIssueProviderError.authorizationCouldNotStart
        }

        func handleOpenURL(_: URL) -> Bool {
            false
        }
    }
#endif
