import Combine
import Foundation

@MainActor
protocol MBIssueWebAuthorizing: AnyObject {
    func authorize(at url: URL, callbackURLScheme: String) async throws
    func handleOpenURL(_ url: URL) -> Bool
}

enum MBIssueReporterConnectionState: Equatable {
    case idle
    case loading
    case disconnected(MBIssueTrackerProvider)
    case authorizing(MBIssueTrackerProvider?)
    case connected(MBIssueReporterConnection)
    case notRequired(MBIssueTrackerProvider)
    case failed(MBIssueTrackerProvider?, String)

    var provider: MBIssueTrackerProvider? {
        switch self {
        case .idle, .loading:
            nil
        case let .disconnected(provider), let .notRequired(provider):
            provider
        case let .authorizing(provider), let .failed(provider, _):
            provider
        case let .connected(connection):
            connection.provider
        }
    }

    var canSubmit: Bool {
        switch self {
        case .connected, .notRequired:
            true
        case .idle, .loading, .disconnected, .authorizing, .failed:
            false
        }
    }
}

@MainActor
final class MBIssueReporterConnectionController: ObservableObject {
    @Published private(set) var state: MBIssueReporterConnectionState = .idle

    private let gateway: (any MBIssueReportingGateway)?
    private let callbackURLScheme: String?
    private let webAuthorizer: (any MBIssueWebAuthorizing)?

    init(
        gateway: any MBIssueReportingGateway,
        callbackURLScheme: String,
        webAuthorizer: any MBIssueWebAuthorizing
    ) {
        self.gateway = gateway
        self.callbackURLScheme = callbackURLScheme
        self.webAuthorizer = webAuthorizer
    }

    init(managedProviderDisplayName: String) {
        gateway = nil
        callbackURLScheme = nil
        webAuthorizer = nil
        state = .notRequired(.init(
            id: "host-managed",
            displayName: managedProviderDisplayName,
            destinationName: managedProviderDisplayName,
            requiresReporterAuthorization: false
        ))
    }

    func refresh() async {
        guard !isBusy else { return }
        guard let gateway else { return }
        state = .loading
        do {
            state = state(for: try await gateway.reporterConnection())
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed(nil, error.localizedDescription)
        }
    }

    func connect() async {
        guard !isBusy else { return }
        guard let gateway, let callbackURLScheme, let webAuthorizer else { return }
        let previousProvider = state.provider
        state = .authorizing(previousProvider)
        do {
            let challenge = try await gateway.startReporterAuthorization()
            guard challenge.expiresAt > Date() else {
                throw MBIssueGatewayError.authorizationExpired
            }
            try await webAuthorizer.authorize(
                at: challenge.authorizationURL,
                callbackURLScheme: callbackURLScheme
            )
            guard challenge.expiresAt > Date() else {
                throw MBIssueGatewayError.authorizationExpired
            }
            let connection = try await gateway.completeReporterAuthorization(
                authorizationID: challenge.authorizationID,
                proof: challenge.proof
            )
            state = state(for: connection)
        } catch MBIssueGatewayError.authorizationCancelled {
            if let previousProvider {
                state = .disconnected(previousProvider)
            } else {
                state = .idle
            }
        } catch is CancellationError {
            if let previousProvider {
                state = .disconnected(previousProvider)
            } else {
                state = .idle
            }
        } catch {
            state = .failed(previousProvider, error.localizedDescription)
        }
    }

    func disconnect() async {
        guard !isBusy else { return }
        guard let gateway else { return }
        let provider = state.provider
        state = .loading
        do {
            try await gateway.disconnectReporter()
            if let provider {
                state = .disconnected(provider)
            } else {
                state = .idle
            }
        } catch {
            state = .failed(provider, error.localizedDescription)
        }
    }

    /// Completes an authorization whose custom callback was delivered directly
    /// to the host application instead of the active web authentication session.
    func handleOpenURL(_ url: URL) -> Bool {
        webAuthorizer?.handleOpenURL(url) ?? false
    }

    private var isBusy: Bool {
        switch state {
        case .loading, .authorizing:
            true
        case .idle, .disconnected, .connected, .notRequired, .failed:
            false
        }
    }

    private func state(for connection: MBIssueReporterConnection) -> MBIssueReporterConnectionState {
        if connection.provider.requiresReporterAuthorization {
            return connection.reporter == nil ? .disconnected(connection.provider) : .connected(connection)
        }
        return .notRequired(connection.provider)
    }
}
