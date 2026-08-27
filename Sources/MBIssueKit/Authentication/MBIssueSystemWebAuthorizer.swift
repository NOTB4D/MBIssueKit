#if canImport(AuthenticationServices)
    import AuthenticationServices
    import Foundation

    @MainActor
    final class MBIssueSystemWebAuthorizer: NSObject, MBIssueWebAuthorizing {
        typealias AnchorProvider = @MainActor () -> ASPresentationAnchor?

        private let anchorProvider: AnchorProvider
        private let browserSessionPolicy: MBIssueBrowserSessionPolicy
        private var activeSession: ASWebAuthenticationSession?
        private var continuation: CheckedContinuation<URL, Error>?
        private var expectedCallbackScheme: String?

        init(
            browserSessionPolicy: MBIssueBrowserSessionPolicy = .shared,
            anchorProvider: @escaping AnchorProvider
        ) {
            self.browserSessionPolicy = browserSessionPolicy
            self.anchorProvider = anchorProvider
        }

        func authorize(at url: URL, callbackURLScheme: String) async throws -> URL {
            guard activeSession == nil else {
                throw MBIssueProviderError.authorizationInProgress
            }
            guard anchorProvider() != nil else {
                throw MBIssueProviderError.missingPresentationAnchor
            }

            return try await withTaskCancellationHandler {
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
                    session.prefersEphemeralWebBrowserSession = browserSessionPolicy == .ephemeral
                    activeSession = session
                    guard session.start() else {
                        finish(result: .failure(MBIssueProviderError.authorizationCouldNotStart))
                        return
                    }
                }
            } onCancel: {
                Task { @MainActor [weak self] in
                    self?.cancel()
                }
            }
        }

        func handleOpenURL(_ url: URL) -> Bool {
            guard continuation != nil,
                  url.scheme?.lowercased() == expectedCallbackScheme
            else {
                return false
            }

            // Some identity-provider handoffs return the custom callback directly
            // to the host app instead of to ASWebAuthenticationSession. Resume the
            // same in-memory authorization and then dismiss the orphaned browser.
            let session = activeSession
            finish(result: .success(url))
            session?.cancel()
            return true
        }

        private func finish(callbackURL: URL?, error: Error?) {
            if let authenticationError = error as? ASWebAuthenticationSessionError,
               authenticationError.code == .canceledLogin
            {
                finish(result: .failure(MBIssueProviderError.authorizationCancelled))
                return
            }
            if let error {
                finish(result: .failure(MBIssueProviderError.transport(error.localizedDescription)))
                return
            }
            guard let callbackURL,
                  callbackURL.scheme?.lowercased() == expectedCallbackScheme
            else {
                finish(result: .failure(MBIssueProviderError.invalidAuthorizationCallback))
                return
            }
            finish(result: .success(callbackURL))
        }

        private func cancel() {
            activeSession?.cancel()
            finish(result: .failure(CancellationError()))
        }

        private func finish(result: Result<URL, Error>) {
            guard let continuation else { return }
            self.continuation = nil
            activeSession = nil
            expectedCallbackScheme = nil
            continuation.resume(with: result)
        }
    }

    extension MBIssueSystemWebAuthorizer: ASWebAuthenticationPresentationContextProviding {
        func presentationAnchor(for _: ASWebAuthenticationSession) -> ASPresentationAnchor {
            // Authorization refuses to start without an anchor, so this fallback is unreachable.
            anchorProvider() ?? ASPresentationAnchor()
        }
    }
#endif
