# KMHD Menu Bar Player

A lightweight macOS menu bar app that streams [KMHD Jazz Radio](https://www.kmhd.org/) from a popover. No dock icon, no window — just a radio icon in your status bar.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Version](https://img.shields.io/badge/version-2.0-green)

## Features

- Radio icon in the macOS menu bar
- Click to open/close the KMHD web player in a popover
- Right-click for context menu (About, Settings, Check for Updates, Quit)
- Network error handling with auto-reconnect
- Optional KMHD logo icon (toggle in Settings)
- Launch at Login (toggle in Settings)
- Automatic update checking via GitHub releases
- No dock icon — lives entirely in the menu bar
- Native Swift — tiny footprint, no Electron/Tauri overhead

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools (`xcode-select --install`)

## Build & Run

```bash
git clone https://github.com/tobybarnes/KMHD-widget.git
cd KMHD-widget
./build.sh
open build/KMHD-Menu-Bar-Player.app
```

### With Xcode

Open `KMHD-Menu-Bar-Player.xcodeproj` in Xcode and hit Run.

## Usage

- **Left-click** the menu bar icon to open/close the KMHD player
- **Right-click** the menu bar icon for the context menu:
  - **About KMHD Menu Bar Player** — version and credits
  - **Check for Updates...** — checks GitHub for new releases
  - **Settings...** — icon toggle, launch at login
  - **Quit KMHD Menu Bar Player**

## How It Works

The app uses standard macOS APIs:

- **`NSStatusItem`** — places the radio icon in the status bar
- **`NSPopover`** — hosts the player UI
- **`WKWebView`** — loads the KMHD web player at `https://audioplayer.opb.org/kmhd`
- **`NWPathMonitor`** — detects network changes for auto-reconnect
- **`SMAppService`** — manages launch at login
- **`LSUIElement`** — set in `Info.plist` to hide from the dock

~350 lines of Swift total. Still lightweight.

## License

MIT
