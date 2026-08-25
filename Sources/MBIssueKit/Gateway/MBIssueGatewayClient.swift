import Foundation

protocol MBIssueReportingGateway: Sendable {
    func submit(entry: MBIssueEntry, screenshotURLs: [URL]) async throws -> MBIssueSubmissionReceipt
    func reporterConnection() async throws -> MBIssueReporterConnection
    func startReporterAuthorization() async throws -> MBIssueReporterAuthorizationChallenge
    func completeReporterAuthorization(
        authorizationID: UUID,
        proof: String
    ) async throws -> MBIssueReporterConnection
    func disconnectReporter() async throws
}

struct MBIssueGatewayClient: MBIssueReportingGateway, Sendable {
    let configuration: MBIssueGatewayConfiguration
    let session: URLSession

    func submit(
        entry: MBIssueEntry,
        screenshotURLs: [URL]
    ) async throws -> MBIssueSubmissionReceipt {
        let accessToken = try await configuration.accessTokenProvider()
        let reporterSessionToken = try await configuration.reporterAuthentication?.sessionStore.loadToken()
        let attachments = try screenshotURLs.map { url in
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw MBIssueGatewayError.attachmentUnreadable(url.lastPathComponent)
            }
            return MBIssueGatewayAttachment(
                fileName: url.lastPathComponent,
                mimeType: "image/png",
                data: data
            )
        }
        let request = try MBIssueGatewayRequestBuilder.submit(
            entry: entry,
            screenshots: attachments,
            configuration: configuration,
            accessToken: accessToken,
            reporterSessionToken: reporterSessionToken
        )
        let response: SubmitResponse = try await perform(request)
        return MBIssueSubmissionReceipt(
            providerID: response.providerID,
            providerDisplayName: response.providerDisplayName,
            issueID: response.issueID,
            issueKey: response.issueKey,
            issueURL: response.issueURL,
            createdAt: Date(),
            uploadedFileNames: attachments.map(\.fileName)
        )
    }

    func reporterConnection() async throws -> MBIssueReporterConnection {
        let authentication = try reporterAuthentication()
        let accessToken = try await configuration.accessTokenProvider()
        let reporterToken = try await authentication.sessionStore.loadToken()
        let request = try MBIssueGatewayRequestBuilder.reporterConnection(
            configuration: configuration,
            accessToken: accessToken,
            reporterSessionToken: reporterToken
        )
        do {
            return try await perform(request)
        } catch MBIssueGatewayError.reporterAuthorizationRequired {
            try? await authentication.sessionStore.deleteToken()
            throw MBIssueGatewayError.reporterAuthorizationRequired
        }
    }

    func startReporterAuthorization() async throws -> MBIssueReporterAuthorizationChallenge {
        _ = try reporterAuthentication()
        let accessToken = try await configuration.accessTokenProvider()
        let request = try MBIssueGatewayRequestBuilder.startReporterAuthorization(
            configuration: configuration,
            accessToken: accessToken
        )
        let challenge: MBIssueReporterAuthorizationChallenge = try await perform(request)
        guard challenge.authorizationURL.scheme?.lowercased() == "https",
              challenge.authorizationURL.host != nil
        else {
            throw MBIssueGatewayError.insecureAuthorizationURL
        }
        return challenge
    }

    func completeReporterAuthorization(
        authorizationID: UUID,
        proof: String
    ) async throws -> MBIssueReporterConnection {
        let authentication = try reporterAuthentication()
        let accessToken = try await configuration.accessTokenProvider()
        let request = try MBIssueGatewayRequestBuilder.completeReporterAuthorization(
            authorizationID: authorizationID,
            proof: proof,
            configuration: configuration,
            accessToken: accessToken
        )
        let response: MBIssueReporterSessionResponse = try await perform(request)
        let token = response.reporterSessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw MBIssueGatewayError.invalidResponse
        }
        try await authentication.sessionStore.saveToken(token)
        return response.connection
    }

    func disconnectReporter() async throws {
        let authentication = try reporterAuthentication()
        guard let reporterToken = try await authentication.sessionStore.loadToken() else {
            return
        }
        let accessToken = try await configuration.accessTokenProvider()
        let request = try MBIssueGatewayRequestBuilder.disconnectReporter(
            configuration: configuration,
            accessToken: accessToken,
            reporterSessionToken: reporterToken
        )
        do {
            try await performNoContent(request)
        } catch MBIssueGatewayError.reporterAuthorizationRequired {
            // An already-expired server session is disconnected from the device below.
        }
        try await authentication.sessionStore.deleteToken()
    }

    private func reporterAuthentication() throws -> MBIssueReporterAuthenticationConfiguration {
        guard let authentication = configuration.reporterAuthentication else {
            throw MBIssueConfigurationError.reporterAuthenticationUnavailable
        }
        return authentication
    }

    private func perform<Output: Decodable>(_ request: URLRequest) async throws -> Output {
        let data = try await responseData(for: request)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Output.self, from: data)
        } catch {
            throw MBIssueGatewayError.invalidResponse
        }
    }

    private func performNoContent(_ request: URLRequest) async throws {
        _ = try await responseData(for: request)
    }

    private func responseData(for request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw MBIssueGatewayError.transport(error.localizedDescription)
        }
        guard let response = response as? HTTPURLResponse else {
            throw MBIssueGatewayError.invalidResponse
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw mapHTTPError(statusCode: response.statusCode, data: data)
        }
        return data
    }

    private func mapHTTPError(statusCode: Int, data: Data) -> MBIssueGatewayError {
        let response = try? JSONDecoder().decode(ErrorResponse.self, from: data)
        if statusCode == 428 || response?.code == "reporter_authorization_required" {
            return .reporterAuthorizationRequired
        }
        switch statusCode {
        case 401:
            return .authenticationFailed
        case 403:
            return .permissionDenied
        default:
            return .server(
                statusCode: statusCode,
                message: response?.reason ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
            )
        }
    }
}

private struct SubmitResponse: Decodable {
    let providerID: String
    let providerDisplayName: String
    let issueID: String
    let issueKey: String
    let issueURL: URL

    private enum CodingKeys: String, CodingKey {
        case providerID
        case providerDisplayName
        case issueID
        case issueKey
        case issueURL
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providerID = try container.decodeIfPresent(String.self, forKey: .providerID) ?? "issue-tracker"
        providerDisplayName = try container.decodeIfPresent(String.self, forKey: .providerDisplayName) ?? "Issue tracker"
        issueID = try container.decode(String.self, forKey: .issueID)
        issueKey = try container.decode(String.self, forKey: .issueKey)
        issueURL = try container.decode(URL.self, forKey: .issueURL)
    }
}

private struct ErrorResponse: Decodable {
    let code: String?
    let reason: String?
}
