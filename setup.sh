#!/bin/bash
# Voice Agent — One-command setup
# Installs everything from scratch: whisper.cpp, LM Studio CLI, builds the app, and launches it.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔══════════════════════════════════════╗"
echo "║       Voice Agent — Setup            ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── Step 1: Check for Xcode command line tools ──
echo "▸ [1/6] Checking Xcode command line tools..."
if ! xcode-select -p &>/dev/null; then
    echo "  Installing Xcode command line tools (this may take a few minutes)..."
    xcode-select --install
    echo "  ⚠️  Please complete the Xcode tools installation, then re-run this script."
    exit 1
fi
echo "  ✓ Xcode tools found"

# ── Step 2: Check for cmake ──
echo "▸ [2/6] Checking cmake..."
if ! command -v cmake &>/dev/null; then
    echo "  Installing cmake via Homebrew..."
    if ! command -v brew &>/dev/null; then
        echo "  ✗ Homebrew not found. Install it from https://brew.sh then re-run."
        exit 1
    fi
    brew install cmake
fi
echo "  ✓ cmake found"

# ── Step 3: Build whisper.cpp ──
echo "▸ [3/6] Building whisper.cpp with Metal GPU support..."
cd VoiceDictation

if [ ! -f "Libraries/lib/libwhisper_full.a" ]; then
    # Clone whisper.cpp if not present
    if [ ! -d "Libraries/whisper.cpp" ]; then
        echo "  Cloning whisper.cpp..."
        git clone --depth 1 https://github.com/ggerganov/whisper.cpp Libraries/whisper.cpp
    fi

    echo "  Compiling (this takes 2-3 minutes)..."
    bash scripts/build-whisper.sh
    echo "  ✓ whisper.cpp built with Metal acceleration"
else
    echo "  ✓ whisper.cpp already built"
fi

cd "$SCRIPT_DIR"

# ── Step 4: Check LM Studio ──
echo "▸ [4/6] Checking LM Studio..."
if ! command -v lms &>/dev/null; then
    echo ""
    echo "  ⚠️  LM Studio CLI (lms) not found."
    echo "  To install:"
    echo "    1. Download LM Studio from https://lmstudio.ai"
    echo "    2. Open LM Studio → Settings → Developer → Enable CLI"
    echo "    3. Or run: npx lmstudio install-cli"
    echo ""
    echo "  The app will still work without LM Studio — it just won't"
    echo "  clean up your transcripts (no filler word removal, etc)."
    echo ""
else
    echo "  ✓ LM Studio CLI found"

    # Start LM Studio if not running
    if ! lms status &>/dev/null 2>&1; then
        echo "  Starting LM Studio..."
        open -a "LM Studio" 2>/dev/null || true
        sleep 3
    fi

    # Load a model if none loaded
    LOADED=$(lms ps 2>/dev/null | grep -c "│" || echo "0")
    if [ "$LOADED" -le 1 ]; then
        echo "  No model currently loaded. Trying to load one..."

        # Try loading already-downloaded models (in order of preference)
        if lms load deepseek/deepseek-r1-0528-qwen3-8b --gpu max -y 2>/dev/null; then
            echo "  ✓ Loaded Qwen3 8B"
        elif lms load google/gemma-3-4b --gpu max -y 2>/dev/null; then
            echo "  ✓ Loaded Gemma 3 4B"
        else
            # No models downloaded — offer to download one
            echo ""
            echo "  No models downloaded yet. Would you like to download one?"
            echo "  Recommended: Gemma 3 4B (2.8 GB, fast, good quality)"
            echo ""
            read -p "  Download Gemma 3 4B? [Y/n] " -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
                echo "  Downloading Gemma 3 4B (this may take a few minutes)..."
                lms get google/gemma-3-4b 2>/dev/null && \
                lms load google/gemma-3-4b --gpu max -y 2>/dev/null && \
                echo "  ✓ Downloaded and loaded Gemma 3 4B" || \
                echo "  ⚠️  Download failed. Open LM Studio and download a model manually."
            else
                echo "  Skipped. The app will work without an LLM — just no text cleanup."
                echo "  You can download a model later from LM Studio or the app's Settings tab."
            fi
        fi
    else
        echo "  ✓ Model already loaded"
    fi
fi

# ── Step 5: Build the app ──
echo "▸ [5/6] Building Voice Agent..."
bash build-app.sh 2>&1 | grep -E "(Build complete|App bundle created|error)" || true
echo "  ✓ App built at ~/Applications/Voice Agent.app"

# ── Step 6: Launch ──
echo "▸ [6/6] Launching Voice Agent..."
open "$HOME/Applications/Voice Agent.app"

echo ""
echo "╔══════════════════════════════════════╗"
echo "║            ✓ All done!               ║"
echo "╠══════════════════════════════════════╣"
echo "║                                      ║"
echo "║  Hold Fn (Globe) key → Speak →       ║"
echo "║  Release → Text appears!             ║"
echo "║                                      ║"
echo "║  First launch:                       ║"
echo "║  • Grant Microphone permission       ║"
echo "║  • Grant Accessibility permission    ║"
echo "║    (System Settings > Privacy >      ║"
echo "║     Accessibility > Voice Agent)     ║"
echo "║  • Download Whisper model (~1.5GB)   ║"
echo "║                                      ║"
echo "╚══════════════════════════════════════╝"
