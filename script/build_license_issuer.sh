#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRODUCT="DynamicNookLicenseIssuer"
APP_NAME="Dynamic Nook License Issuer"
BUNDLE_ID="dev.dynamicnook.licenseissuer"
DIST_DIR="$PROJECT_ROOT/dist-admin"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -1)"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="-"
fi

cd "$PROJECT_ROOT"
xcrun swift build -c release --product "$PRODUCT"
BUILD_DIR="$(xcrun swift build -c release --show-bin-path)"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BUILD_DIR/$PRODUCT" "$MACOS/$PRODUCT"
chmod +x "$MACOS/$PRODUCT"
cp -R "$PROJECT_ROOT/Tools/DynamicNookLicenseIssuer/Resources/en.lproj" "$RESOURCES/"
cp -R "$PROJECT_ROOT/Tools/DynamicNookLicenseIssuer/Resources/ko.lproj" "$RESOURCES/"

plutil -create xml1 "$CONTENTS/Info.plist"
plutil -insert CFBundleExecutable -string "$PRODUCT" "$CONTENTS/Info.plist"
plutil -insert CFBundleIdentifier -string "$BUNDLE_ID" "$CONTENTS/Info.plist"
plutil -insert CFBundleName -string "$APP_NAME" "$CONTENTS/Info.plist"
plutil -insert CFBundleDisplayName -string "$APP_NAME" "$CONTENTS/Info.plist"
plutil -insert CFBundlePackageType -string APPL "$CONTENTS/Info.plist"
plutil -insert CFBundleShortVersionString -string 1.0 "$CONTENTS/Info.plist"
plutil -insert CFBundleVersion -string 1 "$CONTENTS/Info.plist"
plutil -insert LSMinimumSystemVersion -string 14.6 "$CONTENTS/Info.plist"
plutil -insert NSPrincipalClass -string NSApplication "$CONTENTS/Info.plist"

codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

echo "Created $APP_BUNDLE"
