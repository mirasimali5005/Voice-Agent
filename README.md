# Voice Agent

A native macOS app for fast, offline voice dictation. Hold the **Fn (Globe) key**, speak, release — your cleaned-up text appears wherever your cursor is.

Everything runs locally on your Mac. No cloud, no internet, no data leaves your machine.

![macOS](https://img.shields.io/badge/macOS-14.0+-black?logo=apple)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange?logo=swift)
![License](https://img.shields.io/badge/License-MIT-blue)

## How It Works

```
Hold Fn key → Speak → Release Fn key → Text appears in your active text field
```

1. **Whisper** (whisper.cpp with Metal GPU) converts your speech to text in real-time
2. **Local LLM** (via LM Studio) cleans up the transcript — removes filler words, fixes punctuation, formats lists
3. **Auto-paste** into whatever text field your cursor is in, or copies to clipboard

## Features

- **Fully offline** — Whisper STT + local LLM, zero cloud dependency
- **Metal GPU accelerated** — runs on Apple Silicon (M1/M2/M3/M4/M5)
- **Streaming transcription** — processes audio while you speak, not after
- **Smart cleanup** — removes "um", "uh", "like", fixes capitalization, detects lists
- **System-wide hotkey** — works in any app (Fn/Globe key)
- **Auto-paste** — injects text into focused text fields via Accessibility API
- **Dictation history** — SQLite-backed, searchable, with timestamps
- **In-app model management** — switch LLM models without leaving the app
- **Editable system prompt** — customize how the LLM cleans your text
- **Menu bar icon** — runs in background, always accessible

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon** Mac (M1 or later) — required for Metal GPU acceleration
- **[LM Studio](https://lmstudio.ai/)** — for local LLM inference
- **~4GB free RAM** for Whisper model + LLM (8GB+ recommended)

## Quick Start

### 1. Install LM Studio

Download from [lmstudio.ai](https://lmstudio.ai/) and install it. Then install the CLI:

```bash
# In LM Studio: Settings > Developer > Enable CLI
# Or run:
npx lmstudio install-cli
```

### 2. Clone and build

```bash
git clone https://github.com/YOUR_USERNAME/Voice-Agent.git
cd Voice-Agent
```

### 3. Build whisper.cpp

The app uses whisper.cpp compiled as a static library with Metal support:

```bash
cd VoiceDictation

# Clone whisper.cpp if not present
git submodule update --init --recursive
# Or: git clone https://github.com/ggerganov/whisper.cpp Libraries/whisper.cpp

# Build the static library
bash scripts/build-whisper.sh
```

This creates `Libraries/lib/libwhisper_full.a` with Metal GPU acceleration.

### 4. Launch everything

```bash
cd ..
./start.sh
```

This single command:
- Opens LM Studio (if not running)
- Loads the default LLM model
- Builds the app in release mode
- Packages it as `~/Applications/Voice Agent.app`
- Launches it

### 5. Grant permissions

On first launch, you'll need to grant two permissions:

- **Microphone** — macOS will prompt automatically
- **Accessibility** — Go to System Settings > Privacy & Security > Accessibility, add Voice Agent, toggle ON

### 6. Download Whisper model

On first launch, the app will prompt you to download the Whisper model (~1.5GB). This is a one-time download.

### 7. Use it

**Hold Fn (Globe) key** → Speak → **Release** → Text appears where your cursor is.

## Project Structure

```
Voice-Agent/
├── start.sh                          # One-command launcher
├── build-app.sh                      # Builds .app bundle
└── VoiceDictation/
    ├── Package.swift                 # Swift package manifest
    ├── scripts/build-whisper.sh      # Compiles whisper.cpp
    ├── Libraries/
    │   ├── include/                  # whisper.cpp headers
    │   └── lib/                      # libwhisper_full.a (built locally)
    └── Sources/VoiceDictation/
        ├── App/                      # Entry point, global state
        ├── Audio/                    # Mic capture, chunking, VAD
        ├── Transcription/            # Whisper engine, streaming pipeline
        ├── Cleanup/                  # LM Studio client, transcript cleanup
        ├── Hotkey/                   # Fn key detection via CGEvent tap
        ├── TextInjection/            # Auto-paste via Accessibility API
        ├── Orchestration/            # Main flow coordinator
        ├── Storage/                  # SQLite database (GRDB)
        ├── Models/                   # Whisper model management
        └── UI/                       # SwiftUI views
```

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Fn Key     │────▶│  Audio       │────▶│  Whisper     │
│  (CGEvent)  │     │  Recorder    │     │  Engine      │
└─────────────┘     │  16kHz mono  │     │  (Metal GPU) │
                    │  5s chunks   │     └──────┬───────┘
                    └──────────────┘            │
                                               ▼
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│  Text       │◀────│  Transcript  │◀────│  Streaming   │
│  Injector   │     │  Cleaner     │     │  Pipeline    │
│  (Cmd+V /   │     │  (Local LLM) │     │  (overlap    │
│   AXValue)  │     └──────────────┘     │   dedup)     │
└──────┬──────┘                          └─────────────┘
       │
       ▼
┌─────────────┐
│  SQLite     │
│  History    │
└─────────────┘
```

## Configuration

All settings are accessible from the **Settings** tab in the app:

| Setting | Description | Default |
|---------|-------------|---------|
| LM Studio Endpoint | API URL | `http://127.0.0.1:1234` |
| System Prompt | Instructions for LLM cleanup | Removes fillers, fixes punctuation |
| Whisper Model | Turbo (faster) or Standard (more accurate) | Large v3 Turbo |
| LLM Model | Any model loaded in LM Studio | Auto-detected |

## Changing the LLM Model

You can switch models directly from the app's Settings > Models tab, or load any model in LM Studio — the app auto-detects it.

Recommended models (tested):
- **Gemma 3 4B** — fastest, good for short dictations
- **Qwen3 8B** — good balance of speed and quality
- **Gemma 3 12B** — best quality, slower

## Troubleshooting

**"Accessibility permission needed" even though it's granted:**
After rebuilding the app, macOS treats the new binary as a different app. Remove Voice Agent from the Accessibility list, re-add it, and the app will auto-detect the permission (no restart needed).

**Fn key opens emoji picker instead of recording:**
Go to System Settings > Keyboard > "Press 🌐 key to" and set it to "Do Nothing".

**"No speech detected":**
Check that your mic is working and selected as the input device in System Settings > Sound.

**LM Studio timeout:**
Make sure LM Studio is running and a model is loaded. The app will work without LM Studio — it just won't clean up the text.

## Tech Stack

- **Swift 5.9+ / SwiftUI** — native macOS UI
- **whisper.cpp** — C library for Whisper inference, compiled with Metal
- **LM Studio API** — OpenAI-compatible local LLM endpoint
- **GRDB.swift** — SQLite wrapper
- **AVAudioEngine** — audio capture
- **CGEvent** — global hotkey detection
- **AXUIElement** — text field detection and injection

## License

MIT
