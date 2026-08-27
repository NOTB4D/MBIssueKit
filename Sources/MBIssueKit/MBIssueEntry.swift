import Foundation

/// The local delivery state of a report, independent of the configured issue tracker.
public enum MBIssueSubmissionStatus: String, Codable, Equatable, Sendable {
    case notSubmitted
    case submitting
    case submitted
    case failed
}

/// A provider-neutral reference returned after an issue tracker accepts a report.
public struct MBIssueSubmissionReceipt: Codable, Equatable, Sendable {
    public let providerID: String
    public let providerDisplayName: String
    public let issueID: String
    public let issueKey: String
    public let issueURL: URL
    public let createdAt: Date
    public var uploadedFileNames: [String]

    public init(
        providerID: String,
        providerDisplayName: String,
        issueID: String,
        issueKey: String,
        issueURL: URL,
        createdAt: Date,
        uploadedFileNames: [String] = []
    ) {
        self.providerID = providerID
        self.providerDisplayName = providerDisplayName
        self.issueID = issueID
        self.issueKey = issueKey
        self.issueURL = issueURL
        self.createdAt = createdAt
        self.uploadedFileNames = uploadedFileNames
    }

    private enum CodingKeys: String, CodingKey {
        case providerID
        case providerDisplayName
        case issueID
        case issueKey
        case issueURL
        case createdAt
        case uploadedFileNames
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // These defaults exist only to migrate records written by the pre-provider beta.
        providerID = try container.decodeIfPresent(String.self, forKey: .providerID) ?? "jira"
        providerDisplayName = try container.decodeIfPresent(String.self, forKey: .providerDisplayName) ?? "Jira"
        issueID = try container.decode(String.self, forKey: .issueID)
        issueKey = try container.decode(String.self, forKey: .issueKey)
        issueURL = try container.decode(URL.self, forKey: .issueURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        uploadedFileNames = try container.decodeIfPresent([String].self, forKey: .uploadedFileNames) ?? []
    }
}

/// A locally persisted issue report and its provider-neutral submission state.
public struct MBIssueEntry: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public let createdAt: Date
    public let title: String
    public let description: String
    public let severity: MBIssueSeverity
    public let technicalContext: MBIssueTechnicalContext?
    public var screenshotFileNames: [String]
    public var submissionStatus: MBIssueSubmissionStatus
    public var submission: MBIssueSubmissionReceipt?
    public var submissionMessage: String?

    public init(
        id: UUID,
        createdAt: Date,
        title: String,
        description: String,
        severity: MBIssueSeverity = .major,
        technicalContext: MBIssueTechnicalContext? = nil,
        screenshotFileNames: [String],
        submissionStatus: MBIssueSubmissionStatus = .notSubmitted,
        submission: MBIssueSubmissionReceipt? = nil,
        submissionMessage: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.title = title
        self.description = description
        self.severity = severity
        self.technicalContext = technicalContext
        self.screenshotFileNames = screenshotFileNames
        self.submissionStatus = submissionStatus
        self.submission = submission
        self.submissionMessage = submissionMessage
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt
        case title
        case description
        case severity
        case technicalContext
        case screenshotFileNames
        case submissionStatus
        case submission
        case submissionMessage
        case jiraStatus
        case jiraSubmission
        case jiraMessage
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        severity = try container.decodeIfPresent(MBIssueSeverity.self, forKey: .severity) ?? .major
        technicalContext = try container.decodeIfPresent(MBIssueTechnicalContext.self, forKey: .technicalContext)
        screenshotFileNames = try container.decodeIfPresent([String].self, forKey: .screenshotFileNames) ?? []
        submission = try container.decodeIfPresent(MBIssueSubmissionReceipt.self, forKey: .submission)
            ?? container.decodeIfPresent(MBIssueSubmissionReceipt.self, forKey: .jiraSubmission)

        let decodedStatus = try container.decodeIfPresent(MBIssueSubmissionStatus.self, forKey: .submissionStatus)
            ?? container.decodeIfPresent(MBIssueSubmissionStatus.self, forKey: .jiraStatus)
            ?? .notSubmitted
        submissionStatus = decodedStatus == .submitting ? .failed : decodedStatus
        submissionMessage = try container.decodeIfPresent(String.self, forKey: .submissionMessage)
            ?? container.decodeIfPresent(String.self, forKey: .jiraMessage)
        if decodedStatus == .submitting {
            submissionMessage = "The previous submission was interrupted. Try again."
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(severity, forKey: .severity)
        try container.encodeIfPresent(technicalContext, forKey: .technicalContext)
        try container.encode(screenshotFileNames, forKey: .screenshotFileNames)
        try container.encode(submissionStatus, forKey: .submissionStatus)
        try container.encodeIfPresent(submission, forKey: .submission)
        try container.encodeIfPresent(submissionMessage, forKey: .submissionMessage)
    }
}

/// Source compatibility for hosts that adopted the earlier Jira-specific beta API.
public extension MBIssueEntry {
    @available(*, deprecated, renamed: "MBIssueSubmissionStatus")
    typealias JiraStatus = MBIssueSubmissionStatus

    @available(*, deprecated, renamed: "MBIssueSubmissionReceipt")
    typealias JiraSubmission = MBIssueSubmissionReceipt

    @available(*, deprecated, renamed: "submissionStatus")
    var jiraStatus: MBIssueSubmissionStatus {
        get { submissionStatus }
        set { submissionStatus = newValue }
    }

    @available(*, deprecated, renamed: "submission")
    var jiraSubmission: MBIssueSubmissionReceipt? {
        get { submission }
        set { submission = newValue }
    }

    @available(*, deprecated, renamed: "submissionMessage")
    var jiraMessage: String? {
        get { submissionMessage }
        set { submissionMessage = newValue }
    }

    @available(*, deprecated, message: "Use the provider-neutral submission initializer.")
    init(
        id: UUID,
        createdAt: Date,
        title: String,
        description: String,
        severity: MBIssueSeverity = .major,
        technicalContext: MBIssueTechnicalContext? = nil,
        screenshotFileNames: [String],
        jiraStatus: MBIssueSubmissionStatus,
        jiraSubmission: MBIssueSubmissionReceipt? = nil,
        jiraMessage: String? = nil
    ) {
        self.init(
            id: id,
            createdAt: createdAt,
            title: title,
            description: description,
            severity: severity,
            technicalContext: technicalContext,
            screenshotFileNames: screenshotFileNames,
            submissionStatus: jiraStatus,
            submission: jiraSubmission,
            submissionMessage: jiraMessage
        )
    }
}
