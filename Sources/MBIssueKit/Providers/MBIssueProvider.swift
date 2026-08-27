import Foundation

/// Provider boundary used by the reporter UI and submission queue.
///
/// New issue trackers can implement this protocol without changing the report UI,
/// persistence, capture, annotation, or batch-submission layers.
public protocol MBIssueProvider: Sendable {
    var descriptor: MBIssueTrackerProvider { get }
    var callbackURLScheme: String { get }
    var browserSessionPolicy: MBIssueBrowserSessionPolicy { get }

    /// Persists provider bootstrap credentials before the reporter becomes available.
    func prepare() async throws
    func connection() async throws -> MBIssueReporterConnection
    func authorizationURL() async throws -> URL
    func completeAuthorization(callbackURL: URL) async throws -> MBIssueReporterConnection
    func disconnect() async throws
    func submit(entry: MBIssueEntry, screenshotURLs: [URL]) async throws -> MBIssueSubmissionReceipt
}

public extension MBIssueProvider {
    var browserSessionPolicy: MBIssueBrowserSessionPolicy {
        .shared
    }
}
