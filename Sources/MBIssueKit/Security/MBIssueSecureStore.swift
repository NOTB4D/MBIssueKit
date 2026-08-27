import Foundation

protocol MBIssueSecureStoring: Sendable {
    func data(forKey key: String) async throws -> Data?
    func setData(_ data: Data, forKey key: String) async throws
    func removeData(forKey key: String) async throws
}

#if canImport(Security)
    import Security

    actor MBIssueKeychainSecureStore: MBIssueSecureStoring {
        private let service: String
        private let accessGroup: String?

        init(service: String, accessGroup: String?) {
            self.service = service
            self.accessGroup = accessGroup
        }

        func data(forKey key: String) throws -> Data? {
            var query = baseQuery(forKey: key)
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecItemNotFound {
                return nil
            }
            guard status == errSecSuccess, let data = item as? Data else {
                throw MBIssueSecureStoreError.keychain(status)
            }
            return data
        }

        func setData(_ data: Data, forKey key: String) throws {
            let query = baseQuery(forKey: key)
            let status = SecItemUpdate(
                query as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            if status == errSecSuccess {
                return
            }
            guard status == errSecItemNotFound else {
                throw MBIssueSecureStoreError.keychain(status)
            }
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let insertStatus = SecItemAdd(item as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw MBIssueSecureStoreError.keychain(insertStatus)
            }
        }

        func removeData(forKey key: String) throws {
            let status = SecItemDelete(baseQuery(forKey: key) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw MBIssueSecureStoreError.keychain(status)
            }
        }

        private func baseQuery(forKey key: String) -> [String: Any] {
            var query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: key,
                kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            ]
            if let accessGroup {
                query[kSecAttrAccessGroup as String] = accessGroup
            }
            return query
        }
    }

    enum MBIssueSecureStoreError: LocalizedError, Equatable, Sendable {
        case keychain(OSStatus)

        var errorDescription: String? {
            switch self {
            case let .keychain(status):
                "MBIssueKit could not access Keychain (status \(status))."
            }
        }
    }
#endif

actor MBIssueJiraCredentialVault {
    private enum Key {
        static let clientSecret = "oauth-client-secret"
        static let authorization = "oauth-authorization"
    }

    private let store: any MBIssueSecureStoring
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(store: any MBIssueSecureStoring) {
        self.store = store
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func bootstrap(clientSecret: String) async throws {
        let normalized = clientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            throw MBIssueConfigurationError.missingJiraValue("clientSecret")
        }
        try await store.setData(Data(normalized.utf8), forKey: Key.clientSecret)
    }

    func clientSecret() async throws -> String {
        guard let data = try await store.data(forKey: Key.clientSecret),
              let value = String(data: data, encoding: .utf8),
              !value.isEmpty
        else {
            throw MBIssueConfigurationError.missingJiraClientSecret
        }
        return value
    }

    func authorization() async throws -> MBIssueJiraAuthorization? {
        guard let data = try await store.data(forKey: Key.authorization) else {
            return nil
        }
        return try decoder.decode(MBIssueJiraAuthorization.self, from: data)
    }

    func saveAuthorization(_ authorization: MBIssueJiraAuthorization) async throws {
        try await store.setData(encoder.encode(authorization), forKey: Key.authorization)
    }

    func deleteAuthorization() async throws {
        try await store.removeData(forKey: Key.authorization)
    }
}

struct MBIssueJiraAuthorization: Codable, Equatable, Sendable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var scopes: [String]
    let cloudID: String
    let accountID: String
    var displayName: String
    var avatarURL: URL?
    var personalDataRetrievedAt: Date?
    var nextPersonalDataReportAt: Date?
}
