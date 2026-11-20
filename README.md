# KMHD Menu Bar Player

A lightweight macOS menu bar app that streams [KMHD Jazz Radio](https://www.kmhd.org/). No dock icon, no window — just a radio icon in your status bar.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Version](https://img.shields.io/badge/version-2.1-green)

## Install

1. [Download the DMG](https://github.com/Tobybarnes/KMHD-Menu-Bar-Player/releases/latest)
2. Open the DMG and drag **KMHD Menu Bar Player** to your Applications folder
3. Launch it — a radio icon appears in your menu bar

Requires macOS 13.0 (Ventura) or later.

> **Note:** Because this app is not notarized, macOS Sequoia will block it on first launch. To open it:
> 1. Click **Done** on the warning (don't move to trash)
> 2. Go to **System Settings → Privacy & Security**
> 3. Scroll down and click **Open Anyway**
> 4. Authenticate and launch — you only need to do this once.

## Usage

- **Left-click** the menu bar icon to play or pause. The icon fills in while KMHD is playing.
- **Right-click** (or Control-click) for the menu:
  - What's playing now, and the last few tracks from the KMHD playlist
  - Play/Pause and volume
  - **Full Playlist on KMHD.org**
  - **Settings…** — KMHD logo icon, track name in the menu bar, launch at login
  - **Check for Updates…**, **About**, **Quit**
- Your keyboard's play/pause key, AirPods and Control Center's Now Playing control it too.

## Features

- Lives entirely in the menu bar — no dock icon, no window clutter
- One click to play: streams natively, no web player
- Shows what's playing, from KMHD's own playlist
- Auto-reconnects after network drops, stalls and sleep
- Optional KMHD logo icon (toggle in Settings)
- Launch at Login support
- Checks for updates once a day, and only speaks up when there is one
- Native Swift — tiny footprint, instant launch, zero dependencies

## Building from source

```bash
git clone https://github.com/Tobybarnes/KMHD-Menu-Bar-Player.git
cd KMHD-Menu-Bar-Player
./build.sh
open build/KMHD-Menu-Bar-Player.app
```

`./build.sh --dmg` also makes a DMG for distribution. The version lives in `KMHD-Menu-Bar-Player/Info.plist`; keep `MARKETING_VERSION` in the Xcode project and the badge above in step with it.

## License

MIT
