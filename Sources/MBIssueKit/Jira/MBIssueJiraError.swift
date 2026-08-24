import Foundation

public enum MBIssueJiraError: LocalizedError, Equatable, Sendable {
    case invalidRequest
    case invalidResponse
    case authenticationFailed
    case permissionDenied
    case server(statusCode: Int, message: String)
    case transport(String)
    case attachmentUnreadable(String)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "The Jira request could not be created."
        case .invalidResponse:
            return "Jira returned an invalid response."
        case .authenticationFailed:
            return "Jira authentication failed. Check the email and API token."
        case .permissionDenied:
            return "The Jira account cannot create tasks or add attachments in this project."
        case let .server(statusCode, message):
            return "Jira error (\(statusCode)): \(message)"
        case let .transport(message):
            return "Network error: \(message)"
        case let .attachmentUnreadable(fileName):
            return "The attachment \(fileName) could not be read."
        }
    }
}
