#!/bin/bash
# Builds a Release .app signed with the local self-signed identity and installs
# it into /Applications. No Apple account, notarization or Sparkle involved.
#
# Usage:
#   bun run build            build, install to /Applications, launch
#   bun run build --no-open  build and install, don't launch
#   bun run build --clean    discard the incremental build cache first

set -euo pipefail

cd "$(dirname "$0")/.."

WORKSPACE="macos/sol.xcworkspace"
SCHEME="release"
# Stable path so rebuilds are incremental. build/ is gitignored.
BUILD_DIR="build/release-derived"

OPEN_AFTER=1
for arg in "$@"; do
  case "$arg" in
    --no-open) OPEN_AFTER=0 ;;
    --clean) echo "==> Clearing build cache"; rm -rf "$BUILD_DIR" ;;
    *) echo "Unknown option: $arg" >&2; exit 1 ;;
  esac
done

echo "==> Building $SCHEME (Release)"
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  build

APP_PATH=$(find "$BUILD_DIR/Build/Products/Release" -maxdepth 1 -name "*.app" | head -1)

if [ -z "$APP_PATH" ]; then
  echo "!! No .app produced" >&2
  exit 1
fi

APP_NAME=$(basename "$APP_PATH")

echo "==> Verifying signature"
codesign --verify --deep --strict "$APP_PATH"

# Confirm the JS bundle actually made it in; without it the app opens blank.
if [ ! -f "$APP_PATH/Contents/Resources/main.jsbundle" ]; then
  echo "!! main.jsbundle missing from the app bundle" >&2
  exit 1
fi

if pgrep -f "/Applications/$APP_NAME/Contents/MacOS/" >/dev/null 2>&1; then
  echo "==> Quitting running instance"
  pkill -f "/Applications/$APP_NAME/Contents/MacOS/" || true
  sleep 1
fi

echo "==> Installing to /Applications/$APP_NAME"
rm -rf "/Applications/$APP_NAME"
cp -R "$APP_PATH" /Applications/

if [ "$OPEN_AFTER" = "1" ]; then
  echo "==> Launching"
  open "/Applications/$APP_NAME"
fi

echo "Done: /Applications/$APP_NAME"
