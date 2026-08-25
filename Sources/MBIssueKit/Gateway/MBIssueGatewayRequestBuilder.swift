import Foundation

struct MBIssueGatewayAttachment: Equatable, Sendable {
    let fileName: String
    let mimeType: String
    let data: Data
}

enum MBIssueGatewayRequestBuilder {
    static func submit(
        entry: MBIssueEntry,
        screenshots: [MBIssueGatewayAttachment],
        configuration: MBIssueGatewayConfiguration,
        accessToken: String
    ) throws -> URLRequest {
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw MBIssueConfigurationError.missingAccessToken
        }

        var endpoint = configuration.baseURL
        endpoint.appendPathComponent("issue-reporting")
        endpoint.appendPathComponent("api")
        endpoint.appendPathComponent("v1")
        endpoint.appendPathComponent("reports")

        let boundary = "MBIssueKit-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(entry.id.uuidString, forHTTPHeaderField: "Idempotency-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = try multipartBody(
            report: Report(entry: entry),
            screenshots: screenshots,
            boundary: boundary
        )
        return request
    }

    private static func multipartBody(
        report: Report,
        screenshots: [MBIssueGatewayAttachment],
        boundary: String
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let reportData = try encoder.encode(report)
        var body = Data()

        body.appendUTF8("--\(boundary)\r\n")
        body.appendUTF8("Content-Disposition: form-data; name=\"report\"\r\n")
        body.appendUTF8("Content-Type: application/json\r\n\r\n")
        body.append(reportData)
        body.appendUTF8("\r\n")

        for screenshot in screenshots {
            let fileName = safeFileName(screenshot.fileName)
            body.appendUTF8("--\(boundary)\r\n")
            body.appendUTF8("Content-Disposition: form-data; name=\"attachments[]\"; filename=\"\(fileName)\"\r\n")
            body.appendUTF8("Content-Type: \(screenshot.mimeType)\r\n\r\n")
            body.append(screenshot.data)
            body.appendUTF8("\r\n")
        }
        body.appendUTF8("--\(boundary)--\r\n")
        return body
    }

    private static func safeFileName(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "_")
            .replacingOccurrences(of: "\"", with: "_")
            .replacingOccurrences(of: "\r", with: "_")
            .replacingOccurrences(of: "\n", with: "_")
    }
}

private extension MBIssueGatewayRequestBuilder {
    struct Report: Encodable {
        let id: UUID
        let title: String
        let description: String
        let severity: MBIssueSeverity
        let technicalContext: MBIssueTechnicalContext?

        init(entry: MBIssueEntry) {
            id = entry.id
            title = entry.title
            description = entry.description
            severity = entry.severity
            technicalContext = entry.technicalContext
        }
    }
}

private extension Data {
    mutating func appendUTF8(_ value: String) {
        append(Data(value.utf8))
    }
}
