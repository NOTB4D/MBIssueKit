import Foundation

struct MBIssueGatewayClient: Sendable {
    let configuration: MBIssueGatewayConfiguration
    let session: URLSession

    func submit(
        entry: MBIssueEntry,
        screenshotURLs: [URL]
    ) async throws -> MBIssueEntry.JiraSubmission {
        let accessToken = try await configuration.accessTokenProvider()
        let attachments = try screenshotURLs.map { url in
            let data: Data
            do {
                data = try Data(contentsOf: url)
            } catch {
                throw MBIssueGatewayError.attachmentUnreadable(url.lastPathComponent)
            }
            return MBIssueGatewayAttachment(
                fileName: url.lastPathComponent,
                mimeType: "image/png",
                data: data
            )
        }
        let request = try MBIssueGatewayRequestBuilder.submit(
            entry: entry,
            screenshots: attachments,
            configuration: configuration,
            accessToken: accessToken
        )
        let data = try await perform(request)
        let response: SubmitResponse
        do {
            response = try JSONDecoder().decode(SubmitResponse.self, from: data)
        } catch {
            throw MBIssueGatewayError.invalidResponse
        }
        return MBIssueEntry.JiraSubmission(
            issueID: response.issueID,
            issueKey: response.issueKey,
            issueURL: response.issueURL,
            createdAt: Date(),
            uploadedFileNames: attachments.map(\.fileName)
        )
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw MBIssueGatewayError.transport(error.localizedDescription)
        }
        guard let response = response as? HTTPURLResponse else {
            throw MBIssueGatewayError.invalidResponse
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw mapHTTPError(statusCode: response.statusCode, data: data)
        }
        return data
    }

    private func mapHTTPError(statusCode: Int, data: Data) -> MBIssueGatewayError {
        switch statusCode {
        case 401:
            return .authenticationFailed
        case 403:
            return .permissionDenied
        default:
            let response = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            return .server(
                statusCode: statusCode,
                message: response?.reason ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
            )
        }
    }
}

private struct SubmitResponse: Decodable {
    let issueID: String
    let issueKey: String
    let issueURL: URL
}

private struct ErrorResponse: Decodable {
    let reason: String?
}
