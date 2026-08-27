import Foundation

/// Jira Cloud OAuth and routing values supplied by each host application.
public struct MBIssueJiraConfiguration: Sendable {
    public let clientID: String
    public let callbackURL: URL
    public let siteURL: URL
    public let projectKey: String
    public let issueTypeID: String
    public let boardID: Int
    public let sprintFieldID: String
    public let labels: [String]
    public let priorityNames: [MBIssueSeverity: String]
    public let scopes: [String]
    public let browserSessionPolicy: MBIssueBrowserSessionPolicy
    public let keychainService: String
    public let keychainAccessGroup: String?

    var initialClientSecret: String?

    public init(
        clientID: String,
        clientSecret: String,
        callbackURL: URL,
        siteURL: URL,
        projectKey: String,
        issueTypeID: String,
        boardID: Int,
        sprintFieldID: String,
        labels: [String] = [],
        priorityNames: [MBIssueSeverity: String] = [:],
        scopes: [String] = Self.defaultScopes,
        browserSessionPolicy: MBIssueBrowserSessionPolicy = .shared,
        keychainService: String? = nil,
        keychainAccessGroup: String? = nil
    ) throws {
        self.clientID = try Self.required(clientID, name: "clientID")
        initialClientSecret = try Self.required(clientSecret, name: "clientSecret")
        self.callbackURL = try Self.callbackURL(callbackURL)
        self.siteURL = try Self.siteURL(siteURL)
        self.projectKey = try Self.required(projectKey, name: "projectKey").uppercased()
        self.issueTypeID = try Self.required(issueTypeID, name: "issueTypeID")
        guard boardID > 0 else {
            throw MBIssueConfigurationError.invalidJiraRouting("boardID")
        }
        self.boardID = boardID
        self.sprintFieldID = try Self.required(sprintFieldID, name: "sprintFieldID")
        self.labels = Self.normalizedUnique(labels)
        self.priorityNames = priorityNames.reduce(into: [:]) { result, item in
            let value = item.value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                result[item.key] = value
            }
        }
        let normalizedScopes = Self.normalizedUnique(scopes).sorted()
        let requiredScopes = Set(Self.defaultScopes)
        guard requiredScopes.isSubset(of: Set(normalizedScopes)) else {
            throw MBIssueConfigurationError.invalidJiraScopes
        }
        self.scopes = normalizedScopes
        self.browserSessionPolicy = browserSessionPolicy
        let fallbackService = Bundle.main.bundleIdentifier
            .map { "\($0).MBIssueKit.Jira" }
            ?? "com.mobven.MBIssueKit.Jira"
        let normalizedService = keychainService?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.keychainService = normalizedService.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackService
        let normalizedGroup = keychainAccessGroup?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.keychainAccessGroup = normalizedGroup.flatMap { $0.isEmpty ? nil : $0 }
    }

    public static let defaultScopes = [
        "offline_access",
        "read:me",
        "read:jira-work",
        "write:jira-work",
        "read:sprint:jira-software",
        "report:personal-data",
    ]

    static let requiredSubmissionScopes = [
        "read:jira-work",
        "write:jira-work",
        "read:sprint:jira-software",
    ]

    private static func required(_ value: String, name: String) throws -> String {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw MBIssueConfigurationError.missingJiraValue(name)
        }
        return normalized
    }

    private static func callbackURL(_ url: URL) throws -> URL {
        guard let scheme = url.scheme?.lowercased(),
              !scheme.isEmpty,
              scheme != "http",
              scheme != "https"
        else {
            throw MBIssueConfigurationError.invalidJiraCallbackURL
        }
        return url
    }

    private static func siteURL(_ url: URL) throws -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme?.lowercased() == "https",
              components.host != nil
        else {
            throw MBIssueConfigurationError.invalidJiraSiteURL
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        guard let normalized = components.url else {
            throw MBIssueConfigurationError.invalidJiraSiteURL
        }
        return normalized
    }

    private static func normalizedUnique(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else {
                return nil
            }
            return normalized
        }
    }
}
