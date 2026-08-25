import Foundation

public enum MBIssueGatewayError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case authenticationFailed
    case permissionDenied
    case attachmentUnreadable(String)
    case transport(String)
    case server(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The issue-reporting service returned an invalid response."
        case .authenticationFailed:
            return "Your session has expired. Sign in again and retry."
        case .permissionDenied:
            return "This account cannot submit issue reports."
        case let .attachmentUnreadable(fileName):
            return "The screenshot \(fileName) could not be read."
        case let .transport(message):
            return "The issue-reporting service could not be reached: \(message)"
        case let .server(statusCode, message):
            return "Issue-reporting error (\(statusCode)): \(message)"
        }
    }
}
