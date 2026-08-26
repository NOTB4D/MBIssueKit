import Foundation

public enum MBIssueGatewayError: LocalizedError, Equatable, Sendable {
    case invalidResponse
    case authenticationFailed
    case permissionDenied
    case reporterAuthorizationRequired
    case insecureAuthorizationURL
    case authorizationCancelled
    case authorizationExpired
    case authorizationFailed
    case authorizationAlreadyCompleted
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
            "The issue-reporting service returned an invalid response."
        case .authenticationFailed:
            "Your session has expired. Sign in again and retry."
        case .permissionDenied:
            "This account cannot submit issue reports."
        case .reporterAuthorizationRequired:
            "Connect your issue-tracker account before submitting reports."
        case .insecureAuthorizationURL:
            "The issue-reporting service returned an insecure authorization URL."
        case .authorizationCancelled:
            "Issue-tracker authorization was cancelled."
        case .authorizationExpired:
            "Issue-tracker authorization expired. Start again."
        case .authorizationFailed:
            "Issue-tracker authorization could not be completed. Start again."
        case .authorizationAlreadyCompleted:
            "This issue-tracker authorization was already completed. Start again."
        case .authorizationInProgress:
            "Issue-tracker authorization is already in progress."
        case .authorizationCouldNotStart:
            "Issue-tracker authorization could not be started."
        case .invalidAuthorizationCallback:
            "The issue tracker returned an invalid authorization callback."
        case .missingPresentationAnchor:
            "Issue-tracker authorization cannot be presented right now."
        case let .attachmentUnreadable(fileName):
            "The screenshot \(fileName) could not be read."
        case let .transport(message):
            "The issue-reporting service could not be reached: \(message)"
        case let .server(statusCode, message):
            "Issue-reporting error (\(statusCode)): \(message)"
        }
    }
}
