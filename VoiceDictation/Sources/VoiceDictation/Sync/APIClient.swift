import Foundation

/// HTTP client for communicating with the Spring Boot sync API.
final class APIClient {

    // MARK: - Errors

    enum APIError: LocalizedError {
        case invalidURL
        case unauthorized
        case clientError(statusCode: Int, body: String)
        case serverError(statusCode: Int, body: String)
        case networkError(underlying: Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL."
            case .unauthorized:
                return "Unauthorized (401). Check your auth token."
            case .clientError(let code, let body):
                return "Client error \(code): \(body)"
            case .serverError(let code, let body):
                return "Server error \(code): \(body)"
            case .networkError(let underlying):
                return "Network error: \(underlying.localizedDescription)"
            }
        }
    }

    // MARK: - Properties

    let baseURL: String
    var authToken: String?

    private let session: URLSession

    // MARK: - Init

    init(baseURL: String) {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public Methods

    /// POST an Encodable body to the given path and return the raw response data.
    func post<T: Encodable>(path: String, body: T) async throws -> Data {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(&request)

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)

        return try await execute(request)
    }

    /// GET from the given path with optional query parameters and return raw response data.
    func get(path: String, params: [String: String] = [:]) async throws -> Data {
        guard var components = URLComponents(string: baseURL + path) else {
            throw APIError.invalidURL
        }

        if !params.isEmpty {
            components.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuth(&request)

        return try await execute(request)
    }

    // MARK: - Private Helpers

    private func applyAuth(_ request: inout URLRequest) {
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    private func execute(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(underlying: error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(
                underlying: NSError(domain: "APIClient", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Non-HTTP response"])
            )
        }

        let statusCode = httpResponse.statusCode

        switch statusCode {
        case 200..<300:
            return data
        case 401:
            throw APIError.unauthorized
        case 400..<500:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.clientError(statusCode: statusCode, body: body)
        default:
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.serverError(statusCode: statusCode, body: body)
        }
    }
}
