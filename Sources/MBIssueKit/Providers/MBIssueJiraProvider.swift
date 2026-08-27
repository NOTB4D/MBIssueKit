import Foundation

/// Jira Cloud implementation that performs OAuth and issue submission inside MBIssueKit.
public actor MBIssueJiraProvider: MBIssueProvider {
    public nonisolated let descriptor: MBIssueTrackerProvider
    public nonisolated let callbackURLScheme: String
    public nonisolated let browserSessionPolicy: MBIssueBrowserSessionPolicy

    private let configuration: MBIssueJiraConfiguration
    private let transport: any MBIssueNetworkTransport
    private let vault: MBIssueJiraCredentialVault
    private let now: @Sendable () -> Date
    private let stateGenerator: @Sendable () -> String
    private var pendingClientSecret: String?
    private var pendingOAuthState: String?
    private var cachedPriorityOptions: [MBIssueJiraPriorityOption]?

    public init(configuration: MBIssueJiraConfiguration) throws {
        let store = MBIssueKeychainSecureStore(
            service: configuration.keychainService,
            accessGroup: configuration.keychainAccessGroup
        )
        #if canImport(MBAsyncNetworking)
            let transport: any MBIssueNetworkTransport = MBIssueMBAsyncNetworkingTransport()
        #else
            let transport: any MBIssueNetworkTransport = MBIssueUnavailableNetworkTransport()
        #endif
        try self.init(
            configuration: configuration,
            transport: transport,
            vault: MBIssueJiraCredentialVault(store: store)
        )
    }

    init(
        configuration: MBIssueJiraConfiguration,
        transport: any MBIssueNetworkTransport,
        vault: MBIssueJiraCredentialVault,
        now: @escaping @Sendable () -> Date = Date.init,
        stateGenerator: @escaping @Sendable () -> String = {
            UUID().uuidString + UUID().uuidString
        }
    ) throws {
        guard let callbackURLScheme = configuration.callbackURL.scheme?.lowercased() else {
            throw MBIssueConfigurationError.invalidJiraCallbackURL
        }
        var runtimeConfiguration = configuration
        pendingClientSecret = runtimeConfiguration.initialClientSecret
        runtimeConfiguration.initialClientSecret = nil
        self.configuration = runtimeConfiguration
        self.transport = transport
        self.vault = vault
        self.now = now
        self.stateGenerator = stateGenerator
        self.callbackURLScheme = callbackURLScheme
        browserSessionPolicy = configuration.browserSessionPolicy
        descriptor = MBIssueTrackerProvider(
            id: "jira",
            displayName: "Jira",
            destinationName: "\(configuration.projectKey) · Board \(configuration.boardID)",
            requiresReporterAuthorization: true
        )
    }

    public func prepare() async throws {
        if let pendingClientSecret {
            try await vault.bootstrap(clientSecret: pendingClientSecret)
            self.pendingClientSecret = nil
        } else {
            _ = try await vault.clientSecret()
        }
    }

    public func connection() async throws -> MBIssueReporterConnection {
        try await prepare()
        guard let authorization = try await vault.authorization() else {
            return MBIssueReporterConnection(provider: descriptor, reporter: nil)
        }
        return try connection(for: await managedAuthorization(authorization))
    }

    public func authorizationURL() async throws -> URL {
        try await prepare()
        let state = stateGenerator()
        pendingOAuthState = state
        return try MBIssueJiraRequestBuilder.authorizationURL(
            configuration: configuration,
            state: state
        )
    }

    public func completeAuthorization(callbackURL: URL) async throws -> MBIssueReporterConnection {
        guard let expectedState = pendingOAuthState else {
            throw MBIssueProviderError.invalidAuthorizationCallback
        }
        defer { pendingOAuthState = nil }
        let code = try MBIssueJiraOAuthCallbackParser.code(
            from: callbackURL,
            expectedCallbackURL: configuration.callbackURL,
            expectedState: expectedState
        )
        let clientSecret = try await vault.clientSecret()
        let tokenRequest = try MBIssueJiraRequestBuilder.tokenExchange(
            configuration: configuration,
            clientSecret: clientSecret,
            code: code
        )
        let token: TokenResponse = try await transport.send(tokenRequest, decoding: TokenResponse.self)
        let refreshToken = try requiredRefreshToken(token.refreshToken)
        let grantedScopes = try grantedScopes(from: token.scope)
        let resourceRequest = try MBIssueJiraRequestBuilder.accessibleResources(
            accessToken: token.accessToken
        )
        let resources: [AccessibleResource] = try await transport.send(
            resourceRequest,
            decoding: [AccessibleResource].self
        )
        guard let resource = resources.first(where: { normalizedSite($0.url) == configuration.siteURL }) else {
            throw MBIssueProviderError.jiraSiteUnavailable
        }
        let profileRequest = try MBIssueJiraRequestBuilder.profile(accessToken: token.accessToken)
        let profile: ProfileResponse = try await transport.send(
            profileRequest,
            decoding: ProfileResponse.self
        )
        guard profile.accountStatus == "active",
              !profile.accountID.isEmpty,
              !profile.name.isEmpty
        else {
            throw MBIssueProviderError.jiraAccountUnavailable
        }
        let currentDate = now()
        cachedPriorityOptions = nil
        let authorization = MBIssueJiraAuthorization(
            accessToken: token.accessToken,
            refreshToken: refreshToken,
            expiresAt: currentDate.addingTimeInterval(TimeInterval(token.expiresIn)),
            scopes: grantedScopes,
            cloudID: resource.id,
            accountID: profile.accountID,
            displayName: profile.name,
            avatarURL: profile.picture.flatMap(URL.init(string:)),
            personalDataRetrievedAt: currentDate,
            nextPersonalDataReportAt: nil
        )
        try await vault.saveAuthorization(authorization)
        return connection(for: authorization)
    }

    public func disconnect() async throws {
        pendingOAuthState = nil
        cachedPriorityOptions = nil
        try await vault.deleteAuthorization()
    }

    public func submit(
        entry: MBIssueEntry,
        screenshotURLs: [URL]
    ) async throws -> MBIssueSubmissionReceipt {
        let authorization = try await managedAuthorization()
        let sprintRequest = try MBIssueJiraRequestBuilder.activeSprints(
            configuration: configuration,
            cloudID: authorization.cloudID,
            accessToken: authorization.accessToken
        )
        let page: SprintPage = try await transport.send(sprintRequest, decoding: SprintPage.self)
        let activeSprintID = try activeSprintID(in: page.values)
        let priorityID = try await priorityID(
            for: entry.severity,
            authorization: authorization
        )
        let createRequest = try MBIssueJiraRequestBuilder.createIssue(
            entry: entry,
            priorityID: priorityID,
            configuration: configuration,
            cloudID: authorization.cloudID,
            accessToken: authorization.accessToken
        )
        let created: CreateIssueResponse = try await transport.send(
            createRequest,
            decoding: CreateIssueResponse.self
        )
        let moveRequest = try MBIssueJiraRequestBuilder.moveIssue(
            issueKey: created.key,
            activeSprintID: activeSprintID,
            cloudID: authorization.cloudID,
            accessToken: authorization.accessToken
        )
        try MBIssueHTTPResponseDecoder.validate(await transport.sendRaw(moveRequest))
        var uploaded: [String] = []
        for url in screenshotURLs {
            let request = try MBIssueJiraRequestBuilder.attachment(
                fileURL: url,
                issueKey: created.key,
                cloudID: authorization.cloudID,
                accessToken: authorization.accessToken
            )
            let _: [AttachmentResponse] = try await transport.send(
                request,
                decoding: [AttachmentResponse].self
            )
            uploaded.append(url.lastPathComponent)
        }
        let issueURL = configuration.siteURL
            .appendingPathComponent("browse")
            .appendingPathComponent(created.key)
        return MBIssueSubmissionReceipt(
            providerID: descriptor.id,
            providerDisplayName: descriptor.displayName,
            issueID: created.id,
            issueKey: created.key,
            issueURL: issueURL,
            createdAt: now(),
            uploadedFileNames: uploaded
        )
    }

    private func validAuthorization() async throws -> MBIssueJiraAuthorization {
        try await prepare()
        guard var authorization = try await vault.authorization() else {
            throw MBIssueProviderError.reporterAuthorizationRequired
        }
        guard authorization.expiresAt <= now().addingTimeInterval(60) else {
            return authorization
        }
        let secret = try await vault.clientSecret()
        let request = try MBIssueJiraRequestBuilder.tokenRefresh(
            configuration: configuration,
            clientSecret: secret,
            refreshToken: authorization.refreshToken
        )
        let token: TokenResponse = try await transport.send(request, decoding: TokenResponse.self)
        authorization.accessToken = token.accessToken
        authorization.refreshToken = try requiredRefreshToken(token.refreshToken)
        authorization.expiresAt = now().addingTimeInterval(TimeInterval(token.expiresIn))
        if let returnedScope = token.scope {
            authorization.scopes = try grantedScopes(from: returnedScope)
        }
        try await vault.saveAuthorization(authorization)
        return authorization
    }

    private func managedAuthorization(
        _ storedAuthorization: MBIssueJiraAuthorization? = nil
    ) async throws -> MBIssueJiraAuthorization {
        var authorization: MBIssueJiraAuthorization
        if let storedAuthorization,
           storedAuthorization.expiresAt > now().addingTimeInterval(60)
        {
            authorization = storedAuthorization
        } else {
            authorization = try await validAuthorization()
        }
        guard authorization.nextPersonalDataReportAt.map({ $0 <= now() }) ?? true else {
            return authorization
        }
        authorization = try await reportStoredPersonalData(authorization)
        try await vault.saveAuthorization(authorization)
        return authorization
    }

    private func reportStoredPersonalData(
        _ storedAuthorization: MBIssueJiraAuthorization
    ) async throws -> MBIssueJiraAuthorization {
        var authorization = storedAuthorization
        let currentDate = now()
        let request = try MBIssueJiraRequestBuilder.personalDataReport(
            accountID: authorization.accountID,
            updatedAt: authorization.personalDataRetrievedAt ?? currentDate,
            accessToken: authorization.accessToken
        )
        let response = try await transport.sendRaw(request)
        switch response.statusCode {
        case 200:
            let report = try JSONDecoder().decode(PersonalDataReportResponse.self, from: response.data)
            if report.accounts.contains(where: {
                $0.accountID == authorization.accountID && $0.status == "closed"
            }) {
                try await vault.deleteAuthorization()
                throw MBIssueProviderError.reporterAuthorizationRequired
            }
            if report.accounts.contains(where: {
                $0.accountID == authorization.accountID && $0.status == "updated"
            }) {
                let profileRequest = try MBIssueJiraRequestBuilder.profile(
                    accessToken: authorization.accessToken
                )
                let profile: ProfileResponse = try await transport.send(
                    profileRequest,
                    decoding: ProfileResponse.self
                )
                guard profile.accountStatus == "active", !profile.name.isEmpty else {
                    try await vault.deleteAuthorization()
                    throw MBIssueProviderError.reporterAuthorizationRequired
                }
                authorization.displayName = profile.name
                authorization.avatarURL = profile.picture.flatMap(URL.init(string:))
                authorization.personalDataRetrievedAt = currentDate
            }
            authorization.nextPersonalDataReportAt = nextPersonalDataReportDate(
                responseHeaders: response.headers,
                from: currentDate
            )
        case 204:
            authorization.nextPersonalDataReportAt = nextPersonalDataReportDate(
                responseHeaders: response.headers,
                from: currentDate
            )
        case 429:
            authorization.nextPersonalDataReportAt = retryDate(
                responseHeaders: response.headers,
                from: currentDate
            )
        default:
            throw MBIssueProviderError.server(
                statusCode: response.statusCode,
                message: "Personal data reporting failed."
            )
        }
        return authorization
    }

    private func nextPersonalDataReportDate(
        responseHeaders: [String: String],
        from date: Date
    ) -> Date {
        let cycleDays = header(named: "Cycle-Period", in: responseHeaders)
            .flatMap(Double.init)
            .flatMap { $0 > 0 ? $0 : nil }
            ?? 7
        return date.addingTimeInterval(cycleDays * 86400)
    }

    private func retryDate(
        responseHeaders: [String: String],
        from date: Date
    ) -> Date {
        let retrySeconds = header(named: "Retry-After", in: responseHeaders)
            .flatMap(Double.init)
            .flatMap { $0 > 0 ? $0 : nil }
            ?? 3600
        return date.addingTimeInterval(retrySeconds)
    }

    private func header(named name: String, in headers: [String: String]) -> String? {
        headers.first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame })?.value
    }

    private func connection(for authorization: MBIssueJiraAuthorization) -> MBIssueReporterConnection {
        MBIssueReporterConnection(
            provider: descriptor,
            reporter: MBIssueReporterIdentity(
                accountID: authorization.accountID,
                displayName: authorization.displayName,
                avatarURL: authorization.avatarURL
            ),
            expiresAt: authorization.expiresAt
        )
    }

    private func requiredRefreshToken(_ value: String?) throws -> String {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            throw MBIssueProviderError.invalidResponse
        }
        return value
    }

    private func grantedScopes(from value: String?) throws -> [String] {
        guard let value else {
            return configuration.scopes
        }
        let scopes = value.split(whereSeparator: \.isWhitespace).map(String.init)
        guard Set(MBIssueJiraConfiguration.requiredSubmissionScopes).isSubset(of: Set(scopes)) else {
            throw MBIssueProviderError.permissionDenied
        }
        return scopes
    }

    private func normalizedSite(_ value: String) -> URL? {
        guard var components = URLComponents(string: value),
              components.scheme?.lowercased() == "https",
              components.host != nil
        else {
            return nil
        }
        components.path = ""
        components.query = nil
        components.fragment = nil
        return components.url
    }

    private func activeSprintID(in sprints: [SprintResponse]) throws -> Int {
        let active = sprints.filter { $0.state.caseInsensitiveCompare("active") == .orderedSame }
        switch active.count {
        case 1:
            return active[0].id
        case 0:
            throw MBIssueProviderError.noActiveSprint(boardID: configuration.boardID)
        default:
            throw MBIssueProviderError.multipleActiveSprints(boardID: configuration.boardID)
        }
    }

    private func priorityID(
        for severity: MBIssueSeverity,
        authorization: MBIssueJiraAuthorization
    ) async throws -> String? {
        guard let preferredName = configuration.priorityNames[severity] else {
            return nil
        }
        let options: [MBIssueJiraPriorityOption]
        if let cachedPriorityOptions {
            options = cachedPriorityOptions
        } else {
            let request = try MBIssueJiraRequestBuilder.createMetadata(
                configuration: configuration,
                cloudID: authorization.cloudID,
                accessToken: authorization.accessToken
            )
            let page: MBIssueJiraCreateMetadataPage = try await transport.send(
                request,
                decoding: MBIssueJiraCreateMetadataPage.self
            )
            options = page.fields.first(where: {
                $0.fieldID == "priority" || $0.key == "priority"
            })?.allowedValues ?? []
            cachedPriorityOptions = options
        }
        return MBIssueJiraPriorityResolver.resolve(
            severity: severity,
            preferredName: preferredName,
            options: options
        )
    }
}

private struct TokenResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String?
    let expiresIn: Int
    let scope: String?

    private enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case scope
    }
}

private struct AccessibleResource: Decodable, Sendable {
    let id: String
    let url: String
}

private struct ProfileResponse: Decodable, Sendable {
    let accountID: String
    let name: String
    let picture: String?
    let accountStatus: String

    private enum CodingKeys: String, CodingKey {
        case accountID = "account_id"
        case name
        case picture
        case accountStatus = "account_status"
    }
}

private struct PersonalDataReportResponse: Decodable, Sendable {
    let accounts: [Account]

    struct Account: Decodable, Sendable {
        let accountID: String
        let status: String

        private enum CodingKeys: String, CodingKey {
            case accountID = "accountId"
            case status
        }
    }
}

private struct SprintPage: Decodable, Sendable {
    let values: [SprintResponse]
}

private struct SprintResponse: Decodable, Sendable {
    let id: Int
    let name: String
    let state: String
}

private struct CreateIssueResponse: Decodable, Sendable {
    let id: String
    let key: String
}

private struct AttachmentResponse: Decodable, Sendable {
    let id: String
    let filename: String
}
