import Foundation

/// User-authored content for a provider-neutral issue report.
public struct MBIssueDraft: Equatable, Sendable {
    public static let maximumTitleLength = 255
    public static let maximumDescriptionLength = 32767

    public let title: String
    public let description: String
    public let severity: MBIssueSeverity
    public let technicalContext: MBIssueTechnicalContext?

    public init(
        title: String,
        description: String,
        severity: MBIssueSeverity = .major,
        technicalContext: MBIssueTechnicalContext? = nil
    ) {
        self.title = title
        self.description = description
        self.severity = severity
        self.technicalContext = technicalContext
    }

    public func validated() throws -> Self {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTitle.isEmpty else {
            throw MBIssueValidationError.titleRequired
        }
        guard !normalizedDescription.isEmpty else {
            throw MBIssueValidationError.descriptionRequired
        }
        guard normalizedTitle.count <= Self.maximumTitleLength else {
            throw MBIssueValidationError.titleTooLong
        }
        guard normalizedDescription.count <= Self.maximumDescriptionLength else {
            throw MBIssueValidationError.descriptionTooLong
        }
        return Self(
            title: normalizedTitle,
            description: normalizedDescription,
            severity: severity,
            technicalContext: technicalContext
        )
    }
}

public enum MBIssueValidationError: LocalizedError, Equatable, Sendable {
    case titleRequired
    case descriptionRequired
    case titleTooLong
    case descriptionTooLong

    public var errorDescription: String? {
        switch self {
        case .titleRequired:
            return "Enter a title."
        case .descriptionRequired:
            return "Enter a description."
        case .titleTooLong:
            return "The title must be 255 characters or fewer."
        case .descriptionTooLong:
            return "The description is too long."
        }
    }
}
