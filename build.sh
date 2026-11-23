#!/bin/sh
# Builds build/Encore.app.
#
#   ./build.sh              # this Mac's architecture, signed ad hoc
#   ./build.sh --install    # also copies it to /Applications
#   ./build.sh --universal  # arm64 + x86_64
#
# Set SIGN_IDENTITY to sign with a real certificate (release.sh does this).
set -eu
cd "$(dirname "$0")"

INSTALL=0
ARCH_FLAGS=""
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --universal) ARCH_FLAGS="--arch arm64 --arch x86_64" ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

# shellcheck disable=SC2086
xcrun swift build -c release $ARCH_FLAGS
# shellcheck disable=SC2086
BIN_DIR=$(xcrun swift build -c release $ARCH_FLAGS --show-bin-path)

APP=build/Encore.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
cp "$BIN_DIR/Encore" "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
ditto "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"

IDENTITY="${SIGN_IDENTITY:--}"
# Hardened runtime and a timestamp are needed for notarization. An ad hoc
# build can't use the hardened runtime: library validation rejects Sparkle.
FLAGS="--options runtime --timestamp"
[ "$IDENTITY" = "-" ] && FLAGS=""
# shellcheck disable=SC2086
sign() { codesign --force $FLAGS --sign "$IDENTITY" "$@"; }
# Sign Sparkle's nested helpers from the inside out, then the app.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
sign "$SPARKLE/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
sign "$SPARKLE/Autoupdate"
sign "$SPARKLE/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"
sign "$APP"

if [ "$INSTALL" = 1 ]; then
  rm -rf /Applications/Encore.app
  cp -R "$APP" /Applications/
  echo "Installed /Applications/Encore.app"
else
  echo "Built $APP"
fi
