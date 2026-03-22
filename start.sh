#!/bin/bash
# Voice Agent — one-command launcher
# Builds and launches the Voice Agent app.
# Optionally starts LM Studio for transcript cleanup and/or the Spring Boot backend for sync.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/VoiceDictation"
APP_BUNDLE="$HOME/Applications/Voice Agent.app"
LMS="$HOME/.lmstudio/bin/lms"

WITH_BACKEND=false
WITH_LM_STUDIO=false

# Parse arguments
for arg in "$@"; do
    case $arg in
        --with-backend)
            WITH_BACKEND=true
            ;;
        --with-lm-studio)
            WITH_LM_STUDIO=true
            ;;
        --help|-h)
            echo "Usage: ./start.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --with-lm-studio   Start LM Studio and ensure a model is loaded (for transcript cleanup)"
            echo "  --with-backend     Start the Spring Boot backend (for cloud sync)"
            echo "  --help, -h         Show this help message"
            echo ""
            echo "Default: builds and launches Voice Agent only."
            echo "Voice Agent works offline without LM Studio or the backend."
            exit 0
            ;;
    esac
done

echo "==> Starting Voice Agent..."

# ── Optional: LM Studio ──
if $WITH_LM_STUDIO; then
    DEFAULT_MODEL="deepseek/deepseek-r1-0528-qwen3-8b"

    if ! command -v "$LMS" &>/dev/null && ! [ -f "$LMS" ]; then
        echo "    WARNING: LM Studio CLI not found. Skipping LM Studio setup."
        echo "    Install from https://lmstudio.ai and enable CLI in Settings > Developer."
    else
        # Ensure LM Studio is running
        if ! pgrep -q "LM Studio"; then
            echo "    Starting LM Studio..."
            open -a "LM Studio"
            echo "    Waiting for LM Studio to start..."
            sleep 5
        fi

        # Ensure the API server is running
        if ! "$LMS" server status 2>&1 | grep -qi "running"; then
            echo "    Starting LM Studio server..."
            "$LMS" server start 2>/dev/null || true
            sleep 2
        fi

        # Check if ANY model is already loaded — if so, use it
        if "$LMS" ps 2>&1 | grep -q "No models"; then
            echo "    No model loaded. Loading default: $DEFAULT_MODEL"
            "$LMS" load "$DEFAULT_MODEL" --gpu max -y 2>/dev/null || true
            sleep 2
        else
            echo "    Model already loaded — using it as-is."
        fi

        echo "    LM Studio ready on port 1234."
    fi
fi

# ── Optional: Spring Boot Backend ──
if $WITH_BACKEND; then
    echo "    Starting backend..."
    if [ -f "$SCRIPT_DIR/backend/start-backend.sh" ]; then
        bash "$SCRIPT_DIR/backend/start-backend.sh" &
        BACKEND_PID=$!
        echo "    Backend starting in background (PID: $BACKEND_PID)"
        sleep 3
    else
        echo "    WARNING: backend/start-backend.sh not found. Skipping backend."
    fi
fi

# ── Build the app (always rebuild to pick up code changes) ──
echo "    Building Voice Agent app..."
bash "$SCRIPT_DIR/build-app.sh"

# ── Quit old instance if running ──
osascript -e 'tell application "Voice Agent" to quit' 2>/dev/null || true
sleep 1

# ── Launch the app ──
echo "    Launching Voice Agent..."
open "$APP_BUNDLE"

echo ""
echo "==> Voice Agent is running!"
echo "    Hold the Fn (Globe) key to dictate. Release to stop."
echo "    Use the menu bar icon (mic) or Cmd+Q to quit."
if $WITH_LM_STUDIO; then
    echo "    LM Studio is providing transcript cleanup on port 1234."
fi
if $WITH_BACKEND; then
    echo "    Backend sync server is running on port 8080."
fi
echo ""
echo "    Options: ./start.sh --help"
