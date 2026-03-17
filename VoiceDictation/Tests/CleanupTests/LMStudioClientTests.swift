import XCTest
@testable import VoiceDictation

final class LMStudioClientTests: XCTestCase {

    func testBuildRequestBody() {
        let client = LMStudioClient()
        let body = client.buildRequestBody(
            systemPrompt: "You are a helper.",
            userMessage: "Hello!",
            model: "test-model",
            maxTokens: 512,
            temperature: 0.7
        )

        // Verify model
        XCTAssertEqual(body["model"] as? String, "test-model")

        // Verify temperature
        XCTAssertEqual(body["temperature"] as? Double, 0.7)

        // Verify max_tokens
        XCTAssertEqual(body["max_tokens"] as? Int, 512)

        // Verify messages array
        guard let messages = body["messages"] as? [[String: String]] else {
            XCTFail("messages should be an array of dictionaries")
            return
        }
        XCTAssertEqual(messages.count, 2)

        // System message
        XCTAssertEqual(messages[0]["role"], "system")
        XCTAssertEqual(messages[0]["content"], "You are a helper.")

        // User message
        XCTAssertEqual(messages[1]["role"], "user")
        XCTAssertEqual(messages[1]["content"], "Hello!")
    }

    func testTimeoutIsRespected() async {
        // Use a non-routable IP (RFC 5737 TEST-NET) to guarantee a timeout
        let client = LMStudioClient(endpoint: "http://192.0.2.1:9999", timeoutSeconds: 0.5)

        let start = Date()
        let result = await client.complete(
            systemPrompt: "test",
            userMessage: "test"
        )
        let elapsed = Date().timeIntervalSince(start)

        // Should fail
        switch result {
        case .success:
            XCTFail("Expected failure for non-routable endpoint")
        case .failure:
            // Any failure is acceptable (timeout or network error)
            break
        }

        // Should complete within ~2 seconds (0.5s timeout + overhead)
        XCTAssertLessThan(elapsed, 5.0, "Request should time out within a reasonable window")
    }
}
