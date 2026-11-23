#!/bin/sh
# Builds a signed, notarized build/Encore-<version>.dmg and the Sparkle
# update feed build/appcast.xml.
#
#   ./release.sh                  # build, sign, notarize, staple
#   ./release.sh --publish        # also create GitHub release v<version>
#   ./release.sh --skip-notarize  # sign only, for testing the pipeline
#
# Before each release, raise CFBundleShortVersionString and CFBundleVersion in
# Info.plist. Sparkle compares CFBundleVersion to decide what is newer.
#
# One-time setup on the release Mac:
#   - Notarization credentials in the keychain profile NOTARY_PROFILE
#     (default "encore-notary"), see README.
#   - The Sparkle signing key in the login keychain under the account
#     "encore" (created by Sparkle's generate_keys --account encore).
set -eu
cd "$(dirname "$0")"

IDENTITY="${SIGN_IDENTITY:-Developer ID Application: Amartya Singh (FLKT9MQCZ6)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-encore-notary}"
REPO=decocereus/encore
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin
PUBLISH=0
NOTARIZE=1
for arg in "$@"; do
  case "$arg" in
    --publish) PUBLISH=1 ;;
    --skip-notarize) NOTARIZE=0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
if [ "$PUBLISH" = 1 ] && [ "$NOTARIZE" = 0 ]; then
  echo "--publish needs a notarized build" >&2
  exit 2
fi

VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist)
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" Info.plist)
TAG="v$VERSION"
APP=build/Encore.app
DMG="build/Encore-$VERSION.dmg"
APPCAST=build/appcast.xml

if [ "$PUBLISH" = 1 ]; then
  if [ -n "$(git status --porcelain)" ]; then
    echo "Commit your changes before publishing" >&2
    exit 1
  fi
  if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    echo "Release $TAG already exists. Raise the version in Info.plist." >&2
    exit 1
  fi
  git push origin HEAD
fi

echo "==> Building Encore $VERSION ($BUILD), arm64 + x86_64"
SIGN_IDENTITY="$IDENTITY" ./build.sh --universal
codesign --verify --deep --strict --verbose=2 "$APP"

echo "==> Making $DMG"
rm -f "$DMG"
STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/Encore.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -volname "Encore $VERSION" -srcfolder "$STAGE" -fs HFS+ -format UDZO "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [ "$NOTARIZE" = 1 ]; then
  echo "==> Notarizing (this usually takes a few minutes)"
  xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$DMG"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"
fi

echo "==> Writing $APPCAST"
# Prints: sparkle:edSignature="..." length="..."
SIGNATURE=$("$SPARKLE_BIN/sign_update" --account encore "$DMG")
cat > "$APPCAST" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Encore</title>
    <item>
      <title>Encore $VERSION</title>
      <pubDate>$(LC_ALL=C date -u "+%a, %d %b %Y %H:%M:%S +0000")</pubDate>
      <link>https://github.com/$REPO/releases/tag/$TAG</link>
      <sparkle:version>$BUILD</sparkle:version>
      <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>$MIN_OS</sparkle:minimumSystemVersion>
      <sparkle:fullReleaseNotesLink>https://github.com/$REPO/releases/tag/$TAG</sparkle:fullReleaseNotesLink>
      <enclosure url="https://github.com/$REPO/releases/download/$TAG/Encore-$VERSION.dmg" type="application/octet-stream" $SIGNATURE/>
    </item>
  </channel>
</rss>
EOF

if [ "$PUBLISH" = 1 ]; then
  echo "==> Publishing GitHub release $TAG"
  gh release create "$TAG" "$DMG" "$APPCAST" --repo "$REPO" \
    --target "$(git rev-parse HEAD)" --title "Encore $VERSION" --generate-notes
fi

echo "Done: $DMG"
