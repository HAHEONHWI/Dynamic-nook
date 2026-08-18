#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$PROJECT_ROOT/dist"
SOURCE_APP="$DIST_DIR/nook3h.app"
DMG_NAME="Dynamic-Nook-1.0.2.dmg"
VOLUME_NAME="Dynamic Nook"
FINAL_DMG="$DIST_DIR/$DMG_NAME"
RW_DMG="$DIST_DIR/Dynamic-Nook-rw.dmg"
STAGING_DIR="$DIST_DIR/dmg-staging"
BACKGROUND="$PROJECT_ROOT/Assets/DMG/DMGBackground.png"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
MOUNT_DIR=""

detach_image() {
  if [[ -n "$MOUNT_DIR" ]] && mount | grep -Fq "on $MOUNT_DIR "; then
    hdiutil detach "$MOUNT_DIR" -quiet || hdiutil detach "$MOUNT_DIR" -force -quiet || true
  fi
}
trap detach_image EXIT

detach_existing_project_images() {
  hdiutil info | awk -v project="$DIST_DIR" '
    $1 == "image-path" {
      tracked = index($0, project "/Dynamic-Nook") > 0
      next
    }
    tracked && /\/Volumes\// { print substr($0, index($0, "/Volumes/")) }
  ' | while IFS= read -r volume; do
    hdiutil detach "$volume" -quiet || hdiutil detach "$volume" -force -quiet
  done
}

detach_existing_named_volumes() {
  hdiutil info | awk -v prefix="/Volumes/$VOLUME_NAME" '
    index($0, prefix) {
      volume = substr($0, index($0, prefix))
      print volume
    }
  ' | while IFS= read -r volume; do
    hdiutil detach "$volume" -quiet || hdiutil detach "$volume" -force -quiet
  done
}

if [[ ! -f "$BACKGROUND" ]]; then
  echo "Missing DMG background: $BACKGROUND" >&2
  exit 1
fi

detach_existing_project_images
detach_existing_named_volumes
"$PROJECT_ROOT/script/build_and_run.sh" --verify

if [[ -n "$SIGN_IDENTITY" ]]; then
  codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$SOURCE_APP"
fi

rm -rf "$STAGING_DIR"
rm -f "$FINAL_DMG" "$RW_DMG"
mkdir -p "$STAGING_DIR/.background"
cp -R "$SOURCE_APP" "$STAGING_DIR/Dynamic Nook.app"
ln -s /Applications "$STAGING_DIR/Applications"
cp "$BACKGROUND" "$STAGING_DIR/.background/Background.png"

hdiutil create -quiet -size 40m -fs HFS+ -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -format UDRW -ov "$RW_DMG"
MOUNT_DIR="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"

if [[ -z "$MOUNT_DIR" ]]; then
  echo "Could not mount DMG." >&2
  exit 1
fi

osascript <<APPLESCRIPT
tell application "Finder"
  tell folder (POSIX file "$MOUNT_DIR" as alias)
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    -- Background is a 768×512 Finder canvas. Extra height accounts for Finder chrome.
    set bounds of container window to {100, 100, 868, 677}
    set viewOptions to icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 112
    set text size of viewOptions to 14
    set background picture of viewOptions to file ".background:Background.png"
    set position of item "Dynamic Nook.app" of container window to {175, 380}
    set position of item "Applications" of container window to {582, 380}
    update without registering applications
    delay 3
    close
    delay 2
  end tell
end tell
APPLESCRIPT

sync
for _ in {1..20}; do
  [[ -f "$MOUNT_DIR/.DS_Store" ]] && break
  sleep 0.25
done
if [[ ! -f "$MOUNT_DIR/.DS_Store" ]]; then
  echo "Finder did not persist the DMG layout (.DS_Store missing)." >&2
  exit 1
fi
hdiutil detach "$MOUNT_DIR" -quiet
MOUNT_DIR=""
hdiutil convert "$RW_DMG" -quiet -format UDZO -imagekey zlib-level=9 -ov -o "$FINAL_DMG"
rm -f "$RW_DMG"
hdiutil verify "$FINAL_DMG"

if [[ -n "$NOTARY_PROFILE" ]]; then
  xcrun notarytool submit "$FINAL_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
  xcrun stapler staple "$FINAL_DMG"
fi

echo "Created $FINAL_DMG"
