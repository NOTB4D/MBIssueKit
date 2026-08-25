import Foundation

/// Runtime settings supplied by the host application.
///
/// Provider credentials and field mappings intentionally do not belong here.
/// The host configures only its authenticated issue-reporting backend.
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
/// short-lived session token, never an issue tracker's credential.
public struct MBIssueGatewayConfiguration: Sendable {
    public typealias AccessTokenProvider = @Sendable () async throws -> String

    public let baseURL: URL
    public let displayName: String
    public let reporterAuthentication: MBIssueReporterAuthenticationConfiguration?
    let accessTokenProvider: AccessTokenProvider

    public init(
        baseURL: URL,
        displayName: String = "Issue reporting",
        reporterAuthentication: MBIssueReporterAuthenticationConfiguration? = nil,
        accessTokenProvider: @escaping AccessTokenProvider
    ) throws {
        guard baseURL.scheme?.lowercased() == "https", baseURL.host != nil else {
            throw MBIssueConfigurationError.insecureBaseURL
        }
        self.baseURL = try Self.normalizedBaseURL(baseURL)
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.displayName = normalizedName.isEmpty ? "Issue reporting" : normalizedName
        self.reporterAuthentication = reporterAuthentication
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

/// Provider-neutral interactive authorization settings owned by the host app.
public struct MBIssueReporterAuthenticationConfiguration: Sendable {
    public let callbackURLScheme: String
    let sessionStore: any MBIssueReporterSessionStoring

    public init(
        callbackURLScheme: String,
        sessionStore: any MBIssueReporterSessionStoring
    ) throws {
        let scheme = callbackURLScheme.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789+.-")
        guard let first = scheme.unicodeScalars.first,
              CharacterSet.lowercaseLetters.contains(first),
              !scheme.unicodeScalars.contains(where: { !allowed.contains($0) }),
              scheme != "http",
              scheme != "https"
        else {
            throw MBIssueConfigurationError.invalidCallbackURLScheme
        }
        self.callbackURLScheme = scheme
        self.sessionStore = sessionStore
    }
}

public enum MBIssueConfigurationError: LocalizedError, Equatable, Sendable {
    case insecureBaseURL
    case invalidBaseURL
    case missingAccessToken
    case missingReporterSession
    case missingAuthorizationProof
    case invalidCallbackURLScheme
    case reporterAuthenticationUnavailable

    public var errorDescription: String? {
        switch self {
        case .insecureBaseURL:
            return "The issue-reporting backend must use a valid HTTPS URL."
        case .invalidBaseURL:
            return "The issue-reporting backend URL is invalid."
        case .missingAccessToken:
            return "The host application did not provide an access token."
        case .missingReporterSession:
            return "Connect an issue-tracker account before submitting reports."
        case .missingAuthorizationProof:
            return "The reporter authorization proof is missing."
        case .invalidCallbackURLScheme:
            return "Reporter authentication requires a valid custom callback URL scheme."
        case .reporterAuthenticationUnavailable:
            return "Reporter authentication is not configured by the host application."
        }
    }
}
