#!/bin/bash
# Build whisper.cpp static library from submodule
# Requires: cmake (brew install cmake)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WHISPER_DIR="$PROJECT_ROOT/Libraries/whisper.cpp"
BUILD_DIR="$WHISPER_DIR/build"
LIB_DIR="$PROJECT_ROOT/Libraries/lib"
INCLUDE_DIR="$PROJECT_ROOT/Libraries/include"

echo "Building whisper.cpp from: $WHISPER_DIR"

# Ensure submodule is initialized
if [ ! -f "$WHISPER_DIR/CMakeLists.txt" ]; then
    echo "Error: whisper.cpp submodule not found. Run: git submodule update --init"
    exit 1
fi

# Configure
cmake -B "$BUILD_DIR" -S "$WHISPER_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DGGML_METAL=ON \
    -DGGML_METAL_EMBED_LIBRARY=ON \
    -DWHISPER_COREML=OFF \
    -DBUILD_SHARED_LIBS=OFF \
    -DWHISPER_BUILD_EXAMPLES=OFF \
    -DWHISPER_BUILD_TESTS=OFF

# Build
cmake --build "$BUILD_DIR" --config Release -j "$(sysctl -n hw.ncpu)"

# Combine static libraries
mkdir -p "$LIB_DIR" "$INCLUDE_DIR"

libtool -static -o "$LIB_DIR/libwhisper_full.a" \
    "$BUILD_DIR/src/libwhisper.a" \
    "$BUILD_DIR/ggml/src/libggml.a" \
    "$BUILD_DIR/ggml/src/libggml-base.a" \
    "$BUILD_DIR/ggml/src/libggml-cpu.a" \
    "$BUILD_DIR/ggml/src/ggml-metal/libggml-metal.a" \
    "$BUILD_DIR/ggml/src/ggml-blas/libggml-blas.a"

# Copy headers
cp "$WHISPER_DIR/include/whisper.h" "$INCLUDE_DIR/"
cp "$WHISPER_DIR/ggml/include/ggml.h" "$INCLUDE_DIR/"
cp "$WHISPER_DIR/ggml/include/ggml-cpu.h" "$INCLUDE_DIR/"
cp "$WHISPER_DIR/ggml/include/ggml-backend.h" "$INCLUDE_DIR/"
cp "$WHISPER_DIR/ggml/include/ggml-alloc.h" "$INCLUDE_DIR/"
cp "$WHISPER_DIR/ggml/include/ggml-opt.h" "$INCLUDE_DIR/"
cp "$WHISPER_DIR/ggml/include/gguf.h" "$INCLUDE_DIR/"
cp "$WHISPER_DIR/ggml/include/ggml-cpp.h" "$INCLUDE_DIR/" 2>/dev/null || true

echo "Done. Static library: $LIB_DIR/libwhisper_full.a"
echo "Headers: $INCLUDE_DIR/"
