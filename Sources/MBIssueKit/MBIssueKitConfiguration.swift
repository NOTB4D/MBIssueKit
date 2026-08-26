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

/// Controls whether interactive authorization shares Safari's website data.
public enum MBIssueBrowserSessionPolicy: Equatable, Sendable {
    /// Shares the system browser session. This is the resilient default for identity-provider app handoffs.
    case shared

    /// Uses an isolated browser session and may require the reporter to sign in more often.
    case ephemeral
}

/// Provider-neutral interactive authorization settings owned by the host app.
public struct MBIssueReporterAuthenticationConfiguration: Sendable {
    public let callbackURLScheme: String
    public let browserSessionPolicy: MBIssueBrowserSessionPolicy
    public let authorizationTimeout: TimeInterval
    public let pollingInterval: TimeInterval
    let sessionStore: any MBIssueReporterSessionStoring

    public init(
        callbackURLScheme: String,
        browserSessionPolicy: MBIssueBrowserSessionPolicy = .shared,
        authorizationTimeout: TimeInterval = 300,
        pollingInterval: TimeInterval = 1,
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
        guard authorizationTimeout.isFinite,
              pollingInterval.isFinite,
              authorizationTimeout > 0,
              pollingInterval > 0,
              pollingInterval <= authorizationTimeout
        else {
            throw MBIssueConfigurationError.invalidAuthorizationTiming
        }
        self.callbackURLScheme = scheme
        self.browserSessionPolicy = browserSessionPolicy
        self.authorizationTimeout = authorizationTimeout
        self.pollingInterval = pollingInterval
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
    case invalidAuthorizationTiming
    case reporterAuthenticationUnavailable

    public var errorDescription: String? {
        switch self {
        case .insecureBaseURL:
            "The issue-reporting backend must use a valid HTTPS URL."
        case .invalidBaseURL:
            "The issue-reporting backend URL is invalid."
        case .missingAccessToken:
            "The host application did not provide an access token."
        case .missingReporterSession:
            "Connect an issue-tracker account before submitting reports."
        case .missingAuthorizationProof:
            "The reporter authorization proof is missing."
        case .invalidCallbackURLScheme:
            "Reporter authentication requires a valid custom callback URL scheme."
        case .invalidAuthorizationTiming:
            "Reporter authentication timeout and polling interval must be positive and valid."
        case .reporterAuthenticationUnavailable:
            "Reporter authentication is not configured by the host application."
        }
    }
}
