import Foundation

enum MBIssueJiraRequestBuilder {
    static func createIssue(
        draft: MBIssueDraft,
        configuration: MBIssueJiraConfiguration
    ) throws -> URLRequest {
        let url = endpoint(
            configuration: configuration,
            components: ["rest", "api", "3", "issue"]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        authorize(&request, configuration: configuration)

        let payload = CreateIssuePayload(
            fields: .init(
                project: .init(key: configuration.projectKey),
                issueType: .init(name: configuration.issueType),
                summary: draft.title,
                description: .plainText(draft.description),
                labels: configuration.labels
            )
        )
        do {
            request.httpBody = try JSONEncoder().encode(payload)
        } catch {
            throw MBIssueJiraError.invalidRequest
        }
        return request
    }

    static func addAttachment(
        issueKey: String,
        fileName: String,
        mimeType: String,
        data: Data,
        boundary: String = "MBIssueKit-\(UUID().uuidString)",
        configuration: MBIssueJiraConfiguration
    ) throws -> URLRequest {
        let url = endpoint(
            configuration: configuration,
            components: ["rest", "api", "3", "issue", issueKey, "attachments"]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-check", forHTTPHeaderField: "X-Atlassian-Token")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        authorize(&request, configuration: configuration)

        let safeFileName = fileName
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
        var body = Data()
        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"file\"; filename=\"\(safeFileName)\"\r\n")
        body.appendUTF8("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.appendUTF8("\r\n--\(boundary)--\r\n")
        request.httpBody = body
        return request
    }

    private static func endpoint(
        configuration: MBIssueJiraConfiguration,
        components: [String]
    ) -> URL {
        var url = configuration.baseURL
        components.forEach { url.appendPathComponent($0) }
        return url
    }

    private static func authorize(
        _ request: inout URLRequest,
        configuration: MBIssueJiraConfiguration
    ) {
        let credentials = Data("\(configuration.email):\(configuration.apiToken)".utf8)
            .base64EncodedString()
        request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
    }
}

private struct CreateIssuePayload: Encodable {
    let fields: Fields

    struct Fields: Encodable {
        let project: Project
        let issueType: IssueType
        let summary: String
        let description: ADFDocument
        let labels: [String]

        enum CodingKeys: String, CodingKey {
            case project
            case issueType = "issuetype"
            case summary
            case description
            case labels
        }
    }

    struct Project: Encodable {
        let key: String
    }

    struct IssueType: Encodable {
        let name: String
    }
}

private struct ADFDocument: Encodable {
    let version = 1
    let type = "doc"
    let content: [Paragraph]

    static func plainText(_ value: String) -> Self {
        let paragraphs = value.components(separatedBy: .newlines).map { line in
            Paragraph(
                type: "paragraph",
                content: line.isEmpty ? [] : [TextNode(type: "text", text: line)]
            )
        }
        return Self(content: paragraphs)
    }

    struct Paragraph: Encodable {
        let type: String
        let content: [TextNode]
    }

    struct TextNode: Encodable {
        let type: String
        let text: String
    }
}

private extension Data {
    mutating func appendUTF8(_ value: String) {
        append(Data(value.utf8))
    }
}
