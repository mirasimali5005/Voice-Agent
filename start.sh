#!/bin/bash
# Voice Agent — one-command launcher
# Starts LM Studio, ensures a model is loaded, and launches the app.

set -e

DEFAULT_MODEL="deepseek/deepseek-r1-0528-qwen3-8b"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$SCRIPT_DIR/VoiceDictation"
APP_BUNDLE="$HOME/Applications/Voice Agent.app"
LMS="$HOME/.lmstudio/bin/lms"

echo "==> Starting Voice Agent..."

# 1. Ensure LM Studio is running
if ! pgrep -q "LM Studio"; then
    echo "    Starting LM Studio..."
    open -a "LM Studio"
    echo "    Waiting for LM Studio to start..."
    sleep 5
fi

# 2. Ensure the API server is running
if ! "$LMS" server status 2>&1 | grep -qi "running"; then
    echo "    Starting LM Studio server..."
    "$LMS" server start 2>/dev/null || true
    sleep 2
fi

# 3. Check if ANY model is already loaded — if so, use it
if "$LMS" ps 2>&1 | grep -q "No models"; then
    echo "    No model loaded. Loading default: $DEFAULT_MODEL"
    "$LMS" load "$DEFAULT_MODEL" --gpu max -y 2>/dev/null || true
    sleep 2
else
    echo "    Model already loaded — using it as-is."
fi

echo "    LM Studio ready on port 1234."

# 4. Build the app (always rebuild to pick up code changes)
echo "    Building Voice Agent app..."
bash "$SCRIPT_DIR/build-app.sh"

# 5. Quit old instance if running
osascript -e 'tell application "Voice Agent" to quit' 2>/dev/null || true
sleep 1

# 6. Launch the app
echo "    Launching Voice Agent..."
open "$APP_BUNDLE"

echo ""
echo "==> Voice Agent is running!"
echo "    Hold the Fn (Globe) key to dictate. Release to stop."
echo "    Use the menu bar icon (mic) or Cmd+Q to quit."
