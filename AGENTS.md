# Dynamic Nook agent guide

## Project

- Swift 6, SwiftPM, macOS 14.6+, SwiftUI/AppKit.
- Build: `./script/build_and_run.sh --verify`.
- Test: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`.
- Do not add external packages without explicit approval.

## Architecture

- Keep network, EventKit, CoreLocation, timer, and private-framework calls out of SwiftUI views.
- Register widgets in `Sources/NookClone/Models/WidgetType.swift`; wire services through `AppEnvironment`, layouts through `SettingsStore`, settings through `WidgetSettingsView`, and rendering through `ExpandedNookView`.
- Preserve stored page layouts and settings with migrations whenever persisted models change.
- All user-facing strings require matching `en.lproj` and `ko.lproj` entries.

## Private APIs and distribution

- Prefer public API. If private API is needed, isolate it behind a service/bridge, runtime-load symbols where possible, and provide a non-crashing fallback.
- `MediaRemote.framework` is allowed only through its bridge. Add a maintenance comment at private API use sites.
- Never put NEIS keys, signing credentials, notarization credentials, or user data in source control. NEIS key is local Keychain data.
- `script/create_dmg.sh` owns DMG packaging. Keep its background asset at `Assets/DMG/DMGBackground.png`.

## Safety

- Tray storage moves files into app-private temporary storage. Never delete an original unless a successful move has completed; keep drag-export and reveal paths working.
- Preserve keyboard focus without drawing unwanted focus rings.
- Verify build and tests after changes. Do not overwrite unrelated user changes.
