import Foundation

/// Runtime settings supplied by the host application.
///
/// Jira credentials and field mappings intentionally do not belong here. The
/// host configures only its authenticated issue-reporting backend.
public struct MBIssueKitConfiguration: Sendable {
    public let gateway: MBIssueGatewayConfiguration
    public let environment: String
    public let additionalContext: [String: String]

    public init(
        gateway: MBIssueGatewayConfiguration,
        environment: String = "unspecified",
        additionalContext: [String: String] = [:]
    ) {
        self.gateway = gateway
        let normalizedEnvironment = environment.trimmingCharacters(in: .whitespacesAndNewlines)
        self.environment = normalizedEnvironment.isEmpty ? "unspecified" : normalizedEnvironment
        self.additionalContext = additionalContext.reduce(into: [:]) { result, item in
            let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !value.isEmpty {
                result[key] = value
            }
        }
    }
}

/// Connection details for the host application's issue-reporting gateway.
///
/// The access token is resolved at request time so token refreshes do not require
/// reconfiguring the package. The closure must return the host application's own
/// short-lived session token, never a Jira credential.
public struct MBIssueGatewayConfiguration: Sendable {
    public typealias AccessTokenProvider = @Sendable () async throws -> String

    public let baseURL: URL
    public let displayName: String
    let accessTokenProvider: AccessTokenProvider

    public init(
        baseURL: URL,
        displayName: String = "Issue reporting",
        accessTokenProvider: @escaping AccessTokenProvider
    ) throws {
        guard baseURL.scheme?.lowercased() == "https", baseURL.host != nil else {
            throw MBIssueConfigurationError.insecureBaseURL
        }
        self.baseURL = try Self.normalizedBaseURL(baseURL)
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = normalizedName.isEmpty ? "Issue reporting" : normalizedName
        self.accessTokenProvider = accessTokenProvider
    }

    private static func normalizedBaseURL(_ url: URL) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw MBIssueConfigurationError.invalidBaseURL
        }
        components.query = nil
        components.fragment = nil
        while components.path.hasSuffix("/") {
            components.path.removeLast()
        }
        guard let normalized = components.url else {
            throw MBIssueConfigurationError.invalidBaseURL
        }
        return normalized
    }
}

public enum MBIssueConfigurationError: LocalizedError, Equatable, Sendable {
    case insecureBaseURL
    case invalidBaseURL
    case missingAccessToken

    public var errorDescription: String? {
        switch self {
        case .insecureBaseURL:
            return "The issue-reporting backend must use a valid HTTPS URL."
        case .invalidBaseURL:
            return "The issue-reporting backend URL is invalid."
        case .missingAccessToken:
            return "The host application did not provide an access token."
        }
    }
}
