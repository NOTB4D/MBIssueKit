import Foundation

protocol MBIssueHTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: MBIssueHTTPTransport {}

actor MBIssueReporterSessionRenewer {
    private var renewalTask: Task<MBIssueReporterSessionResponse, any Error>?

    func renew(
        operation: @escaping @Sendable () async throws -> MBIssueReporterSessionResponse
    ) async throws -> MBIssueReporterSessionResponse {
        if let renewalTask {
            return try await renewalTask.value
        }
        let task = Task { try await operation() }
        renewalTask = task
        defer { renewalTask = nil }
        return try await task.value
    }
}

protocol MBIssueReportingGateway: Sendable {
    func submit(entry: MBIssueEntry, screenshotURLs: [URL]) async throws -> MBIssueSubmissionReceipt
    func reporterConnection() async throws -> MBIssueReporterConnection
    func startReporterAuthorization() async throws -> MBIssueReporterAuthorizationChallenge
    func reporterAuthorizationStatus(
        authorizationID: UUID,
        proof: String
    ) async throws -> MBIssueReporterAuthorizationStatus
    func completeReporterAuthorization(
        authorizationID: UUID,
        proof: String
    ) async throws -> MBIssueReporterConnection
    func disconnectReporter() async throws
}

struct MBIssueGatewayClient: MBIssueReportingGateway, Sendable {
    let configuration: MBIssueGatewayConfiguration
    private let transport: any MBIssueHTTPTransport
    private let sessionRenewer: MBIssueReporterSessionRenewer

    init(configuration: MBIssueGatewayConfiguration, session: URLSession) {
        self.init(configuration: configuration, transport: session)
    }

    init(
        configuration: MBIssueGatewayConfiguration,
        transport: any MBIssueHTTPTransport,
        sessionRenewer: MBIssueReporterSessionRenewer = .init()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.sessionRenewer = sessionRenewer
    }

    func submit(
        entry: MBIssueEntry,
        screenshotURLs: [URL]
    ) async throws -> MBIssueSubmissionReceipt {
        let accessToken = try await configuration.accessTokenProvider()
        let authentication = configuration.reporterAuthentication
        var reporterSessionToken = try await authentication?.sessionStore.loadToken()
        if reporterSessionToken == nil, authentication != nil {
            reporterSessionToken = try await renewReporterSession(accessToken: accessToken).reporterSessionToken
        }
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
        let response: SubmitResponse
        do {
            response = try await perform(request)
        } catch MBIssueGatewayError.reporterAuthorizationRequired {
            let renewed = try await renewReporterSession(accessToken: accessToken)
            let retry = try MBIssueGatewayRequestBuilder.submit(
                entry: entry,
                screenshots: attachments,
                configuration: configuration,
                accessToken: accessToken,
                reporterSessionToken: renewed.reporterSessionToken
            )
            response = try await perform(retry)
        }
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
        guard let reporterToken else {
            return try await renewReporterSession(accessToken: accessToken).connection
        }
        let request = try MBIssueGatewayRequestBuilder.reporterConnection(
            configuration: configuration,
            accessToken: accessToken,
            reporterSessionToken: reporterToken
        )
        do {
            return try await perform(request)
        } catch MBIssueGatewayError.reporterAuthorizationRequired {
            try? await authentication.sessionStore.deleteToken()
            return try await renewReporterSession(accessToken: accessToken).connection
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

    func reporterAuthorizationStatus(
        authorizationID: UUID,
        proof: String
    ) async throws -> MBIssueReporterAuthorizationStatus {
        _ = try reporterAuthentication()
        let accessToken = try await configuration.accessTokenProvider()
        let request = try MBIssueGatewayRequestBuilder.reporterAuthorizationStatus(
            authorizationID: authorizationID,
            proof: proof,
            configuration: configuration,
            accessToken: accessToken
        )
        let response: MBIssueReporterAuthorizationStatusResponse = try await perform(request)
        return response.status
    }

    func disconnectReporter() async throws {
        let authentication = try reporterAuthentication()
        let accessToken = try await configuration.accessTokenProvider()
        let request = try MBIssueGatewayRequestBuilder.disconnectReporter(
            configuration: configuration,
            accessToken: accessToken
        )
        do {
            try await performNoContent(request)
        } catch MBIssueGatewayError.reporterAuthorizationRequired {
            // An already-expired server session is disconnected from the device below.
        }
        try await authentication.sessionStore.deleteToken()
    }

    private func renewReporterSession(accessToken: String) async throws -> MBIssueReporterSessionResponse {
        let authentication = try reporterAuthentication()
        let configuration = configuration
        let transport = transport
        let response = try await sessionRenewer.renew {
            let request = try MBIssueGatewayRequestBuilder.renewReporterSession(
                configuration: configuration,
                accessToken: accessToken
            )
            return try await Self.perform(request, using: transport)
        }
        let token = response.reporterSessionToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw MBIssueGatewayError.invalidResponse
        }
        try await authentication.sessionStore.saveToken(token)
        return response
    }

    private func reporterAuthentication() throws -> MBIssueReporterAuthenticationConfiguration {
        guard let authentication = configuration.reporterAuthentication else {
            throw MBIssueConfigurationError.reporterAuthenticationUnavailable
        }
        return authentication
    }

    private func perform<Output: Decodable>(_ request: URLRequest) async throws -> Output {
        try await Self.perform(request, using: transport)
    }

    private static func perform<Output: Decodable>(
        _ request: URLRequest,
        using transport: any MBIssueHTTPTransport
    ) async throws -> Output {
        let data = try await responseData(for: request, using: transport)
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Output.self, from: data)
        } catch {
            throw MBIssueGatewayError.invalidResponse
        }
    }

    private func performNoContent(_ request: URLRequest) async throws {
        _ = try await Self.responseData(for: request, using: transport)
    }

    private static func responseData(
        for request: URLRequest,
        using transport: any MBIssueHTTPTransport
    ) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
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

    private static func mapHTTPError(statusCode: Int, data: Data) -> MBIssueGatewayError {
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
