#!/bin/bash
# Build Voice Agent as a proper macOS .app bundle
set -e

APP_NAME="Voice Agent"
APP_DIR="$(cd "$(dirname "$0")/VoiceDictation" && pwd)"
BUILD_DIR="$APP_DIR/.build/release"
APP_BUNDLE="$HOME/Applications/${APP_NAME}.app"

echo "==> Building Voice Agent..."
cd "$APP_DIR"
swift build -c release 2>&1

BINARY="$BUILD_DIR/VoiceDictation"
if [ ! -f "$BINARY" ]; then
    echo "ERROR: Binary not found at $BINARY"
    exit 1
fi

echo "==> Creating app bundle..."
mkdir -p "$HOME/Applications"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BINARY" "$APP_BUNDLE/Contents/MacOS/VoiceAgent"

# Create Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>Voice Agent</string>
    <key>CFBundleDisplayName</key>
    <string>Voice Agent</string>
    <key>CFBundleIdentifier</key>
    <string>com.voiceagent.app</string>
    <key>CFBundleVersion</key>
    <string>1.1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundleExecutable</key>
    <string>VoiceAgent</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIconName</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>Voice Agent needs microphone access to transcribe your speech.</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>LSUIElement</key>
    <false/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSSupportsAutomaticTermination</key>
    <false/>
    <key>NSSupportsSuddenTermination</key>
    <false/>
</dict>
</plist>
PLIST

# Generate blue robot app icon
python3 - << 'PYEOF'
import struct, zlib, os, math

def create_png(width, height, pixels):
    def chunk(chunk_type, data):
        c = chunk_type + data
        return struct.pack('>I', len(data)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
    raw = b''
    for y in range(height):
        raw += b'\x00'
        for x in range(width):
            idx = (y * width + x) * 4
            raw += pixels[idx:idx+4]
    return (b'\x89PNG\r\n\x1a\n' +
            chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 6, 0, 0, 0)) +
            chunk(b'IDAT', zlib.compress(raw, 9)) +
            chunk(b'IEND', b''))

size = 512
pixels = bytearray(size * size * 4)
cx, cy = size // 2, size // 2
light_blue = (100, 190, 240)
dark_blue = (30, 80, 140)
visor_bg = (200, 220, 240)

for y in range(size):
    for x in range(size):
        idx = (y * size + x) * 4
        dx, dy = x - cx, y - cy
        dist = math.sqrt(dx*dx + dy*dy)
        main_r = size * 0.40
        if dist <= main_r:
            grad = 0.5 + 0.5 * (dx + dy) / (main_r * 2)
            r = int(light_blue[0] * (1 - grad * 0.3))
            g = int(light_blue[1] * (1 - grad * 0.2))
            b = int(light_blue[2] * (1 - grad * 0.1))
            a = 255
            visor_w, visor_h = main_r * 0.75, main_r * 0.28
            visor_cx, visor_cy = cx, cy - main_r * 0.05
            visor_dx = abs(x - visor_cx) - visor_w / 2 + visor_h / 2
            visor_dy = abs(y - visor_cy) - visor_h / 2 + visor_h / 2
            visor_dist = math.sqrt(max(0, visor_dx)**2 + max(0, visor_dy)**2)
            if visor_dist < visor_h / 2:
                r, g, b = visor_bg
                eye_r = main_r * 0.09
                eye_spacing = main_r * 0.25
                for eye_offset in [-eye_spacing, eye_spacing]:
                    eye_cx = cx + eye_offset
                    eye_cy = visor_cy
                    eye_dist = math.sqrt((x - eye_cx)**2 + (y - eye_cy)**2)
                    if eye_dist < eye_r:
                        r, g, b = dark_blue
            ear_r = main_r * 0.14
            for side in [-1, 1]:
                ear_cx = cx + side * (main_r * 0.95)
                ear_cy = cy - main_r * 0.05
                if abs(x - ear_cx) < ear_r and abs(y - ear_cy) < main_r * 0.22:
                    r, g, b = dark_blue
                    a = 255
            pixels[idx] = max(0, min(255, r))
            pixels[idx+1] = max(0, min(255, g))
            pixels[idx+2] = max(0, min(255, b))
            pixels[idx+3] = a
        else:
            ear_r = main_r * 0.16
            drawn = False
            for side in [-1, 1]:
                ear_cx = cx + side * (main_r * 0.97)
                ear_cy = cy - main_r * 0.05
                if abs(x - ear_cx) < ear_r and abs(y - ear_cy) < main_r * 0.22:
                    pixels[idx] = dark_blue[0]
                    pixels[idx+1] = dark_blue[1]
                    pixels[idx+2] = dark_blue[2]
                    pixels[idx+3] = 255
                    drawn = True
                    break
            if not drawn:
                band_cx, band_cy = cx + main_r * 0.15, cy
                band_dist = math.sqrt((x - band_cx)**2 + (y - band_cy)**2)
                band_angle = math.atan2(y - band_cy, x - band_cx)
                if (main_r * 1.05 < band_dist < main_r * 1.15 and
                    -math.pi * 0.6 < band_angle < math.pi * 0.75 and
                    x > cx + main_r * 0.2):
                    pixels[idx] = dark_blue[0]
                    pixels[idx+1] = dark_blue[1]
                    pixels[idx+2] = dark_blue[2]
                    pixels[idx+3] = 255
                else:
                    pixels[idx:idx+4] = b'\x00\x00\x00\x00'

png_data = create_png(size, size, bytes(pixels))
res_dir = os.path.expanduser('~/Applications/Voice Agent.app/Contents/Resources')
with open(f'{res_dir}/AppIcon.png', 'wb') as f:
    f.write(png_data)

# Create iconset for .icns
tmp_dir = '/tmp/VoiceAgent.iconset'
os.makedirs(tmp_dir, exist_ok=True)
for s in [16, 32, 128, 256, 512]:
    with open(f'{tmp_dir}/icon_{s}x{s}.png', 'wb') as f:
        f.write(png_data)
    if s <= 256:
        with open(f'{tmp_dir}/icon_{s}x{s}@2x.png', 'wb') as f:
            f.write(png_data)
PYEOF

# Convert to .icns
iconutil -c icns /tmp/VoiceAgent.iconset -o "$APP_BUNDLE/Contents/Resources/AppIcon.icns" 2>/dev/null || true

# Touch bundle to refresh icon cache
touch "$APP_BUNDLE"

echo "==> App bundle created at: $APP_BUNDLE"
echo ""
echo "You can now:"
echo "  - Find 'Voice Agent' in ~/Applications"
echo "  - Open it from Finder or Spotlight"
echo "  - Drag it to your Dock"
