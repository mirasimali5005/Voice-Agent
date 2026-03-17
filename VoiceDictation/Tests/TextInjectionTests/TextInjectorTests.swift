import XCTest
import AppKit
@testable import VoiceDictation

final class TextInjectorTests: XCTestCase {

    // MARK: - Copy to Clipboard (no UI context)

    func testCopyToClipboard() {
        let testText = "Hello from voice dictation test"
        let result = TextInjector.inject(text: testText)

        // Without a focused text field (headless test environment), should fall back to clipboard
        XCTAssertEqual(result, .copiedToClipboard, "With no focused text field, result should be copiedToClipboard")

        // Verify the clipboard actually has the text
        let clipboardString = NSPasteboard.general.string(forType: .string)
        XCTAssertEqual(clipboardString, testText, "Clipboard should contain the injected text")
    }
}
