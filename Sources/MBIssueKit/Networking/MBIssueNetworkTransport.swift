import Foundation

struct MBIssueRawNetworkResponse: Sendable {
    let statusCode: Int
    let data: Data
    let headers: [String: String]
}

enum MBIssueHTTPResponseDecoder {
    static func decode<Response: Decodable & Sendable>(
        _ response: MBIssueRawNetworkResponse,
        as _: Response.Type
    ) throws -> Response {
        try validate(response)
        do {
            return try JSONDecoder().decode(Response.self, from: response.data)
        } catch {
            throw MBIssueProviderError.invalidResponse
        }
    }

    static func validate(_ response: MBIssueRawNetworkResponse) throws {
        guard (200 ..< 300).contains(response.statusCode) else {
            switch response.statusCode {
            case 401:
                throw MBIssueProviderError.authenticationFailed
            case 403:
                throw MBIssueProviderError.permissionDenied
            default:
                throw MBIssueProviderError.server(
                    statusCode: response.statusCode,
                    message: errorMessage(from: response.data)
                )
            }
        }
    }

    private static func errorMessage(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "The issue tracker request failed."
        }
        var messages: [String] = []
        if let errorMessages = object["errorMessages"] as? [String] {
            messages.append(contentsOf: errorMessages)
        }
        if let errors = object["errors"] as? [String: Any] {
            messages.append(contentsOf: errors.keys.sorted().compactMap { key in
                guard let value = errors[key] as? String, !value.isEmpty else { return nil }
                return "\(key): \(value)"
            })
        }
        for key in ["message", "error_description", "error"] {
            if let value = object[key] as? String, !value.isEmpty {
                messages.append(value)
            }
        }
        let unique = messages.reduce(into: [String]()) { result, message in
            guard !result.contains(message) else { return }
            result.append(message)
        }
        let message = unique.joined(separator: " ")
        return message.isEmpty ? "The issue tracker request failed." : String(message.prefix(1000))
    }
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
            try MBIssueHTTPResponseDecoder.decode(
                await sendRaw(request),
                as: Response.self
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
