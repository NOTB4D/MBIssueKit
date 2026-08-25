import Foundation

/// Stores only the host backend's revocable reporter-session token.
///
/// Implementations must never store an issue tracker's OAuth access or refresh token.
public protocol MBIssueReporterSessionStoring: Sendable {
    func loadToken() async throws -> String?
    func saveToken(_ token: String) async throws
    func deleteToken() async throws
}

#if canImport(Security)
    import Security

    /// A device-only Keychain store for the backend-issued reporter session.
    public actor MBIssueKeychainReporterSessionStore: MBIssueReporterSessionStoring {
        private let service: String
        private let account: String

        public init(service: String, account: String = "reporter-session") {
            self.service = service
            self.account = account
        }

        public func loadToken() throws -> String? {
            var query = baseQuery
            query[kSecReturnData as String] = true
            query[kSecMatchLimit as String] = kSecMatchLimitOne

            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            if status == errSecItemNotFound {
                return nil
            }
            guard status == errSecSuccess,
                  let data = item as? Data,
                  let token = String(data: data, encoding: .utf8),
                  !token.isEmpty
            else {
                throw MBIssueReporterSessionStoreError.keychain(status)
            }
            return token
        }

        public func saveToken(_ token: String) throws {
            let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                throw MBIssueReporterSessionStoreError.emptyToken
            }
            let data = Data(normalized.utf8)
            let updateStatus = SecItemUpdate(
                baseQuery as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            if updateStatus == errSecSuccess {
                return
            }
            guard updateStatus == errSecItemNotFound else {
                throw MBIssueReporterSessionStoreError.keychain(updateStatus)
            }

            var insert = baseQuery
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let insertStatus = SecItemAdd(insert as CFDictionary, nil)
            guard insertStatus == errSecSuccess else {
                throw MBIssueReporterSessionStoreError.keychain(insertStatus)
            }
        }

        public func deleteToken() throws {
            let status = SecItemDelete(baseQuery as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw MBIssueReporterSessionStoreError.keychain(status)
            }
        }

        private var baseQuery: [String: Any] {
            [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecAttrSynchronizable as String: kCFBooleanFalse as Any,
            ]
        }
    }

    public enum MBIssueReporterSessionStoreError: LocalizedError, Equatable, Sendable {
        case emptyToken
        case keychain(OSStatus)

        public var errorDescription: String? {
            switch self {
            case .emptyToken:
                "The reporter session token is empty."
            case let .keychain(status):
                "The reporter session could not be stored securely (Keychain status \(status))."
            }
        }
    }
#endif
