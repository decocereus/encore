#!/bin/sh
# Builds build/Encore.app. Pass --install to copy it to /Applications.
set -eu
cd "$(dirname "$0")"
xcrun swift build -c release
APP=build/Encore.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/Encore "$APP/Contents/MacOS/"
cp Info.plist "$APP/Contents/"
codesign --force --sign - "$APP"
if [ "${1:-}" = "--install" ]; then
  rm -rf /Applications/Encore.app
  cp -R "$APP" /Applications/
  echo "Installed /Applications/Encore.app"
else
  echo "Built $APP"
fi
