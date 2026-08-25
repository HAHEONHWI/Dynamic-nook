#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="nook3h"
LEGACY_APP_NAME="NookClone"
BUNDLE_ID="dev.nookclone.app"
MIN_SYSTEM_VERSION="14.6"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
LICENSE_SERVER_URL="${LICENSE_SERVER_URL:-https://dynamic-nook-license.2010haheon.workers.dev}"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
LEGACY_APP_BUNDLE="$DIST_DIR/$LEGACY_APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
MODULE_CACHE="${TMPDIR:-/tmp}/nookclone-module-cache"
MEDIAREMOTE_ADAPTER_ROOT="$PROJECT_ROOT/ThirdParty/MediaRemoteAdapter"
MEDIAREMOTE_ADAPTER_FRAMEWORK="$APP_FRAMEWORKS/MediaRemoteAdapter.framework"
MEDIAREMOTE_ADAPTER_BINARY="$MEDIAREMOTE_ADAPTER_FRAMEWORK/MediaRemoteAdapter"
MEDIAREMOTE_ADAPTER_RESOURCES="$APP_RESOURCES/MediaRemoteAdapter"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
export CLANG_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFT_MODULE_CACHE_PATH="$MODULE_CACHE"
export SWIFTPM_MODULECACHE_OVERRIDE="$MODULE_CACHE"

# Stable signing identity matters for TCC permissions. Ad-hoc signatures use a
# changing cdhash, so Calendar/Reminders/Camera access can appear to reset after
# every rebuild. Prefer an explicit identity, then a local Apple Development one.
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
  echo "warning: no Apple Development signing identity found; TCC permissions may reset after rebuild" >&2
fi

mkdir -p "$MODULE_CACHE"
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
pkill -x "$LEGACY_APP_NAME" >/dev/null 2>&1 || true

cd "$PROJECT_ROOT"
xcrun swift build -c release --product "$APP_NAME"
BUILD_BINARY="$(xcrun swift build -c release --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE" "$LEGACY_APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
cp -R "$PROJECT_ROOT/Sources/NookClone/Resources/en.lproj" "$APP_RESOURCES/"
cp -R "$PROJECT_ROOT/Sources/NookClone/Resources/ko.lproj" "$APP_RESOURCES/"
cp "$PROJECT_ROOT/Sources/NookClone/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
cp "$PROJECT_ROOT/LICENSE" "$APP_RESOURCES/LICENSE.txt"

MEDIAREMOTE_ADAPTER_SOURCES=(
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/env.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/get.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/globals.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/keys.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/now_playing.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/repeat.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/seek.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/send.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/shuffle.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/speed.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/adapter/stream.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/private/MediaRemote.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/utility/Debounce.m"
  "$MEDIAREMOTE_ADAPTER_ROOT/src/utility/helpers.m"
)

mkdir -p "$MEDIAREMOTE_ADAPTER_FRAMEWORK" "$MEDIAREMOTE_ADAPTER_RESOURCES"
xcrun clang \
  -dynamiclib \
  -fobjc-arc \
  -fblocks \
  -fvisibility=default \
  -mmacosx-version-min="$MIN_SYSTEM_VERSION" \
  -I "$MEDIAREMOTE_ADAPTER_ROOT/include" \
  -I "$MEDIAREMOTE_ADAPTER_ROOT/src" \
  "${MEDIAREMOTE_ADAPTER_SOURCES[@]}" \
  -framework Foundation \
  -framework AppKit \
  -framework UniformTypeIdentifiers \
  -o "$MEDIAREMOTE_ADAPTER_BINARY"
chmod +x "$MEDIAREMOTE_ADAPTER_BINARY"
cp "$MEDIAREMOTE_ADAPTER_ROOT/bin/mediaremote-adapter.pl" "$MEDIAREMOTE_ADAPTER_RESOURCES/"
cp "$MEDIAREMOTE_ADAPTER_ROOT/LICENSE" "$MEDIAREMOTE_ADAPTER_RESOURCES/LICENSE.txt"
chmod +x "$MEDIAREMOTE_ADAPTER_RESOURCES/mediaremote-adapter.pl"
codesign --force --sign "$SIGN_IDENTITY" "$MEDIAREMOTE_ADAPTER_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>$APP_NAME</string>
  <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
  <key>CFBundleName</key><string>Dynamic Nook</string>
  <key>CFBundleDisplayName</key><string>Dynamic Nook</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key>
  <array><string>en</string><string>ko</string></array>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0.5</string>
  <key>CFBundleVersion</key><string>105</string>
  <key>CFBundleGetInfoString</key><string>Dynamic Nook 1.0.5</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>NSCalendarsFullAccessUsageDescription</key><string>nook3h shows your upcoming events in the notch calendar widget.</string>
  <key>NSRemindersFullAccessUsageDescription</key><string>nook3h shows and updates reminders in the notch widget.</string>
  <key>NSLocationUsageDescription</key><string>nook3h uses your location to show local weather.</string>
  <key>NSCameraUsageDescription</key><string>nook3h uses the camera only while the Mirror widget is visible.</string>
  <key>NSAppleEventsUsageDescription</key><string>nook3h controls Apple Music when system media controls are unavailable.</string>
  <key>NSAppTransportSecurity</key>
  <dict>
    <key>NSExceptionDomains</key>
    <dict>
      <key>comci.net</key>
      <dict>
        <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
        <key>NSIncludesSubdomains</key><true/>
      </dict>
      <key>xn--s39aj90b0nb2xw6xh.kr</key>
      <dict>
        <key>NSExceptionAllowsInsecureHTTPLoads</key><true/>
      </dict>
    </dict>
  </dict>
</dict>
</plist>
PLIST

if [[ -n "$LICENSE_SERVER_URL" ]]; then
  plutil -insert DynamicNookLicenseServerURL -string "$LICENSE_SERVER_URL" "$INFO_PLIST"
fi

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
