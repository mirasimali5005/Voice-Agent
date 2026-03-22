import Foundation

/// Errors that can occur when communicating with the LM Studio API.
public enum LMStudioError: Error, LocalizedError, Sendable {
    case invalidEndpoint
    case serializationError
    case invalidResponse
    case httpError(statusCode: Int, body: String)
    case parseError
    case timeout
    case networkError

    public var errorDescription: String? {
        switch self {
        case .invalidEndpoint:
            return "The LM Studio endpoint URL is invalid."
        case .serializationError:
            return "Failed to serialize the request body to JSON."
        case .invalidResponse:
            return "Received an invalid response from LM Studio."
        case .httpError(let statusCode, let body):
            return "HTTP error \(statusCode): \(body)"
        case .parseError:
            return "Failed to parse the LM Studio response."
        case .timeout:
            return "The request to LM Studio timed out."
        case .networkError:
            return "A network error occurred while contacting LM Studio."
        }
    }
}

/// A client for communicating with a local LM Studio server via the OpenAI-compatible API.
public final class LMStudioClient: CleanupBackend, Sendable {
    public let backendName = "LM Studio"
    public let endpoint: String
    public let timeoutSeconds: Double

    public init(endpoint: String = "http://localhost:1234", timeoutSeconds: Double = 30.0) {
        self.endpoint = endpoint
        self.timeoutSeconds = timeoutSeconds
    }

    // MARK: - CleanupBackend Conformance

    /// Checks if LM Studio is reachable by sending a lightweight request.
    public func isAvailable() async -> Bool {
        let urlString = "\(endpoint)/v1/models"
        guard let url = URL(string: urlString) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 3.0 // short timeout for availability check

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return (200...299).contains(http.statusCode)
        } catch {
            return false
        }
    }

    /// Protocol-conforming complete method (uses default model and temperature).
    public func complete(systemPrompt: String, userMessage: String) async -> Result<String, Error> {
        let result = await complete(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            model: "default",
            maxTokens: 2048,
            temperature: 0.3
        )
        switch result {
        case .success(let text):
            return .success(text)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Builds the JSON request body for the chat completions endpoint.
    public func buildRequestBody(
        systemPrompt: String,
        userMessage: String,
        model: String = "default",
        maxTokens: Int = 2048,
        temperature: Double = 0.3
    ) -> [String: Any] {
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userMessage],
        ]
        return [
            "model": model,
            "messages": messages,
            "max_tokens": maxTokens,
            "temperature": temperature,
        ]
    }

    /// Sends a chat completion request to LM Studio and returns the assistant's reply.
    public func complete(
        systemPrompt: String,
        userMessage: String,
        model: String = "default",
        maxTokens: Int = 2048,
        temperature: Double = 0.3
    ) async -> Result<String, LMStudioError> {
        let urlString = "\(endpoint)/v1/chat/completions"
        guard let url = URL(string: urlString) else {
            return .failure(.invalidEndpoint)
        }

        let body = buildRequestBody(
            systemPrompt: systemPrompt,
            userMessage: userMessage,
            model: model,
            maxTokens: maxTokens,
            temperature: temperature
        )

        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return .failure(.serializationError)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        request.timeoutInterval = timeoutSeconds

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError where urlError.code == .timedOut {
            return .failure(.timeout)
        } catch let urlError as URLError where urlError.code == .cannotConnectToHost
            || urlError.code == .networkConnectionLost
            || urlError.code == .cannotFindHost
        {
            return .failure(.networkError)
        } catch {
            return .failure(.timeout)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            return .failure(.invalidResponse)
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let bodyString = String(data: data, encoding: .utf8) ?? ""
            return .failure(.httpError(statusCode: httpResponse.statusCode, body: bodyString))
        }

        // Parse the response JSON to extract choices[0].message.content
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String
        else {
            return .failure(.parseError)
        }

        return .success(content)
    }
}
