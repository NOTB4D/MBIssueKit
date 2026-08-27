import Foundation

/// Runtime settings supplied by the host application.
///
public struct MBIssueKitConfiguration: Sendable {
    public let provider: any MBIssueProvider
    public let environment: String
    public let additionalContext: [String: String]

    /// Creates a configuration backed directly by an issue-tracker provider.
    public init(
        provider: any MBIssueProvider,
        environment: String = "unspecified",
        additionalContext: [String: String] = [:]
    ) {
        self.provider = provider
        self.environment = Self.normalizedEnvironment(environment)
        self.additionalContext = Self.normalizedContext(additionalContext)
    }

    /// Creates a configuration that connects to Jira directly from the SDK.
    public init(
        jira: MBIssueJiraConfiguration,
        environment: String = "unspecified",
        additionalContext: [String: String] = [:]
    ) throws {
        try self.init(
            provider: MBIssueJiraProvider(configuration: jira),
            environment: environment,
            additionalContext: additionalContext
        )
    }

    var destinationName: String {
        provider.descriptor.destinationName
    }

    private static func normalizedEnvironment(_ environment: String) -> String {
        let normalized = environment.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? "unspecified" : normalized
    }

    private static func normalizedContext(_ context: [String: String]) -> [String: String] {
        context.reduce(into: [:]) { result, item in
            let key = item.key.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty, !value.isEmpty {
                result[key] = value
            }
        }
    }
}

/// Controls whether interactive authorization shares Safari's website data.
public enum MBIssueBrowserSessionPolicy: Equatable, Sendable {
    /// Shares the system browser session. This is the resilient default for identity-provider app handoffs.
    case shared

    /// Uses an isolated browser session and may require the reporter to sign in more often.
    case ephemeral
}

public enum MBIssueConfigurationError: LocalizedError, Equatable, Sendable {
    case missingJiraValue(String)
    case invalidJiraCallbackURL
    case invalidJiraSiteURL
    case invalidJiraRouting(String)
    case invalidJiraScopes
    case missingJiraClientSecret

    public var errorDescription: String? {
        switch self {
        case let .missingJiraValue(name):
            "The Jira configuration value \(name) is required."
        case .invalidJiraCallbackURL:
            "Jira OAuth requires a valid app callback URL."
        case .invalidJiraSiteURL:
            "Jira Cloud site URL must be a valid HTTPS URL."
        case let .invalidJiraRouting(name):
            "The Jira routing value \(name) is invalid."
        case .invalidJiraScopes:
            "Jira OAuth scopes do not include the permissions required by MBIssueKit."
        case .missingJiraClientSecret:
            "Jira OAuth client secret is missing from Keychain."
        }
    }
}
