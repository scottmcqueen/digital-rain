#!/bin/bash
# Builds DigitalRain.saver and installs it for the current user.
set -euo pipefail
cd "$(dirname "$0")"

if ! xcrun --find swiftc >/dev/null 2>&1; then
  echo "Swift isn't installed. Run: xcode-select --install"; exit 1
fi

NAME=DigitalRain
OUT="build/$NAME.saver"
rm -rf build
mkdir -p "$OUT/Contents/MacOS"

xcrun swiftc -O -emit-library -module-name "$NAME" \
  -target arm64-apple-macos13.0 \
  -framework ScreenSaver -framework Metal -framework MetalKit \
  -framework CoreText -framework AppKit -framework QuartzCore \
  Sources/*.swift -o "$OUT/Contents/MacOS/$NAME"

cp Info.plist "$OUT/Contents/Info.plist"
codesign --force --sign - "$OUT"

DEST="$HOME/Library/Screen Savers"
mkdir -p "$DEST"
rm -rf "$DEST/$NAME.saver"
cp -R "$OUT" "$DEST/"

# macOS caches loaded screen savers; quit the hosts so the new build is picked up.
killall legacyScreenSaver 2>/dev/null || true
killall "System Settings" 2>/dev/null || true

echo "Installed to $DEST/$NAME.saver"
echo "Choose it in System Settings > Screen Saver."
