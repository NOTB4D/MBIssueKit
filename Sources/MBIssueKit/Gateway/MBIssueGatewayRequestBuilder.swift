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
        accessToken: String,
        reporterSessionToken: String?
    ) throws -> URLRequest {
        let token = try validatedHostToken(accessToken)
        let endpoint = endpoint(configuration, path: ["reports"])

        let boundary = "MBIssueKit-\(UUID().uuidString)"
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        try addReporterSession(reporterSessionToken, to: &request)
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

    static func startReporterAuthorization(
        configuration: MBIssueGatewayConfiguration,
        accessToken: String
    ) throws -> URLRequest {
        let token = try validatedHostToken(accessToken)
        var request = URLRequest(url: endpoint(configuration, path: ["reporter", "authorization"]))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    static func completeReporterAuthorization(
        authorizationID: UUID,
        proof: String,
        configuration: MBIssueGatewayConfiguration,
        accessToken: String
    ) throws -> URLRequest {
        let token = try validatedHostToken(accessToken)
        let normalizedProof = proof.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedProof.isEmpty else {
            throw MBIssueConfigurationError.missingAuthorizationProof
        }
        var request = URLRequest(url: endpoint(
            configuration,
            path: ["reporter", "authorization", authorizationID.uuidString, "complete"]
        ))
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(AuthorizationCompletion(proof: normalizedProof))
        return request
    }

    static func reporterConnection(
        configuration: MBIssueGatewayConfiguration,
        accessToken: String,
        reporterSessionToken: String?
    ) throws -> URLRequest {
        let token = try validatedHostToken(accessToken)
        var request = URLRequest(url: endpoint(configuration, path: ["reporter"]))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        try addReporterSession(reporterSessionToken, to: &request)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    static func disconnectReporter(
        configuration: MBIssueGatewayConfiguration,
        accessToken: String,
        reporterSessionToken: String
    ) throws -> URLRequest {
        var request = try reporterConnection(
            configuration: configuration,
            accessToken: accessToken,
            reporterSessionToken: reporterSessionToken
        )
        request.httpMethod = "DELETE"
        return request
    }

    private static func endpoint(
        _ configuration: MBIssueGatewayConfiguration,
        path: [String]
    ) -> URL {
        var endpoint = configuration.baseURL
        endpoint.appendPathComponent("issue-reporting")
        endpoint.appendPathComponent("api")
        endpoint.appendPathComponent("v1")
        path.forEach { endpoint.appendPathComponent($0) }
        return endpoint
    }

    private static func validatedHostToken(_ value: String) throws -> String {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw MBIssueConfigurationError.missingAccessToken
        }
        return token
    }

    private static func validatedReporterToken(_ value: String) throws -> String {
        let token = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw MBIssueConfigurationError.missingReporterSession
        }
        return token
    }

    private static func addReporterSession(_ value: String?, to request: inout URLRequest) throws {
        guard let value else { return }
        let token = try validatedReporterToken(value)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "X-MBIssue-Reporter-Session")
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

private struct AuthorizationCompletion: Encodable {
    let proof: String
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
