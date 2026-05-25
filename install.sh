#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="Mouse++"
EXECUTABLE_NAME="SmoothScroll"
CONFIGURATION="release"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
DEST_DIR="${SMOOTH_SCROLL_INSTALL_DIR:-$HOME/Applications}"
APP_DEST="$DEST_DIR/$APP_NAME.app"
BUNDLE_IDENTIFIER="com.local.SmoothScroll"
OLD_APP_DEST="$DEST_DIR/Smooth Scroll.app"
SIGN_IDENTITY="${SMOOTH_SCROLL_SIGN_IDENTITY:-}"
ICON_SOURCE="$ROOT_DIR/mouse-svgrepo-com.svg"
UPDATE_FROM_APP="${MOUSE_PLUS_PLUS_UPDATE_FROM_APP:-0}"

notify_from_app() {
  [[ "$UPDATE_FROM_APP" == "1" ]] || return 0
  /usr/bin/osascript -e "display notification \"$1\" with title \"Mouse++\"" >/dev/null 2>&1 || true
}

handle_exit() {
  local exit_status="$?"
  if [[ "$exit_status" -ne 0 ]]; then
    notify_from_app "Update failed. See Library/Logs/Mouse++/update.log."
  fi
}

trap handle_exit EXIT

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F '"' '/Apple Development:/ { print $2; exit }')"
fi

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

quit_running_app() {
  osascript <<APPLESCRIPT >/dev/null 2>&1 || true
tell application id "$BUNDLE_IDENTIFIER" to quit
APPLESCRIPT

  for _ in {1..30}; do
    if ! pgrep -x "$EXECUTABLE_NAME" >/dev/null 2>&1; then
      return
    fi
    sleep 0.1
  done

  pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true
}

render_icon_png() {
  local size="$1"
  local output="$2"

  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$size" -h "$size" "$ICON_SOURCE" -o "$output"
    return
  fi

  if command -v magick >/dev/null 2>&1; then
    magick "$ICON_SOURCE" -resize "${size}x${size}" "$output"
    return
  fi

  if command -v convert >/dev/null 2>&1; then
    convert "$ICON_SOURCE" -resize "${size}x${size}" "$output"
    return
  fi

  echo "Missing SVG renderer. Install librsvg or ImageMagick to build the app icon." >&2
  exit 1
}

build_app_icon() {
  [[ -f "$ICON_SOURCE" ]] || return

  local iconset_dir="$DIST_DIR/AppIcon.iconset"
  rm -rf "$iconset_dir"
  mkdir -p "$iconset_dir"

  render_icon_png 16 "$iconset_dir/icon_16x16.png"
  render_icon_png 32 "$iconset_dir/icon_16x16@2x.png"
  render_icon_png 32 "$iconset_dir/icon_32x32.png"
  render_icon_png 64 "$iconset_dir/icon_32x32@2x.png"
  render_icon_png 128 "$iconset_dir/icon_128x128.png"
  render_icon_png 256 "$iconset_dir/icon_128x128@2x.png"
  render_icon_png 256 "$iconset_dir/icon_256x256.png"
  render_icon_png 512 "$iconset_dir/icon_256x256@2x.png"
  render_icon_png 512 "$iconset_dir/icon_512x512.png"
  render_icon_png 1024 "$iconset_dir/icon_512x512@2x.png"

  iconutil -c icns "$iconset_dir" -o "$RESOURCES_DIR/AppIcon.icns"
  cp "$ICON_SOURCE" "$RESOURCES_DIR/AppIcon.svg"
}

cd "$ROOT_DIR"
notify_from_app "Updating Mouse++..."

swift build \
  -c "$CONFIGURATION" \
  --disable-sandbox \
  --cache-path "$ROOT_DIR/.build/swiftpm-cache" \
  --scratch-path "$ROOT_DIR/.build" \
  --manifest-cache local \
  --disable-dependency-cache

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/$CONFIGURATION/$EXECUTABLE_NAME" "$MACOS_DIR/$EXECUTABLE_NAME"
cp "Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
build_app_icon
printf "%s\n" "$ROOT_DIR" > "$RESOURCES_DIR/SourceRoot.path"
printf "%s\n" "$DEST_DIR" > "$RESOURCES_DIR/InstallDirectory.path"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"
codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null

mkdir -p "$DEST_DIR"
quit_running_app
rm -rf "$APP_DEST"
rm -rf "$OLD_APP_DEST"
cp -R "$APP_DIR" "$APP_DEST"

if [[ "${SMOOTH_SCROLL_SKIP_OPEN:-0}" != "1" ]]; then
  open "$APP_DEST"
fi

echo "Updated: $APP_DEST"
echo "Signed with: $SIGN_IDENTITY"
notify_from_app "Updated and reopened."
