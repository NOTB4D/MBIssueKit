import Foundation

/// Runtime settings supplied by the host application.
public struct MBIssueKitConfiguration: Sendable {
    public let jira: MBIssueJiraConfiguration

    public init(jira: MBIssueJiraConfiguration) {
        self.jira = jira
    }
}

/// Credentials and Jira Cloud field defaults used when creating tasks.
///
/// Swift Package Manager cannot receive runtime credentials while resolving a
/// dependency. Supply this value from the host app at startup instead, and keep
/// the API token out of source control.
public struct MBIssueJiraConfiguration: Equatable, Sendable {
    public let baseURL: URL
    public let email: String
    public let apiToken: String
    public let projectKey: String
    public let issueType: String
    public let labels: [String]

    public init(
        baseURL: URL,
        email: String,
        apiToken: String,
        projectKey: String,
        issueType: String = "Task",
        labels: [String] = ["mbissuekit", "ios"]
    ) throws {
        guard baseURL.scheme?.lowercased() == "https", baseURL.host != nil else {
            throw MBIssueConfigurationError.insecureBaseURL
        }

        self.email = try Self.required(email, name: "email")
        self.apiToken = try Self.required(apiToken, name: "apiToken")
        self.projectKey = try Self.required(projectKey, name: "projectKey").uppercased()
        self.issueType = try Self.required(issueType, name: "issueType")
        self.labels = labels.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        }
        self.baseURL = try Self.normalizedBaseURL(baseURL)
    }

    /// Creates Jira settings from values injected by the host app's scheme or
    /// configuration layer.
    public init(environment: [String: String] = ProcessInfo.processInfo.environment) throws {
        let baseURLValue = try Self.environmentValue(.baseURL, in: environment)
        guard let baseURL = URL(string: baseURLValue) else {
            throw MBIssueConfigurationError.invalidBaseURL
        }
        let labelValue = environment[EnvironmentKey.labels.rawValue]
        let labels = labelValue?.components(separatedBy: ",") ?? ["mbissuekit", "ios"]

        try self.init(
            baseURL: baseURL,
            email: Self.environmentValue(.email, in: environment),
            apiToken: Self.environmentValue(.apiToken, in: environment),
            projectKey: Self.environmentValue(.projectKey, in: environment),
            issueType: environment[EnvironmentKey.issueType.rawValue] ?? "Task",
            labels: labels
        )
    }

    private static func required(_ value: String, name: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw MBIssueConfigurationError.missingValue(name)
        }
        return normalized
    }

    private static func environmentValue(
        _ key: EnvironmentKey,
        in environment: [String: String]
    ) throws -> String {
        guard let value = environment[key.rawValue] else {
            throw MBIssueConfigurationError.missingValue(key.rawValue)
        }
        return try required(value, name: key.rawValue)
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

public extension MBIssueJiraConfiguration {
    enum EnvironmentKey: String, CaseIterable, Sendable {
        case baseURL = "MBISSUEKIT_JIRA_BASE_URL"
        case email = "MBISSUEKIT_JIRA_EMAIL"
        case apiToken = "MBISSUEKIT_JIRA_API_TOKEN"
        case projectKey = "MBISSUEKIT_JIRA_PROJECT_KEY"
        case issueType = "MBISSUEKIT_JIRA_ISSUE_TYPE"
        case labels = "MBISSUEKIT_JIRA_LABELS"
    }
}

public enum MBIssueConfigurationError: LocalizedError, Equatable, Sendable {
    case insecureBaseURL
    case invalidBaseURL
    case missingValue(String)

    public var errorDescription: String? {
        switch self {
        case .insecureBaseURL:
            return "Jira base URL must be a valid HTTPS URL."
        case .invalidBaseURL:
            return "Jira base URL is invalid."
        case let .missingValue(name):
            return "Jira configuration is missing a value for \(name)."
        }
    }
}
