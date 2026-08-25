#if canImport(AuthenticationServices)
    import AuthenticationServices
    import Foundation

    @MainActor
    final class MBIssueSystemWebAuthorizer: NSObject, MBIssueWebAuthorizing {
        typealias AnchorProvider = @MainActor () -> ASPresentationAnchor?

        private let anchorProvider: AnchorProvider
        private var activeSession: ASWebAuthenticationSession?
        private var continuation: CheckedContinuation<Void, Error>?
        private var expectedCallbackScheme: String?

        init(anchorProvider: @escaping AnchorProvider) {
            self.anchorProvider = anchorProvider
        }

        func authorize(at url: URL, callbackURLScheme: String) async throws {
            guard activeSession == nil else {
                throw MBIssueGatewayError.authorizationInProgress
            }
            guard anchorProvider() != nil else {
                throw MBIssueGatewayError.missingPresentationAnchor
            }

            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                    expectedCallbackScheme = callbackURLScheme
                    let session = ASWebAuthenticationSession(
                        url: url,
                        callbackURLScheme: callbackURLScheme
                    ) { [weak self] callbackURL, error in
                        Task { @MainActor [weak self] in
                            self?.finish(callbackURL: callbackURL, error: error)
                        }
                    }
                    session.presentationContextProvider = self
                    session.prefersEphemeralWebBrowserSession = true
                    activeSession = session
                    guard session.start() else {
                        finish(result: .failure(MBIssueGatewayError.authorizationCouldNotStart))
                        return
                    }
                }
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.cancel()
                }
            }
        }

        private func finish(callbackURL: URL?, error: Error?) {
            if let authenticationError = error as? ASWebAuthenticationSessionError,
               authenticationError.code == .canceledLogin {
                finish(result: .failure(MBIssueGatewayError.authorizationCancelled))
                return
            }
            if let error {
                finish(result: .failure(MBIssueGatewayError.transport(error.localizedDescription)))
                return
            }
            guard let callbackURL,
                  callbackURL.scheme?.lowercased() == expectedCallbackScheme
            else {
                finish(result: .failure(MBIssueGatewayError.invalidAuthorizationCallback))
                return
            }
            finish(result: .success(()))
        }

        private func cancel() {
            activeSession?.cancel()
            finish(result: .failure(CancellationError()))
        }

        private func finish(result: Result<Void, Error>) {
            guard let continuation else { return }
            self.continuation = nil
            activeSession = nil
            expectedCallbackScheme = nil
            continuation.resume(with: result)
        }
    }

    extension MBIssueSystemWebAuthorizer: ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
            // Authorization refuses to start without an anchor, so this fallback is unreachable.
            anchorProvider() ?? ASPresentationAnchor()
        }
    }
#endif
