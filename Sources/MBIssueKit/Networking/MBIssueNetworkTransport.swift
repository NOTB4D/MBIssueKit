import Foundation

struct MBIssueRawNetworkResponse: Sendable {
    let statusCode: Int
    let data: Data
    let headers: [String: String]
}

protocol MBIssueNetworkTransport: Sendable {
    func send<Response: Decodable & Sendable>(
        _ request: URLRequest,
        decoding type: Response.Type
    ) async throws -> Response

    func sendRaw(_ request: URLRequest) async throws -> MBIssueRawNetworkResponse
}

extension MBIssueNetworkTransport {
    func sendRaw(_: URLRequest) async throws -> MBIssueRawNetworkResponse {
        throw MBIssueProviderError.invalidResponse
    }
}

#if canImport(MBAsyncNetworking)
    @preconcurrency import MBAsyncNetworking

    struct MBIssueMBAsyncNetworkingTransport: MBIssueNetworkTransport, @unchecked Sendable {
        private let client: NetworkClient

        init() {
            let logsManager = NetworkLogsManager(registerDefaultHandler: false)
            client = NetworkClient(
                storage: MBIssueNetworkingStorage(),
                session: Session(),
                logsManager: logsManager
            )
        }

        func send<Response: Decodable & Sendable>(
            _ request: URLRequest,
            decoding _: Response.Type
        ) async throws -> Response {
            try await MBIssueNetworkEndpoint(urlRequest: request).fetch(
                hasAuthentication: false,
                using: client
            )
        }

        func sendRaw(_ request: URLRequest) async throws -> MBIssueRawNetworkResponse {
            let (data, response) = try await client.session.session.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw MBIssueProviderError.invalidResponse
            }
            let headers = response.allHeaderFields.reduce(into: [String: String]()) { result, item in
                result[String(describing: item.key)] = String(describing: item.value)
            }
            return MBIssueRawNetworkResponse(
                statusCode: response.statusCode,
                data: data,
                headers: headers
            )
        }
    }

    private struct MBIssueNetworkEndpoint: AsyncNetworkable {
        let urlRequest: URLRequest

        func request() async -> URLRequest {
            urlRequest
        }
    }

    private final class MBIssueNetworkingStorage: NetworkingStorable, @unchecked Sendable {
        private let lock = NSLock()
        private var storedAccessToken: String?
        private var storedRefreshToken: String?

        var accessToken: String? {
            get { lock.withLock { storedAccessToken } }
            set { lock.withLock { storedAccessToken = newValue } }
        }

        var refreshToken: String? {
            get { lock.withLock { storedRefreshToken } }
            set { lock.withLock { storedRefreshToken = newValue } }
        }
    }
#endif

struct MBIssueUnavailableNetworkTransport: MBIssueNetworkTransport {
    func send<Response: Decodable & Sendable>(
        _: URLRequest,
        decoding _: Response.Type
    ) async throws -> Response {
        throw MBIssueProviderError.transport("MBAsyncNetworking is unavailable on this platform.")
    }

    func sendRaw(_: URLRequest) async throws -> MBIssueRawNetworkResponse {
        throw MBIssueProviderError.transport("MBAsyncNetworking is unavailable on this platform.")
    }
}
