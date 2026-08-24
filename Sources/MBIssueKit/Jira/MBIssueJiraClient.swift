import Foundation

struct MBIssueJiraClient: Sendable {
    let configuration: MBIssueJiraConfiguration
    let session: URLSession

    init(
        configuration: MBIssueJiraConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session
    }

    func createIssue(draft: MBIssueDraft) async throws -> MBIssueEntry.JiraSubmission {
        let request = try MBIssueJiraRequestBuilder.createIssue(
            draft: draft,
            configuration: configuration
        )
        let data = try await perform(request)
        let response: CreateIssueResponse
        do {
            response = try JSONDecoder().decode(CreateIssueResponse.self, from: data)
        } catch {
            throw MBIssueJiraError.invalidResponse
        }

        var issueURL = configuration.baseURL
        issueURL.appendPathComponent("browse")
        issueURL.appendPathComponent(response.key)
        return MBIssueEntry.JiraSubmission(
            issueID: response.id,
            issueKey: response.key,
            issueURL: issueURL,
            createdAt: Date()
        )
    }

    func addAttachment(
        at fileURL: URL,
        to issueKey: String
    ) async throws {
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw MBIssueJiraError.attachmentUnreadable(fileURL.lastPathComponent)
        }
        let request = try MBIssueJiraRequestBuilder.addAttachment(
            issueKey: issueKey,
            fileName: fileURL.lastPathComponent,
            mimeType: "image/png",
            data: data,
            configuration: configuration
        )
        _ = try await perform(request)
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw MBIssueJiraError.transport(error.localizedDescription)
        }

        guard let response = response as? HTTPURLResponse else {
            throw MBIssueJiraError.invalidResponse
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw mapHTTPError(statusCode: response.statusCode, data: data)
        }
        return data
    }

    private func mapHTTPError(statusCode: Int, data: Data) -> MBIssueJiraError {
        switch statusCode {
        case 401:
            return .authenticationFailed
        case 403:
            return .permissionDenied
        default:
            let response = try? JSONDecoder().decode(JiraErrorResponse.self, from: data)
            let fieldMessages = response?.errors?.values.sorted().joined(separator: ", ")
            let message = response?.errorMessages?.joined(separator: ", ")
                ?? fieldMessages
                ?? HTTPURLResponse.localizedString(forStatusCode: statusCode)
            return .server(statusCode: statusCode, message: message)
        }
    }
}

private struct CreateIssueResponse: Decodable {
    let id: String
    let key: String
}

private struct JiraErrorResponse: Decodable {
    let errorMessages: [String]?
    let errors: [String: String]?
}
