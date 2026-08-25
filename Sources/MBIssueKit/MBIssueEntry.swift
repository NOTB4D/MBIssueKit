import Foundation

/// A locally persisted issue report and its Jira submission state.
public struct MBIssueEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let title: String
    public let description: String
    public let severity: MBIssueSeverity
    public let technicalContext: MBIssueTechnicalContext?
    public var screenshotFileNames: [String]
    public var jiraStatus: JiraStatus
    public var jiraSubmission: JiraSubmission?
    public var jiraMessage: String?

    public init(
        id: UUID,
        createdAt: Date,
        title: String,
        description: String,
        severity: MBIssueSeverity = .major,
        technicalContext: MBIssueTechnicalContext? = nil,
        screenshotFileNames: [String],
        jiraStatus: JiraStatus = .notSubmitted,
        jiraSubmission: JiraSubmission? = nil,
        jiraMessage: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.description = description
        self.severity = severity
        self.technicalContext = technicalContext
        self.screenshotFileNames = screenshotFileNames
        self.jiraStatus = jiraStatus
        self.jiraSubmission = jiraSubmission
        self.jiraMessage = jiraMessage
    }

    public enum JiraStatus: String, Codable, Equatable, Sendable {
        case notSubmitted
        case submitting
        case submitted
        case failed
    }

    public struct JiraSubmission: Codable, Equatable, Sendable {
        public let issueID: String
        public let issueKey: String
        public let issueURL: URL
        public let createdAt: Date
        public var uploadedFileNames: [String]

        public init(
            issueID: String,
            issueKey: String,
            issueURL: URL,
            createdAt: Date,
            uploadedFileNames: [String] = []
        ) {
            self.issueID = issueID
            self.issueKey = issueKey
            self.issueURL = issueURL
            self.createdAt = createdAt
            self.uploadedFileNames = uploadedFileNames
        }
    }
}

public extension MBIssueEntry {
    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case title
        case description
        case severity
        case technicalContext
        case screenshotFileNames
        case jiraStatus
        case jiraSubmission
        case jiraMessage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        severity = try container.decodeIfPresent(MBIssueSeverity.self, forKey: .severity) ?? .major
        technicalContext = try container.decodeIfPresent(MBIssueTechnicalContext.self, forKey: .technicalContext)
        screenshotFileNames = try container.decodeIfPresent([String].self, forKey: .screenshotFileNames) ?? []
        jiraSubmission = try container.decodeIfPresent(JiraSubmission.self, forKey: .jiraSubmission)

        let decodedStatus = try container.decodeIfPresent(JiraStatus.self, forKey: .jiraStatus) ?? .notSubmitted
        jiraStatus = decodedStatus == .submitting ? .failed : decodedStatus
        jiraMessage = try container.decodeIfPresent(String.self, forKey: .jiraMessage)
        if decodedStatus == .submitting {
            jiraMessage = "The previous submission was interrupted. Try again."
        }
    }
}
