# Voice Dictation Tool — Design Spec

## Overview

A native Swift macOS app for fast, offline voice dictation. Hold a hotkey to record, release to get cleaned-up text pasted into the active text field or copied to clipboard. All dictations are stored in-app for reference.

**Target latency** (from Ctrl release to text appearing):
- Under 10 seconds of speech: ~500ms
- 1 minute of speech: ~1-1.5 seconds
- 3+ minutes: ~2-3 seconds (LLM cleanup scales with transcript length)

## Core Architecture

Two layers:

1. **Background daemon** — always running, listens for the hotkey globally via `CGEvent` tap (requires Accessibility permission). On hold: starts recording + streaming audio chunks to whisper.cpp. On release: finishes transcription, runs LLM cleanup, pastes or copies.

2. **Main window** — SwiftUI window showing dictation history. Can be opened/closed without affecting the background listener.

### Pipeline

```
[Hotkey held] → Audio recording starts
  → 5-second chunks (with 0.5s overlap) streamed to whisper.cpp (Metal-accelerated)
  → Each chunk transcribed on background thread pool (overlapped with recording)
  → Voice Activity Detection: skip silent chunks

[Hotkey released] → Final partial chunk processed (~250-400ms)
  → Overlap regions deduplicated
  → Full transcript assembled
  → Sent to LM Studio for cleanup (if available; raw transcript used as fallback)
  → Always: save to history + copy to clipboard
  → If cursor is in a text field: paste via Cmd+V or AXValue fallback
```

## Recording & Transcription

### Audio Capture
- `AVAudioEngine` at 16kHz mono (Whisper's expected format)
- Audio streams in ~5-second chunks with **0.5-second overlap** to prevent words being cut at boundaries
- Each chunk fed to whisper.cpp immediately — no waiting for full recording

### Chunk Boundary Handling
- Each chunk overlaps the previous by 0.5 seconds
- On assembly, the overlap region is deduplicated by comparing the last ~5 words of the previous chunk with the first ~5 words of the next chunk, dropping the duplicate
- This prevents garbled or duplicated words at chunk boundaries

### Voice Activity Detection (VAD)
- Before sending a chunk to whisper.cpp, check audio energy level (RMS amplitude)
- If a chunk is below a silence threshold, skip it entirely (don't transcribe silence)
- This prevents whisper.cpp from hallucinating text on silent audio (a known behavior)
- If no speech is detected for the entire recording, show a "No speech detected" notification on release

### Whisper Setup
- whisper.cpp compiled with Metal support, linked directly into the Swift app (no subprocess)
- Default model: `large-v3-turbo` — best speed/accuracy tradeoff on Apple Silicon
- Each 5-second chunk transcribes in ~250-400ms on M5 with Metal
- Chunks processed on background thread pool, overlapping with recording

### Streaming Assembly
- As each chunk finishes, transcript appended to a running buffer (with overlap dedup)
- On Ctrl release, only the final partial chunk (0-5 seconds) needs processing
- Total wait after release: last chunk processing + LLM cleanup

### Recording Limits
- **Maximum recording duration**: 5 minutes. At 4:30, the overlay shows a warning. At 5:00, recording auto-stops and processes what it has.
- **Reason**: A 5-minute transcript is ~750-1000 words, approaching the practical context window of 7B models. Longer recordings should be split into multiple dictations.

### Chunk Failure Handling
- If whisper.cpp fails on a single chunk (Metal error, crash, garbled output): log the error, mark a `[gap]` placeholder in the transcript, and continue with the next chunk
- If 3+ consecutive chunks fail: abort the recording, notify the user with "Transcription error", and save whatever was captured so far

## LLM Cleanup (LM Studio)

### Purpose
- Remove filler words (uh, um, like, you know)
- Fix punctuation, capitalization, sentence boundaries
- Detect and format lists (numbered lists when speaker enumerates items)
- Detect paragraph breaks from context

### Setup
- Calls LM Studio's OpenAI-compatible endpoint at `http://localhost:1234/v1/chat/completions`
- Recommended model: Qwen 2.5 7B or Llama 3.1 8B (smart enough for structural formatting, fast enough for low latency)
- **Temperature**: 0 (deterministic, no creative rephrasing)
- **max_tokens**: 2x the input word count (prevents runaway generation)

### System Prompt
```
Clean up this dictation transcript. Remove filler words (uh, um, like, you know). Fix punctuation, capitalization, and sentence boundaries. When the speaker is listing items, format as a numbered list. Detect paragraph breaks from context. Preserve the speaker's exact non-filler words — do not rephrase, summarize, or add words. Return only the cleaned text.
```

### Sanity Check
- After receiving the LLM output, compare word count to input. If the output is less than 50% or more than 150% of the input word count, discard the LLM output and use the raw transcript instead (indicates hallucination or truncation)

### Fallback: LM Studio Unavailable
- On Ctrl release, attempt to reach LM Studio with a 500ms timeout
- If LM Studio is not running, unreachable, or returns an error: **skip cleanup and use the raw Whisper transcript directly**
- Show a subtle notification: "LM Studio offline — using raw transcript"
- The dictation is still saved and pasted/copied as normal, just without cleanup

### Example
**Input**: "So my groceries are uh a shopping bag a wooden cutting board and a cap"

**Output**:
```
1. Shopping bag
2. Wooden cutting board
3. Cap
```

## Text Injection & Clipboard

### Detecting Text Field Focus
- macOS Accessibility API (`AXUIElement`) queries the focused element
- Checks for `AXTextField` or `AXTextArea` role
- Requires Accessibility permission (standard macOS prompt on first launch)

### Behavior on Hotkey Release
1. **Always**: save cleaned text to app history (SQLite) + copy to clipboard
2. **If cursor is in a text field**: paste the text

### Paste Strategy (two-tier)
1. **Primary**: Use Accessibility API `AXValue` setter to directly insert text into the focused text field. This is more reliable than simulating keystrokes.
2. **Fallback**: If `AXValue` setter fails (sandboxed apps, custom controls), simulate `Cmd+V` via `CGEvent`.
3. **Known limitation**: Some Electron apps and sandboxed apps may block both methods. In these cases, the text is still on the clipboard — the user can manually paste.

## Hotkey Design

### Default: Double-tap Ctrl (then hold)
- Single Ctrl press/hold is too common (Terminal shortcuts, Emacs keybindings, Ctrl+Click)
- **Activation**: double-tap Ctrl within 300ms, then hold on the second tap to record
- **Release**: let go of Ctrl to stop recording and process
- This avoids conflicts with normal Ctrl usage while keeping the interaction fast

### Distinguishing from Key Combos
- If any other key is pressed while Ctrl is held (e.g., Ctrl+C), cancel the recording — it was a keyboard shortcut, not a dictation
- Only pure Ctrl-hold (no other keys) triggers/continues recording

### Configurable
- Users can change the hotkey to any modifier key or key combo in settings

## UI

### Recording Overlay
- Small floating pill/capsule near center-bottom of screen
- Pulsing waveform or mic icon indicating active recording
- Semi-transparent, always on top, does not steal focus
- Fade-in on hotkey activation, fade-out on release
- Shows elapsed time
- At 4:30 of recording, pill turns yellow as a warning

### Main App Window
- List of all dictation entries, newest first
- Each entry: timestamp, duration, cleaned text, copy button to re-copy
- Search bar to find past dictations
- Entries persist across restarts (SQLite storage)

### Menu Bar Icon
- Small mic icon for quick access to open window or quit
- Visual indicator (dot/color change) while recording

## Configuration & Settings

- **Hotkey**: Double-tap Ctrl by default, configurable to any modifier key or combo
- **LM Studio endpoint**: defaults to `http://localhost:1234`, configurable
- **LM Studio model**: picker for which loaded model to use
- **Whisper model**: toggle between `large-v3-turbo` (faster) and `large-v3` (more accurate)
- **Cleanup prompt**: editable system prompt for tweaking formatting behavior (stored in SQLite, not UserDefaults)
- **History retention**: how long to keep history (default: forever)
- **Launch at login**: toggle to start background listener on boot

## Data Storage

- SQLite database in `~/Library/Application Support/VoiceDictation/`
- Schema: `dictations` table with `id`, `timestamp`, `duration_seconds`, `raw_transcript`, `cleaned_text`, `was_pasted` (boolean)
- Cleanup prompt and other large text settings stored in SQLite `settings` table
- Simple preferences (hotkey, endpoint URL, booleans) stored via `UserDefaults`
- Schema version tracked in SQLite for future migrations

## Model Bundling

- The Whisper `large-v3-turbo` model (~1.5GB) is **not bundled** with the app
- On first launch, the app checks for the model in `~/Library/Application Support/VoiceDictation/models/`
- If not found, prompts the user to download it (with a progress bar) or point to an existing file
- This keeps the app distribution size small

## Permissions Required

- **Accessibility**: for global hotkey listening, text field detection, and paste simulation
- **Microphone**: for audio recording

Both requested via standard macOS permission prompts on first launch. The app shows a brief explanation of why each permission is needed before triggering the system prompt.

## Future Scope (Not in v1)

- Remote GPU support (run whisper on another machine's GPU over LAN)
- Phone-to-laptop voice input
- Custom vocabulary / domain-specific terms
- Multiple hotkey profiles
