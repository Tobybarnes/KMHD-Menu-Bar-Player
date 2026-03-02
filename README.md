# KMHD Widget

A lightweight macOS menu bar app that streams [KMHD Jazz Radio](https://www.kmhd.org/) from a popover. No dock icon, no window — just a radio icon in your status bar.

![macOS](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)

## Features

- Radio icon in the macOS menu bar
- Click to open/close the KMHD web player in a popover
- Click outside the popover to dismiss
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
open build/KMHD-Widget.app
```

### With Xcode

Open `KMHD-Widget.xcodeproj` in Xcode and hit Run.

## Launch at Login

To start KMHD Widget automatically when you log in:

1. Open **System Settings > General > Login Items**
2. Click **+** and select `KMHD-Widget.app` from the `build/` folder

Or copy it to `/Applications` first:

```bash
cp -r build/KMHD-Widget.app /Applications/
```

## How It Works

The app uses a standard macOS menu bar pattern:

- **`NSStatusItem`** — places the radio icon in the status bar
- **`NSPopover`** — hosts the player UI
- **`WKWebView`** — loads the KMHD web player at `https://audioplayer.opb.org/kmhd`
- **`LSUIElement`** — set in `Info.plist` to hide from the dock

The entire app is ~70 lines of Swift.

## License

MIT
