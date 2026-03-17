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

## Requirements

- **macOS 14.0+** (Sonoma or later)
- **Apple Silicon** Mac (M1 or later)
- **[LM Studio](https://lmstudio.ai/)** — for local LLM text cleanup (optional — app works without it)

## Quick Start

### One command does everything:

```bash
git clone https://github.com/mirasimali5005/Voice-Agent.git
cd Voice-Agent
./setup.sh
```

That's it. The script automatically:
- Builds whisper.cpp with Metal GPU acceleration
- Checks for LM Studio and loads an LLM model
- Compiles and packages the app
- Launches Voice Agent

### First launch permissions

macOS will ask you to grant:
- **Microphone** — prompted automatically
- **Accessibility** — System Settings > Privacy & Security > Accessibility > toggle Voice Agent ON

Then download the Whisper model (~1.5GB) when prompted in the app. One-time only.

### Already set up? Just run:

```bash
./start.sh
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

## Project Structure

```
Voice-Agent/
├── setup.sh                          # One-command setup (builds everything)
├── start.sh                          # Quick launch (after first setup)
├── build-app.sh                      # Builds .app bundle
└── VoiceDictation/
    ├── Package.swift                 # Swift package manifest
    ├── scripts/build-whisper.sh      # Compiles whisper.cpp with Metal
    ├── Libraries/include/            # whisper.cpp C headers
    └── Sources/VoiceDictation/
        ├── App/                      # Entry point, global state
        ├── Audio/                    # Mic capture (16kHz), chunking, VAD
        ├── Transcription/            # Whisper engine, streaming pipeline
        ├── Cleanup/                  # LM Studio client, transcript cleanup
        ├── Hotkey/                   # Fn key detection (CGEvent tap)
        ├── TextInjection/            # Auto-paste (Accessibility API)
        ├── Orchestration/            # Main flow coordinator
        ├── Storage/                  # SQLite database (GRDB)
        ├── Models/                   # Whisper model management
        └── UI/                       # SwiftUI views
```

## Configuration

All settings are in the **Settings** tab of the app:

| Setting | Description | Default |
|---------|-------------|---------|
| LM Studio Endpoint | API URL | `http://127.0.0.1:1234` |
| System Prompt | Instructions for LLM cleanup | Removes fillers, fixes punctuation |
| Whisper Model | Turbo (faster) or Standard (more accurate) | Large v3 Turbo |
| LLM Model | Switch between downloaded models | Auto-detected |

## Recommended LLM Models

| Model | Size | Speed | Quality | Best For |
|-------|------|-------|---------|----------|
| Gemma 3 4B | 2.8 GB | ⚡ Fast | Good | Short dictations |
| Qwen3 8B | 4.3 GB | ⚡ Medium | Better | General use |
| Gemma 3 12B | 7.5 GB | 🐢 Slower | Best | Long-form, accuracy |

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "Accessibility permission needed" after rebuild | Remove Voice Agent from Accessibility list, re-add it — app auto-detects |
| Fn key opens emoji picker | System Settings > Keyboard > "Press 🌐 key to" → "Do Nothing" |
| "No speech detected" | Check mic is working in System Settings > Sound |
| LM Studio timeout | Make sure LM Studio is running with a model loaded |

## Tech Stack

- **Swift 5.9+ / SwiftUI** — native macOS UI
- **whisper.cpp** — Whisper inference with Metal GPU
- **LM Studio** — OpenAI-compatible local LLM API
- **GRDB.swift** — SQLite persistence
- **AVAudioEngine** — real-time audio capture
- **CGEvent** — global hotkey detection
- **AXUIElement** — text field detection and injection

## License

MIT
