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
    private enum AuthorizationSignal: Sendable {
        case browserCallback
        case backendReady
    }

    typealias PollingDelay = @Sendable (TimeInterval) async throws -> Void

    @Published private(set) var state: MBIssueReporterConnectionState = .idle

    private let gateway: (any MBIssueReportingGateway)?
    private let callbackURLScheme: String?
    private let webAuthorizer: (any MBIssueWebAuthorizing)?
    private let authorizationTimeout: TimeInterval
    private let pollingInterval: TimeInterval
    private let pollingDelay: PollingDelay

    init(
        gateway: any MBIssueReportingGateway,
        callbackURLScheme: String,
        webAuthorizer: any MBIssueWebAuthorizing,
        authorizationTimeout: TimeInterval = 300,
        pollingInterval: TimeInterval = 1,
        pollingDelay: @escaping PollingDelay = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.gateway = gateway
        self.callbackURLScheme = callbackURLScheme
        self.webAuthorizer = webAuthorizer
        self.authorizationTimeout = authorizationTimeout
        self.pollingInterval = pollingInterval
        self.pollingDelay = pollingDelay
    }

    init(managedProviderDisplayName: String) {
        gateway = nil
        callbackURLScheme = nil
        webAuthorizer = nil
        authorizationTimeout = 0
        pollingInterval = 0
        pollingDelay = { _ in }
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
            state = try await state(for: gateway.reporterConnection())
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
            try await awaitAuthorizationReadiness(
                challenge: challenge,
                gateway: gateway,
                callbackURLScheme: callbackURLScheme,
                webAuthorizer: webAuthorizer
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

    private func awaitAuthorizationReadiness(
        challenge: MBIssueReporterAuthorizationChallenge,
        gateway: any MBIssueReportingGateway,
        callbackURLScheme: String,
        webAuthorizer: any MBIssueWebAuthorizing
    ) async throws {
        let browserTask = Task { @MainActor in
            try await webAuthorizer.authorize(
                at: challenge.authorizationURL,
                callbackURLScheme: callbackURLScheme
            )
        }
        let timeout = authorizationTimeout
        let interval = pollingInterval
        let delay = pollingDelay

        try await withThrowingTaskGroup(of: AuthorizationSignal.self) { group in
            group.addTask {
                try await browserTask.value
                return .browserCallback
            }
            group.addTask {
                try await Self.waitForBackendReadiness(
                    challenge: challenge,
                    gateway: gateway,
                    timeout: timeout,
                    pollingInterval: interval,
                    pollingDelay: delay
                )
                return .backendReady
            }

            do {
                guard try await group.next() != nil else {
                    throw CancellationError()
                }
                browserTask.cancel()
                group.cancelAll()
            } catch {
                browserTask.cancel()
                group.cancelAll()
                throw error
            }
        }
    }

    private nonisolated static func waitForBackendReadiness(
        challenge: MBIssueReporterAuthorizationChallenge,
        gateway: any MBIssueReportingGateway,
        timeout: TimeInterval,
        pollingInterval: TimeInterval,
        pollingDelay: PollingDelay
    ) async throws {
        let deadline = min(challenge.expiresAt, Date().addingTimeInterval(timeout))
        while Date() < deadline {
            try Task.checkCancellation()
            switch try await gateway.reporterAuthorizationStatus(
                authorizationID: challenge.authorizationID,
                proof: challenge.proof
            ) {
            case .ready:
                return
            case .pending:
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0 else {
                    throw MBIssueGatewayError.authorizationExpired
                }
                try await pollingDelay(min(pollingInterval, remaining))
            case .failed:
                throw MBIssueGatewayError.authorizationFailed
            case .expired:
                throw MBIssueGatewayError.authorizationExpired
            case .consumed:
                throw MBIssueGatewayError.authorizationAlreadyCompleted
            }
        }
        throw MBIssueGatewayError.authorizationExpired
    }
}
