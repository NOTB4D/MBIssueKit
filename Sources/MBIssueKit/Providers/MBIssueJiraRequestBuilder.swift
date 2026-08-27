import Foundation

enum MBIssueJiraRequestBuilder {
    static func authorizationURL(
        configuration: MBIssueJiraConfiguration,
        state: String
    ) throws -> URL {
        let normalizedState = state.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedState.isEmpty else {
            throw MBIssueProviderError.invalidAuthorizationCallback
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "auth.atlassian.com"
        components.path = "/authorize"
        components.queryItems = [
            URLQueryItem(name: "audience", value: "api.atlassian.com"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "redirect_uri", value: configuration.callbackURL.absoluteString),
            URLQueryItem(name: "state", value: normalizedState),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "prompt", value: "consent"),
        ]
        guard let url = components.url else {
            throw MBIssueProviderError.invalidAuthorizationCallback
        }
        return url
    }

    static func tokenExchange(
        configuration: MBIssueJiraConfiguration,
        clientSecret: String,
        code: String
    ) throws -> URLRequest {
        try tokenRequest(body: [
            "grant_type": "authorization_code",
            "client_id": configuration.clientID,
            "client_secret": clientSecret,
            "code": code,
            "redirect_uri": configuration.callbackURL.absoluteString,
        ])
    }

    static func tokenRefresh(
        configuration: MBIssueJiraConfiguration,
        clientSecret: String,
        refreshToken: String
    ) throws -> URLRequest {
        try tokenRequest(body: [
            "grant_type": "refresh_token",
            "client_id": configuration.clientID,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
        ])
    }

    static func accessibleResources(accessToken: String) throws -> URLRequest {
        try authorizedGET(
            urlString: "https://api.atlassian.com/oauth/token/accessible-resources",
            accessToken: accessToken
        )
    }

    static func profile(accessToken: String) throws -> URLRequest {
        try authorizedGET(urlString: "https://api.atlassian.com/me", accessToken: accessToken)
    }

    static func personalDataReport(
        accountID: String,
        updatedAt: Date,
        accessToken: String
    ) throws -> URLRequest {
        guard let url = URL(string: "https://api.atlassian.com/app/report-accounts/") else {
            throw MBIssueProviderError.invalidResponse
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var request = authorizedRequest(url: url, method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "accounts": [[
                "accountId": accountID,
                "updatedAt": formatter.string(from: updatedAt),
            ]],
        ])
        return request
    }

    static func activeSprints(
        configuration: MBIssueJiraConfiguration,
        cloudID: String,
        accessToken: String
    ) throws -> URLRequest {
        let path = "/ex/jira/\(cloudID)/rest/agile/1.0/board/\(configuration.boardID)/sprint"
        guard var components = URLComponents(string: "https://api.atlassian.com\(path)") else {
            throw MBIssueProviderError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "state", value: "active")]
        guard let url = components.url else {
            throw MBIssueProviderError.invalidResponse
        }
        return authorizedRequest(url: url, method: "GET", accessToken: accessToken)
    }

    static func createMetadata(
        configuration: MBIssueJiraConfiguration,
        cloudID: String,
        accessToken: String
    ) throws -> URLRequest {
        let projectKey = configuration.projectKey.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? configuration.projectKey
        let issueTypeID = configuration.issueTypeID.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) ?? configuration.issueTypeID
        let path = "/ex/jira/\(cloudID)/rest/api/3/issue/createmeta/\(projectKey)/issuetypes/\(issueTypeID)"
        guard var components = URLComponents(string: "https://api.atlassian.com\(path)") else {
            throw MBIssueProviderError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "maxResults", value: "100")]
        guard let url = components.url else {
            throw MBIssueProviderError.invalidResponse
        }
        return authorizedRequest(url: url, method: "GET", accessToken: accessToken)
    }

    static func createIssue(
        entry: MBIssueEntry,
        priorityID: String?,
        configuration: MBIssueJiraConfiguration,
        cloudID: String,
        accessToken: String
    ) throws -> URLRequest {
        guard let url = URL(string: "https://api.atlassian.com/ex/jira/\(cloudID)/rest/api/3/issue") else {
            throw MBIssueProviderError.invalidResponse
        }
        var fields: [String: Any] = [
            "project": ["key": configuration.projectKey],
            "issuetype": ["id": configuration.issueTypeID],
            "summary": entry.title,
            "description": descriptionDocument(for: entry),
            "labels": Array(Set(configuration.labels + ["severity-\(entry.severity.rawValue)"])).sorted(),
        ]
        if let priorityID {
            fields["priority"] = ["id": priorityID]
        }
        var request = authorizedRequest(url: url, method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["fields": fields],
            options: [.sortedKeys]
        )
        return request
    }

    static func moveIssue(
        issueKey: String,
        activeSprintID: Int,
        cloudID: String,
        accessToken: String
    ) throws -> URLRequest {
        guard let url = URL(
            string: "https://api.atlassian.com/ex/jira/\(cloudID)/rest/agile/1.0/sprint/\(activeSprintID)/issue"
        ) else {
            throw MBIssueProviderError.invalidResponse
        }
        var request = authorizedRequest(url: url, method: "POST", accessToken: accessToken)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: ["issues": [issueKey]],
            options: [.sortedKeys]
        )
        return request
    }

    static func attachment(
        fileURL: URL,
        issueKey: String,
        cloudID: String,
        accessToken: String,
        boundary: String = "MBIssueKit-\(UUID().uuidString)"
    ) throws -> URLRequest {
        let encodedKey = issueKey.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? issueKey
        guard let url = URL(
            string: "https://api.atlassian.com/ex/jira/\(cloudID)/rest/api/3/issue/\(encodedKey)/attachments"
        ) else {
            throw MBIssueProviderError.invalidResponse
        }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw MBIssueProviderError.attachmentUnreadable(fileURL.lastPathComponent)
        }
        var request = authorizedRequest(url: url, method: "POST", accessToken: accessToken)
        request.setValue("no-check", forHTTPHeaderField: "X-Atlassian-Token")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(
            data: data,
            name: "file",
            fileName: fileURL.lastPathComponent,
            mimeType: "image/png",
            boundary: boundary
        )
        return request
    }

    private static func tokenRequest(body: [String: String]) throws -> URLRequest {
        guard let url = URL(string: "https://auth.atlassian.com/oauth/token") else {
            throw MBIssueProviderError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }

    private static func authorizedGET(urlString: String, accessToken: String) throws -> URLRequest {
        guard let url = URL(string: urlString) else {
            throw MBIssueProviderError.invalidResponse
        }
        return authorizedRequest(url: url, method: "GET", accessToken: accessToken)
    }

    private static func authorizedRequest(
        url: URL,
        method: String,
        accessToken: String
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func descriptionDocument(for entry: MBIssueEntry) -> [String: Any] {
        var blocks = [
            heading("User description", level: 2),
            paragraph(entry.description),
            heading("Severity", level: 2),
            paragraph(entry.severity.title),
        ]
        if let technicalContext = entry.technicalContext {
            blocks.append(heading("Technical context", level: 2))
            blocks.append([
                "type": "codeBlock",
                "content": [["type": "text", "text": formatted(technicalContext)]],
            ])
        }
        return ["type": "doc", "version": 1, "content": blocks]
    }

    private static func heading(_ text: String, level: Int) -> [String: Any] {
        [
            "type": "heading",
            "attrs": ["level": level],
            "content": [["type": "text", "text": text]],
        ]
    }

    private static func paragraph(_ text: String) -> [String: Any] {
        ["type": "paragraph", "content": [["type": "text", "text": text]]]
    }

    private static func formatted(_ context: MBIssueTechnicalContext) -> String {
        var rows: [(String, String)] = [
            ("Screen", context.screenName),
            ("Controller", context.viewControllerName),
            ("Navigation", context.navigationStack.joined(separator: " -> ")),
            ("App", "\(context.appName) \(context.appVersion) (\(context.buildNumber))"),
            ("Bundle", context.bundleIdentifier),
            ("Environment", context.environment),
            ("OS", context.osVersion),
            ("Device", "\(context.deviceModel) / \(context.deviceIdentifier)"),
            ("Architecture", context.architecture),
            ("Appearance", context.isDarkMode ? "Dark" : "Light"),
            ("Locale", context.locale),
            ("Screen size", context.screenSize),
        ]
        rows.append(contentsOf: context.additional.keys.sorted().compactMap { key in
            context.additional[key].map { (key, $0) }
        })
        return rows
            .filter { !$0.1.isEmpty }
            .map { "\($0.0): \($0.1)" }
            .joined(separator: "\n")
    }

    private static func multipartBody(
        data: Data,
        name: String,
        fileName: String,
        mimeType: String,
        boundary: String
    ) -> Data {
        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data(
            "Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n".utf8
        ))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(data)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        return body
    }
}

enum MBIssueJiraOAuthCallbackParser {
    static func code(
        from url: URL,
        expectedCallbackURL: URL,
        expectedState: String
    ) throws -> String {
        guard matches(url, expectedCallbackURL),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            throw MBIssueProviderError.invalidAuthorizationCallback
        }
        let items = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })
        if let oauthError = items["error"], !oauthError.isEmpty {
            if oauthError == "access_denied" {
                throw MBIssueProviderError.authorizationCancelled
            }
            throw MBIssueProviderError.authorizationFailed
        }
        guard items["state"] == expectedState,
              let code = items["code"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !code.isEmpty
        else {
            throw MBIssueProviderError.invalidAuthorizationCallback
        }
        return code
    }

    private static func matches(_ received: URL, _ expected: URL) -> Bool {
        guard let received = URLComponents(url: received, resolvingAgainstBaseURL: false),
              let expected = URLComponents(url: expected, resolvingAgainstBaseURL: false)
        else {
            return false
        }
        return received.scheme?.lowercased() == expected.scheme?.lowercased()
            && received.host?.lowercased() == expected.host?.lowercased()
            && received.path == expected.path
    }
}
