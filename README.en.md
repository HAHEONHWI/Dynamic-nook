<div align="center">

![Dynamic Nook hero](Assets/README/dynamic-nook-hero.png)

# Dynamic Nook

**Your MacBook notch, made useful.**

Native macOS utility that turns the notch into customizable dashboards, system controls, and a temporary file tray.

[한국어](README.md) · **English**

![macOS 14.6+](https://img.shields.io/badge/macOS-14.6%2B-111111?logo=apple)
![Swift 6](https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white)
![Release](https://img.shields.io/badge/release-1.0.5-168BFF)

[![Download DMG](https://img.shields.io/badge/Download_DMG-1.0.5-0A84FF?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/HAHEONHWI/Dynamic-nook/releases/download/v1.0.5/Dynamic-Nook-1.0.5.dmg)

</div>

> [!NOTE]
> Dynamic Nook is a direct-distribution application, not a Mac App Store application. It is source-available for noncommercial use only.

## What it does

- **Dynamic notch:** Hover, click, or swipe to expand the notch. System media can appear as a compact Dynamic Island with playback controls.
- **Custom Nook pages:** Add or remove pages, place any widget on any page, reorder widgets, resize cells, and restore the last opened page.
- **File tray:** Drop files onto the notch to move them into temporary app storage. Reveal, drag out, share, AirDrop, or restore them later.
- **System integration:** Control audio output, displays, brightness, keep-awake sessions, windows, battery, and connected devices.
- **Bilingual UI:** English and Korean. System language is used by default; unsupported languages fall back to English.

## Widgets

| Productivity | System | Information |
| --- | --- | --- |
| Calendar and nearest upcoming event | Media player | Weather and six-hour forecast |
| Reminders with quick add | Audio output and volume | Comcigan timetable / NEIS meals and school schedule |
| Focus timer | Display control | Network, Wi-Fi, VPN, public IP |
| Countdown timer and stopwatch | Keep Awake | Exchange rates and KR/US stocks |
| Markdown notes | CPU, memory, and disk monitor | GitHub activity and local Git status |
| Shortcuts and quick actions | Battery and power | Connected Bluetooth, USB, and removable drives |
| Clipboard history | Window layout | Camera mirror |

## Install

1. Download [Dynamic Nook 1.0.5 DMG](https://github.com/HAHEONHWI/Dynamic-nook/releases/download/v1.0.5/Dynamic-Nook-1.0.5.dmg).
2. Open the DMG and drag **Dynamic Nook.app** into **Applications**.
3. Launch Dynamic Nook and grant only the permissions needed by the widgets you use.

To update, quit Dynamic Nook and replace the existing app in Applications with the app from the new DMG. Settings remain in `UserDefaults` and secrets remain in Keychain.

> [!WARNING]
> Builds without Developer ID signing and Apple notarization may be blocked by Gatekeeper on other Macs. The repository build can use a local Apple Development identity, but public distribution should use `Developer ID Application` and notarization.

## Permissions and privacy

The Permissions page shows current access state and provides request or System Settings buttons.

- **Calendar / Reminders:** Read schedules and update reminder completion.
- **Location:** Resolve local weather. Manual location works when access is denied.
- **Camera:** Used only while the Mirror widget is visible.
- **Accessibility:** Required only for window arrangement.
- **Automation:** Apple Music fallback control when system media control is unavailable.
- **Clipboard:** Up to 20 recent items kept in memory only; app restart clears them. Password-like content is excluded.
- **NEIS:** API key is stored in local Keychain, never source control. [Get a NEIS API key](https://open.neis.go.kr/portal/guide/actKeyPage.do).
- **GitHub:** Public profile and contribution data only. No GitHub token is stored; unauthenticated API limits apply.

## Technology

- Swift 6, SwiftUI, AppKit, SwiftPM
- macOS 14.6+
- EventKit, CoreLocation, CoreAudio, IOKit, Accessibility, CoreWLAN
- Open-Meteo for weather; NEIS for school data
- Yahoo Finance chart data for stocks; Frankfurter for exchange rates
- Runtime-loaded `MediaRemote.framework` for macOS System Now Playing

Private API code is isolated behind service and bridge layers, loaded defensively, and given non-crashing fallbacks. macOS updates may require maintenance.

## Build and test

```bash
./script/build_and_run.sh --verify
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

The run script builds a release-style app bundle in `dist/nook3h.app`, signs it with an available Apple Development identity when possible, launches it, and verifies the process.

## Create a DMG

```bash
./script/create_dmg.sh
```

Output: `dist/Dynamic-Nook-1.0.5.dmg`

For a public direct-distribution build:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="notarytool-profile" \
./script/create_dmg.sh
```

The script uses `Assets/DMG/DMGBackground.png`, creates a drag-to-Applications layout, and verifies the final disk image.

## Current status

Dynamic Nook **1.0.5**. Core features work, but private-framework behavior, DDC/CI display support, hardware-specific sleep prevention, and unnotarized distribution can vary by Mac and macOS version.

## License

Released under the [PolyForm Noncommercial License 1.0.0](LICENSE). Noncommercial personal study, research, hobby use, modification, and redistribution are permitted. Commercial use requires separate written permission from the copyright holder.

Copyright © 2026 Ha HeonHwi
