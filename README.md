# ScreenPath

ScreenPath is a macOS menu bar utility that tracks screenshot files, keeps a short history of recent captures, and makes it easy to drag the latest screenshot or copy its path to any tool.

## What It Does

- Runs as a menu bar app.
- Watches the current macOS screenshot directory.
- Detects changes if the screenshot save location changes while the app is running.
- Tracks only files that match standard macOS screenshot names:
  - `Screenshot ...`
  - `Screen Shot ...`
- Keeps the latest screenshot path available from the menu.
- Shows recent screenshots in the menu.
- Supports drag-and-drop of the latest screenshot and recent screenshots.
- Stores a short history log at `~/Library/Application Support/ScreenPath/paths.log`.
- Caps the history log at 25 entries.

## Install

### Homebrew (recommended)

Once the Homebrew tap is published and the first release asset exists:

```bash
brew tap Ekwinder/screenpath
brew install --cask screenpath
```

### Run from source

```bash
git clone git@github.com:Ekwinder/screenpath.git
cd screenpath
swift run ScreenPath
```

Keep the process running. ScreenPath appears in the macOS menu bar.

## Build From Source

```bash
git clone git@github.com:Ekwinder/screenpath.git
cd screenpath
swift build -c release
./.build/release/ScreenPath
```

## Create A `.app` Bundle

If you want to distribute a standalone app bundle:

```bash
cd screenpath
swift build -c release

rm -rf dist
mkdir -p dist/ScreenPath.app/Contents/{MacOS,Resources}
cp .build/release/ScreenPath dist/ScreenPath.app/Contents/MacOS/ScreenPath
chmod +x dist/ScreenPath.app/Contents/MacOS/ScreenPath
```

Create `dist/ScreenPath.app/Contents/Info.plist` with your bundle metadata, then package it:

```bash
ditto -c -k --sequesterRsrc --keepParent dist/ScreenPath.app dist/ScreenPath.app.zip
```

## Menu Behaviour

The menu currently includes:

- `Copy Latest Path`
- `Drag Latest Screenshot`
- `Recent screenshots`
- `Options`
  - `Open paths.log`
  - `Reveal Latest in Finder`
  - `About ScreenPath`
  - `Version: 0.2`

## Requirements

- macOS 13 or later
- Xcode 15+ or another Swift 6-compatible toolchain

## Data Storage

- Log file: `~/Library/Application Support/ScreenPath/paths.log`
- Maximum log entries: `25`


## License

MIT
