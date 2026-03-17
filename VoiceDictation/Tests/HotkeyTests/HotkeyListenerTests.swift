import XCTest
@testable import VoiceDictation

final class HotkeyListenerTests: XCTestCase {

    // Fn-hold hotkey uses HotkeyListener directly via CGEvent tap —
    // we test HotkeyAction enum values remain valid since the listener
    // requires a real CGEvent tap (Accessibility permission) to test end-to-end.

    func testHotkeyActionsAreDistinct() {
        XCTAssertNotEqual(HotkeyAction.startRecording, HotkeyAction.stopRecording)
        XCTAssertNotEqual(HotkeyAction.startRecording, HotkeyAction.cancelRecording)
        XCTAssertNotEqual(HotkeyAction.stopRecording, HotkeyAction.cancelRecording)
        XCTAssertNotEqual(HotkeyAction.none, HotkeyAction.startRecording)
    }

    func testHotkeyListenerInitialState() {
        let listener = HotkeyListener()
        // isRecording is private; we verify no crash on init
        XCTAssertNil(listener.onAction)
    }
}
