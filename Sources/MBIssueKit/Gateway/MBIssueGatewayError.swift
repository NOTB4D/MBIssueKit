import Foundation

public enum MBIssueGatewayError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case authenticationFailed
    case permissionDenied
    case reporterAuthorizationRequired
    case insecureAuthorizationURL
    case authorizationCancelled
    case authorizationExpired
    case authorizationInProgress
    case authorizationCouldNotStart
    case invalidAuthorizationCallback
    case missingPresentationAnchor
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
        case .reporterAuthorizationRequired:
            return "Connect your issue-tracker account before submitting reports."
        case .insecureAuthorizationURL:
            return "The issue-reporting service returned an insecure authorization URL."
        case .authorizationCancelled:
            return "Issue-tracker authorization was cancelled."
        case .authorizationExpired:
            return "Issue-tracker authorization expired. Start again."
        case .authorizationInProgress:
            return "Issue-tracker authorization is already in progress."
        case .authorizationCouldNotStart:
            return "Issue-tracker authorization could not be started."
        case .invalidAuthorizationCallback:
            return "The issue tracker returned an invalid authorization callback."
        case .missingPresentationAnchor:
            return "Issue-tracker authorization cannot be presented right now."
        case let .attachmentUnreadable(fileName):
            return "The screenshot \(fileName) could not be read."
        case let .transport(message):
            return "The issue-reporting service could not be reached: \(message)"
        case let .server(statusCode, message):
            return "Issue-reporting error (\(statusCode)): \(message)"
        }
    }
}
