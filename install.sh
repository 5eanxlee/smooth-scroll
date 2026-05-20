#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Smooth Scroll"
EXECUTABLE_NAME="SmoothScroll"
CONFIGURATION="release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
DEST_DIR="${SMOOTH_SCROLL_INSTALL_DIR:-$HOME/Applications}"
APP_DEST="$DEST_DIR/$APP_NAME.app"

cd "$ROOT_DIR"
mkdir -p "$ROOT_DIR/.build/module-cache"
export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/module-cache"

swift build \
  -c "$CONFIGURATION" \
  --disable-sandbox \
  --cache-path "$ROOT_DIR/.build/swiftpm-cache" \
  --scratch-path "$ROOT_DIR/.build" \
  --manifest-cache local \
  --disable-dependency-cache

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
cp ".build/$CONFIGURATION/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

mkdir -p "$DEST_DIR"
rm -rf "$APP_DEST"
cp -R "$APP_DIR" "$APP_DEST"

if [[ "${SMOOTH_SCROLL_SKIP_OPEN:-0}" != "1" ]]; then
  open "$APP_DEST"
fi

echo "Installed: $APP_DEST"
