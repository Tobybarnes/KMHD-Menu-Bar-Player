# KMHD Menu Bar Player

A lightweight macOS menu bar app that streams [KMHD Jazz Radio](https://www.kmhd.org/). No dock icon, no window — just a radio icon in your status bar.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Version](https://img.shields.io/badge/version-2.0-green)

## Install

1. [Download the DMG](https://github.com/Tobybarnes/KMHD-Menu-Bar-Player/releases/latest)
2. Open the DMG and drag **KMHD Menu Bar Player** to your Applications folder
3. Launch it — a radio icon appears in your menu bar

Requires macOS 13.0 (Ventura) or later.

## Usage

- **Left-click** the menu bar icon to open the KMHD player
- **Right-click** for the context menu:
  - **About KMHD Menu Bar Player** — version and credits
  - **Check for Updates...** — checks GitHub for new releases
  - **Settings...** — icon style, launch at login
  - **Quit KMHD Menu Bar Player**

## Features

- Lives entirely in the menu bar — no dock icon, no window clutter
- Auto-reconnects when your network drops and comes back
- Optional KMHD logo icon (toggle in Settings)
- Launch at Login support
- Automatic update checking
- Native Swift — tiny footprint, instant launch, zero dependencies

## Building from source

```bash
git clone https://github.com/Tobybarnes/KMHD-Menu-Bar-Player.git
cd KMHD-Menu-Bar-Player
./build.sh
open build/KMHD-Menu-Bar-Player.app
```

## License

MIT
