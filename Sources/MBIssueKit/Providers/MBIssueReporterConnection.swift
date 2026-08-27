import Foundation

/// Metadata describing the issue tracker configured by the host application.
public struct MBIssueTrackerProvider: Codable, Equatable, Sendable {
    public let id: String
    public let displayName: String
    public let destinationName: String
    public let requiresReporterAuthorization: Bool

    public init(
        id: String,
        displayName: String,
        destinationName: String,
        requiresReporterAuthorization: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.destinationName = destinationName
        self.requiresReporterAuthorization = requiresReporterAuthorization
    }
}

/// The verified human identity connected to the issue tracker.
public struct MBIssueReporterIdentity: Codable, Equatable, Sendable {
    public let accountID: String
    public let displayName: String
    public let avatarURL: URL?

    public init(accountID: String, displayName: String, avatarURL: URL? = nil) {
        self.accountID = accountID
        self.displayName = displayName
        self.avatarURL = avatarURL
    }
}

/// Current provider and verified reporter returned by the provider adapter.
public struct MBIssueReporterConnection: Codable, Equatable, Sendable {
    public let provider: MBIssueTrackerProvider
    public let reporter: MBIssueReporterIdentity?
    public let expiresAt: Date?

    public init(
        provider: MBIssueTrackerProvider,
        reporter: MBIssueReporterIdentity?,
        expiresAt: Date? = nil
    ) {
        self.provider = provider
        self.reporter = reporter
        self.expiresAt = expiresAt
    }

    public var isConnected: Bool {
        reporter != nil
    }
}
